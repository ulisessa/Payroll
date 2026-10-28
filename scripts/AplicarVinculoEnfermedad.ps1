<# Aplica sólo las dos decisiones confirmadas de enfermedad.
   Sin -Aplicar prueba la escritura completa con rollback. La publicación de AL,
   renovación de caché y recálculo se coordinan aparte, una vez revisado este ensayo. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Backup,
      [Parameter(Mandatory)][ValidatePattern('^\d{5}$')][string]$EmpleadoRestaurar,
      [switch]$Aplicar)
$ErrorActionPreference='Stop'
$Backup=(Resolve-Path -LiteralPath $Backup).Path
$sqlPath=Join-Path $PSScriptRoot 'CorregirVinculoEnfermedad.sql'
function Leer($nombre){return @(Get-Content -LiteralPath (Join-Path $Backup ('antes-'+$nombre+'.json')) -Raw|ConvertFrom-Json)}
$conceptos=Leer conceptos
$prom=@($conceptos|Where-Object {$_.'Código' -eq 'PROM_ENF_MES' -and ([datetime]$_.'Vigencia Desde').Date -eq [datetime]'2026-02-01'})
if($prom.Count -ne 1){throw 'Falta la vigencia original de febrero del promedio.'}
$formulaNueva='IF(MESES_AUS >= 12, IF(DIV_PROM_ENF_12 > 0, (ENF_BASE_12 + ENF_NR_12) / IFZERO(DIV_PROM_ENF_12, 1), 0), IF(DIV_PROM_ENF_6 > 0, (ENF_BASE_6 + ENF_NR_6) / IFZERO(DIV_PROM_ENF_6, 1), 0))'
$estados=@(Leer estados|Where-Object {$_.'No_ Empleado' -eq $EmpleadoRestaurar})
$au=@($estados|Where-Object {$_.'Cód_ Estado' -eq 'AU1' -and ([datetime]$_.'Fecha Inicio').Date -eq [datetime]'2025-11-20' -and ([datetime]$_.'Fecha Fin').Date -eq [datetime]'2025-12-31'})
$manual=@($estados|Where-Object {$_.'Cód_ Estado' -eq 'ACT' -and ([datetime]$_.'Fecha Inicio').Date -eq [datetime]'2026-01-01' -and ([datetime]$_.'Fecha Fin').Date -eq [datetime]'2026-03-15'})
$siguiente=@($estados|Where-Object {$_.'Cód_ Estado' -eq 'ACT' -and ([datetime]$_.'Fecha Inicio').Date -eq [datetime]'2026-03-16' -and ([datetime]$_.'Fecha Fin').Year -eq 1753})
if($au.Count -ne 1 -or $manual.Count -ne 1 -or $siguiente.Count -ne 1){throw 'Los estados ya no coinciden con la restauración confirmada.'}
$cambios=@(
 [pscustomobject]@{mov=[int]$au[0].'No_ Mov_';empleado=$EmpleadoRestaurar;codigo='AU1';inicioAntes='2025-11-20';finAntes='2025-12-31';inicioDespues='2025-11-20';finDespues='2026-03-15';eliminar=$false},
 [pscustomobject]@{mov=[int]$manual[0].'No_ Mov_';empleado=$EmpleadoRestaurar;codigo='ACT';inicioAntes='2026-01-01';finAntes='2026-03-15';inicioDespues=$null;finDespues=$null;eliminar=$true}
)
$json=ConvertTo-Json -InputObject $cambios -Compress
$sqlHash=(Get-FileHash -LiteralPath $sqlPath).Hash
if($Aplicar){
 $prueba=Get-Content -LiteralPath (Join-Path $Backup 'prueba-vinculo.json') -Raw|ConvertFrom-Json
 if(!$prueba.revertida -or $prueba.sqlHash -ne $sqlHash -or $prueba.payload -cne $json){throw 'Falta una prueba reversible de esta versión exacta.'}
}
$cx=[Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
try{
 $cx.Open();$cmd=$cx.CreateCommand();$cmd.CommandTimeout=120
 foreach($kv in @{FormulaPromAnterior=[string]$prom[0].Fórmula;FormulaPromNueva=$formulaNueva;CambiosEstadoJSON=$json}.GetEnumerator()){$null=$cmd.Parameters.Add('@'+$kv.Key,[Data.SqlDbType]::NVarChar,-1);$cmd.Parameters['@'+$kv.Key].Value=$kv.Value}
 $null=$cmd.Parameters.Add('@Aplicar',[Data.SqlDbType]::Bit);$cmd.Parameters['@Aplicar'].Value=[bool]$Aplicar
 $cmd.CommandText=Get-Content -LiteralPath $sqlPath -Raw;$null=$cmd.ExecuteNonQuery()
 if(!$Aplicar){[pscustomobject]@{revertida=$true;sqlHash=$sqlHash;payload=$json;formulaAnterior=$prom[0].Fórmula;formulaNueva=$formulaNueva}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $Backup 'prueba-vinculo.json') -Encoding utf8;'Escritura probada y revertida; falta cotejar respaldos.'}
 else{'Configuración y restauración aplicadas. Renovar caché y recalcular la cadena autorizada.'}
}finally{$cx.Dispose()}
