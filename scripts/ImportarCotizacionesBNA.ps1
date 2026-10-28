<#
.SYNOPSIS
    Trae las cotizaciones históricas de billetes del Banco Nación y las carga en la tabla de tipos de cambio de BC.

.DESCRIPTION
    La página "Cotizaciones históricas de las principales monedas" del BNA descarga un CSV con un GET sin sesión ni token:
    https://www.bna.com.ar/Cotizador/DescargarPorFecha?id=billetes&fechaDesde=dd/MM/aaaa&fechaHasta=dd/MM/aaaa&idMonedaDescarga=<id>
    con id 12 = Euro, 22 = Dólar U.S.A, 23 = Real. Compra va al TC comprador ("Valor T.C. relacionada") y Venta al TC vendedor
    ("Valor T.C. ajustes relacionada"), que es lo que ya tienen las filas del USD (29/4/2026: 1.365 / 1.415).

    Hace upsert por fecha: actualiza las filas que existen y clona una fila de la misma moneda para las que faltan. Los días sin
    cotización (fines de semana y feriados) no se cargan: BC toma la última fila con fecha <= la de la liquidación.
    Sin -Aplicar sólo lista lo que haría. Escribe por SQL directo: después hay que reiniciar el servicio (la caché del service tier
    no se entera).

.PARAMETER Moneda   EUR o USD.
.PARAMETER Desde    Primer día, aaaa-mm-dd.
.PARAMETER Hasta    Último día, aaaa-mm-dd (por defecto hoy).
.PARAMETER Aplicar  Escribe en la base. Sin esto es una previsualización.
.PARAMETER Servidor Instancia SQL de BC (por defecto mimir).

.EXAMPLE
    pwsh scripts/ImportarCotizacionesBNA.ps1 -Moneda EUR -Desde 2026-04-01
    pwsh scripts/ImportarCotizacionesBNA.ps1 -Moneda EUR -Desde 2026-04-01 -Aplicar
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('EUR', 'USD')][string]$Moneda,
    [Parameter(Mandatory)][datetime]$Desde,
    [datetime]$Hasta = (Get-Date).Date,
    [switch]$Aplicar,
    [string]$Servidor = 'mimir',
    [string]$Base = 'Migr2013R2'
)

$ErrorActionPreference = 'Stop'
$ci = [Globalization.CultureInfo]::InvariantCulture
$idBna = @{ EUR = 12; USD = 22 }[$Moneda]
$sqlcmd = 'C:\Program Files\SqlCmd\sqlcmd.exe'
$tabla = 'dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]'

# ---------------------------------------------------------------- descarga
$url = 'https://www.bna.com.ar/Cotizador/DescargarPorFecha?id=billetes&fechaDesde={0}&fechaHasta={1}&idMonedaDescarga={2}' -f `
    $Desde.ToString('dd/MM/yyyy'), $Hasta.ToString('dd/MM/yyyy'), $idBna
$csv = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
if ($csv -is [byte[]]) { $csv = [Text.Encoding]::UTF8.GetString($csv) }
$filas = @()
foreach ($l in ($csv -split "`r?`n" | Select-Object -Skip 1)) {
    $f = $l.Split(';')
    if ($f.Count -lt 4 -or -not $f[1].Trim()) { continue }
    $filas += [pscustomobject]@{
        Fecha  = [datetime]::ParseExact($f[1].Trim(), 'd/M/yyyy', $ci)
        Compra = [decimal]::Parse($f[2].Trim().Replace(',', '.'), $ci)
        Venta  = [decimal]::Parse($f[3].Trim().Replace(',', '.'), $ci)
    }
}
if (-not $filas) { throw ("El BNA no devolvió cotizaciones para {0} entre {1:yyyy-MM-dd} y {2:yyyy-MM-dd}." -f $Moneda, $Desde, $Hasta) }
Write-Host ("BNA: {0} filas de {1}, del {2:yyyy-MM-dd} al {3:yyyy-MM-dd}" -f $filas.Count, $Moneda, ($filas[0].Fecha), ($filas[-1].Fecha))

# ---------------------------------------------------------------- SQL
$valores = ($filas | ForEach-Object { "('{0:yyyyMMdd}',{1},{2})" -f $_.Fecha, $_.Compra.ToString($ci), $_.Venta.ToString($ci) }) -join ','
$escribir = if ($Aplicar) { 1 } else { 0 }
$sql = @"
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @M nvarchar(10) = N'$Moneda', @Aplicar bit = $escribir;
DECLARE @R TABLE (f date PRIMARY KEY, compra decimal(38,20), venta decimal(38,20));
INSERT @R VALUES $valores;
DECLARE @Plantilla date = (SELECT MAX([Starting Date]) FROM $tabla WHERE [Currency Code] = @M);
IF @Plantilla IS NULL BEGIN RAISERROR('No hay ninguna fila de %s para usar de plantilla.', 16, 1, @M); RETURN; END;
SELECT r.f, r.compra, r.venta,
       CASE WHEN x.[Starting Date] IS NULL THEN 'INSERTA' WHEN x.[Relational Exch_ Rate Amount] = r.compra AND x.[Relational Adjmt Exch Rate Amt] = r.venta THEN 'igual' ELSE 'ACTUALIZA' END accion,
       x.[Relational Exch_ Rate Amount] compra_hoy, x.[Relational Adjmt Exch Rate Amt] venta_hoy
INTO #Plan FROM @R r LEFT JOIN $tabla x ON x.[Currency Code] = @M AND x.[Starting Date] = r.f;
SELECT accion, COUNT(*) filas FROM #Plan GROUP BY accion;
SELECT TOP 15 CONVERT(varchar(10), f, 120) fecha, compra, venta, accion, compra_hoy, venta_hoy FROM #Plan WHERE accion <> 'igual' ORDER BY f;
IF @Aplicar = 1
BEGIN
  BEGIN TRAN;
  UPDATE x SET [Relational Exch_ Rate Amount] = p.compra, [Relational Adjmt Exch Rate Amt] = p.venta, [`$systemModifiedAt] = SYSUTCDATETIME()
    FROM $tabla x JOIN #Plan p ON p.f = x.[Starting Date] WHERE x.[Currency Code] = @M AND p.accion = 'ACTUALIZA';
  SELECT @@ROWCOUNT AS actualizadas;
  DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'$tabla') AND c.name <> 'timestamp' AND c.name NOT LIKE '`$system%');
  DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Starting Date' THEN N'p.f' WHEN N'Relational Exch_ Rate Amount' THEN N'p.compra' WHEN N'Relational Adjmt Exch Rate Amt' THEN N'p.venta' ELSE N't.' + QUOTENAME(c.name) END, ',')
    FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'$tabla') AND c.name <> 'timestamp' AND c.name NOT LIKE '`$system%');
  DECLARE @sql nvarchar(max) = N'INSERT $tabla (' + @cc + N',[`$systemId],[`$systemCreatedAt],[`$systemCreatedBy],[`$systemModifiedAt],[`$systemModifiedBy]) SELECT ' + @cs
    + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM #Plan p CROSS JOIN $tabla t WHERE p.accion = ''INSERTA'' AND t.[Currency Code] = @M AND t.[Starting Date] = @Plantilla;';
  EXEC sp_executesql @sql, N'@M nvarchar(10), @Plantilla date', @M = @M, @Plantilla = @Plantilla;
  SELECT @@ROWCOUNT AS insertadas;
  COMMIT;
END
ELSE PRINT 'Previsualización: no se escribió nada. Agregá -Aplicar para cargar.';
"@
$archivo = Join-Path $env:TEMP ("cotizaciones_bna_{0}.sql" -f $Moneda)
Set-Content -Path $archivo -Value $sql -Encoding UTF8
& $sqlcmd -S $Servidor -E -C -d $Base -W -s '|' -i $archivo
if ($LASTEXITCODE -ne 0) { throw "sqlcmd terminó con código $LASTEXITCODE" }
if ($Aplicar) { Write-Host 'Listo. Reiniciá el servicio de BC (la caché no ve los cambios hechos por SQL).' }
