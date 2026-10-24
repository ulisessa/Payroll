<# Aplica el payload verificado de Meta4 mediante AL, sin SQL directo ni reinicio.
   Sin -Aplicar ejecuta una simulación cuyo error deliberado revierte toda la transacción.
   Conservar fuentes y respaldos privados del payload antes de aplicar. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PayloadPath,[switch]$Aplicar)
$ErrorActionPreference='Stop'
$payload=Get-Content -LiteralPath $PayloadPath -Raw
$json=$payload | ConvertFrom-Json
if($json.periodo -ne '202602'){throw 'Payload de período incorrecto.'}
$metodo=if($Aplicar){'Aplicar'}else{'Simular'}
try {
 Invoke-Command -ComputerName mimir -ScriptBlock {
  param($Contenido,$Metodo)
  $ErrorActionPreference='Stop'
  $null=Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\252\Service\NavAdminTool.ps1' 6>$null
  Invoke-NAVCodeunit -ServerInstance BC252 -Tenant default -CompanyName ArbuTest -CodeunitId 110067 -MethodName $Metodo -Argument $Contenido -Force -NetworkTimeout ([timespan]::FromMinutes(5)) -ErrorAction Stop
 } -ArgumentList $payload,$metodo -ErrorAction Stop
 if(!$Aplicar){throw 'La simulación terminó sin su rollback deliberado.'}
 'Prevuelo de febrero cargado mediante AL.'
} catch {
 if(!$Aplicar -and $_.Exception.Message.Contains('SIMULACION_FEBRERO_OK')) {'Simulación validada; la transacción se revirtió.';return}
 throw
}
