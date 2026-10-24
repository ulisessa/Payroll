<# Conserva backup local de configuración, reabre enero por dependencias y consolida vigencias.
   Sin -Aplicar sólo previsualiza. Requiere versión 634 o posterior; no recalcula recibos. #>
[CmdletBinding()]
param([switch]$Aplicar)
$ErrorActionPreference = 'Stop'
$sqlPath = Join-Path $PSScriptRoot 'UnificarConceptosEnero.sql'
$sql = Get-Content -LiteralPath $sqlPath -Raw
$conexion = [System.Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
try {
    $conexion.Open()
    if ($Aplicar) {
        $raiz = Split-Path -Parent $PSScriptRoot
        $backup = Join-Path $raiz ('.snapshots/unificacion-enero-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $null = New-Item -ItemType Directory -Path $backup
        $tablas = @('Concepto Liquidación','Fracción Acumulador','Concepto CCT Vigente')
        foreach ($tabla in $tablas) {
            $comando = $conexion.CreateCommand()
            $comando.CommandTimeout = 120
            $comando.CommandText = 'SELECT (SELECT * FROM [ArbuTest$' + $tabla + '$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] FOR JSON PATH, INCLUDE_NULL_VALUES)'
            $contenido = [string]$comando.ExecuteScalar()
            if (-not $contenido.StartsWith('[')) { throw "Backup inválido de $tabla" }
            $null = ConvertFrom-Json -InputObject $contenido
            [IO.File]::WriteAllText((Join-Path $backup ($tabla + '.json')), $contenido, [Text.UTF8Encoding]::new($false))
        }
        $comando = $conexion.CreateCommand()
        $comando.CommandText = @'
SELECT (SELECT [No_ Liquidación],[No_ Línea],[Cód_ Concepto],[Vigencia Concepto]
FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Cód_ Período]='202601' FOR JSON PATH, INCLUDE_NULL_VALUES)
'@
        [IO.File]::WriteAllText((Join-Path $backup 'referencias-lineas.json'), [string]$comando.ExecuteScalar(), [Text.UTF8Encoding]::new($false))
        Write-Output "Backup local: $backup"
        Invoke-Command -ComputerName mimir -ScriptBlock {
            $ErrorActionPreference = 'Stop'
            $null = Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\252\Service\NavAdminTool.ps1' 6>$null
            Invoke-NAVCodeunit -ServerInstance BC252 -Tenant default -CompanyName ArbuTest -CodeunitId 50019 -MethodName ReabrirPeriodoPorCodigo -Argument '202601' -Force -NetworkTimeout ([timespan]::FromMinutes(10)) -ErrorAction Stop
        } -ErrorAction Stop
        $sql = $sql.Replace('@Aplicar bit=0', '@Aplicar bit=1')
    }
    $comando = $conexion.CreateCommand()
    $comando.CommandTimeout = 300
    $comando.CommandText = $sql
    $lector = $comando.ExecuteReader()
    do {
        while ($lector.Read()) {
            $valores = for ($i = 0; $i -lt $lector.FieldCount; $i++) { [string]$lector.GetValue($i) }
            Write-Output ($valores -join ' | ')
        }
    } while ($lector.NextResult())
    $lector.Close()
    if ($Aplicar) {
        $servicio = [System.ServiceProcess.ServiceController]::new('MicrosoftDynamicsNavServer$BC252','mimir')
        $servicio.Refresh()
        $servicio.Stop()
        $servicio.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,[timespan]::FromSeconds(60))
        $servicio.Start()
        $servicio.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(60))
        Write-Output 'BC252 reiniciado. Enero en Borrador, listo para calcular.'
    }
} finally { $conexion.Dispose() }
