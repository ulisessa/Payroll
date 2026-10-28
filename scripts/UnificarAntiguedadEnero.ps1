<# Respalda la configuración, reabre enero por dependencias y unifica antigüedad mediante AL.
   Sin -Aplicar sólo describe el alcance. No recalcula importes ni requiere reinicio por SQL. #>
[CmdletBinding()]
param([switch]$Aplicar)
$ErrorActionPreference = 'Stop'
if (-not $Aplicar) {
    'Unifica 1055 en 1053 desde 01/01/2026, conservando reglas, órdenes y bases por convenio.'
    'Con -Aplicar guarda respaldo y deja enero completo en Borrador para recalcular.'
    return
}
$raiz = Split-Path -Parent $PSScriptRoot
$backup = Join-Path $raiz ('.snapshots/antiguedad-unificada-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$null = New-Item -ItemType Directory -Path $backup
$conexion = [System.Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
try {
    $conexion.Open()
    foreach ($tabla in @('Concepto Liquidación','Fracción Acumulador','Concepto CCT Vigente','Variable Sistema Liq_')) {
        $comando = $conexion.CreateCommand()
        $comando.CommandTimeout = 120
        $comando.CommandText = 'SELECT (SELECT * FROM [ArbuTest$' + $tabla + '$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] FOR JSON PATH, INCLUDE_NULL_VALUES)'
        $contenido = [string]$comando.ExecuteScalar()
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
} finally { $conexion.Dispose() }
Write-Output "Respaldo: $backup"
Invoke-Command -ComputerName mimir -ScriptBlock {
    $ErrorActionPreference = 'Stop'
    $null = Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\252\Service\NavAdminTool.ps1' 6>$null
    Invoke-NAVCodeunit -ServerInstance BC252 -Tenant default -CompanyName ArbuTest -CodeunitId 50019 -MethodName ReabrirPeriodoPorCodigo -Argument '202601' -Force -NetworkTimeout ([timespan]::FromMinutes(10)) -ErrorAction Stop
    Invoke-NAVCodeunit -ServerInstance BC252 -Tenant default -CompanyName ArbuTest -CodeunitId 110066 -MethodName Aplicar -Argument '2026-01-01' -Force -ErrorAction Stop
    'Antigüedad unificada mediante AL; enero queda en Borrador para recalcular.'
} -ErrorAction Stop
