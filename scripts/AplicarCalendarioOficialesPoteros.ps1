[CmdletBinding()]
param(
    [switch]$Aplicar,
    [string]$PlanPath = (Join-Path $PSScriptRoot '../.snapshots/oficiales-poteros-20261013/agente-maquinas/plan-calendario175.json'),
    [string]$Servidor = 'tcp:mimir.arbumasa.com,1433',
    [string]$BaseDatos = 'Migr2013R2'
)

# Por omisión se ensaya dentro de una transacción y se revierte. Sólo -Aplicar confirma.
# No recalcula recibos. El calendario nuevo reproduce BASE excepto el 8 y 9 de febrero de 2026.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$plan = Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($plan.version_plan -ne 1 -or $plan.empresa -ne 'ArbuTest' -or $plan.convenio -ne '175/75' -or
    $plan.calendario_origen -ne 'BASE' -or $plan.calendario_destino -ne 'CCT-175') {
    throw 'El plan no corresponde al calendario preparado y revisado para 175/75.'
}
if ($BaseDatos -ine [string]$plan.base) { throw 'La base solicitada no coincide con la base del plan.' }
$servidorEsperado = 'tcp:' + [string]$plan.servidor + ',1433'
if ($Servidor -ine $servidorEsperado) { throw 'El servidor debe coincidir con el host y puerto del plan.' }
$tablaCabNombre = [string]$plan.esquema.calendar_header_table
$tablaCambiosNombre = [string]$plan.esquema.calendar_changes_table
$tablaConvenioNombre = [string]$plan.esquema.convenio_table
function NombreTabla([string]$nombre) { '[dbo].[' + $nombre.Replace(']', ']]') + ']' }
$tablaCab = NombreTabla $tablaCabNombre
$tablaCambios = NombreTabla $tablaCambiosNombre
$tablaConvenio = NombreTabla $tablaConvenioNombre
$campos = '[Base Calendar Code],[Recurring System],[Date],[Day],[Description],[Nonworking]'
$orden = '[Base Calendar Code],[Recurring System],[Date],[Day]'
$actor = [Guid]::Empty
$tx = $null
$conexion = [Data.SqlClient.SqlConnectionStringBuilder]::new()
$conexion['Data Source'] = $Servidor
$conexion['Initial Catalog'] = $BaseDatos
$conexion['Integrated Security'] = $true
$conexion['Encrypt'] = $true
$conexion['TrustServerCertificate'] = $true
$conexion['Connect Timeout'] = 15
$cx = [Data.SqlClient.SqlConnection]::new($conexion.ConnectionString)

function Comando([string]$sql, [hashtable]$parametros) {
    $cmd = $cx.CreateCommand()
    $cmd.CommandTimeout = 60
    if ($null -ne $tx) { $cmd.Transaction = $tx }
    $cmd.CommandText = $sql
    foreach ($nombre in $parametros.Keys) {
        [void]$cmd.Parameters.AddWithValue('@' + $nombre, $parametros[$nombre])
    }
    $cmd
}
function LeerJson([string]$sql, [hashtable]$parametros = @{}) {
    $cmd = Comando ('SELECT (' + $sql + ' FOR JSON PATH,INCLUDE_NULL_VALUES)') $parametros
    try {
        $json = [string]$cmd.ExecuteScalar()
        if ($json) { $json | ConvertFrom-Json }
    } finally { $cmd.Dispose() }
}
function Ejecutar([string]$sql, [hashtable]$parametros = @{}) {
    $cmd = Comando $sql $parametros
    try { $cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
}
function CanonCalendario($filas) {
    $normalizadas = foreach ($fila in @($filas)) {
        [ordered]@{
            Calendar = [string]$fila.'Base Calendar Code'
            Recurring = [int]$fila.'Recurring System'
            Date = ([DateTime]$fila.Date).ToString('yyyy-MM-ddTHH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
            Day = [int]$fila.Day
            Description = [string]$fila.Description
            Nonworking = [int]$fila.Nonworking
        }
    }
    @($normalizadas | Sort-Object Calendar, Recurring, Date, Day) | ConvertTo-Json -Depth 8 -Compress
}
function CanonConvenios($filas, [switch]$IgnorarCalendario) {
    @($filas | Sort-Object Código | ForEach-Object {
        $registro = [ordered]@{}
        foreach ($propiedad in @($_.PSObject.Properties | Sort-Object Name)) {
            if ($propiedad.Name -in @('timestamp', '$systemModifiedAt', '$systemModifiedBy')) { continue }
            if ($IgnorarCalendario -and $propiedad.Name -eq 'Cód_ Calendario') { continue }
            $valor = $propiedad.Value
            if ($valor -is [DateTime]) {
                $valor = $valor.ToString('yyyy-MM-ddTHH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture)
            }
            $registro[$propiedad.Name] = $valor
        }
        $registro
    }) | ConvertTo-Json -Depth 10 -Compress
}
function Exigir([bool]$condicion, [string]$mensaje) {
    if (-not $condicion) { throw $mensaje }
}
function Huella([string]$texto) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($texto))) }
    finally { $sha.Dispose() }
}

$firmaScript = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$firmaPlan = (Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash
$pruebaPath = Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($PlanPath))) 'prueba-calendario175.json'
if ($Aplicar) {
    if (-not (Test-Path -LiteralPath $pruebaPath)) { throw 'Falta un ensayo verificado y revertido del calendario.' }
    $prueba = Get-Content -LiteralPath $pruebaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Exigir ($prueba.Rollback -eq $true -and $prueba.ReversionComprobada -eq $true) 'El ensayo previo no acredita la reversión completa.'
    Exigir ($prueba.FirmaScript -ceq $firmaScript -and $prueba.FirmaPlan -ceq $firmaPlan) 'Cambió el script o el plan desde el ensayo; repetir sin -Aplicar.'
    Exigir ($prueba.Servidor -ceq $Servidor -and $prueba.Base -ceq $BaseDatos) 'El ensayo previo corresponde a otra conexión SQL.'
}
$auditoria = [ordered]@{ Modo = $(if ($Aplicar) { 'Aplicar' } else { 'Ensayo revertido' }); Servidor = $Servidor; Base = $BaseDatos; Plan = [IO.Path]::GetFullPath($PlanPath); FirmaScript = $firmaScript; FirmaPlan = $firmaPlan }
$destinoAudit = Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($PlanPath))) ('calendario175-' + $(if ($Aplicar) { 'aplicacion' } else { 'ensayo' }) + '-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff') + '.json')
try {
    $cx.Open()
    $identidad = @(LeerJson 'SELECT DB_NAME() BaseActual,@@SERVERNAME ServidorReal')
    Exigir ($identidad.Count -eq 1 -and [string]$identidad[0].BaseActual -ieq [string]$plan.base) 'La conexión SQL no abrió la base prevista en el plan.'
    $auditoria.IdentidadSQL = $identidad
    $tablasParam = @{ cab = $tablaCabNombre; cambios = $tablaCambiosNombre; convenio = $tablaConvenioNombre }
    $esquema = @(LeerJson 'SELECT t.name Tabla,c.name Columna,ty.name Tipo,c.max_length,c.is_nullable FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id WHERE t.name IN(@cab,@cambios,@convenio) ORDER BY t.name,c.column_id' $tablasParam)
    $claves = @(LeerJson 'SELECT t.name Tabla,k.key_ordinal,c.name Columna FROM sys.tables t JOIN sys.indexes i ON i.object_id=t.object_id AND i.is_primary_key=1 JOIN sys.index_columns k ON k.object_id=i.object_id AND k.index_id=i.index_id JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE t.name IN(@cab,@cambios,@convenio) ORDER BY t.name,k.key_ordinal' $tablasParam)
    foreach ($nombre in @($tablaCabNombre, $tablaCambiosNombre, $tablaConvenioNombre)) {
        $actual = @($claves | Where-Object Tabla -eq $nombre | Sort-Object key_ordinal | ForEach-Object Columna) -join '|'
        $esperada = @($plan.esquema.claves | Where-Object Tabla -eq $nombre | Sort-Object key_ordinal | ForEach-Object Columna) -join '|'
        Exigir ($actual -eq $esperada -and $actual -ne '') ('La clave SQL cambió: ' + $nombre)
    }
    $auditoria.Esquema = $esquema
    $auditoria.Claves = $claves
    $tx = $cx.BeginTransaction([Data.IsolationLevel]::Serializable)
    $baseAntes = @(LeerJson "SELECT $campos FROM $tablaCambios WHERE [Base Calendar Code]=@origen ORDER BY $orden" @{ origen = 'BASE' })
    $calendariosAntes = @(LeerJson "SELECT $campos FROM $tablaCambios ORDER BY $orden")
    $conveniosAntes = @(LeerJson "SELECT * FROM $tablaConvenio ORDER BY [Código]")
    $convenioAntes = @(LeerJson "SELECT * FROM $tablaConvenio WHERE [Código]=@codigo" @{ codigo = '175/75' })
    $cabOrigen = @(LeerJson "SELECT * FROM $tablaCab WHERE [Code]=@origen" @{ origen = 'BASE' })
    $cabDestino = @(LeerJson "SELECT [Code] FROM $tablaCab WHERE [Code]=@destino" @{ destino = 'CCT-175' })
    $filasDestinoPrevias = @($calendariosAntes | Where-Object 'Base Calendar Code' -eq 'CCT-175')
    Exigir ($baseAntes.Count -eq 25) 'BASE debe conservar sus 25 filas verificadas.'
    Exigir ($cabOrigen.Count -eq 1) 'Debe existir una única cabecera BASE.'
    Exigir ($cabDestino.Count -eq 0 -and $filasDestinoPrevias.Count -eq 0) 'CCT-175 ya existe: no se reemplaza ni se reutiliza.'
    Exigir ($convenioAntes.Count -eq 1) 'Debe existir un único convenio 175/75.'
    Exigir ([string]$convenioAntes[0].'Cód_ Calendario' -eq [string]$plan.asignacion_calendario_anterior) 'Cambió la asignación de calendario del convenio.'
    Exigir ((CanonConvenios $convenioAntes -IgnorarCalendario) -ceq (CanonConvenios @($plan.baseline.convenio175) -IgnorarCalendario)) 'El convenio cambió respecto de la fila completa revisada en el plan.'
    Exigir ((CanonCalendario $baseAntes) -ceq (CanonCalendario $plan.baseline.calendario_base_funcional)) 'BASE cambió después de preparar el plan; revisar antes de aplicar.'
    foreach ($fecha in @('2026-02-08', '2026-02-09')) {
        $fila = @($baseAntes | Where-Object { ([DateTime]$_.Date).ToString('yyyy-MM-dd') -eq $fecha -and [int]$_.'Recurring System' -eq 0 })
        Exigir ($fila.Count -eq 1 -and [int]$fila[0].Nonworking -eq 1) ('La excepción de BASE no coincide con el plan: ' + $fecha)
    }
    $auditoria.BaseAntes = $baseAntes
    $auditoria.ConvenioAntes = $convenioAntes
    $auditoria.HuellaBaseAntes = Huella (CanonCalendario $baseAntes)
    Exigir ((Ejecutar "INSERT INTO $tablaCab ([Code],[Name],[`$systemId],[`$systemCreatedAt],[`$systemCreatedBy],[`$systemModifiedAt],[`$systemModifiedBy]) VALUES (@destino,@nombre,NEWID(),SYSUTCDATETIME(),@actor,SYSUTCDATETIME(),@actor)" @{ destino = 'CCT-175'; nombre = [string]$plan.nombre_calendario_destino; actor = $actor }) -eq 1) 'No se insertó la cabecera del calendario.'
    Exigir ((Ejecutar "INSERT INTO $tablaCambios ([Base Calendar Code],[Recurring System],[Date],[Day],[Description],[Nonworking],[`$systemId],[`$systemCreatedAt],[`$systemCreatedBy],[`$systemModifiedAt],[`$systemModifiedBy]) SELECT @destino,[Recurring System],[Date],[Day],[Description],[Nonworking],NEWID(),SYSUTCDATETIME(),@actor,SYSUTCDATETIME(),@actor FROM $tablaCambios WHERE [Base Calendar Code]=@origen" @{ destino = 'CCT-175'; origen = 'BASE'; actor = $actor }) -eq 25) 'La copia del calendario debe insertar exactamente 25 filas.'
    Exigir ((Ejecutar "UPDATE $tablaCambios SET [Nonworking]=0,[`$systemModifiedAt]=SYSUTCDATETIME(),[`$systemModifiedBy]=@actor WHERE [Base Calendar Code]=@destino AND [Recurring System]=0 AND [Date] IN(@fecha8,@fecha9) AND [Nonworking]=1" @{ destino = 'CCT-175'; fecha8 = [DateTime]'2026-02-08'; fecha9 = [DateTime]'2026-02-09'; actor = $actor }) -eq 2) 'Deben cambiar exclusivamente las dos fechas preparadas.'
    Exigir ((Ejecutar "UPDATE $tablaConvenio SET [Cód_ Calendario]=@destino,[`$systemModifiedAt]=SYSUTCDATETIME(),[`$systemModifiedBy]=@actor WHERE [Código]=@codigo AND [Cód_ Calendario]=@anterior" @{ destino = 'CCT-175'; codigo = '175/75'; anterior = [string]$plan.asignacion_calendario_anterior; actor = $actor }) -eq 1) 'No se asignó el calendario al convenio esperado.'
    $destinoDespues = @(LeerJson "SELECT $campos FROM $tablaCambios WHERE [Base Calendar Code]=@destino ORDER BY $orden" @{ destino = 'CCT-175' })
    $calendariosDespues = @(LeerJson "SELECT $campos FROM $tablaCambios WHERE [Base Calendar Code]<>@destino ORDER BY $orden" @{ destino = 'CCT-175' })
    $conveniosDespues = @(LeerJson "SELECT * FROM $tablaConvenio ORDER BY [Código]")
    $convenioDespues = @($conveniosDespues | Where-Object Código -eq '175/75')
    Exigir ($destinoDespues.Count -eq 25) 'El calendario nuevo no tiene 25 filas.'
    Exigir ((CanonCalendario $destinoDespues) -ceq (CanonCalendario $plan.filas_destino_esperadas)) 'El calendario nuevo difiere del clon exacto revisado.'
    Exigir ((CanonCalendario $calendariosAntes) -ceq (CanonCalendario $calendariosDespues)) 'Se modificó un calendario existente.'
    Exigir ((CanonConvenios @($conveniosAntes | Where-Object Código -ne '175/75')) -ceq (CanonConvenios @($conveniosDespues | Where-Object Código -ne '175/75'))) 'Se modificó la asignación de otro convenio.'
    Exigir ((CanonConvenios $convenioAntes -IgnorarCalendario) -ceq (CanonConvenios $convenioDespues -IgnorarCalendario)) 'Se modificó un campo del convenio además del calendario y los metadatos de modificación.'
    Exigir ($convenioDespues.Count -eq 1 -and [string]$convenioDespues[0].'Cód_ Calendario' -ceq 'CCT-175') 'La asignación final del convenio no coincide con el plan.'
    $auditoria.DestinoVerificado = $destinoDespues
    $auditoria.HuellaDestinoVerificado = Huella (CanonCalendario $destinoDespues)
    $auditoria.EneroYOtrasFechasIdenticas = $true
    $auditoria.OtrosCalendariosYConveniosIntactos = $true
    $auditoria.ConvenioDespues = $convenioDespues
    $auditoria.ConvenioCompletoPreservado = $true
    if ($Aplicar) {
        $tx.Commit()
        $auditoria.Resultado = 'Aplicado; reiniciar service tier antes de recalcular por el cambio SQL directo.'
    } else {
        $tx.Rollback()
        $auditoria.Resultado = 'Ensayo verificado y revertido; no se conservó ningún cambio.'
    }
    $tx.Dispose()
    $tx = $null
    if (-not $Aplicar) {
        $calendariosRevertidos = @(LeerJson "SELECT $campos FROM $tablaCambios ORDER BY $orden")
        $conveniosRevertidos = @(LeerJson "SELECT * FROM $tablaConvenio ORDER BY [Código]")
        $cabRevertida = @(LeerJson "SELECT [Code] FROM $tablaCab WHERE [Code]=@destino" @{ destino = 'CCT-175' })
        Exigir ($cabRevertida.Count -eq 0) 'La cabecera del ensayo no se revirtió.'
        Exigir ((CanonCalendario $calendariosAntes) -ceq (CanonCalendario $calendariosRevertidos)) 'El ensayo dejó diferencias en los calendarios.'
        Exigir ((CanonConvenios $conveniosAntes) -ceq (CanonConvenios $conveniosRevertidos)) 'El ensayo dejó diferencias en los convenios.'
        $auditoria.ReversionComprobadaPorLecturaPosterior = $true
    }
} catch {
    if ($null -ne $tx) { $tx.Rollback(); $tx.Dispose(); $tx = $null }
    $auditoria.Error = $_.Exception.Message
    throw
} finally {
    $cx.Dispose()
    [IO.File]::WriteAllText($destinoAudit, ($auditoria | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
if (-not $Aplicar) {
    [IO.File]::WriteAllText($pruebaPath, ([ordered]@{
        Rollback = $true
        ReversionComprobada = $auditoria.ReversionComprobadaPorLecturaPosterior
        FirmaScript = $firmaScript
        FirmaPlan = $firmaPlan
        Servidor = $Servidor
        Base = $BaseDatos
        Auditoria = $destinoAudit
        UTC = [DateTime]::UtcNow
    } | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}
Write-Output $auditoria.Resultado
Write-Output ('Auditoría: ' + $destinoAudit)
