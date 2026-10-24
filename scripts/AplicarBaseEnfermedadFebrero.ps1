<# Corrección paramétrica del promedio de enfermedad, efectiva desde febrero.
   El histórico específico se coteja con Oracle y con la historia importada.
   Sin -Aplicar prueba todas las escrituras y las revierte. No publica AL. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Backup,
      [Parameter(Mandatory)][string]$HistoriaOracle,
      [Parameter(Mandatory)][string]$CasosOracle,
      [switch]$Aplicar,[switch]$SoloExportar)
$ErrorActionPreference='Stop'
$null=New-Item -ItemType Directory -Path $Backup -Force
$m4=@(Get-Content -LiteralPath $HistoriaOracle -Raw|ConvertFrom-Json)
$casos=@(Get-Content -LiteralPath $CasosOracle -Raw|ConvertFrom-Json)
$emps=@($casos.ID_EMPLEADO|Sort-Object -Unique)
if($emps.Count -ne 23 -or @($emps|Where-Object {$_ -notmatch '^\d{5}$'}).Count){throw 'Alcance de empleados inesperado.'}
$scope=($emps|ForEach-Object {"'"+$_+"'"})-join ','
$s='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$h='[ArbuTest$Liquidación'+$s+']';$l='[ArbuTest$Línea Liquidación'+$s+']'
$consultas=[ordered]@{
 conceptos='SELECT * FROM [ArbuTest$Concepto Liquidación'+$s+'] ORDER BY Código,[Vigencia Desde]'
 fuentes='SELECT * FROM [ArbuTest$Fuente Datos Liquidación'+$s+'] ORDER BY [Nombre Variable]'
 filtros='SELECT * FROM [ArbuTest$Filtro Fuente Datos Liq_'+$s+'] ORDER BY [Nombre Variable],[No_ Línea]'
 fracciones='SELECT * FROM [ArbuTest$Fracción Acumulador'+$s+'] WHERE [Cód_ Concepto]=''4110'' ORDER BY [Vigencia Desde],[Cód_ Acumulador]'
 cabenero="SELECT * FROM $h WHERE [Cód_ Período]='202601' ORDER BY No_"
 cabfebrero="SELECT * FROM $h WHERE [Cód_ Período]='202602' ORDER BY No_"
 cabhistoria="SELECT * FROM $h WHERE [No_ Empleado] IN ($scope) AND [Cód_ Tipo Liq_]='HIST_REMUN' ORDER BY No_"
 historia="SELECT * FROM $l WHERE [No_ Empleado] IN ($scope) AND [Cód_ Tipo Liq_]='HIST_REMUN' AND [Fecha Liquidación] BETWEEN '20240101' AND '20251231' ORDER BY [No_ Liquidación],[No_ Línea]"
 historiareal="SELECT [No_ Liquidación],[No_ Empleado],[Fecha Liquidación],[Cód_ Tipo Liq_],[Cód_ Concepto],Importe FROM $l WHERE [No_ Empleado] IN ($scope) AND [Fecha Liquidación] BETWEEN '20240101' AND '20260131' AND [Cód_ Concepto] IN ('BASE_PROMEDIO','BASE_PROMEDIO_NR','AJ_HIST_AUS') ORDER BY [No_ Empleado],[Fecha Liquidación],[No_ Liquidación],[Cód_ Concepto]"
 lineasenero="SELECT [No_ Liquidación],[Cód_ Concepto],Importe,Cantidad,[Base Cálculo],[Vigencia Concepto] FROM $l WHERE [Cód_ Período]='202601' ORDER BY [No_ Liquidación],[No_ Línea]"
 lineasfebrero="SELECT [No_ Liquidación],[No_ Empleado],[Cód_ Concepto],Importe,Cantidad,[Base Cálculo],[Vigencia Concepto],[Fórmula Evaluada],[Fuente Parámetros] FROM $l WHERE [Cód_ Período]='202602' ORDER BY [No_ Liquidación],[No_ Línea]"
 variables='SELECT d.* FROM [ArbuTest$Resumen Variable Liq_'+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[No_ Empleado] IN ($scope) AND h.[Cód_ Período]='202602' ORDER BY d.[No_ Liquidación],d.[Nombre Variable]"
 estados='SELECT * FROM [ArbuTest$Estado Empleado'+$s+"] WHERE [No_ Empleado] IN ($scope) ORDER BY [No_ Mov_]"
 meta4='SELECT h.[No_ Empleado] empleado,h.[Año]*100+h.Mes periodo,SUM(COALESCE(v.Valor,0)) objetivo FROM [ArbuTest$Hist_ Liq_ Meta4'+$s+'] h LEFT JOIN [ArbuTest$Valor Hist_ Meta4'+$s+'] v ON v.[No_ Entrada]=h.[No_ Entrada] AND v.[No_ Columna]=(SELECT No_ FROM [ArbuTest$Columna Hist_ Meta4'+$s+'] WHERE [Nombre Columna]=''TOT_PROMEDIOS'' AND [Tabla Origen]=''M4T_ACUMULADO_RL'') '+"WHERE h.[No_ Empleado] IN ($scope) AND h.Año IN (2024,2025) AND h.[Tipo Imputación] IN (1,10,11,12,13,14,15,3) GROUP BY h.[No_ Empleado],h.Año,h.Mes ORDER BY h.[No_ Empleado],h.Año,h.Mes"
}
$cx=[Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
function Exportar([string]$Etapa){
 $cmd.Parameters.Clear()
 foreach($item in $consultas.GetEnumerator()){
  $cmd.CommandText='SELECT ('+$item.Value+' FOR JSON PATH, INCLUDE_NULL_VALUES)';$j=[string]$cmd.ExecuteScalar();if(!$j){$j='[]'}
  [IO.File]::WriteAllText((Join-Path $Backup ($Etapa+'-'+$item.Key+'.json')),$j,[Text.UTF8Encoding]::new($false))
 }
}
function Leer($nombre){return @(Get-Content -LiteralPath (Join-Path $Backup ('antes-'+$nombre+'.json')) -Raw|ConvertFrom-Json)}
try{
 $cx.Open();$cmd=$cx.CreateCommand();$cmd.CommandTimeout=120
 if($SoloExportar){Exportar despues;return}
 if(!$Aplicar){Exportar antes}
 elseif(!(Test-Path -LiteralPath (Join-Path $Backup 'payload.json'))){throw 'Falta la prueba previa.'}
 $hist=Leer historia;$archive=Leer meta4;$oracle=@{};$local=@{};$bases=@{}
 foreach($r in $m4){$key=$r.ID_EMPLEADO+'|'+$r.PERIODO;if($oracle.ContainsKey($key)){throw 'Mes duplicado en Oracle.'};if($r.VINCULOS -ne 1 -or [decimal]$r.PROMEDIO_CONTADOR0 -ne 0){throw 'Mes con vínculos mixtos o contador cero.'};$oracle[$key]=[decimal]$r.TOT_PROMEDIOS}
 foreach($r in $archive){$local[$r.empleado+'|'+$r.periodo]=[decimal]$r.objetivo}
 foreach($key in @($oracle.Keys)+@($local.Keys)|Sort-Object -Unique){if([math]::Abs([decimal]$oracle[$key]-[decimal]$local[$key]) -gt .01){throw ('Oracle y archivo BC no coinciden: '+$key)}}
 foreach($r in @($hist|Where-Object {$_.'Cód_ Concepto' -eq 'BASE_PROMEDIO'})){
  $key=$r.'No_ Empleado'+'|'+$r.'Cód_ Período';if($bases.ContainsKey($key)){throw ('Más de una base por mes: '+$key)};$bases[$key]=$r
 }
 $payload=@();$faltantes=@()
 foreach($key in @($oracle.Keys)+@($bases.Keys)|Sort-Object -Unique){
  $part=$key.Split('|');if($part[0] -eq '80668'){continue} # Estado manual pendiente de confirmar.
  $base=$bases[$key];$objetivo=[decimal]$oracle[$key];$actual=if($base){[decimal]$base.Importe}else{[decimal]0};$ajuste=$objetivo-$actual
  if([math]::Abs($ajuste) -lt .01){continue} # Evita crear diferencias sólo por precisión del archivo.
  if(!$base){
   if($key -notin @('02737|202411','03986|202411','03986|202412')){throw ('Mes faltante no revisado: '+$key)}
   $faltantes+=[pscustomobject]@{empleado=$part[0];periodo=$part[1];objetivo=$objetivo}
  }
  $payload+=[pscustomobject]@{empleado=$part[0];periodo=$part[1];documento=if($base){$base.'No_ Liquidación'}else{'AUS-'+$part[0]+'-'+$part[1]};base=$actual;objetivo=$objetivo;ajuste=$ajuste;nuevo=[bool](!$base)}
 }
 $faltantes|ConvertTo-Json -Depth 3|Set-Content -LiteralPath (Join-Path $Backup 'meses-faltantes.json') -Encoding utf8
 if($faltantes.Count -ne 3){throw 'Cambió el alcance de los meses históricos omitidos.'}
 $conceptos=Leer conceptos;$fuente=@($conceptos|Where-Object {$_.'Código' -eq '4110'}|Sort-Object 'Vigencia Desde' -Descending)[0]
 if(([datetime]$fuente.'Vigencia Desde').Date -ne [datetime]'2026-01-01' -or ([datetime]$fuente.'Vigencia Hasta').Year -ne 1753){throw 'Cambió la vigencia del 4110.'}
 $anterior=[string]$fuente.Fórmula;$nueva=$anterior.Replace('#PROM_AUS_MES','#PROM_ENF_MES');if($anterior -eq $nueva){throw 'No existe la referencia a reemplazar.'}
 $prom='IF(MESES_AUS >= 12, (PROM_AUS_12 + AUS_AJUSTE_HIST_12 + AUS_NO_REM_ACT_12) / MAX(1, MESES_PROM_AUS_12), (PROM_AUS_6 + AUS_AJUSTE_HIST_6 + AUS_NO_REM_ACT_6) / MAX(1, MESES_PROM_AUS_6))'
 $json=ConvertTo-Json -InputObject @($payload) -Compress -Depth 4
 if(!$Aplicar){$json|Set-Content -LiteralPath (Join-Path $Backup 'payload.json') -Encoding utf8}
 elseif($json -cne (Get-Content -LiteralPath (Join-Path $Backup 'payload.json') -Raw).Trim()){throw 'Cambió el payload respecto a la prueba.'}
 $sql=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'CorregirBaseEnfermedadFebrero.sql') -Raw
 $cmd.Parameters.Clear();foreach($kv in @{FormulaAnterior=$anterior;FormulaNueva=$nueva;FormulaPromEnf=$prom;Payload=$json}.GetEnumerator()){$null=$cmd.Parameters.Add('@'+$kv.Key,[Data.SqlDbType]::NVarChar,-1);$cmd.Parameters['@'+$kv.Key].Value=$kv.Value}
 $null=$cmd.Parameters.Add('@Aplicar',[Data.SqlDbType]::Bit);$cmd.Parameters['@Aplicar'].Value=[bool]$Aplicar;$cmd.CommandText=$sql;$null=$cmd.ExecuteNonQuery()
 if(!$Aplicar){Exportar simulacion;foreach($name in $consultas.Keys){if((Get-FileHash -LiteralPath (Join-Path $Backup ('antes-'+$name+'.json'))).Hash -ne (Get-FileHash -LiteralPath (Join-Path $Backup ('simulacion-'+$name+'.json'))).Hash){throw ('Rollback distinto: '+$name)}};'Prueba de escritura revertida; meses ajustables: '+$payload.Count;return}
 Exportar aplicado
 'Base de enfermedad configurada desde febrero; pendiente reinicio y recálculo.'
}finally{$cx.Dispose()}
