<# Cambia exclusivamente configuración respaldada. Sin -Aplicar ensaya y revierte SQL.
   Requiere publicar primero el motor genérico y mantener detenido el cálculo mientras se aplica.
   El llamador renueva luego la caché de BC y recalcula los períodos afectados. #>
[CmdletBinding()]
param([string]$Backup=(Join-Path (Split-Path -Parent $PSScriptRoot) '.snapshots\ausentismo-configurable-20261013'),[switch]$Aplicar)
$ErrorActionPreference='Stop'
$null=New-Item -ItemType Directory -Path $Backup -Force
$s='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$tab=@{variables='Variable Sistema Liq_';fuentes='Fuente Datos Liquidación';filtros='Filtro Fuente Datos Liq_';parametros='Parámetro';valores='Parámetro Vigente';conceptos='Concepto Liquidación';fracciones='Fracción Acumulador';convenios='Convenio Colectivo';historial='Historial Fórmula Concepto';atributos='Tipo Atributo Liq_'}
function Tabla([string]$Id){return '[dbo].[ArbuTest$'+$tab[$Id]+$s+']'}
function Q([string]$Campo){return '['+$Campo.Replace(']',']]')+']'}
function Leer([string]$Nombre){$path=Join-Path $Backup ('antes-'+$Nombre+'.json');if(!(Test-Path -LiteralPath $path)){throw ('Falta respaldo: '+$path)};return @(Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)}
function Canonico($Fila){$v=[ordered]@{};foreach($p in @($Fila.PSObject.Properties|Sort-Object Name)){$v[$p.Name]=$p.Value};return ConvertTo-Json -InputObject $v -Compress -Depth 10}
function Una($Filas,[string]$Descripcion){$a=@($Filas);if($a.Count -ne 1){throw ('Se esperaba una fila: '+$Descripcion)};return $a[0]}
function Fecha($Valor){return ([datetime]$Valor).ToString('yyyy-MM-dd')}
$datos=@{};foreach($key in @('variables','fuentes','filtros','parametros','valores','conceptos','fracciones','convenios')){$datos[$key]=Leer $key}
$enf=Una @($datos.variables|Where-Object {$_.'Nombre Variable' -eq 'DIAS_ENFERMEDAD'}) 'variable de enfermedad'
$acc=Una @($datos.variables|Where-Object {$_.'Nombre Variable' -eq 'DIAS_ACCIDENTE'}) 'variable de accidente'
foreach($v in @($enf,$acc)){if($v.'Cód_ Cálculo' -ne 'DIAS_ESTADO_PERIODO' -or !$v.'Cód_ Estado'){throw 'Las dos variables deben ser contadores genéricos con estado configurado.'}}
$previos=Una @($datos.variables|Where-Object {$_.'Nombre Variable' -eq 'DIAS_ACC_PREVIOS'}) 'días previos de accidente'
$legacyDiv=@($datos.variables|Where-Object {$_.'Nombre Variable' -in @('DIV_PROM_ENF_6','DIV_PROM_ENF_12')})
if($legacyDiv.Count -ne 2){throw 'Faltan los dos divisores anteriores.'}
$dias=@(
 [pscustomobject]@{nombre='DIAS_ENFERMEDAD';estado=$enf.'Cód_ Estado';agregado=5;descripcion=$enf.Descripción},
 [pscustomobject]@{nombre='DIAS_ACCIDENTE';estado=$acc.'Cód_ Estado';agregado=5;descripcion=$acc.Descripción},
 [pscustomobject]@{nombre='DIAS_ENFERMEDAD_30';estado=$enf.'Cód_ Estado';agregado=10;descripcion='Días de enfermedad dentro de los tramos, mes comercial de 30'}
)
$paramPlan=@(
 [pscustomobject]@{codigo='AUS_MES_COMERCIAL';descripcion='Usar días comerciales de enfermedad';desde='2026-01-01';valor=0;convenio=''},
 [pscustomobject]@{codigo='PROM_LIC_MESES';descripcion='Meses de ventana del promedio de licencia';desde='2000-01-01';valor=12;convenio=''},
 [pscustomobject]@{codigo='PROM_LIC_UMBRAL';descripcion='Días del vínculo para completar la ventana';desde='2000-01-01';valor=362;convenio=''},
 [pscustomobject]@{codigo='PROM_LIC_DIAS_MES';descripcion='Días por mes del divisor proporcional de licencia';desde='2000-01-01';valor=30;convenio=''}
)
foreach($cct in @($datos.convenios|Where-Object {$_.'Tipo Empleado' -eq 2})){
 $paramPlan+=[pscustomobject]@{codigo='AUS_MES_COMERCIAL';descripcion='Usar días comerciales de enfermedad';desde='2026-01-01';valor=1;convenio=$cct.Código}
}
$mesesAus=@($datos.valores|Where-Object {$_.'Cód_ Parámetro Base' -eq 'MESES_AUS' -and [datetime]$_.'Vigencia Desde' -le [datetime]'2026-01-01'}|Group-Object 'Cód_ Parámetro'|ForEach-Object {$_.Group|Sort-Object 'Vigencia Desde' -Descending|Select-Object -First 1})
foreach($m in @($mesesAus|Where-Object {$_.Valor -eq 6})){
 if(!$m.'Cód_ Convenio' -or $m.'No_ Empleado' -or $m.'Cód_ Categoría'){throw 'El semestre de MESES_AUS tiene un alcance no contemplado.'}
 $paramPlan+=[pscustomobject]@{codigo='PROM_LIC_MESES';descripcion='Meses de ventana del promedio de licencia';desde='2000-01-01';valor=6;convenio=$m.'Cód_ Convenio'}
 $paramPlan+=[pscustomobject]@{codigo='PROM_LIC_UMBRAL';descripcion='Días del vínculo para completar la ventana';desde='2000-01-01';valor=181;convenio=$m.'Cód_ Convenio'}
}
$diasFormula='IF(AUS_MES_COMERCIAL=1,DIAS_ENFERMEDAD_30,DIAS_ENFERMEDAD)'
$regexDias=[regex]::new('\bDIAS_ENFERMEDAD\b',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
$versionPlan=@()
foreach($esp in @(@('4110','2026-01-01','2026-01-02'),@('4115','2026-01-01','2026-01-02'),@('PROM_AUS_MES','2026-01-01','2026-01-02'),@('PROM_AUS_MES_NR','2026-01-01','2026-01-02'),@('4110','2026-02-02','2026-02-03'),@('PROM_ENF_MES','2026-02-02','2026-02-03'))){
 $orig=Una @($datos.conceptos|Where-Object {$_.Código -eq $esp[0] -and (Fecha $_.'Vigencia Desde') -eq $esp[1]}) ('concepto '+$esp[0]+'/'+$esp[1])
 $formula=$regexDias.Replace([string]$orig.Fórmula,$diasFormula)
 if($esp[0] -eq 'PROM_ENF_MES'){$formula='IF(DIV_PROM_LIC>0,(ENF_BASE+ENF_NR)/IFZERO(DIV_PROM_LIC,1),0)'}
 $versionPlan+=[pscustomobject]@{codigo=$esp[0];desdeAntes=$esp[1];desdeNuevo=$esp[2];hasta=(Fecha $orig.'Vigencia Hasta');formula=$formula;condicion=$regexDias.Replace([string]$orig.Condición,$diasFormula);cantidad=$regexDias.Replace([string]$orig.'Variable Cantidad',$diasFormula)}
}
$otrosRefs=@($datos.conceptos|Where-Object {$regexDias.IsMatch([string]$_.Fórmula+' '+[string]$_.Condición+' '+[string]$_.'Variable Cantidad') -and $_.Código -notin @('4110','4115','PROM_AUS_MES','PROM_AUS_MES_NR','PROM_ENF_MES')}|Select-Object Código,'Vigencia Desde','Vigencia Hasta')
$plan=[ordered]@{dias=$dias;parametros=$paramPlan;conceptos=$versionPlan;estado_promedio=$enf.'Cód_ Estado';otras_referencias=$otrosRefs}
$planJson=ConvertTo-Json -InputObject $plan -Depth 12 -Compress
$sha=[Security.Cryptography.SHA256]::Create();try{$planHash=[Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($planJson)))}finally{$sha.Dispose()}
$huellas=@(Get-ChildItem -LiteralPath $Backup -Filter 'antes-*.json'|Sort-Object Name|ForEach-Object {[pscustomobject]@{nombre=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
$firma=[ordered]@{script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;plan=$planHash;respaldos=$huellas}
$firmaJson=ConvertTo-Json -InputObject $firma -Depth 6 -Compress
$pruebaPath=Join-Path $Backup 'prueba-configuracion.json'
if($Aplicar){if(!(Test-Path -LiteralPath $pruebaPath)){throw 'Falta el ensayo previo con rollback.'};$prueba=Get-Content -LiteralPath $pruebaPath -Raw|ConvertFrom-Json;if(!$prueba.rollback -or $prueba.firma -cne $firmaJson){throw 'Cambió el script, el plan o un respaldo desde el ensayo: repetir sin -Aplicar.'}}
[IO.File]::WriteAllText((Join-Path $Backup 'plan-configuracion.json'),(ConvertTo-Json -InputObject $plan -Depth 12),[Text.UTF8Encoding]::new($false))

$cx=[Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
$tx=$null;$schema=@{};$counts=[ordered]@{variables_retiradas=0;fuentes=0;filtros=0;parametros=0;valores=0;divisores=0;conceptos=0;fracciones=0;historial=0}
function Param($Cmd,[string]$Nombre,$Valor){
 if($null -eq $Valor){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::NVarChar,-1);$p.Value=[DBNull]::Value;return}
 if($Valor -is [datetime]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::DateTime)}elseif($Valor -is [bool]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::Bit)}elseif($Valor -is [int]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::Int)}elseif($Valor -is [decimal]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::Decimal);$p.Precision=38;$p.Scale=20}elseif($Valor -is [guid]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::UniqueIdentifier)}else{$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::NVarChar,-1)};$p.Value=$Valor
}
function Cmd([string]$Sql,$Bindings=@{}){$c=$cx.CreateCommand();$c.Transaction=$tx;$c.CommandTimeout=120;$c.CommandText=$Sql;foreach($k in $Bindings.Keys){Param $c ('@'+$k) $Bindings[$k]};return $c}
function ClaveSQL($Claves,$Bindings){$parts=@();$i=0;foreach($k in @($Claves.Keys|Sort-Object)){$n='k'+$i;$Bindings[$n]=$Claves[$k];$parts+=(Q $k)+'=@'+$n;$i++};return $parts-join' AND '}
function Rows([string]$Id,$Claves=@{}){$b=@{};$w=if($Claves.Count){' WHERE '+(ClaveSQL $Claves $b)}else{''};$c=Cmd ('SELECT (SELECT * FROM '+(Tabla $Id)+$w+' FOR JSON PATH, INCLUDE_NULL_VALUES)') $b;try{$j=[string]$c.ExecuteScalar();if(!$j){return @()};return @($j|ConvertFrom-Json)}finally{$c.Dispose()}}
function AssertRow([string]$Id,$Claves,$Anterior){$actual=Una @(Rows $Id $Claves) ('fila actual '+$Id);if((Canonico $actual) -cne (Canonico $Anterior)){throw ('La fila de '+$Id+' cambió desde el respaldo: '+(ConvertTo-Json $Claves -Compress))}}
function AssertSet([string]$Id,$Claves,$Esperadas){
 $actuales=@(Rows $Id $Claves|ForEach-Object {Canonico $_}|Sort-Object)
 $anteriores=@($Esperadas|ForEach-Object {Canonico $_}|Sort-Object)
 if(($actuales.Count -ne $anteriores.Count) -or (($actuales -join "`n") -cne ($anteriores -join "`n"))){throw ('Cambió el conjunto completo de '+$Id+' desde el respaldo.')}
}
function Schema([string]$Id){if(!$schema.ContainsKey($Id)){$c=Cmd 'SELECT (SELECT name,is_identity,is_computed,system_type_id FROM sys.columns WHERE object_id=OBJECT_ID(@obj) ORDER BY column_id FOR JSON PATH)' @{obj=(Tabla $Id)};try{$a=@(([string]$c.ExecuteScalar())|ConvertFrom-Json);if(!$a.Count){throw ('No existe tabla '+$Id)};$schema[$Id]=$a}finally{$c.Dispose()}};return @($schema[$Id])}
function Clone([string]$Id,$Claves,$Cambios){
 $b=@{};$w=ClaveSQL $Claves $b;$nuevo=@{};foreach($k in $Cambios.Keys){$nuevo[$k]=$Cambios[$k]};$nuevo['$systemId']=[guid]::NewGuid();$nuevo['$systemCreatedAt']=[datetime]::UtcNow;$nuevo['$systemModifiedAt']=$nuevo['$systemCreatedAt'];$nuevo['$systemCreatedBy']=[guid]::Empty;$nuevo['$systemModifiedBy']=[guid]::Empty
 $columnas=@();$seleccion=@();$i=0;foreach($col in @(Schema $Id|Where-Object {!$_.is_identity -and !$_.is_computed -and $_.system_type_id -ne 189})){$columnas+=Q $col.name;if($nuevo.ContainsKey($col.name)){$n='v'+$i;$b[$n]=$nuevo[$col.name];$seleccion+='@'+$n;$i++}else{$seleccion+=Q $col.name}}
 $c=Cmd ('INSERT '+(Tabla $Id)+' ('+($columnas-join',')+') SELECT '+($seleccion-join',')+' FROM '+(Tabla $Id)+' WHERE '+$w) $b;try{if($c.ExecuteNonQuery() -ne 1){throw ('Clonación no unitaria: '+$Id)}}finally{$c.Dispose()};$counts[$Id]++
}
function Update([string]$Id,$Claves,$Cambios){$b=@{};$w=ClaveSQL $Claves $b;$sets=@();$i=0;foreach($k in $Cambios.Keys){$n='u'+$i;$b[$n]=$Cambios[$k];$sets+=(Q $k)+'=@'+$n;$i++};$b.now=[datetime]::UtcNow;$b.actor=[guid]::Empty;$sets+='[$systemModifiedAt]=@now';$sets+='[$systemModifiedBy]=@actor';$c=Cmd ('UPDATE '+(Tabla $Id)+' SET '+($sets-join',')+' WHERE '+$w) $b;try{if($c.ExecuteNonQuery() -ne 1){throw ('Actualización no unitaria: '+$Id)}}finally{$c.Dispose()}}
function Libre([string]$Nombre,[bool]$RetirarSistema=$false){
 if(@(Rows filtros @{'Nombre Variable'=$Nombre}).Count){throw ('Hay filtros destino huérfanos o ya configurados: '+$Nombre)}
 foreach($id in @('fuentes','variables','parametros','conceptos','atributos')){$campo=if($id -eq 'conceptos'){'Código'}else{'Nombre Variable'};$rows=@(Rows $id @{$campo=$Nombre});if($id -eq 'variables' -and $RetirarSistema){$rows=@($rows|Where-Object {$_.'Nombre Variable' -notin @('DIAS_ENFERMEDAD','DIAS_ACCIDENTE')})};if($rows.Count){throw ('Nombre ocupado: '+$Nombre+'/'+$id)}}
}
function Filtro([string]$Nombre,[int]$Campo,[string]$Valor){$t=$datos.filtros[0];AssertRow filtros @{'Nombre Variable'=$t.'Nombre Variable';'No_ Línea'=$t.'No_ Línea'} $t;Clone filtros @{'Nombre Variable'=$t.'Nombre Variable';'No_ Línea'=$t.'No_ Línea'} @{'Nombre Variable'=$Nombre;'No_ Campo'=$Campo;'Filtro Valor'=$Valor}}
function Audit($Vig,$Original){
 $nuevos=@{cod=$Vig.codigo;vig=[datetime]$Vig.desdeNuevo;descr=$Original.Descripción;anterior=$Original.Fórmula;nueva=$Vig.formula;condAnt=$Original.Condición;condNueva=$Vig.condicion;formulaChanged=($Original.Fórmula -cne $Vig.formula);conditionChanged=($Original.Condición -cne $Vig.condicion);now=[datetime]::UtcNow;id=[guid]::NewGuid();actor=[guid]::Empty}
 $sql='INSERT '+(Tabla historial)+' ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],Usuario,[Tipo Cambio],[Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],[Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) VALUES(@cod,@vig,@descr,@now,N''AUSENTISMO CONFIGURABLE'',0,@anterior,@nueva,@condAnt,@condNueva,@formulaChanged,@conditionChanged,@now,@id,@now,@actor,@now,@actor)';$c=Cmd $sql $nuevos;try{if($c.ExecuteNonQuery() -ne 1){throw 'No se registró el alta en historial.'};$counts.historial++}finally{$c.Dispose()}
}
try{
 $cx.Open();$tx=$cx.BeginTransaction([Data.IsolationLevel]::Serializable)
 $g=Cmd ('IF DB_NAME()<>N''Migr2013R2'' THROW 51200,N''Base inesperada'',1; IF EXISTS(SELECT 1 FROM [dbo].[ArbuTest$Liquidación'+$s+'] WITH(UPDLOCK,HOLDLOCK) WHERE [Cód_ Tipo Liq_]<>N''HIST_REMUN'' AND (([Cód_ Período] IN(N''202601'',N''202602'') AND Estado>1) OR ([Fecha Liquidación]>=''20260301'' AND Estado>=1))) THROW 51200,N''Hay liquidaciones protegidas o posteriores calculadas'',1;');try{$null=$g.ExecuteNonQuery()}finally{$g.Dispose()}
 foreach($id in @('filtros','historial')){if(@(Schema $id|Where-Object {$_.name -in @('No_ Línea','No_ Entrada') -and $_.is_identity}).Count -ne 1){throw ('La clave autoincremental cambió: '+$id)}}
 foreach($v in @($enf,$acc,$previos)+$legacyDiv){AssertRow variables @{'Nombre Variable'=$v.'Nombre Variable'} $v}
 foreach($nombre in @('ENF_BASE_6','ENF_NR_6')){AssertSet filtros @{'Nombre Variable'=$nombre} @($datos.filtros|Where-Object {$_.'Nombre Variable' -eq $nombre})}
 foreach($codigo in @($versionPlan.codigo|Sort-Object -Unique)){AssertSet fracciones @{'Cód_ Concepto'=$codigo} @($datos.fracciones|Where-Object {$_.'Cód_ Concepto' -eq $codigo})}
 foreach($nuevo in @($dias.nombre)+@('DIV_PROM_LIC','ENF_BASE','ENF_NR')+@($paramPlan.codigo|Sort-Object -Unique)){Libre $nuevo ($nuevo -in @('DIAS_ENFERMEDAD','DIAS_ACCIDENTE'))}
 foreach($cct in $datos.convenios){AssertRow convenios @{Código=$cct.Código} $cct}
 foreach($m in $mesesAus){AssertRow valores @{'Cód_ Parámetro'=$m.'Cód_ Parámetro';'Vigencia Desde'=$m.'Vigencia Desde'} $m}
 foreach($v in @($enf,$acc)){$rv='0x'+(([Convert]::FromBase64String([string]$v.timestamp)|ForEach-Object {$_.ToString('X2')})-join'');$c=Cmd ('DELETE FROM '+(Tabla variables)+' WHERE [Nombre Variable]=@nom AND [timestamp]=CONVERT(varbinary(8),@rv,1)') @{nom=$v.'Nombre Variable';rv=$rv};try{if($c.ExecuteNonQuery() -ne 1){throw 'Cambió una variable antes de retirar su origen.'};$counts.variables_retiradas++}finally{$c.Dispose()}}
 $modeloDias=Una @($datos.fuentes|Where-Object {$_.'Nombre Variable' -eq 'DIAS_ENF_PERIODO'}) 'fuente de días por estado'
 AssertRow fuentes @{'Nombre Variable'=$modeloDias.'Nombre Variable'} $modeloDias
 foreach($d in $dias){Clone fuentes @{'Nombre Variable'=$modeloDias.'Nombre Variable'} @{'Nombre Variable'=$d.nombre;'Descripción'=$d.descripcion;'Id_ Tabla'=60000;'No_ Campo Valor'=0;'Función Agregado'=[int]$d.agregado;'No_ Campo Fecha Inicio'=2;'No_ Campo Fecha Fin'=4;'Fin Efectivo'=1;'Activo'=1;'Mostrar en Recibo'=0;'Etiqueta Recibo'='';'No_ Filtro 1'=0;'No_ Filtro 2'=0;'No_ Filtro 3'=0;'Filtro Valor 1'='';'Filtro Valor 2'='';'Filtro Valor 3'='';'No_ Campo Clave'=1;'Orden Descendente'=0};Filtro $d.nombre 9 '0';Filtro $d.nombre 1 '{EMP_NO}';Filtro $d.nombre 3 $d.estado;Filtro $d.nombre 2 '<={FECHA_REF}'}
 $modeloParam=Una @($datos.parametros|Where-Object {$_.Código -eq 'MESES_AUS'}) 'parámetro de meses'
 $modeloValor=Una @($datos.valores|Where-Object {$_.'Cód_ Parámetro Base' -eq 'MESES_AUS' -and !$_. 'Cód_ Convenio' -and !$_. 'No_ Empleado'}|Sort-Object 'Vigencia Desde' -Descending|Select-Object -First 1) 'valor general de meses'
 AssertRow parametros @{Código=$modeloParam.Código} $modeloParam;AssertRow valores @{'Cód_ Parámetro'=$modeloValor.'Cód_ Parámetro';'Vigencia Desde'=$modeloValor.'Vigencia Desde'} $modeloValor
 foreach($codigo in @($paramPlan.codigo|Sort-Object -Unique)){$p=@($paramPlan|Where-Object codigo -eq $codigo)[0];Clone parametros @{Código=$modeloParam.Código} @{Código=$codigo;'Nombre Variable'=$codigo;'Descripción'=$p.descripcion;Notas='Configuración de ausentismo por estado y vínculo';'Sufijo CCT'=0;'Sufijo Empleado'=0;'Sufijo Convenio'=0;'Antigüedad Máxima Vigencia'='';'Edad Máxima Familiar'=0;'Cód_ Tipo Atributo 1'='';'Cód_ Tipo Atributo 2'='';'Cód_ Tipo Atributo 3'=''}}
 foreach($p in $paramPlan){$clave=$p.codigo;if($p.convenio){$clave+='_'+$p.convenio};if(@(Rows valores @{'Cód_ Parámetro'=$clave}).Count){throw ('Ya existe valor destino '+$clave)};Clone valores @{'Cód_ Parámetro'=$modeloValor.'Cód_ Parámetro';'Vigencia Desde'=$modeloValor.'Vigencia Desde'} @{'Cód_ Parámetro Base'=$p.codigo;'Cód_ Parámetro'=$clave;'Vigencia Desde'=[datetime]$p.desde;'Descripción'=$p.descripcion;Valor=[decimal]$p.valor;Moneda='';Notas='Ausentismo configurable: preservar vínculo y regla comercial';'En Uso'=0;'No_ Empleado'='';'Cód_ Convenio'=$p.convenio;'Cód_ Categoría'='';Nivel=[int][bool]$p.convenio;'Cód_ Variable TC'='';'Sufijo Atributo 1'='';'Sufijo Atributo 2'='';'Sufijo Atributo 3'=''}}
 foreach($v in $legacyDiv){Update variables @{'Nombre Variable'=$v.'Nombre Variable'} @{'Cód_ Estado'=$enf.'Cód_ Estado'}}
 $tpl=$legacyDiv[0];Clone variables @{'Nombre Variable'=$tpl.'Nombre Variable'} @{'Nombre Variable'='DIV_PROM_LIC';'Cód_ Cálculo'='DIV_PROM_LIC';'Cód_ Estado'=$enf.'Cód_ Estado';Descripción='Divisor del promedio de licencia configurado por vínculo';Activo=1;'Mostrar en Recibo'=0;'Etiqueta Recibo'='';'Etiqueta Det_ Ganancias'='';'Orden Det_ Ganancias'=0};$counts.divisores=3
 foreach($map in @(@('ENF_BASE_6','ENF_BASE'),@('ENF_NR_6','ENF_NR'))){$f=Una @($datos.fuentes|Where-Object {$_.'Nombre Variable' -eq $map[0]}) ('fuente '+$map[0]);AssertRow fuentes @{'Nombre Variable'=$f.'Nombre Variable'} $f;Clone fuentes @{'Nombre Variable'=$f.'Nombre Variable'} @{'Nombre Variable'=$map[1];Descripción='Histórico del vínculo y ventana de licencia configurada'};foreach($fl in @($datos.filtros|Where-Object {$_.'Nombre Variable' -eq $map[0]})){AssertRow filtros @{'Nombre Variable'=$fl.'Nombre Variable';'No_ Línea'=$fl.'No_ Línea'} $fl;$valor=if($fl.'No_ Campo' -eq 23){'{PROM_LIC_DESDE:DIV_PROM_LIC}..{PROM_LIC_HASTA:DIV_PROM_LIC}'}else{$fl.'Filtro Valor'};Clone filtros @{'Nombre Variable'=$fl.'Nombre Variable';'No_ Línea'=$fl.'No_ Línea'} @{'Nombre Variable'=$map[1];'Filtro Valor'=$valor}}}
 foreach($v in $versionPlan){$orig=Una @($datos.conceptos|Where-Object {$_.Código -eq $v.codigo -and (Fecha $_.'Vigencia Desde') -eq $v.desdeAntes}) 'concepto origen';$key=@{Código=$v.codigo;'Vigencia Desde'=$orig.'Vigencia Desde'};AssertRow conceptos $key $orig;if(@(Rows conceptos @{Código=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeNuevo}).Count){throw 'Ya existe una vigencia destino.'};foreach($txt in @($v.formula,$v.condicion)){if($txt.Length -gt 2048){throw 'Fórmula o condición supera su campo.'}};if($v.cantidad.Length -gt 100){throw 'La cantidad supera su campo.'};Clone conceptos $key @{'Vigencia Desde'=[datetime]$v.desdeNuevo;Fórmula=$v.formula;Condición=$v.condicion;'Variable Cantidad'=$v.cantidad};Update conceptos $key @{'Vigencia Hasta'=([datetime]$v.desdeNuevo).AddDays(-1)}
  $fracs=@($datos.fracciones|Where-Object {$_.'Cód_ Concepto' -eq $v.codigo -and [datetime]$_.'Vigencia Desde' -le [datetime]$v.desdeAntes}|Group-Object 'Cód_ Acumulador'|ForEach-Object {$_.Group|Sort-Object 'Vigencia Desde' -Descending|Select-Object -First 1});foreach($f in $fracs){$fk=@{'Cód_ Concepto'=$f.'Cód_ Concepto';'Vigencia Desde'=$f.'Vigencia Desde';'Cód_ Acumulador'=$f.'Cód_ Acumulador'};AssertRow fracciones $fk $f;if(@(Rows fracciones @{'Cód_ Concepto'=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeNuevo;'Cód_ Acumulador'=$f.'Cód_ Acumulador'}).Count){throw 'Fracción destino ya existente.'};Clone fracciones $fk @{'Vigencia Desde'=[datetime]$v.desdeNuevo}}
  Audit $v $orig
 }
 AssertRow variables @{'Nombre Variable'=$previos.'Nombre Variable'} $previos
 if($counts.variables_retiradas -ne 2 -or $counts.fuentes -ne 5 -or $counts.conceptos -ne 6 -or $counts.historial -ne 6){throw 'Cantidad de cambios distinta del plan auditado.'}
 if($Aplicar){$tx.Commit();$tx.Dispose();$tx=$null;foreach($id in @('variables','fuentes','filtros','parametros','valores','conceptos','fracciones')){$filas=Rows $id;[IO.File]::WriteAllText((Join-Path $Backup ('aplicado-'+$id+'.json')),(ConvertTo-Json -InputObject @($filas) -Depth 12),[Text.UTF8Encoding]::new($false))};'Configuración aplicada; renovar caché y recalcular antes de conciliar.'}
 else{$tx.Rollback();$tx.Dispose();$tx=$null;foreach($v in @($enf,$acc,$previos)+$legacyDiv){AssertRow variables @{'Nombre Variable'=$v.'Nombre Variable'} $v};foreach($nuevo in @($dias.nombre)+@('DIV_PROM_LIC','ENF_BASE','ENF_NR')+@($paramPlan.codigo|Sort-Object -Unique)){Libre $nuevo ($nuevo -in @('DIAS_ENFERMEDAD','DIAS_ACCIDENTE'))};foreach($v in $versionPlan){$old=Una @($datos.conceptos|Where-Object {$_.Código -eq $v.codigo -and (Fecha $_.'Vigencia Desde') -eq $v.desdeAntes}) 'versión original tras rollback';AssertRow conceptos @{Código=$v.codigo;'Vigencia Desde'=$old.'Vigencia Desde'} $old;if(@(Rows conceptos @{Código=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeNuevo}).Count -or @(Rows fracciones @{'Cód_ Concepto'=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeNuevo}).Count){throw 'Quedó una versión o fracción nueva después del rollback.'}};foreach($p in $paramPlan){$clave=$p.codigo;if($p.convenio){$clave+='_'+$p.convenio};if(@(Rows valores @{'Cód_ Parámetro'=$clave}).Count){throw 'Quedó un parámetro vigente nuevo después del rollback.'}};[IO.File]::WriteAllText($pruebaPath,(ConvertTo-Json -InputObject @{rollback=$true;firma=$firmaJson;cuentas=$counts} -Depth 8),[Text.UTF8Encoding]::new($false));'Ensayo completo revertido; se guardó la firma de script, plan y respaldos.'}
 $counts|ConvertTo-Json -Compress
 if($otrosRefs.Count){'Otras referencias que requieren revisión antes de ampliar la migración:';$otrosRefs|Format-Table -AutoSize}
}finally{if($tx){try{$tx.Rollback()}finally{$tx.Dispose()}};$cx.Dispose()}
