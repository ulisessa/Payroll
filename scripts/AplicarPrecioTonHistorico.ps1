<# Extiende la conversión equivalente a enero. Por omisión ensaya y revierte. No calcula recibos. #>
[CmdletBinding()]
param(
 [string]$Backup=(Join-Path $PSScriptRoot '../.snapshots/oficiales-poteros-20261013/historia-precio-ton/antes'),
 [string]$PlanPath=(Join-Path $PSScriptRoot '../.snapshots/oficiales-poteros-20261013/historia-precio-ton/plan-historia-precio-ton.json'),
 [switch]$Aplicar
)
$ErrorActionPreference='Stop'
$Backup=(Resolve-Path -LiteralPath $Backup).Path;$PlanPath=(Resolve-Path -LiteralPath $PlanPath).Path
$Salida=Split-Path -Parent $Backup
$plan=Get-Content -LiteralPath $PlanPath -Raw|ConvertFrom-Json
$Servidor='tcp:mimir.arbumasa.com,1433';$Base='Migr2013R2';$Compania='ArbuTest'
$sufijo='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$tablas=@{conceptos='Concepto Liquidación';parametros='Parámetro';valores_param='Parámetro Vigente';fracciones='Fracción Acumulador';historial='Historial Fórmula Concepto';fuentes='Fuente Datos Liquidación';variables_cfg='Variable Sistema Liq_';tipos_atributo='Tipo Atributo Liq_';atributos='Atributo Entidad Liq_'}
function Q($n) { '[' + ([string]$n).Replace(']', ']]') + ']' }
function T($id) { '[dbo].' + (Q ($Compania + '$' + $tablas[$id] + $sufijo)) }
function Leer($id) { @(Get-Content -LiteralPath (Join-Path $Backup ($id+'.json')) -Raw -Encoding UTF8 | ConvertFrom-Json) }
function Una($filas) { $a=@($filas); if($a.Count -ne 1){throw 'Se esperaba una única fila modelo.'}; $a[0] }
function Canon($filas) { (@($filas | ForEach-Object { $r=[ordered]@{}; foreach($p in @($_.PSObject.Properties|Sort-Object Name)){$r[$p.Name]=$p.Value}; ConvertTo-Json -InputObject $r -Depth 12 -Compress } | Sort-Object) -join "`n") }
function Guardar($nombre,$datos) { [IO.File]::WriteAllText((Join-Path $Salida $nombre),(ConvertTo-Json -InputObject $datos -Depth 20),[Text.UTF8Encoding]::new($false)) }
function Exigir($condicion,$mensaje) { if(!$condicion){throw $mensaje} }

$archivos=@('columnas_sql','conceptos','parametros','valores_param','fracciones','fuentes','variables_cfg','tipos_atributo','atributos','historial','cabeceras','variables','lineas','control_financiero')
function Firma {
 [ordered]@{script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;plan=(Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash;servidor=$Servidor;base=$Base;compania=$Compania;respaldos=@(foreach($a in $archivos){[ordered]@{archivo=$a;sha256=(Get-FileHash -LiteralPath (Join-Path $Backup ($a+'.json')) -Algorithm SHA256).Hash}})}|ConvertTo-Json -Depth 8 -Compress
}
$firma=Firma;$pruebaPath=Join-Path $Salida 'prueba-historia-precio-ton.json'
if($Aplicar){Exigir (Test-Path -LiteralPath $pruebaPath) 'Falta ensayo revertido.';$prueba=Get-Content -LiteralPath $pruebaPath -Raw|ConvertFrom-Json;Exigir ($prueba.rollback -and $prueba.firma -ceq $firma) 'Cambió script, plan o respaldo: repetir el ensayo.'}
Exigir ($plan.desde -eq '2026-01-01' -and @($plan.formulas).Count -eq 3 -and @($plan.valoresNuevos).Count -eq 19 -and $plan.auxiliar.codigo -eq 'PCT_PROD_CALC') 'Plan fuera del alcance revisado.'
$datos=@{};foreach($id in @('conceptos','parametros','valores_param','fracciones','historial','control_financiero')){$datos[$id]=Leer $id}
$parametro=Una @($datos.parametros|Where-Object Código -eq 'USD_TON_PACTADO')
$empleados=@($datos.valores_param|Where-Object {$_.'Cód_ Parámetro Base' -eq 'USD_TON_PACTADO' -and [datetime]$_.'Vigencia Desde' -eq [datetime]'2026-02-03' -and $_.'No_ Empleado' -ne ''}|Select-Object -ExpandProperty 'No_ Empleado'|Sort-Object -Unique)
Exigir ($empleados.Count -eq 8) 'No se encontraron los ocho acuerdos vigentes.'
foreach($v in $plan.valoresNuevos){
 $o=$v.origen;$r=$v.referencia
 Exigir ($o.'Cód_ Parámetro Base' -eq 'PCT_PROD' -and $r.'Cód_ Parámetro Base' -eq 'USD_TON_PROD' -and $r.Moneda -eq 'USD' -and $r.'Cód_ Variable TC' -eq 'TC_COMPRADOR') 'Origen o referencia inválidos.'
 Exigir ([decimal]$v.valor -eq [decimal]$o.Valor*[decimal]$r.Valor/100 -and [decimal]$v.valor -gt 0) 'Precio no equivalente al porcentaje histórico.'
 Exigir ($v.codigo -ceq ('USD_TON_PACTADO'+$o.'Cód_ Parámetro'.Substring('PCT_PROD'.Length)) -and [datetime]$v.desde -eq [datetime]$o.'Vigencia Desde' -and [datetime]$v.desde -ge [datetime]'2026-01-01') 'Clave o vigencia no conserva el origen.'
 Exigir (($o.'No_ Empleado' -in $empleados) -or ($o.'No_ Empleado' -eq '' -and $o.'Cód_ Convenio' -in @('175/75','768/19','ESP'))) 'Alcance fuera de los acuerdos.'
 foreach($eje in @('Sufijo Atributo 1','Sufijo Atributo 2','Sufijo Atributo 3')){Exigir ($o.$eje -eq '') 'El parámetro de precio no declara ejes de atributos.'}
}
foreach($f in $plan.formulas){
 Exigir ($f.codigo -eq 'PROD_EMPRESA' -and $f.desde -in @('2026-01-01','2026-02-01','2026-02-02') -and $f.formula.Length -le 2048) 'Fórmula fuera del alcance autorizado.'
 $reversa=if($f.envoltorio){$f.formula.Replace($f.envoltorio,'PCT_PROD')}else{$f.formula.Replace('@PCT_PROD_CALC','PCT_PROD')}
 Exigir ($reversa -ceq $f.formulaAntes) 'Se cambió otra operación de la fórmula.'
}
$modeloHistorial=Una @($datos.historial|Where-Object 'Cód_ Concepto' -eq 'PROD_EMPRESA'|Sort-Object 'No_ Entrada' -Descending|Select-Object -First 1)
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new();$builder['Data Source']=$Servidor;$builder['Initial Catalog']=$Base;$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=15
$cx=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$tx=$null;$schema=@{}
$cuentas=[ordered]@{parametros=0;valores_param=0;conceptos=0;fracciones=0;historial=0;formulas_actualizadas=0}
function Cmd($sql,$b=@{}) { $c=$cx.CreateCommand();$c.Transaction=$tx;$c.CommandTimeout=120;$c.CommandText=$sql;foreach($k in $b.Keys){[void]$c.Parameters.AddWithValue('@'+$k,$b[$k])};$c }
function Query($sql,$b=@{}) { $c=Cmd ('SELECT ('+$sql+' FOR JSON PATH,INCLUDE_NULL_VALUES)') $b;try{$j=[string]$c.ExecuteScalar();if($j){@($j|ConvertFrom-Json)}}finally{$c.Dispose()} }
function Ejecutar($sql,$b=@{}) { $c=Cmd $sql $b;try{$c.ExecuteNonQuery()}finally{$c.Dispose()} }
function WhereClave($clave,$b) { $a=@();$i=0;foreach($k in @($clave.Keys|Sort-Object)){$n='k'+$i;$b[$n]=$clave[$k];$a+=(Q $k)+'=@'+$n;$i++};$a-join' AND ' }
function Rows($id,$clave=@{}) { $b=@{};$w=if($clave.Count){' WHERE '+(WhereClave $clave $b)}else{''};@(Query ('SELECT * FROM '+(T $id)+' WITH(UPDLOCK,HOLDLOCK)'+$w) $b) }
function Igual($id,$clave,$esperado) { Exigir ((Canon @(Rows $id $clave)) -ceq (Canon @($esperado))) ('Cambió el respaldo/modelo de '+$id) }
function Schema($id) { if(!$schema.ContainsKey($id)){$schema[$id]=@(Query 'SELECT name,is_identity,is_computed,system_type_id FROM sys.columns WHERE object_id=OBJECT_ID(@obj) ORDER BY column_id' @{obj=(T $id)})};Exigir ($schema[$id].Count -gt 0) ('Falta esquema '+$id);@($schema[$id]) }
function Clonar($id,$clave,$cambios) {
    $b=@{};$w=WhereClave $clave $b;$nuevo=@{};foreach($k in $cambios.Keys){$nuevo[$k]=$cambios[$k]}
    $nuevo['$systemId']=[guid]::NewGuid();$nuevo['$systemCreatedAt']=[datetime]::UtcNow;$nuevo['$systemModifiedAt']=$nuevo['$systemCreatedAt'];$nuevo['$systemCreatedBy']=[guid]::Empty;$nuevo['$systemModifiedBy']=[guid]::Empty
    $cols=@();$sel=@();$i=0
    foreach($col in @(Schema $id|Where-Object {!$_.is_identity -and !$_.is_computed -and $_.system_type_id -ne 189})){$cols+=Q $col.name;if($nuevo.ContainsKey($col.name)){$n='v'+$i;$b[$n]=$nuevo[$col.name];$sel+='@'+$n;$i++}else{$sel+=Q $col.name}}
    Exigir ((Ejecutar ('INSERT '+(T $id)+' ('+($cols-join',')+') SELECT '+($sel-join',')+' FROM '+(T $id)+' WHERE '+$w) $b) -eq 1) ('Clonación no unitaria '+$id)
    $cuentas[$id]++
}
function ControlFinanciero {
    @(foreach($fila in $datos.control_financiero){$tabla='[dbo].'+(Q ($Compania+'$'+$fila.Tabla+$sufijo));Query ('SELECT @tabla Tabla,COUNT_BIG(*) Filas,COALESCE(MAX(CONVERT(bigint,[timestamp])),0) Revision FROM '+$tabla) @{tabla=[string]$fila.Tabla}})
}
function Stats($id) { @(Query ('SELECT COUNT_BIG(*) Filas,COALESCE(MAX(CONVERT(bigint,[timestamp])),0) Revision FROM '+(T $id))) }
function Audit($codigo,$descripcion,$anterior,$nueva,$condAnterior,$condNueva) {
    Clonar historial @{'No_ Entrada'=[int]$modeloHistorial.'No_ Entrada'} @{'Cód_ Concepto'=$codigo;'Vigencia Desde'=$fecha;'Descripción Concepto'=$descripcion;'Fecha Hora'=[datetime]::UtcNow;'Última Edición'=[datetime]::UtcNow;Usuario='PRECIO TON HISTORICO';'Tipo Cambio'=0;'Fórmula Anterior'=$anterior;'Fórmula Nueva'=$nueva;'Condición Anterior'=$condAnterior;'Condición Nueva'=$condNueva;'Cambió Fórmula'=1;'Cambió Condición'=[int]($condAnterior -cne $condNueva)}
}
try{
 $cx.Open();Exigir ((Una @(Query 'SELECT DB_NAME() Nombre')).Nombre -ceq $Base) 'Base inesperada.'
 $tx=$cx.BeginTransaction([Data.IsolationLevel]::Serializable)
 $antes=@{};foreach($id in @('conceptos','parametros','valores_param','fracciones','historial')){$antes[$id]=Rows $id;Guardar ('ensayo-antes-'+$id+'.json') $antes[$id];Exigir ((Canon $antes[$id]) -ceq (Canon $datos[$id])) ('Cambió configuración desde el respaldo: '+$id)}
 $finAntes=@(ControlFinanciero);Exigir ((Canon $finAntes) -ceq (Canon $datos.control_financiero)) 'Cambió el estado de recibos desde el respaldo.'
 $inmutables=@{};foreach($id in @('fuentes','variables_cfg','tipos_atributo','atributos')){$inmutables[$id]=Stats $id}
 Exigir (@(Rows conceptos @{Código='PCT_PROD_CALC';'Vigencia Desde'=[datetime]'2026-01-01'}).Count -eq 0) 'El auxiliar de enero ya existe.'
 foreach($v in $plan.valoresNuevos){
  $o=$v.origen;$fechaValor=[datetime]$v.desde
  $clave=@{'Cód_ Parámetro Base'=$o.'Cód_ Parámetro Base';'Cód_ Parámetro'=$o.'Cód_ Parámetro';'Vigencia Desde'=[datetime]$o.'Vigencia Desde'}
  Igual valores_param $clave $o
  Exigir (@(Rows valores_param @{'Cód_ Parámetro Base'='USD_TON_PACTADO';'Cód_ Parámetro'=$v.codigo;'Vigencia Desde'=$fechaValor}).Count -eq 0) 'Ya existe una vigencia de precio prevista.'
  Clonar valores_param $clave @{'Cód_ Parámetro Base'='USD_TON_PACTADO';'Cód_ Parámetro'=$v.codigo;'Vigencia Desde'=$fechaValor;Valor=[decimal]$v.valor;Moneda='USD';'Cód_ Variable TC'='TC_COMPRADOR';'En Uso'=0;Descripción='Precio por tonelada equivalente a la vigencia original';Notas=$v.notas}
 }
 $a=$plan.auxiliar;$fecha=[datetime]$a.desde
 Clonar conceptos @{Código=$a.codigo;'Vigencia Desde'=[datetime]$a.modeloDesde} @{'Vigencia Desde'=$fecha;'Vigencia Hasta'=[datetime]$a.hasta}
 Audit $a.codigo $a.original.Descripción '' $a.original.Fórmula '' $a.original.Condición
 foreach($f in $plan.formulas){
  $fecha=[datetime]$f.desde
  Exigir ((Ejecutar ('UPDATE '+(T conceptos)+' SET Fórmula=@formula,[$systemModifiedAt]=@utc,[$systemModifiedBy]=@actor WHERE Código=@cod AND [Vigencia Desde]=@vig AND Fórmula=@original') @{formula=$f.formula;utc=[datetime]::UtcNow;actor=[guid]::Empty;cod=$f.codigo;vig=$fecha;original=$f.formulaAntes}) -eq 1) 'No se actualizó una única fórmula esperada.'
  $cuentas.formulas_actualizadas++
  Audit $f.codigo $f.original.Descripción $f.formulaAntes $f.formula $f.original.Condición $f.original.Condición
 }
 $posteriores=@{};foreach($id in $antes.Keys){$posteriores[$id]=Rows $id}
 Exigir ((Canon $posteriores.parametros) -ceq (Canon $antes.parametros)) 'Se alteró una cabecera de parámetro.'
 Exigir ((Canon $posteriores.fracciones) -ceq (Canon $antes.fracciones)) 'Se alteró una fracción.'
 $altas=@{};foreach($v in $plan.valoresNuevos){$altas[$v.codigo+'|'+([datetime]$v.desde).ToString('yyyy-MM-dd')]=$true}
 $viejos=@($posteriores.valores_param|Where-Object {!($_.'Cód_ Parámetro Base' -eq 'USD_TON_PACTADO' -and $altas.ContainsKey($_.'Cód_ Parámetro'+'|'+([datetime]$_.'Vigencia Desde').ToString('yyyy-MM-dd')))})
 Exigir ((Canon $viejos) -ceq (Canon $antes.valores_param)) 'Se alteró un precio o porcentaje previo.'
 $fechaAux=[datetime]$a.desde
 $filtAntes=@($antes.conceptos|Where-Object {!($_.Código -eq 'PROD_EMPRESA' -and ([datetime]$_.'Vigencia Desde').ToString('yyyy-MM-dd') -in @($plan.formulas.desde))})
 $filtDespues=@($posteriores.conceptos|Where-Object {!($_.Código -eq 'PCT_PROD_CALC' -and [datetime]$_.'Vigencia Desde' -eq $fechaAux) -and !($_.Código -eq 'PROD_EMPRESA' -and ([datetime]$_.'Vigencia Desde').ToString('yyyy-MM-dd') -in @($plan.formulas.desde))})
 Exigir ((Canon $filtAntes) -ceq (Canon $filtDespues)) 'Se alteró una versión de concepto fuera del plan.'
 foreach($f in $plan.formulas){$nuevo=Una @($posteriores.conceptos|Where-Object {$_.Código -eq $f.codigo -and [datetime]$_.'Vigencia Desde' -eq [datetime]$f.desde});foreach($p in $f.original.PSObject.Properties){if($p.Name -in @('timestamp','Fórmula','$systemModifiedAt','$systemModifiedBy')){continue};Exigir ((ConvertTo-Json -InputObject $p.Value -Compress) -ceq (ConvertTo-Json -InputObject $nuevo.($p.Name) -Compress)) ('Campo ajeno cambiado: '+$p.Name)};Exigir ($nuevo.Fórmula -ceq $f.formula) 'Fórmula nueva no coincide.'}
 $histPrev=@{};foreach($h in $antes.historial){$histPrev[[int]$h.'No_ Entrada']=$true}
 Exigir ((Canon @($posteriores.historial|Where-Object {$histPrev.ContainsKey([int]$_.'No_ Entrada')})) -ceq (Canon $antes.historial)) 'Se alteró el historial de fórmulas previo.'
 Exigir ((Canon @(ControlFinanciero)) -ceq (Canon $finAntes)) 'Se alteró un recibo o detalle guardado.'
 foreach($id in $inmutables.Keys){Exigir ((Canon @(Stats $id)) -ceq (Canon $inmutables[$id])) ('Se alteró configuración ajena: '+$id)}
 Exigir ($cuentas.valores_param -eq 19 -and $cuentas.conceptos -eq 1 -and $cuentas.historial -eq 4 -and $cuentas.formulas_actualizadas -eq 3 -and $cuentas.parametros -eq 0 -and $cuentas.fracciones -eq 0) 'Número de mutaciones distinto del plan.'
 foreach($id in $posteriores.Keys){Guardar ('verificado-'+$id+'.json') $posteriores[$id]}
 if($Aplicar){$tx.Commit();$tx.Dispose();$tx=$null;Guardar 'resultado-historia-precio-ton.json' ([ordered]@{aplicado=$true;firma=$firma;cuentas=$cuentas;utc=[datetime]::UtcNow});'Conversión histórica aplicada; recibos preservados.'}
 else{$tx.Rollback();$tx.Dispose();$tx=$null;foreach($id in $antes.Keys){Exigir ((Canon @(Rows $id)) -ceq (Canon $antes[$id])) ('No se revirtió '+$id)};Exigir ((Canon @(ControlFinanciero)) -ceq (Canon $finAntes)) 'Cambió un recibo al revertir.';Guardar 'prueba-historia-precio-ton.json' ([ordered]@{rollback=$true;firma=$firma;cuentas=$cuentas;utc=[datetime]::UtcNow});'Ensayo revertido: configuración y recibos previos intactos.'}
}finally{if($tx){try{$tx.Rollback()}finally{$tx.Dispose()}};$cx.Dispose()}
