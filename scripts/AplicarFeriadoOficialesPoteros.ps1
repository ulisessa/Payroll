<# Aplica una única vigencia de feriado mediante plan privado. Por omisión ensaya y revierte.
No reabre, calcula ni cambia documentos. -Aplicar exige la firma del ensayo previo. #>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Backup,
 [Parameter(Mandatory)][string]$PlanPath,
 [string]$Servidor='tcp:mimir.arbumasa.com,1433',
 [string]$Base='Migr2013R2',
 [string]$Compania='ArbuTest',
 [guid]$ExtensionId='d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890',
 [switch]$Aplicar
)
$ErrorActionPreference='Stop'
$Backup=(Resolve-Path -LiteralPath $Backup).Path;$PlanPath=(Resolve-Path -LiteralPath $PlanPath).Path
$plan=Get-Content -Raw -LiteralPath $PlanPath|ConvertFrom-Json
if(!$plan.codigo -or !$plan.formula -or $plan.formula.Length -gt 2048 -or [datetime]$plan.desdeNuevo -le [datetime]$plan.desdeAntes -or ([datetime]$plan.cerrarAnterior).Date -ne ([datetime]$plan.desdeNuevo).AddDays(-1).Date -or !$plan.formula.Contains($plan.formulaAnterior) -or $plan.fracciones.Count -ne 9){throw 'Plan inválido o sin rama anterior exacta.'}
$s='$'+$ExtensionId.ToString();$tab=@{cabeceras='Liquidación';lineas='Línea Liquidación';variables='Resumen Variable Liq_';detalles='Detalle Variable Línea Liq_';francos='Movimiento Franco Liq_';uso_parametros='Uso Parámetro Liq_';conceptos='Concepto Liquidación';fracciones='Fracción Acumulador';fuentes='Fuente Datos Liquidación';filtros='Filtro Fuente Datos Liq_';parametros='Parámetro';valores_param='Parámetro Vigente';atributos='Atributo Entidad Liq_';variables_cfg='Variable Sistema Liq_';tipos_atributo='Tipo Atributo Liq_';historial='Historial Fórmula Concepto';tramos='Tramo Cobertura Liq_'}
function Q($n){'['+$n.Replace(']',']]')+']'}
function Tabla($id){if(!$tab.ContainsKey($id)){throw ('Tabla desconocida: '+$id)};'[dbo].'+(Q ($Compania+'$'+$tab[$id]+$s))}
function Leer($n){$p=Join-Path $Backup ($n+'.json');if(!(Test-Path -LiteralPath $p)){throw ('Falta respaldo: '+$p)};@(Get-Content -Raw -LiteralPath $p|ConvertFrom-Json)}
function Guardar($n,$v){[IO.File]::WriteAllText((Join-Path $Backup ($n+'.json')),(ConvertTo-Json -InputObject $v -Depth 24),[Text.UTF8Encoding]::new($false))}
function Una($a,$desc){$a=@($a);if($a.Count -ne 1){throw ('Se esperaba una fila: '+$desc)};$a[0]}
function Fecha($v){([datetime]$v).ToString('yyyy-MM-dd')}
function Canonico($fila){$o=[ordered]@{};foreach($p in @($fila.PSObject.Properties|Sort-Object Name)){$o[$p.Name]=$p.Value};ConvertTo-Json -InputObject $o -Compress -Depth 15}
function SetCanonico($a){(@($a|Where-Object {$null -ne $_}|ForEach-Object {Canonico $_}|Sort-Object)-join "`n")}
$ids=@('cabeceras','lineas','variables','detalles','francos','uso_parametros','conceptos','fracciones','fuentes','filtros','parametros','valores_param','atributos','variables_cfg','tipos_atributo');$datos=@{};foreach($id in $ids){$datos[$id]=Leer $id}
$empleados=@($datos.cabeceras.'No_ Empleado'|Sort-Object -Unique);$docs=@($datos.cabeceras.No_|Sort-Object -Unique);$periodos=@($datos.cabeceras.'Cód_ Período'|Sort-Object -Unique);$entidades=@($datos.atributos.'Cód_ Entidad'|Sort-Object -Unique)
$limite=([datetime](@($datos.cabeceras.'Fecha Liquidación'|Sort-Object -Descending)[0])).Date
$fracsCod=@($datos.fracciones.'Cód_ Concepto'|Sort-Object -Unique);$aux=@('historial','tramos')
$pruebaPath=Join-Path $Backup 'prueba-feriado-oficiales.json'
function Firma {
 $hs=@(foreach($n in @($ids+@($aux|ForEach-Object {'antes-feriado-'+$_})|Sort-Object -Unique)){$p=Join-Path $Backup ($n+'.json');if(!(Test-Path -LiteralPath $p)){throw ('Falta respaldo de ensayo: '+$n)};[ordered]@{nombre=$n;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}})
 ConvertTo-Json -InputObject ([ordered]@{script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;plan=(Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash;servidor=$Servidor;base=$Base;compania=$Compania;extension=$ExtensionId.ToString();respaldos=$hs}) -Compress -Depth 20
}
if($Aplicar){if(!(Test-Path -LiteralPath $pruebaPath)){throw 'Falta ensayo revertido.'};$prueba=Get-Content -Raw -LiteralPath $pruebaPath|ConvertFrom-Json;if(!$prueba.rollback -or $prueba.firma -cne (Firma)){throw 'Cambió el script, plan, conexión o respaldo. Repetir el ensayo sin -Aplicar.'}}
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new();$builder['Data Source']=$Servidor;$builder['Initial Catalog']=$Base;$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=15
$cx=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$tx=$null;$schema=@{}
$cuentas=[ordered]@{conceptos=0;fracciones=0;historial=0;vigencias_cerradas=0}
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
  {$_ -in @('lineas','variables','detalles','uso_parametros','francos','tramos')} {$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [No_ Liquidación] IN('+ $doc +')'}
  'atributos' {$ent=Lista $entidades 'a' $b;$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [Cód_ Entidad] IN('+ $ent +')'}
  'fracciones' {$fc=Lista $fracsCod 'fc' $b;$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [Cód_ Concepto] IN('+$fc+')'}
  'valores_param' {$sql='SELECT * FROM '+(Tabla $id)+$hint+' WHERE [Vigencia Desde]<=@limite AND ([No_ Empleado]=N'''' OR [No_ Empleado] IN('+ $emp +'))'}
  'valores-futuros' {$sql='SELECT * FROM '+(Tabla valores_param)+$hint+' WHERE [Vigencia Desde]>@limite AND ([No_ Empleado]=N'''' OR [No_ Empleado] IN('+ $emp +'))'}
  default {$sql='SELECT * FROM '+(Tabla $id)+$hint}
 };@(Query $sql $b)
}
function Schema($id){if(!$schema.ContainsKey($id)){$schema[$id]=@(Query 'SELECT name,is_identity,is_computed,system_type_id FROM sys.columns WHERE object_id=OBJECT_ID(@obj) ORDER BY column_id' @{obj=(Tabla $id)});if(!$schema[$id].Count){throw ('Tabla inexistente: '+$id)}};@($schema[$id])}
function Clone($id,$key,$changes){
 $b=@{};$where=Clave $key $b;$nuevo=@{};foreach($k in $changes.Keys){$nuevo[$k]=$changes[$k]};$nuevo['$systemId']=[guid]::NewGuid();$nuevo['$systemCreatedAt']=[datetime]::UtcNow;$nuevo['$systemModifiedAt']=$nuevo['$systemCreatedAt'];$nuevo['$systemCreatedBy']=[guid]::Empty;$nuevo['$systemModifiedBy']=[guid]::Empty
 $cols=@();$sel=@();$i=0;foreach($col in @(Schema $id|Where-Object {!$_.is_identity -and !$_.is_computed -and $_.system_type_id -ne 189})){$cols+=Q $col.name;if($nuevo.ContainsKey($col.name)){$n='v'+$i;$b[$n]=$nuevo[$col.name];$sel+='@'+$n;$i++}else{$sel+=Q $col.name}}
 $c=Cmd ('INSERT '+(Tabla $id)+' ('+($cols-join',')+') SELECT '+($sel-join',')+' FROM '+(Tabla $id)+' WHERE '+$where) $b;try{if($c.ExecuteNonQuery() -ne 1){throw ('Clonación no unitaria: '+$id)};$cuentas[$id]++}finally{$c.Dispose()}
}
function IgualSalvo($antes,$despues,$permitidos,$nombre){foreach($p in $antes.PSObject.Properties){if($p.Name -notin $permitidos -and (ConvertTo-Json -InputObject $p.Value -Compress) -cne (ConvertTo-Json -InputObject $despues.($p.Name) -Compress)){throw ($nombre+': cambió '+$p.Name)}}}
function Assert($actual,$previo,$nombre){if((SetCanonico @($actual)) -cne (SetCanonico @($previo))){Guardar ('guard-feriado-fallo-'+$nombre) @($actual);throw ('Cambió el respaldo protegido: '+$nombre)}}
function Invariantes {
 foreach($id in $ids|Where-Object {$_ -notin @('conceptos','fracciones')}){Assert @(Scoped $id) $datos[$id] $id}
 Assert @(Scoped tramos) $datos['antes-feriado-tramos'] 'tramos'
 $claves=@(($plan.codigo+'|'+(Fecha $plan.desdeAntes)),($plan.codigo+'|'+(Fecha $plan.desdeNuevo)))
 Assert @(Scoped conceptos|Where-Object {($_.Código+'|'+(Fecha $_.'Vigencia Desde')) -notin $claves}) @($datos.conceptos|Where-Object {($_.Código+'|'+(Fecha $_.'Vigencia Desde')) -ne $claves[0]}) 'conceptos-ajenos'
 Assert @(Scoped fracciones|Where-Object {!($_.'Cód_ Concepto' -eq $plan.codigo -and (Fecha $_.'Vigencia Desde') -eq (Fecha $plan.desdeNuevo))}) $datos.fracciones 'fracciones-anteriores'
 $histActual=@(Scoped historial);$entradasAntes=@($datos['antes-feriado-historial'].'No_ Entrada')
 Assert @($histActual|Where-Object {$_.'No_ Entrada' -in $entradasAntes}) $datos['antes-feriado-historial'] 'auditoria-anterior'
 if($histActual.Count -ne $datos['antes-feriado-historial'].Count+1){throw 'Auditorías ajenas al plan.'}
}
$meta=@('timestamp','$systemId','$systemCreatedAt','$systemModifiedAt','$systemCreatedBy','$systemModifiedBy')
try {
 $cx.Open();$tx=$cx.BeginTransaction([Data.IsolationLevel]::Serializable)
 $c=Cmd 'IF DB_NAME()<>@db THROW 51250,N''Base inesperada'',1;' @{db=$Base};try{$null=$c.ExecuteNonQuery()}finally{$c.Dispose()}
 foreach($id in $ids){Assert @(Scoped $id) $datos[$id] $id}
 foreach($id in $aux){$nombre='antes-feriado-'+$id;$p=Join-Path $Backup ($nombre+'.json');if(!(Test-Path -LiteralPath $p)){if($Aplicar){throw ('Falta respaldo auxiliar: '+$id)};Guardar $nombre @(Scoped $id)};$datos[$nombre]=Leer $nombre;Assert @(Scoped $id) $datos[$nombre] $nombre}
 $key=@{Código=$plan.codigo;'Vigencia Desde'=[datetime]$plan.desdeAntes};$o=Una @(Rows conceptos $key) 'concepto origen'
 Assert @($o) @($plan.original) 'origen-plan'
 if([datetime]$o.'Vigencia Hasta' -gt [datetime]'1753-01-01' -and [datetime]$o.'Vigencia Hasta' -lt [datetime]$plan.desdeNuevo){throw 'Origen cerrado antes de la nueva vigencia.'}
 if(@(Rows conceptos @{Código=$plan.codigo}|Where-Object {[datetime]$_.'Vigencia Desde' -gt [datetime]$plan.desdeAntes}).Count){throw 'Existe vigencia posterior; no se sobrescribe.'}
 Assert @(Rows fracciones @{'Cód_ Concepto'=$plan.codigo;'Vigencia Desde'=[datetime]$plan.desdeAntes}) $plan.fracciones 'fracciones-plan'
 Clone conceptos $key @{'Vigencia Desde'=[datetime]$plan.desdeNuevo;Fórmula=$plan.formula}
 $n=Una @(Rows conceptos @{Código=$plan.codigo;'Vigencia Desde'=[datetime]$plan.desdeNuevo}) 'concepto creado';IgualSalvo $o $n @($meta+@('Vigencia Desde','Fórmula')) 'concepto creado'
 if($n.Fórmula -cne $plan.formula){throw 'La fórmula insertada difiere del plan.'}
 foreach($fr in $plan.fracciones){
  Clone fracciones @{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Vigencia Desde'=[datetime]$fr.'Vigencia Desde';'Cód_ Acumulador'=$fr.'Cód_ Acumulador'} @{'Vigencia Desde'=[datetime]$plan.desdeNuevo}
  $fn=Una @(Rows fracciones @{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Vigencia Desde'=[datetime]$plan.desdeNuevo;'Cód_ Acumulador'=$fr.'Cód_ Acumulador'}) 'fracción nueva';IgualSalvo $fr $fn @($meta+@('Vigencia Desde')) 'fracción nueva'
 }
 $b=@{codigo=$plan.codigo;desde=[datetime]$plan.desdeAntes;hasta=[datetime]$plan.cerrarAnterior;utc=[datetime]::UtcNow;actor=[guid]::Empty}
 $c=Cmd ('UPDATE '+(Tabla conceptos)+' SET [Vigencia Hasta]=@hasta,[$systemModifiedAt]=@utc,[$systemModifiedBy]=@actor WHERE Código=@codigo AND [Vigencia Desde]=@desde') $b;try{if($c.ExecuteNonQuery() -ne 1){throw 'Cierre no unitario.'};$cuentas.vigencias_cerradas++}finally{$c.Dispose()}
 $cerrado=Una @(Rows conceptos $key) 'concepto cerrado';IgualSalvo $o $cerrado @('timestamp','Vigencia Hasta','$systemModifiedAt','$systemModifiedBy') 'origen cerrado';if((Fecha $cerrado.'Vigencia Hasta') -ne (Fecha $plan.cerrarAnterior)){throw 'Vigencia hasta incorrecta.'}
 $b=@{cod=$plan.codigo;vig=[datetime]$plan.desdeNuevo;descr=$o.Descripción;antes=$o.Fórmula;nueva=$plan.formula;cond=$o.Condición;utc=[datetime]::UtcNow;id=[guid]::NewGuid();actor=[guid]::Empty}
 $sql='INSERT '+(Tabla historial)+' ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],Usuario,[Tipo Cambio],[Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],[Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) VALUES(@cod,@vig,@descr,@utc,N''FERIADO OFICIALES POTEROS'',0,@antes,@nueva,@cond,@cond,1,0,@utc,@id,@utc,@actor,@utc,@actor)'
 $c=Cmd $sql $b;try{if($c.ExecuteNonQuery() -ne 1){throw 'No se registró auditoría.'};$cuentas.historial++}finally{$c.Dispose()}
 if($cuentas.conceptos -ne 1 -or $cuentas.fracciones -ne 9 -or $cuentas.historial -ne 1 -or $cuentas.vigencias_cerradas -ne 1){throw 'Cantidad de cambios no corresponde al plan.'}
 Invariantes
 if($Aplicar){
  $tx.Commit();$tx.Dispose();$tx=$null
  foreach($id in @('conceptos','fracciones','historial')){Guardar ('aplicado-feriado-'+$id) @(Scoped $id)}
  Guardar 'resultado-feriado-oficiales' ([ordered]@{aplicado=$true;cuentas=$cuentas;utc=[datetime]::UtcNow;documentosProtegidos=$docs;planSha256=(Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash})
  'Configuración de feriado aplicada; no se reabrieron ni calcularon documentos.'
 }else{
  $tx.Rollback();$tx.Dispose();$tx=$null
  foreach($id in $ids){Assert @(Scoped $id) $datos[$id] ('rollback-'+$id)};foreach($id in $aux){Assert @(Scoped $id) $datos['antes-feriado-'+$id] ('rollback-'+$id)}
  Guardar 'prueba-feriado-oficiales' ([ordered]@{rollback=$true;cuentas=$cuentas;utc=[datetime]::UtcNow;firma=(Firma);documentosProtegidos=$docs})
  'Ensayo de feriado completo revertido; documentos y configuración anterior idénticos.'
 }
 $cuentas|ConvertTo-Json -Compress
}finally{if($tx){try{$tx.Rollback()}finally{$tx.Dispose()}};$cx.Dispose()}
