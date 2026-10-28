<# Recalcula las liquidaciones Calculadas del empleado y período del documento indicado.
   Reabre todo el mes antes de calcularlo. La operación AL es una única transacción.
   No incluye borradores preexistentes ni permite aprobadas/contabilizadas o meses posteriores. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^LIQ-[0-9]+$')]
    [ValidateLength(1,20)]
    [string]$Numero,
    [string]$ComputerName = 'mimir',
    [string]$ServerInstance = 'BC252'
)
$ErrorActionPreference = 'Stop'
Invoke-Command -ComputerName $ComputerName -ScriptBlock {
    param($Instance,$Documento)
    $ErrorActionPreference = 'Stop'
    $null = Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\252\Service\NavAdminTool.ps1' 6>$null
    Invoke-NAVCodeunit -ServerInstance $Instance -Tenant default -CompanyName ArbuTest -CodeunitId 110031 -MethodName EjecutarMesEmpleado -Argument $Documento -Force -NetworkTimeout ([timespan]::FromMinutes(5)) -ErrorAction Stop
    'Mes del empleado recalculado; topes y acumulados reconstruidos en orden.'
} -ArgumentList $ServerInstance,$Numero -ErrorAction Stop
