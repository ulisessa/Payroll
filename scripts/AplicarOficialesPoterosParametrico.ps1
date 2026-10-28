<#
Aplica exclusivamente el plan privado de configuración de oficiales poteros.
Sin -Aplicar ensaya todos los cambios en una transacción y revierte. No calcula ni reabre.
La selección, precios, fechas y fórmulas provienen del JSON; no hay legajos embebidos.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Backup,
 [Parameter(Mandatory)][string]$PlanConfiguracion,
 [string]$Servidor='tcp:mimir.arbumasa.com,1433',
 [string]$Base='Migr2013R2',
 [string]$Compania='ArbuTest',
 [guid]$ExtensionId='d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890',
 [switch]$Aplicar
)
$ErrorActionPreference='Stop'
$Backup=(Resolve-Path -LiteralPath $Backup).Path;$PlanConfiguracion=(Resolve-Path -LiteralPath $PlanConfiguracion).Path
$plan=Get-Content -Raw -LiteralPath $PlanConfiguracion|ConvertFrom-Json
$versiones=@($plan.formulas);$fuentesPlan=@($plan.fuentes);$personales=@($plan.parametrosPersonales|Where-Object accion -eq 'crear_vigencia_personal');$norma=@($plan.parametroNuevo.valores)
if($versiones.Count -ne 3 -or @($versiones.codigo|Sort-Object -Unique).Count -ne 3 -or $fuentesPlan.Count -ne 2 -or $norma.Count -ne 3 -or $personales.Count -ne 8){throw 'Cantidad de cambios no corresponde al plan revisado.'}
if($plan.PSObject.Properties.Name -contains 'calendario'){throw 'El calendario requiere plan y aplicador revisados; no se admite un cambio implícito.'}
foreach($v in $versiones){if(!$v.formula -or $v.formula.Length -gt 2048 -or $v.formulaOrden.Length -gt 2048 -or [datetime]$v.desdeNuevo -le [datetime]$v.desdeAntes -or !$v.formula.Contains($v.formulaElseOriginal)){throw ('Fórmula o vigencia inválida: '+$v.codigo)}}
$s='$'+$ExtensionId.ToString();$tab=@{cabeceras='Liquidación';lineas='Línea Liquidación';variables='Resumen Variable Liq_';uso_parametros='Uso Parámetro Liq_';conceptos='Concepto Liquidación';fracciones='Fracción Acumulador';fuentes='Fuente Datos Liquidación';filtros='Filtro Fuente Datos Liq_';parametros='Parámetro';valores_param='Parámetro Vigente';atributos='Atributo Entidad Liq_';variables_cfg='Variable Sistema Liq_';tipos_atributo='Tipo Atributo Liq_';historial='Historial Fórmula Concepto';francos='Movimiento Franco Liq_';tramos='Tramo Cobertura Liq_'}
function Q($n){'['+$n.Replace(']',']]')+']'}
function Tabla($id){if(!$tab.ContainsKey($id)){throw ('Tabla desconocida: '+$id)};'[dbo].'+(Q ($Compania+'$'+$tab[$id]+$s))}
function Leer($n){$p=Join-Path $Backup ($n+'.json');if(!(Test-Path -LiteralPath $p)){throw ('Falta respaldo: '+$p)};@(Get-Content -Raw -LiteralPath $p|ConvertFrom-Json)}
function Guardar($n,$v){[IO.File]::WriteAllText((Join-Path $Backup ($n+'.json')),(ConvertTo-Json -InputObject $v -Depth 24),[Text.UTF8Encoding]::new($false))}
function Una($a,$desc){$a=@($a);if($a.Count -ne 1){throw ('Se esperaba una fila: '+$desc)};$a[0]}
function Fecha($v){([datetime]$v).ToString('yyyy-MM-dd')}
function Canonico($fila){$o=[ordered]@{};foreach($p in @($fila.PSObject.Properties|Sort-Object Name)){$o[$p.Name]=$p.Value};ConvertTo-Json -InputObject $o -Compress -Depth 15}
function SetCanonico($a){(@($a|Where-Object {$null -ne $_}|ForEach-Object {Canonico $_}|Sort-Object)-join "`n")}
$ids=@('cabeceras','lineas','variables','uso_parametros','conceptos','fracciones','fuentes','filtros','parametros','valores_param','atributos');$datos=@{};foreach($id in $ids){$datos[$id]=Leer $id}
$empleados=@($plan.acuerdos.empleado|Sort-Object -Unique);$docs=@($datos.cabeceras.No_|Sort-Object -Unique);$periodos=@($datos.cabeceras.'Cód_ Período'|Sort-Object -Unique)
if(!$empleados.Count -or !$docs.Count -or @($datos.cabeceras|Where-Object {$_.'No_ Empleado' -notin $empleados}).Count){throw 'El respaldo no corresponde al alcance de acuerdos.'}
$limite=([datetime](@($datos.cabeceras.'Fecha Liquidación'|Sort-Object -Descending)[0])).Date
$aux=@('variables_cfg','tipos_atributo','historial','francos','tramos','valores-futuros')
$pruebaPath=Join-Path $Backup 'prueba-oficiales-poteros.json'
function Firma {
 $hs=@(foreach($n in @($ids+@($aux|ForEach-Object {'antes-'+$_})|Sort-Object -Unique)){$p=Join-Path $Backup ($n+'.json');if(!(Test-Path -LiteralPath $p)){throw ('Falta respaldo de ensayo: '+$n)};[ordered]@{nombre=$n;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}})
 ConvertTo-Json -InputObject ([ordered]@{script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;plan=(Get-FileHash -LiteralPath $PlanConfiguracion -Algorithm SHA256).Hash;servidor=$Servidor;base=$Base;compania=$Compania;extension=$ExtensionId.ToString();respaldos=$hs}) -Compress -Depth 20
}
if($Aplicar){if(!(Test-Path -LiteralPath $pruebaPath)){throw 'Falta ensayo revertido.'};$prueba=Get-Content -Raw -LiteralPath $pruebaPath|ConvertFrom-Json;if(!$prueba.rollback -or $prueba.firma -cne (Firma)){throw 'Cambió el script, plan, conexión o respaldo. Repetir el ensayo sin -Aplicar.'}}
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new();$builder['Data Source']=$Servidor;$builder['Initial Catalog']=$Base;$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=15
$cx=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$tx=$null;$schema=@{}
$cuentas=[ordered]@{fuentes=0;filtros=0;parametros=0;valores_param=0;conceptos=0;fracciones=0;historial=0;vigencias_cerradas=0}
function Param($cmd,$nombre,$valor){
 if($null -eq $valor){$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::NVarChar,-1);$p.Value=[DBNull]::Value;return}
 if($valor -is [datetime]){$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::DateTime)}elseif($valor -is [guid]){$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::UniqueIdentifier)}elseif($valor -is [decimal]){$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::Decimal);$p.Precision=38;$p.Scale=20}elseif($valor -is [int]){$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::Int)}elseif($valor -is [bool]){$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::Bit)}else{$p=$cmd.Parameters.Add($nombre,[Data.SqlDbType]::NVarChar,-1)};$p.Value=$valor
}
function Cmd($sql,$b=@{}){$c=$cx.CreateCommand();$c.Transaction=$tx;$c.CommandTimeout=120;$c.CommandText=$sql;foreach($k in $b.Keys){Param $c ('@'+$k) $b[$k]};$c}
function Lista($a,$prefix,$b){$out=@();$i=0;foreach($v in $a){$n=$prefix+$i;$b[$n]=$v;$out+='@'+$n;$i++};if(!$out.Count){throw 'Lista vacía.'};$out-join','}
function Clave($a,$b){$out=@();$i=0;foreach($k in @($a.Keys|Sort-Object)){$n='k'+$i;$b[$n]=$a[$k];$out+=(Q $k)+'=@'+$n;$i++};$out-join' AND '}
function Query($sql,$b=@{}){$c=Cmd ('SELECT ('+$sql+' FOR JSON PATH,INCLUDE_NULL_VALUES)') $b;try{$j=[string]$c.ExecuteScalar();if(!$j){return @()};@($j|ConvertFrom-Json)}finally{$c.Dispose()}}
function Rows($id,$key=@{}){$b=@{};$w=if($key.Count){' WHERE '+(Clave $key $b)}else{''};@(Query ('SELECT * FROM '+(Tabla $id)+' WITH(UPDLOCK,HOLDLOCK)'+$w) $b)}
function Scoped($id){
 $b=@{limite=$limite};$emp=Lista $empleados 'e' $b;$doc=Lista $docs 'd' $b;$per=Lista $periodos 'p' $b;$hint=' WITH(UPDLOCK,HOLDLOCK)'
 switch($id){
  'cabeceras' {$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [No_ Empleado] IN('+ $emp +') AND [Cód_ Período] IN('+ $per +')'}
  {$_ -in @('lineas','variables','uso_parametros','francos','tramos')} {$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [No_ Liquidación] IN('+ $doc +')'}
  'atributos' {$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [Tipo Entidad]=0 AND [Cód_ Entidad] IN('+ $emp +')'}
  'valores_param' {$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [Vigencia Desde]<=@limite AND ([No_ Empleado]=N'''' OR [No_ Empleado] IN('+ $emp +'))'}
  'valores-futuros' {$sql='SELECT * FROM '+(Tabla valores_param)+$hint+' WHERE [Vigencia Desde]>@limite AND ([No_ Empleado]=N'''' OR [No_ Empleado] IN('+ $emp +'))'}
  default {$sql='SELECT * FROM '+(Tabla $id)+$hint}
 };@(Query $sql $b)
}
function Assert($actual,$previo,$nombre){if((SetCanonico @($actual)) -cne (SetCanonico @($previo))){Guardar ('guard-fallo-'+$nombre) @($actual);throw ('Cambió el respaldo protegido: '+$nombre)}}
function Schema($id){if(!$schema.ContainsKey($id)){$schema[$id]=@(Query 'SELECT name,is_identity,is_computed,system_type_id FROM sys.columns WHERE object_id=OBJECT_ID(@obj) ORDER BY column_id' @{obj=(Tabla $id)});if(!$schema[$id].Count){throw ('Tabla inexistente: '+$id)}};@($schema[$id])}
function Clone($id,$key,$changes){
 $b=@{};$where=Clave $key $b;$nuevo=@{};foreach($k in $changes.Keys){$nuevo[$k]=$changes[$k]};$nuevo['$systemId']=[guid]::NewGuid();$nuevo['$systemCreatedAt']=[datetime]::UtcNow;$nuevo['$systemModifiedAt']=$nuevo['$systemCreatedAt'];$nuevo['$systemCreatedBy']=[guid]::Empty;$nuevo['$systemModifiedBy']=[guid]::Empty
 $cols=@();$sel=@();$i=0;foreach($col in @(Schema $id|Where-Object {!$_.is_identity -and !$_.is_computed -and $_.system_type_id -ne 189})){$cols+=Q $col.name;if($nuevo.ContainsKey($col.name)){$n='v'+$i;$b[$n]=$nuevo[$col.name];$sel+='@'+$n;$i++}else{$sel+=Q $col.name}}
 $c=Cmd ('INSERT '+(Tabla $id)+' ('+($cols-join',')+') SELECT '+($sel-join',')+' FROM '+(Tabla $id)+' WHERE '+$where) $b;try{if($c.ExecuteNonQuery() -ne 1){throw ('Clonación no unitaria: '+$id)};$cuentas[$id]++}finally{$c.Dispose()}
}
function IgualSalvo($antes,$despues,$permitidos,$nombre){foreach($p in $antes.PSObject.Properties){if($p.Name -notin $permitidos -and (ConvertTo-Json -InputObject $p.Value -Compress) -cne (ConvertTo-Json -InputObject $despues.($p.Name) -Compress)){throw ($nombre+': cambió '+$p.Name)}}}
$meta=@('timestamp','$systemId','$systemCreatedAt','$systemModifiedAt','$systemCreatedBy','$systemModifiedBy')
function Libre($nombre){foreach($id in @('fuentes','filtros','variables_cfg','parametros','tipos_atributo','conceptos')){$campo=if($id -eq 'conceptos'){'Código'}else{'Nombre Variable'};if(@(Rows $id @{$campo=$nombre}).Count){throw ('Nombre variable ocupado: '+$nombre+'/'+$id)}}}
function Audit($v,$original){
 $b=@{cod=$v.codigo;vig=[datetime]$v.desdeNuevo;descr=$original.Descripción;antes=$original.Fórmula;nueva=$v.formula;cond=$original.Condición;utc=[datetime]::UtcNow;id=[guid]::NewGuid();actor=[guid]::Empty}
 $sql='INSERT '+(Tabla historial)+' ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],Usuario,[Tipo Cambio],[Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],[Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) VALUES(@cod,@vig,@descr,@utc,N''OFICIALES POTEROS PARAMETRICOS'',0,@antes,@nueva,@cond,@cond,1,0,@utc,@id,@utc,@actor,@utc,@actor)'
 $c=Cmd $sql $b;try{if($c.ExecuteNonQuery() -ne 1){throw 'No se insertó auditoría.'};$cuentas.historial++}finally{$c.Dispose()}
}
function Invariantes {
 foreach($id in @('cabeceras','lineas','variables','uso_parametros','atributos')){Assert @(Scoped $id) $datos[$id] $id}
 foreach($id in $aux|Where-Object {$_ -ne 'historial'}){Assert @(Scoped $id) $datos['antes-'+$id] $id}
 foreach($id in @('fuentes','filtros')){Assert @(Scoped $id|Where-Object {$_.'Nombre Variable' -notin $fuentesPlan.nombre}) $datos[$id] $id}
 Assert @(Scoped parametros|Where-Object Código -ne $plan.parametroNuevo.codigo) $datos.parametros 'parametros-existentes'
 $nuevasClaves=@($norma|ForEach-Object {$_.codigo+'|'+(Fecha $_.desde)})+@($personales|ForEach-Object {$_.codigo+'|'+(Fecha $_.desde)})
 Assert @(Scoped valores_param|Where-Object {($_.'Cód_ Parámetro'+'|'+(Fecha $_.'Vigencia Desde')) -notin $nuevasClaves}) $datos.valores_param 'valores-anteriores'
 foreach($a in $datos['antes-historial']){Assert @(Rows historial @{'No_ Entrada'=$a.'No_ Entrada'}) @($a) 'auditoria-anterior'}
 $viejas=@($versiones|ForEach-Object {$_.codigo+'|'+(Fecha $_.desdeAntes)});$nuevas=@($versiones|ForEach-Object {$_.codigo+'|'+(Fecha $_.desdeNuevo)})
 Assert @(Scoped conceptos|Where-Object {($_.Código+'|'+(Fecha $_.'Vigencia Desde')) -notin @($viejas+$nuevas)}) @($datos.conceptos|Where-Object {($_.Código+'|'+(Fecha $_.'Vigencia Desde')) -notin $viejas}) 'conceptos-ajenos'
 Assert @(Scoped fracciones|Where-Object {($_.'Cód_ Concepto'+'|'+(Fecha $_.'Vigencia Desde')) -notin $nuevas}) $datos.fracciones 'fracciones-anteriores'
}
try{
 $cx.Open();$tx=$cx.BeginTransaction([Data.IsolationLevel]::Serializable)
 $c=Cmd 'IF DB_NAME()<>@db THROW 51240,N''Base inesperada'',1;' @{db=$Base};try{$null=$c.ExecuteNonQuery()}finally{$c.Dispose()}
 foreach($id in $ids){Assert @(Scoped $id) $datos[$id] $id}
 if(@(Schema filtros|Where-Object {$_.name -eq 'No_ Línea' -and $_.is_identity}).Count -ne 1){throw 'No_ Línea dejó de serIDENTITY; revisar numeración antes de clonar filtros.'}
 foreach($id in $aux){$nombre='antes-'+$id;$p=Join-Path $Backup ($nombre+'.json');if(!(Test-Path -LiteralPath $p)){if($Aplicar){throw ('Falta respaldoauxiliar: '+$id)};Guardar $nombre @(Scoped $id)};$datos[$nombre]=Leer $nombre;Assert @(Scoped $id) $datos[$nombre] $nombre}
 foreach($f in $fuentesPlan){Libre $f.nombre};Libre $plan.parametroNuevo.nombreVariable
 $modeloFuente=Una @($datos.fuentes|Where-Object 'Nombre Variable' -eq 'A_CUENTA_MAREA') 'fuente modelo'
 $modeloFiltro=Una @($datos.filtros|Select-Object -First 1) 'filtro modelo'
 foreach($f in $fuentesPlan){
  Clone fuentes @{'Nombre Variable'=$modeloFuente.'Nombre Variable'} @{'Nombre Variable'=$f.nombre;Descripción=('Oficiales poteros: '+$f.nombre);'Id_ Tabla'=[int]$f.tabla;'No_ Campo Valor'=[int]$f.valor;'Función Agregado'=[int]$f.agregado;Activo=1;'Mostrar en Recibo'=0;'Etiqueta Recibo'='';'No_ Campo Fecha Inicio'=0;'No_ Campo Fecha Fin'=0;'Fin Efectivo'=0;'Tipo Dato'=0;'No_ Campo Clave'=0;'Orden Descendente'=0;'No_ Filtro 1'=0;'No_ Filtro 2'=0;'No_ Filtro 3'=0;'Filtro Valor 1'='';'Filtro Valor 2'='';'Filtro Valor 3'=''}
  foreach($fl in $f.filtros){Clone filtros @{'Nombre Variable'=$modeloFiltro.'Nombre Variable';'No_ Línea'=$modeloFiltro.'No_ Línea'} @{'Nombre Variable'=$f.nombre;'No_ Campo'=[int]$fl.campo;'Filtro Valor'=[string]$fl.valor}}
  $n=Una @(Rows fuentes @{'Nombre Variable'=$f.nombre}) 'fuente creada';if($n.'Id_ Tabla' -ne $f.tabla -or $n.'No_ Campo Valor' -ne $f.valor -or $n.'Función Agregado' -ne $f.agregado){throw 'Fuente difiere del plan.'}
  Assert @(Rows filtros @{'Nombre Variable'=$f.nombre}|ForEach-Object {[pscustomobject]@{campo=[int]$_.'No_ Campo';valor=[string]$_.'Filtro Valor'}}) $f.filtros 'filtros-nuevos'
  $lineasFiltro=@(Rows filtros @{'Nombre Variable'=$f.nombre}|Select-Object -ExpandProperty 'No_ Línea');if(@($lineasFiltro|Sort-Object -Unique).Count -ne $f.filtros.Count){throw 'Claves de filtros repetidas.'}
 }
 $modeloParam=Una @($datos.parametros|Where-Object Código -eq 'VALOR_NAV_EMP') 'parámetro modelo'
 Clone parametros @{Código=$modeloParam.Código} @{Código=$plan.parametroNuevo.codigo;'Nombre Variable'=$plan.parametroNuevo.nombreVariable;Descripción=$plan.parametroNuevo.descripcion;Notas='Tarifa normativa CCT; reconstrucción histórica sin precio personal';'Sufijo CCT'=1;'Sufijo Empleado'=0;'Sufijo Convenio'=0;'Antigüedad Máxima Vigencia'='';'Edad Máxima Familiar'=0;'Cód_ Tipo Atributo 1'='';'Cód_ Tipo Atributo 2'='';'Cód_ Tipo Atributo 3'=''}
 foreach($p in @($norma+$personales)){
  if(@(Rows valores_param @{'Cód_ Parámetro Base'=$p.base;'Cód_ Parámetro'=$p.codigo;'Vigencia Desde'=[datetime]$p.desde}).Count){throw ('Vigencia destino ocupada: '+$p.codigo)}
  $candidatos=@($datos.valores_param|Where-Object 'Cód_ Parámetro Base' -eq $p.base|Sort-Object 'Vigencia Desde' -Descending);if(!$candidatos.Count){$candidatos=@($datos.valores_param|Where-Object 'Cód_ Parámetro Base' -eq $modeloParam.Código|Sort-Object 'Vigencia Desde' -Descending)}
  $modelo=Una @($candidatos|Select-Object -First 1) 'valor modelo';$emp='';$cct='';$cat='';$nivel=0
  if($p.PSObject.Properties.Name -contains 'empleado'){$emp=[string]$p.empleado};if($p.PSObject.Properties.Name -contains 'convenio'){$cct=[string]$p.convenio};if($p.PSObject.Properties.Name -contains 'categoria'){$cat=[string]$p.categoria};if($emp){$nivel=1}elseif($cct -and $cat){$nivel=2}elseif($cct){$nivel=3}
  Clone valores_param @{'Cód_ Parámetro Base'=$modelo.'Cód_ Parámetro Base';'Cód_ Parámetro'=$modelo.'Cód_ Parámetro';'Vigencia Desde'=[datetime]$modelo.'Vigencia Desde'} @{'Cód_ Parámetro Base'=$p.base;'Cód_ Parámetro'=$p.codigo;'Vigencia Desde'=[datetime]$p.desde;Descripción='Acuerdo o tarifa normativa de oficiales poteros';Valor=[decimal]$p.valor;Moneda=[string]$p.moneda;Notas='Según plan revisado y respaldo de acuerdos; preservar enero';'En Uso'=0;'No_ Empleado'=$emp;'Cód_ Convenio'=$cct;'Cód_ Categoría'=$cat;Nivel=[int]$nivel;'Cód_ Variable TC'=[string]$p.variableTC;'Sufijo Atributo 1'='';'Sufijo Atributo 2'='';'Sufijo Atributo 3'=''}
  $n=Una @(Rows valores_param @{'Cód_ Parámetro Base'=$p.base;'Cód_ Parámetro'=$p.codigo;'Vigencia Desde'=[datetime]$p.desde}) 'valor creado';if([decimal]$n.Valor -ne [decimal]$p.valor -or $n.'Cód_ Parámetro Base' -ne $p.base -or $n.Moneda -ne [string]$p.moneda -or $n.'Cód_ Variable TC' -ne [string]$p.variableTC -or $n.'No_ Empleado' -ne $emp -or $n.'Cód_ Convenio' -ne $cct -or $n.'Cód_ Categoría' -ne $cat){throw 'Valor creado difiere del plan.'}
 }
 foreach($v in $versiones){
  $key=@{Código=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeAntes};$o=Una @(Rows conceptos $key) 'concepto origen'
  if($o.Fórmula -cne $v.formulaAnterior -or $o.'Fórmula Orden Cálculo' -cne $v.formulaOrdenAnterior){throw ('Cambió fórmula origen: '+$v.codigo)}
  if([datetime]$o.'Vigencia Hasta' -gt [datetime]'1753-01-01' -and [datetime]$o.'Vigencia Hasta' -lt [datetime]$v.desdeNuevo){throw ('Origen ya cerrado antes de la nueva vigencia: '+$v.codigo)}
  if(@(Rows conceptos @{Código=$v.codigo}|Where-Object {[datetime]$_.'Vigencia Desde' -gt [datetime]$v.desdeAntes}).Count){throw ('Existe versión posterior: '+$v.codigo)}
  Clone conceptos $key @{'Vigencia Desde'=[datetime]$v.desdeNuevo;Fórmula=$v.formula;'Fórmula Orden Cálculo'=$v.formulaOrden}
  $n=Una @(Rows conceptos @{Código=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeNuevo}) 'concepto creado';IgualSalvo $o $n @($meta+@('Vigencia Desde','Fórmula','Fórmula Orden Cálculo')) 'concepto creado'
  if($n.Fórmula -cne $v.formula -or $n.'Fórmula Orden Cálculo' -cne $v.formulaOrden){throw 'Texto nuevo difiere del plan.'}
  foreach($fr in @($datos.fracciones|Where-Object {$_.'Cód_ Concepto' -eq $v.codigo -and (Fecha $_.'Vigencia Desde') -eq (Fecha $v.desdeAntes)})){
   Clone fracciones @{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Vigencia Desde'=[datetime]$fr.'Vigencia Desde';'Cód_ Acumulador'=$fr.'Cód_ Acumulador'} @{'Vigencia Desde'=[datetime]$v.desdeNuevo}
   $fn=Una @(Rows fracciones @{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Vigencia Desde'=[datetime]$v.desdeNuevo;'Cód_ Acumulador'=$fr.'Cód_ Acumulador'}) 'fracción creada';IgualSalvo $fr $fn @($meta+@('Vigencia Desde')) 'fracción creada'
  }
  $b=@{codigo=$v.codigo;desde=[datetime]$v.desdeAntes;hasta=([datetime]$v.desdeNuevo).AddDays(-1);utc=[datetime]::UtcNow;actor=[guid]::Empty}
  $c=Cmd ('UPDATE '+(Tabla conceptos)+' SET [Vigencia Hasta]=@hasta,[$systemModifiedAt]=@utc,[$systemModifiedBy]=@actor WHERE Código=@codigo AND [Vigencia Desde]=@desde') $b;try{if($c.ExecuteNonQuery() -ne 1){throw 'Cierre no unitario de vigencia.'};$cuentas.vigencias_cerradas++}finally{$c.Dispose()}
  $cerrada=Una @(Rows conceptos $key) 'versión cerrada';IgualSalvo $o $cerrada @('timestamp','Vigencia Hasta','$systemModifiedAt','$systemModifiedBy') 'versión cerrada';if((Fecha $cerrada.'Vigencia Hasta') -ne (Fecha $b.hasta)){throw 'Fin de vigencia inválido.'};Audit $v $o
 }
 if($cuentas.fuentes -ne 2 -or $cuentas.filtros -ne 9 -or $cuentas.parametros -ne 1 -or $cuentas.valores_param -ne 11 -or $cuentas.conceptos -ne 3 -or $cuentas.fracciones -ne 16 -or $cuentas.historial -ne 3 -or $cuentas.vigencias_cerradas -ne 3){throw 'Cantidades distintas del plan.'}
 Invariantes
 if(@(Scoped historial).Count -ne $datos['antes-historial'].Count+3){throw 'Auditorías ajenas al plan.'}
 if($Aplicar){
  $tx.Commit();$tx.Dispose();$tx=$null
  foreach($id in @('conceptos','fracciones','fuentes','filtros','parametros','valores_param','historial')){Guardar ('aplicado-'+$id) @(Scoped $id)}
  Guardar 'resultado-oficiales-poteros' ([ordered]@{aplicado=$true;cuentas=$cuentas;utc=[datetime]::UtcNow;documentosProtegidos=$docs;planSha256=(Get-FileHash -LiteralPath $PlanConfiguracion -Algorithm SHA256).Hash})
  'Configuración aplicada. No se reabrieron ni calcularon documentos.'
 }else{
  $tx.Rollback();$tx.Dispose();$tx=$null
  foreach($id in $ids){Assert @(Scoped $id) $datos[$id] ('rollback-'+$id)};foreach($id in $aux){Assert @(Scoped $id) $datos['antes-'+$id] ('rollback-'+$id)}
  foreach($f in $fuentesPlan){Libre $f.nombre};Libre $plan.parametroNuevo.nombreVariable
  Guardar 'prueba-oficiales-poteros' ([ordered]@{rollback=$true;cuentas=$cuentas;utc=[datetime]::UtcNow;firma=(Firma);documentosProtegidos=$docs})
  'Ensayo completo revertido. Enero y documentos/configuración anteriores permanecen idénticos.'
 }
 $cuentas|ConvertTo-Json -Compress
}finally{if($tx){try{$tx.Rollback()}finally{$tx.Dispose()}};$cx.Dispose()}
