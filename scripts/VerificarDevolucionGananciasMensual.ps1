[CmdletBinding()]
param([Parameter(Mandatory)][string]$Backup,[switch]$CambiosConcurrentes)
$ErrorActionPreference='Stop'
function Leer($etapa,$tabla){return @(Get-Content (Join-Path $Backup ($etapa+'-'+$tabla+'.json')) -Raw|ConvertFrom-Json)}
if((Get-FileHash (Join-Path $Backup 'antes-enero.json')).Hash -ne (Get-FileHash (Join-Path $Backup 'despues-enero.json')).Hash){throw 'Cambió enero.'}
$casos=Get-Content (Join-Path $Backup 'recalculados.json') -Raw|ConvertFrom-Json
$proyeccion=Get-Content (Join-Path $Backup 'proyeccion.json') -Raw|ConvertFrom-Json
$emp=@($casos.empleado);$a=Leer antes febrero;$d=Leer despues febrero
$omitidos=@();if(Test-Path (Join-Path $Backup 'omitidos-borrador.json')){$omitidos=@(Get-Content (Join-Path $Backup 'omitidos-borrador.json') -Raw|ConvertFrom-Json)}
$docsOmitidos=@($omitidos.documento)
$idx=@{};foreach($h in $d){$idx[$h.No_]=$h}
if($a.Count -ne $d.Count){throw 'Cambió la cantidad de documentos de febrero.'}
$cambiosCab=@()
foreach($h in $a){$n=$idx[$h.No_];if(!$n){throw 'Falta un documento.'};if($h.No_ -in $docsOmitidos){if($n.Estado -ne 0){throw 'Se calculó el borrador omitido.'};continue};if($h.'No_ Empleado' -notin $emp -or $h.Estado -eq 0){if(($h|ConvertTo-Json -Compress) -cne ($n|ConvertTo-Json -Compress) -and !$CambiosConcurrentes){throw ('Cambió una cabecera ajena: '+$h.No_)}}else{foreach($campo in @('Estado','Total Haberes','Total Contribuciones','No_ Empleado','Cód_ Período','Cód_ Tipo Liq_','Fecha Liquidación','Cód_ Convenio','Cód_ Categoría')){if([string]$h.$campo -cne [string]$n.$campo){if(!$CambiosConcurrentes -or $campo -notin @('Total Haberes','Total Contribuciones')){throw ('Cambió '+$campo+' en '+$h.No_)};$cambiosCab+=[pscustomobject]@{documento=$h.No_;campo=$campo;antes=$h.$campo;despues=$n.$campo}}}}}
$la=Leer antes lineas;$ld=Leer despues lineas
function Economicos($filas){return @($filas|Where-Object {$_.'Cód_ Concepto' -ne '5010' -and $_.'No_ Liquidación' -notin $docsOmitidos}|Select-Object 'No_ Liquidación','Cód_ Concepto','Vigencia Concepto','Es Devengo','Cód_ Convenio','Cód_ Categoría',Importe,Cantidad,'Base Cálculo'|Sort-Object 'No_ Liquidación','Cód_ Concepto',Importe,Cantidad)}
$cambiosConceptos=@(Compare-Object @(Economicos $la|ForEach-Object {$_|ConvertTo-Json -Compress}) @(Economicos $ld|ForEach-Object {$_|ConvertTo-Json -Compress}))
if($cambiosConceptos.Count -and !$CambiosConcurrentes){throw 'Cambió un concepto distinto de Ganancias.'}
if($CambiosConcurrentes){[pscustomobject]@{cabeceras=$cambiosCab;conceptos=$cambiosConceptos}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $Backup 'cambios-concurrentes.json') -Encoding utf8}
function Saldos($filas){return @($filas|Where-Object 'No_ Liquidación' -NotIn $docsOmitidos|Group-Object 'No_ Liquidación','Cód_ Convenio','Cód_ Categoría','Cód_ Puesto','Cód_ Estado','No_ Proyecto','Fecha Devengamiento','Cód_ Concepto'|ForEach-Object {$cantidad=[decimal]0;foreach($r in $_.Group){$cantidad+=[decimal]$r.Cantidad};[pscustomobject]@{clave=$_.Name;cantidad=$cantidad}}|Sort-Object clave)}
if((Saldos (Leer antes francos)|ConvertTo-Json -Compress) -cne (Saldos (Leer despues francos)|ConvertTo-Json -Compress)){throw 'Cambió el saldo de francos.'}
$valA=Leer antes parametros;$valD=Leer despues parametros;$map=@{};foreach($v in $valD){$map[$v.'Cód_ Parámetro Base'+'|'+$v.'Cód_ Parámetro'+'|'+([datetime]$v.'Vigencia Desde').ToString('yyyy-MM-dd')]=$v}
if($valA.Count -ne $valD.Count){throw 'Cambió la cantidad de parámetros.'}
$normalizados=0
foreach($v in $valA){$fecha=[datetime]$v.'Vigencia Desde';$key=$v.'Cód_ Parámetro Base'+'|'+$v.'Cód_ Parámetro'+'|'+$fecha.ToString('yyyy-MM-dd');$n=$map[$key];$esperado=[decimal]$v.Valor
 if($v.'Cód_ Parámetro Base' -in @('MNI_ANUAL','DESP_4CAT','CONYUGE','HIJO','HIJO_INC') -and $fecha -ge [datetime]'2026-02-01' -and $fecha -le [datetime]'2026-06-01'){$esperado/=$fecha.Month;$normalizados++}
 if([decimal]$n.Valor -ne $esperado){throw ('Valor fiscal distinto al previsto: '+$key)}
 foreach($p in $v.PSObject.Properties){if($p.Name -notin @('Valor','timestamp','$systemModifiedAt') -and [string]$p.Value -cne [string]$n.($p.Name)){throw ('Cambió un campo de parámetro: '+$p.Name)}}
}
if($normalizados -ne 24){throw 'Alcance de normalización distinto.'}
$tax=@{};foreach($l in $ld){if($l.'Cód_ Concepto' -eq '5010'){$tax[$l.'No_ Liquidación']+=[decimal]$l.Importe}}
$ctx=@{};foreach($v in (Leer despues variables)){if($v.'Nombre Variable' -eq 'YTD_RETENIDO_ANUAL'){$ctx[$v.'No_ Liquidación']=[decimal]$v.Valor}}
$trazas=@{};foreach($t in (Leer despues trazas)){$trazas[$t.'No_ Liquidación']=$t}
$revisados=@();$tramosVerificados=0
foreach($p in $proyeccion){if($p.documento -in $docsOmitidos){continue};$actual=[decimal]$tax[$p.documento]
 if($p.empleado -in $emp){
  # El resumen se guarda al final: algunos acumuladores reciben aportes después
  # de 5010. La fuente correcta para comprobar el cálculo es la traza TRAMO
  # capturada cuando se evaluó el impuesto, con valores exactos invariantes.
  $log=[string]$trazas[$p.documento].'Fuente Parámetros'
  $m=[regex]::Match($log,'(?:^|\|)TRAMO:TAB_IMP_4CAT~([^~|]+)~([^|]+)')
  if(!$m.Success){throw ('Falta la escala aplicada en la traza: '+$p.documento)}
  $total=[decimal]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
  $parts=$m.Value.TrimStart('|').Split('~')
  if($parts.Length -ge 8){$base=[decimal]::Parse($parts[3],[Globalization.CultureInfo]::InvariantCulture);$lower=[decimal]::Parse($parts[4],[Globalization.CultureInfo]::InvariantCulture);$fijo=[decimal]::Parse($parts[5],[Globalization.CultureInfo]::InvariantCulture);$pct=[decimal]::Parse($parts[6],[Globalization.CultureInfo]::InvariantCulture);if([math]::Abs(($fijo+($base-$lower)*$pct/100)-$total) -ge .0002){throw 'La escala no reproduce su traza.'}}
  $ret=[decimal]$ctx[$p.documento];$esperado=[math]::Round([math]::Max($total-$ret,-[math]::Max($ret,0)),4,[MidpointRounding]::AwayFromZero)
  if([math]::Abs($actual-$esperado) -ge .02){throw ('El impuesto no coincide con su escala y saldo: '+$p.empleado)};$tramosVerificados++
 }elseif([math]::Abs($actual-[decimal]$p.anterior) -ge .02 -and !$CambiosConcurrentes){throw 'Cambió un impuesto ajeno al recálculo.'}
 if($actual -lt -[math]::Max([decimal]$p.retenido,0)-.02){throw 'Se devolvió más de lo retenido.'}
 $revisados+=[pscustomobject]@{empleado=$p.empleado;documento=$p.documento;antes=$p.anterior;despues=$actual;meta4=$p.meta4;diferencia=if($null -ne $p.meta4){$actual-[decimal]$p.meta4}else{$null}}
}
$original=@($revisados|Where-Object empleado -EQ '00406');if($original.Count -ne 1 -or [math]::Abs($original[0].diferencia) -ge .01){throw 'El 00406 no concilia al centavo.'}
$revisados|ConvertTo-Json -Depth 4|Set-Content (Join-Path $Backup 'verificacion.json') -Encoding utf8
'Verificación fiscal aprobada: '+$tramosVerificados+' escalas y saldos comprobados; '+$revisados.Count+' resultados controlados; enero conservado.'
if($CambiosConcurrentes){'Cambios económicos concurrentes documentados: '+$cambiosCab.Count+' campos de cabecera; '+$cambiosConceptos.Count+' diferencias de líneas. No afirmar que esos importes se conservaron.'}else{'Demás importes conservados.'}
$original|Format-Table empleado,antes,despues,meta4,diferencia
'Otros casos con diferencia > $1 frente a Meta4: '+@($revisados|Where-Object {$null -ne $_.diferencia -and [math]::Abs($_.diferencia) -gt 1}).Count
