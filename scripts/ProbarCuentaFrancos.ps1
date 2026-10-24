<# Ejecuta las pruebas de francos y recálculo publicadas. Los diez casos se revierten por TestIsolation/AutoRollback.
   Incluye reconstrucción histórica y comparación de recibos reales de enero sólo en ArbuTest. #>
[CmdletBinding()]
param(
    [string]$ComputerName = 'mimir',
    [string]$ServerInstance = 'BC252'
)
$ErrorActionPreference = 'Stop'
Invoke-Command -ComputerName $ComputerName -ScriptBlock {
    param($Instance)
    $ErrorActionPreference = 'Stop'
    $null = Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\252\Service\NavAdminTool.ps1' 6>$null
    Invoke-NAVCodeunit -ServerInstance $Instance -Tenant default -CompanyName ArbuTest -CodeunitId 110062 -Force -ErrorAction Stop
    'Las diez pruebas finalizaron correctamente; cambios de prueba revertidos.'
} -ArgumentList $ServerInstance -ErrorAction Stop
