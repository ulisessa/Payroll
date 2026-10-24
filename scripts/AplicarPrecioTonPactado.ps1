<# Configuración acotada de USD/tn. Por omisión ensaya y revierte; no calcula recibos. #>
[CmdletBinding()]
param(
    [string]$Backup = (Join-Path $PSScriptRoot '../.snapshots/oficiales-poteros-20261013/precio-ton-pactado/antes'),
    [string]$PlanPath = (Join-Path $PSScriptRoot '../.snapshots/oficiales-poteros-20261013/precio-ton-pactado/plan-precio-ton-pactado.json'),
    [string]$Servidor = 'tcp:mimir.arbumasa.com,1433',
    [string]$Base = 'Migr2013R2',
    [string]$Compania = 'ArbuTest',
    [switch]$Aplicar
)
$ErrorActionPreference = 'Stop'
$Backup = (Resolve-Path -LiteralPath $Backup).Path
$PlanPath = (Resolve-Path -LiteralPath $PlanPath).Path
$Salida = Split-Path -Parent $Backup
$plan = Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
$sufijo = '$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$tablas = @{ conceptos='Concepto Liquidación'; parametros='Parámetro'; valores_param='Parámetro Vigente'; fracciones='Fracción Acumulador'; historial='Historial Fórmula Concepto'; fuentes='Fuente Datos Liquidación'; variables_cfg='Variable Sistema Liq_'; tipos_atributo='Tipo Atributo Liq_'; atributos='Atributo Entidad Liq_' }
function Q($n) { '[' + ([string]$n).Replace(']', ']]') + ']' }
function T($id) { '[dbo].' + (Q ($Compania + '$' + $tablas[$id] + $sufijo)) }
function Leer($id) { @(Get-Content -LiteralPath (Join-Path $Backup ($id+'.json')) -Raw -Encoding UTF8 | ConvertFrom-Json) }
function Una($filas) { $a=@($filas); if($a.Count -ne 1){throw 'Se esperaba una única fila modelo.'}; $a[0] }
function Canon($filas) { (@($filas | ForEach-Object { $r=[ordered]@{}; foreach($p in @($_.PSObject.Properties|Sort-Object Name)){$r[$p.Name]=$p.Value}; ConvertTo-Json -InputObject $r -Depth 12 -Compress } | Sort-Object) -join "`n") }
function Guardar($nombre,$datos) { [IO.File]::WriteAllText((Join-Path $Salida $nombre),(ConvertTo-Json -InputObject $datos -Depth 20),[Text.UTF8Encoding]::new($false)) }
function Exigir($condicion,$mensaje) { if(!$condicion){throw $mensaje} }
$archivos=@('columnas_sql','conceptos','parametros','valores_param','fracciones','fuentes','variables_cfg','tipos_atributo','atributos','historial','cabeceras','variables','lineas','control_financiero')
function Firma {
    [ordered]@{ script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash; plan=(Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash; servidor=$Servidor; base=$Base; compania=$Compania; respaldos=@(foreach($a in $archivos){[ordered]@{archivo=$a;sha256=(Get-FileHash -LiteralPath (Join-Path $Backup ($a+'.json')) -Algorithm SHA256).Hash}}) } | ConvertTo-Json -Depth 8 -Compress
}
$firma=Firma
$pruebaPath=Join-Path $Salida 'prueba-precio-ton-pactado.json'
if($Aplicar){ Exigir (Test-Path -LiteralPath $pruebaPath) 'Falta ensayo revertido.'; $prueba=Get-Content -LiteralPath $pruebaPath -Raw | ConvertFrom-Json; Exigir ($prueba.rollback -and $prueba.firma -ceq $firma) 'Cambió script, plan, conexión o respaldo: repetir sin -Aplicar.' }
Exigir ($Servidor -ceq 'tcp:mimir.arbumasa.com,1433' -and $Base -ceq 'Migr2013R2' -and $Compania -ceq 'ArbuTest') 'Conexión fuera del entorno revisado.'
Exigir ($plan.parametroNuevo.codigo -ceq 'USD_TON_PACTADO' -and $plan.auxiliar.codigo -ceq 'PCT_PROD_CALC' -and $plan.consumidor.codigo -ceq 'PROD_EMPRESA') 'Plan fuera de la migración revisada.'
Exigir (@($plan.valores).Count -eq 8) 'Deben existir ocho precios personales.'
Exigir ($plan.auxiliar.formula.Contains('ERROR(') -and !$plan.auxiliar.formula.Contains('"')) 'ERROR debe usar comillas simples.'
Exigir ($plan.consumidor.formula.EndsWith($plan.consumidor.elseOriginal)) 'La rama ELSE debe conservarse exactamente.'
Exigir ($plan.consumidor.formula.Replace('@PCT_PROD_CALC','PCT_PROD') -ceq $plan.consumidor.sourceFormula) 'Sólo se permiten las sustituciones de porcentaje.'
Exigir ([regex]::Matches($plan.consumidor.formula,'@PCT_PROD_CALC').Count -eq 2) 'Deben sustituirse exactamente dos referencias.'
$fecha=[datetime]$plan.consumidor.targetVigencia
$desdeAnterior=[datetime]$plan.consumidor.sourceVigencia
Exigir ($fecha -gt $desdeAnterior -and $fecha -eq [datetime]$plan.auxiliar.targetVigencia) 'Las vigencias nuevas deben ser posteriores y coincidir.'
$datos=@{}; foreach($id in @('conceptos','parametros','valores_param','fracciones','historial','columnas_sql','control_financiero')){$datos[$id]=Leer $id}
$original=Una @($datos.conceptos|Where-Object {$_.Código -eq 'PROD_EMPRESA' -and [datetime]$_.'Vigencia Desde' -eq $desdeAnterior})
Exigir ($original.Fórmula -ceq $plan.consumidor.sourceFormula) 'La fórmula fuente del plan no coincide con el respaldo.'
$modeloParametro=Una @($datos.parametros|Where-Object Código -eq $plan.parametroNuevo.modeloCodigo)
$modeloValor=Una @($datos.valores_param|Where-Object {$_.'Cód_ Parámetro Base' -eq 'USD_TON_PROD' -and $_.'Cód_ Parámetro' -eq 'USD_TON_PROD'}|Sort-Object 'Vigencia Desde' -Descending|Select-Object -First 1)
Exigir ($modeloValor.Moneda -ceq 'USD' -and $modeloValor.'Cód_ Variable TC' -ceq 'TC_COMPRADOR' -and [decimal]$modeloValor.Valor -gt 0) 'La referencia debe tener moneda y tipo de cambio iguales al precio pactado.'
$claveModeloValor=@{'Cód_ Parámetro Base'=$modeloValor.'Cód_ Parámetro Base';'Cód_ Parámetro'=$modeloValor.'Cód_ Parámetro';'Vigencia Desde'=[datetime]$modeloValor.'Vigencia Desde'}
$modeloAuxiliar=Una @($datos.conceptos|Where-Object {$_.Código -eq 'COEF_PESQUERIA' -and [datetime]$_.'Vigencia Desde' -eq [datetime]'2026-01-01'})
$modeloHistorial=Una @($datos.historial|Where-Object 'Cód_ Concepto' -eq 'PROD_EMPRESA'|Sort-Object 'No_ Entrada' -Descending|Select-Object -First 1)
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']=$Servidor;$builder['Initial Catalog']=$Base;$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=15
$cx=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$tx=$null;$schema=@{}
$cuentas=[ordered]@{parametros=0;valores_param=0;conceptos=0;fracciones=0;historial=0;vigencias_cerradas=0}
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
    Clonar historial @{'No_ Entrada'=[int]$modeloHistorial.'No_ Entrada'} @{'Cód_ Concepto'=$codigo;'Vigencia Desde'=$fecha;'Descripción Concepto'=$descripcion;'Fecha Hora'=[datetime]::UtcNow;'Última Edición'=[datetime]::UtcNow;Usuario='PRECIO TON PACTADO PARAMETRICO';'Tipo Cambio'=0;'Fórmula Anterior'=$anterior;'Fórmula Nueva'=$nueva;'Condición Anterior'=$condAnterior;'Condición Nueva'=$condNueva;'Cambió Fórmula'=1;'Cambió Condición'=[int]($condAnterior -cne $condNueva)}
}
try {
    $cx.Open();Exigir ((Una @(Query 'SELECT DB_NAME() Nombre')).Nombre -ceq $Base) 'DB_NAME no coincide.'
    $tx=$cx.BeginTransaction([Data.IsolationLevel]::Serializable)
    Igual conceptos @{Código='PROD_EMPRESA';'Vigencia Desde'=$desdeAnterior} $original
    Igual parametros @{Código=$modeloParametro.Código} $modeloParametro
    Igual valores_param $claveModeloValor $modeloValor
    Igual conceptos @{Código=$modeloAuxiliar.Código;'Vigencia Desde'=[datetime]$modeloAuxiliar.'Vigencia Desde'} $modeloAuxiliar
    Exigir (@(Rows conceptos|Where-Object {$_.Código -eq 'PROD_EMPRESA' -and [datetime]$_.'Vigencia Desde' -gt $desdeAnterior}).Count -eq 0) 'Existe una vigencia posterior del consumidor.'
    foreach($n in @('USD_TON_PACTADO','USD_TON_PACTADO_ESFCY','PCT_PROD_CALC')) {
        Exigir (@(Query ('SELECT Código FROM '+(T conceptos)+' WHERE Código=@n') @{n=$n}).Count -eq 0) ('Nombre ya existente: '+$n)
        foreach($id in @('parametros','fuentes','variables_cfg','tipos_atributo')){Exigir (@(Query ('SELECT [Nombre Variable] FROM '+(T $id)+' WHERE [Nombre Variable]=@n') @{n=$n}).Count -eq 0) ('Variable ya existente: '+$n)}
    }
    $controlAntes=@(ControlFinanciero);Guardar 'control-financiero-ensayo.json' $controlAntes
    Exigir ((Canon $controlAntes) -ceq (Canon $datos.control_financiero)) 'Cambió el estado financiero desde el respaldo.'
    $inmutables=@{};foreach($id in @('fuentes','variables_cfg','tipos_atributo','atributos')){$inmutables[$id]=Stats $id}
    $antes=@{};foreach($id in @('conceptos','parametros','valores_param','fracciones','historial')){$antes[$id]=Rows $id;Guardar ('ensayo-antes-'+$id+'.json') $antes[$id];Exigir ((Canon $antes[$id]) -ceq (Canon $datos[$id])) ('Cambió la configuración desde el respaldo: '+$id)}
    Clonar parametros @{Código=$modeloParametro.Código} @{Código='USD_TON_PACTADO';'Nombre Variable'='USD_TON_PACTADO';Descripción=$plan.parametroNuevo.descripcion;Notas=$plan.parametroNuevo.notas;'Sufijo Empleado'=1;'Sufijo CCT'=0;'Sufijo Convenio'=0;'Cód_ Tipo Atributo 1'='';'Cód_ Tipo Atributo 2'='';'Cód_ Tipo Atributo 3'=''}
    foreach($v in $plan.valores){Exigir ([datetime]$v.desde -eq $fecha -and [decimal]$v.precioUSD -gt 0 -and $v.moneda -ceq 'USD' -and $v.tc -ceq 'TC_COMPRADOR') 'Precio fuera del plan revisado.';Clonar valores_param $claveModeloValor @{'Cód_ Parámetro Base'='USD_TON_PACTADO';'Cód_ Parámetro'=$v.codigo;'Vigencia Desde'=$fecha;Descripción=$v.descripcion;Valor=[decimal]$v.precioUSD;Moneda='USD';'En Uso'=0;Notas=$v.notas;'No_ Empleado'=$v.empleado;'Cód_ Convenio'='';'Cód_ Categoría'='';Nivel=1;'Cód_ Variable TC'='TC_COMPRADOR';'Sufijo Atributo 1'='';'Sufijo Atributo 2'='';'Sufijo Atributo 3'=''}}
    Clonar conceptos @{Código=$modeloAuxiliar.Código;'Vigencia Desde'=[datetime]$modeloAuxiliar.'Vigencia Desde'} @{Código='PCT_PROD_CALC';'Vigencia Desde'=$fecha;'Vigencia Hasta'=[datetime]'1753-01-01';Descripción=$plan.auxiliar.descripcion;'Nombre Impresión'=$plan.auxiliar.descripcion;'Tipo Concepto'=6;Fórmula=$plan.auxiliar.formula;Condición=$plan.auxiliar.condicion;'Orden Cálculo'=0;'Fórmula Orden Cálculo'='0';'Aplica A'=0;Activo=1;'Es Acumulador'=0;'Imprime en Recibo'=0;'Es Devengo'=0;'Par CCT a Usar'=[int]$plan.auxiliar.parCCT;'Tipos Liq_ Aplicables'='CIERRE_MAREA'}
    Clonar conceptos @{Código='PROD_EMPRESA';'Vigencia Desde'=$desdeAnterior} @{'Vigencia Desde'=$fecha;Fórmula=$plan.consumidor.formula}
    foreach($fr in @($plan.consumidor.fraccionesClonar)){Clonar fracciones @{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Cód_ Acumulador'=$fr.'Cód_ Acumulador';'Vigencia Desde'=[datetime]$fr.'Vigencia Desde'} @{'Vigencia Desde'=$fecha}}
    Exigir ((Ejecutar ('UPDATE '+(T conceptos)+' SET [Vigencia Hasta]=@hasta,[$systemModifiedAt]=@ahora,[$systemModifiedBy]=@actor WHERE Código=@codigo AND [Vigencia Desde]=@desde') @{hasta=$fecha.AddDays(-1);ahora=[datetime]::UtcNow;actor=[guid]::Empty;codigo='PROD_EMPRESA';desde=$desdeAnterior}) -eq 1) 'No se cerró una única vigencia.';$cuentas.vigencias_cerradas++
    Audit 'PCT_PROD_CALC' $plan.auxiliar.descripcion '' $plan.auxiliar.formula '' $plan.auxiliar.condicion
    Audit 'PROD_EMPRESA' $original.Descripción $original.Fórmula $plan.consumidor.formula $original.Condición $original.Condición
    foreach($id in $inmutables.Keys){Exigir ((Canon @(Stats $id)) -ceq (Canon $inmutables[$id])) ('Cambió configuración protegida: '+$id)}
    Exigir ((Canon @(ControlFinanciero)) -ceq (Canon $datos.control_financiero)) 'Se alteró un dato financiero.'
    $posteriores=@{};foreach($id in $antes.Keys){$posteriores[$id]=Rows $id}
    Exigir ((Canon @($posteriores.parametros|Where-Object Código -ne 'USD_TON_PACTADO')) -ceq (Canon $antes.parametros)) 'Se alteró un parámetro anterior.'
    Exigir ((Canon @($posteriores.valores_param|Where-Object 'Cód_ Parámetro Base' -ne 'USD_TON_PACTADO')) -ceq (Canon $antes.valores_param)) 'Se alteró un valor anterior.'
    Exigir ((Canon @($posteriores.fracciones|Where-Object {$_.'Cód_ Concepto' -ne 'PROD_EMPRESA' -or [datetime]$_.'Vigencia Desde' -ne $fecha})) -ceq (Canon $antes.fracciones)) 'Se alteró una fracción anterior.'
    $idsHistorial=@{};foreach($o in $antes.historial){$idsHistorial[[int]$o.'No_ Entrada']=$true}
    Exigir ((Canon @($posteriores.historial|Where-Object {$idsHistorial.ContainsKey([int]$_.'No_ Entrada')})) -ceq (Canon $antes.historial)) 'Se alteró la auditoría anterior.'
    $conceptosPrevios=@($antes.conceptos|Where-Object {!($_.Código -eq 'PROD_EMPRESA' -and [datetime]$_.'Vigencia Desde' -eq $desdeAnterior)})
    $conceptosConservados=@($posteriores.conceptos|Where-Object {$_.Código -ne 'PCT_PROD_CALC' -and !($_.Código -eq 'PROD_EMPRESA' -and ([datetime]$_.'Vigencia Desde' -eq $desdeAnterior -or [datetime]$_.'Vigencia Desde' -eq $fecha))})
    Exigir ((Canon $conceptosConservados) -ceq (Canon $conceptosPrevios)) 'Se alteró un concepto anterior ajeno al cambio.'
    $cerrado=Una @($posteriores.conceptos|Where-Object {$_.Código -eq 'PROD_EMPRESA' -and [datetime]$_.'Vigencia Desde' -eq $desdeAnterior})
    foreach($p in $original.PSObject.Properties){if($p.Name -in @('timestamp','Vigencia Hasta','$systemModifiedAt','$systemModifiedBy')){continue};Exigir ((ConvertTo-Json -InputObject $p.Value -Compress) -ceq (ConvertTo-Json -InputObject $cerrado.($p.Name) -Compress)) ('Se alteró la versión anterior: '+$p.Name)}
    Exigir ($cuentas.parametros -eq 1 -and $cuentas.valores_param -eq 8 -and $cuentas.conceptos -eq 2 -and $cuentas.historial -eq 2 -and $cuentas.vigencias_cerradas -eq 1 -and $cuentas.fracciones -eq @($plan.consumidor.fraccionesClonar).Count) 'Cantidad de cambios distinta del plan.'
    foreach($id in $antes.Keys){Guardar ('verificado-'+$id+'.json') @(Rows $id)}
    if($Aplicar){$tx.Commit();$tx.Dispose();$tx=$null;Guardar 'resultado-precio-ton-pactado.json' ([ordered]@{aplicado=$true;firma=$firma;cuentas=$cuentas;utc=[datetime]::UtcNow});'Configuración aplicada. Renovar caché antes de recalcular por BC.'}
    else{$tx.Rollback();$tx.Dispose();$tx=$null;foreach($id in $antes.Keys){Exigir ((Canon @(Rows $id)) -ceq (Canon $antes[$id])) ('No se revirtió '+$id)};Exigir ((Canon @(ControlFinanciero)) -ceq (Canon $datos.control_financiero)) 'Cambió el control financiero tras revertir.';Guardar 'prueba-precio-ton-pactado.json' ([ordered]@{rollback=$true;firma=$firma;cuentas=$cuentas;utc=[datetime]::UtcNow});'Ensayo revertido; configuración previa y datos financieros conservados.'}
} finally {if($tx){try{$tx.Rollback()}finally{$tx.Dispose()}};$cx.Dispose()}
