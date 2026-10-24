<# Sin -Aplicar sólo valida y muestra el alcance. Con -Aplicar respalda, crea el
   devengo fiscal 5397, renueva caché de BC y recalcula enero de los afectados.
   Cada mes se rehace mediante AL en una transacción; no cambia estados por SQL. #>
[CmdletBinding()]
param([switch]$Aplicar)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$sql = Get-Content (Join-Path $PSScriptRoot 'CrearObraSocialAdicionalSAC.sql') -Raw
$conexion = [System.Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
try {
    $conexion.Open()
    $comando = $conexion.CreateCommand()
    $comando.CommandTimeout = 120
    $comando.CommandText = $sql
    $null = $comando.ExecuteNonQuery() # Las guardas también corren en preview.
    $comando.CommandText = @'
SELECT h.[No_ Empleado] Empleado,MIN(h.No_) Documento
FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
JOIN [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l ON l.[No_ Liquidación]=h.No_
WHERE h.[Cód_ Período]='202601' AND h.Estado=1 AND h.[Cód_ Tipo Liq_]<>'LIQ_FINAL'
AND l.[Cód_ Concepto] IN ('6032','6037') AND l.Importe<>0
AND EXISTS(SELECT 1 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
 WHERE s.[No_ Liquidación]=h.No_ AND s.[Cód_ Concepto]='4750' AND s.Importe<>0)
GROUP BY h.[No_ Empleado]
'@
    $tabla = [System.Data.DataTable]::new()
    $lector = $comando.ExecuteReader()
    try { $tabla.Load($lector) } finally { $lector.Dispose() }
    $casos = @($tabla.Rows | ForEach-Object { [pscustomobject]@{ Empleado=[string]$_.Empleado; Documento=[string]$_.Documento } })
    if ($casos.Count -eq 0) { throw 'No hay meses calculados con adicional y devengo de SAC; revisar alcance.' }
    $filtros = @()
    for ($i=0; $i -lt $casos.Count; $i++) {
        $nombre = '@Emp' + $i
        $filtros += $nombre
        $null = $comando.Parameters.Add($nombre,[System.Data.SqlDbType]::NVarChar,20)
        $comando.Parameters[$nombre].Value = $casos[$i].Empleado
    }
    $scope = 'h.[No_ Empleado] IN (' + ($filtros -join ',') + ')'
    $comando.CommandText = 'SELECT COUNT(*) FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h WHERE ' + $scope + ' AND h.[Fecha Liquidación]>=''20260201'' AND h.Estado<>0'
    if ([int]$comando.ExecuteScalar() -gt 0) { throw 'Hay meses posteriores calculados: usar recálculo de cadena completa.' }
    Write-Output ('Devengo 5397 desde 01/01/2026; meses de empleados a recalcular: ' + $casos.Count)
    if (-not $Aplicar) { return }
    $backup = Join-Path $raiz ('.snapshots/obra-social-sac-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $null = New-Item -ItemType Directory -Path $backup
    $casos | ConvertTo-Json | Set-Content (Join-Path $backup 'casos.json') -Encoding utf8
    $consultas = [ordered]@{
        conceptos = 'SELECT * FROM [ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Código IN (''4753'',''5397'')'
        fracciones = 'SELECT * FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (''4753'',''5397'')'
        cabeceras = 'SELECT h.* FROM [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h WHERE ' + $scope
        lineas = 'SELECT l.* FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.No_=l.[No_ Liquidación] WHERE ' + $scope
        variables = 'SELECT v.* FROM [ArbuTest$Resumen Variable Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v JOIN [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.No_=v.[No_ Liquidación] WHERE ' + $scope
        francos = 'SELECT f.* FROM [ArbuTest$Movimiento Franco Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f JOIN [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.No_=f.[No_ Liquidación] WHERE ' + $scope
    }
    foreach ($etapa in @('antes','despues')) {
        foreach ($entrada in $consultas.GetEnumerator()) {
            $comando.CommandText = 'SELECT (' + $entrada.Value + ' FOR JSON PATH, INCLUDE_NULL_VALUES)'
            $contenido = [string]$comando.ExecuteScalar()
            if ([string]::IsNullOrEmpty($contenido)) { $contenido = '[]' }
            $null = ConvertFrom-Json -InputObject $contenido
            [IO.File]::WriteAllText((Join-Path $backup ($etapa + '-' + $entrada.Key + '.json')), $contenido, [Text.UTF8Encoding]::new($false))
        }
        if ($etapa -eq 'despues') { break }
        Write-Output "Respaldo: $backup"
        $comando.CommandText = $sql.Replace('DECLARE @Aplicar bit=0,','DECLARE @Aplicar bit=1,')
        $null = $comando.ExecuteNonQuery()
        # SQL directo: la caché del service tier debe renovarse antes del primer recálculo.
        $servicio = [System.ServiceProcess.ServiceController]::new('MicrosoftDynamicsNavServer$BC252','mimir')
        try {
            $servicio.Stop()
            $servicio.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,[timespan]::FromSeconds(60))
            $servicio.Start()
            $servicio.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(60))
        } finally { $servicio.Dispose() }
        Write-Output 'Servicio BC252 reiniciado; nueva configuración disponible.'
        foreach ($caso in $casos) {
            & (Join-Path $PSScriptRoot 'RecalcularMesEmpleado.ps1') -Numero $caso.Documento
        }
    }
    Write-Output 'Configuración aplicada; meses afectados recalculados y respaldados.'
} finally { $conexion.Dispose() }
