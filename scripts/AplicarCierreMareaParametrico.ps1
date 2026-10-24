<#
Aplica configuración de un cierre identificado por un plan y un respaldo privado.
Sin -Aplicar ensaya en SQL y revierte. No reabre, calcula, publica ni reinicia BC.
La selección del caso vive en las fuentes configuradas; las fórmulas son reutilizables.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Backup,
    [Parameter(Mandatory)][string]$PlanFormulas,
    [Parameter(Mandatory)][ValidateLength(1,20)][string]$Documento,
    [string]$Servidor='tcp:mimir.arbumasa.com,1433',
    [string]$Base='Migr2013R2',
    [string]$Compania='ArbuTest',
    [guid]$ExtensionId='d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890',
    [switch]$Aplicar
)
$ErrorActionPreference='Stop'
$Backup=(Resolve-Path -LiteralPath $Backup).Path
$PlanFormulas=(Resolve-Path -LiteralPath $PlanFormulas).Path
$s='$'+$ExtensionId.ToString()
$tab=@{
    cabeceras='Liquidación';lineas='Línea Liquidación';variables='Resumen Variable Liq_';
    fuentes='Fuente Datos Liquidación';filtros='Filtro Fuente Datos Liq_';
    parametros='Parámetro';valores_param='Parámetro Vigente';conceptos='Concepto Liquidación';
    fracciones='Fracción Acumulador';historial='Historial Fórmula Concepto';
    atributos='Atributo Entidad Liq_';tipos_atributo='Tipo Atributo Liq_';variables_cfg='Variable Sistema Liq_';
    uso_parametros='Uso Parámetro Liq_';francos='Movimiento Franco Liq_';tramos='Tramo Cobertura Liq_'
}
function Q([string]$Nombre){return '['+$Nombre.Replace(']',']]')+']'}
function Tabla([string]$Id){if(!$tab.ContainsKey($Id)){throw "Tabla lógica desconocida: $Id"};return '[dbo].'+(Q ($Compania+'$'+$tab[$Id]+$s))}
function Leer([string]$Nombre){$p=Join-Path $Backup ($Nombre+'.json');if(!(Test-Path -LiteralPath $p)){throw "Falta respaldo: $p"};return @(Get-Content -LiteralPath $p -Raw|ConvertFrom-Json)}
function Una($Filas,[string]$Descripcion){$a=@($Filas);if($a.Count -ne 1){throw "Se esperaba una fila: $Descripcion"};return $a[0]}
function Fecha($Valor){return ([datetime]$Valor).ToString('yyyy-MM-dd')}
function Canonico($Fila){$o=[ordered]@{};foreach($p in @($Fila.PSObject.Properties|Sort-Object Name)){$o[$p.Name]=$p.Value};return ConvertTo-Json -InputObject $o -Depth 12 -Compress}
function CanonicoSet($Filas){return (@($Filas|Where-Object {$null -ne $_}|ForEach-Object {Canonico $_}|Sort-Object)-join "`n")}
function GuardarJson([string]$Nombre,$Valor){[IO.File]::WriteAllText((Join-Path $Backup $Nombre),(ConvertTo-Json -InputObject $Valor -Depth 16),[Text.UTF8Encoding]::new($false))}
$requeridos=@('cabeceras','lineas','variables','fuentes','filtros','parametros','valores_param','conceptos','fracciones','atributos','tipos_atributo','variables_cfg','uso_parametros','francos')
$datos=@{};foreach($id in $requeridos){$datos[$id]=Leer $id}
$target=Una @($datos.cabeceras|Where-Object No_ -eq $Documento) 'documento objetivo'
if($target.'Cód_ Tipo Liq_' -ne 'CIERRE_MAREA' -or [int]$target.Estado -notin @(0,1)){throw 'El objetivo debe ser un cierre borrador o calculado, sin aprobar ni contabilizar.'}
if(!$target.'No_ Empleado' -or !$target.'No_ Proyecto'){throw 'El cierre debe identificar empleado y proyecto.'}
$mesDesde=[datetime]::new(([datetime]$target.'Fecha Liquidación').Year,([datetime]$target.'Fecha Liquidación').Month,1)
$mesHasta=$mesDesde.AddMonths(1).AddDays(-1)
if([datetime]$target.'Cobertura Desde' -lt $mesDesde -or [datetime]$target.'Cobertura Hasta' -gt $mesHasta){throw 'La cobertura del cierre debe pertenecer al mes que se corrige.'}
if(@($datos.cabeceras|Where-Object {$_.'No_ Empleado' -ne $target.'No_ Empleado'}).Count){throw 'El respaldo mezcla empleados.'}
$periodos=@($datos.cabeceras.'Cód_ Período'|Sort-Object -Unique)
$entidades=@(@($target.'No_ Empleado')+@($datos.cabeceras.'No_ Proyecto'|Where-Object {$_}|Sort-Object -Unique)|Sort-Object -Unique)
$adicional=Una @($datos.atributos|Where-Object {$_.'Tipo Entidad' -eq 0 -and $_.'Cód_ Entidad' -eq $target.'No_ Empleado' -and $_.'Cód_ Tipo Atributo' -eq 'PCT_ADIC_PESCA' -and [datetime]$_.'Vigencia Desde' -le [datetime]$target.'Fecha Liquidación' -and ([datetime]$_.'Vigencia Hasta' -le [datetime]'1753-01-01' -or [datetime]$_.'Vigencia Hasta' -ge [datetime]$target.'Fecha Liquidación')}) 'adicional de pesca vigente'
if([decimal]$adicional.'Valor Decimal' -ne [decimal]1.25){throw 'El atributo adicional de pesca esperado debe estar ya cargado con1,25; el script no lo modifica.'}
$controlArchivos=@();$controles=@()
if(Test-Path -LiteralPath (Join-Path $Backup 'antes-controles.json')){
    $controlArchivos+= 'antes-controles.json'
    foreach($control in @(Leer 'antes-controles')){
        if(!$control.tabla.StartsWith($Compania+'$') -or !$control.tabla.EndsWith($s) -or $control.campo -notin @('No_ Liquidación','No_ Liquidación Aplicada','No_ Liq_ Aplicada')){throw 'Identidad de control complementario fuera del alcance.'}
        $nombre=$control.tabla.Substring($Compania.Length+1);$nombre=$nombre.Substring(0,$nombre.Length-$s.Length)
        $archivo='antes-control-'+$nombre+'--'+$control.campo+'.json';$p=Join-Path $Backup $archivo
        if(!(Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $control.sha256){throw ('Cambió un respaldo de control: '+$archivo)}
        $filas=@(Get-Content -LiteralPath $p -Raw|ConvertFrom-Json)
        if($filas.Count -ne $control.filas){throw ('Cantidad inconsistente en control: '+$archivo)}
        $controlArchivos+=$archivo;$controles+=[pscustomobject]@{tabla=$control.tabla;campo=$control.campo;archivo=$archivo;filas=$filas}
    }
}
$versiones=@(Get-Content -LiteralPath $PlanFormulas -Raw|ConvertFrom-Json)
if(@($versiones.codigo|Sort-Object -Unique).Count -ne 3 -or $versiones.Count -ne 3 -or (Compare-Object @('1534','2003','PROD_EMPRESA') @($versiones.codigo|Sort-Object))){throw 'El plan debe contener exactamente PROD_EMPRESA,1534 y2003.'}
$orig=@{};$fracsPlan=@()
foreach($v in $versiones){
    if((Fecha $v.desdeNuevo) -ne (Fecha $mesDesde)){throw 'Las nuevas fórmulas deben comenzar el primer día del mes del cierre.'}
    if([datetime]$v.desdeAntes -ge [datetime]$v.desdeNuevo){throw 'La vigencia anterior debe ser previa a la nueva.'}
    $o=Una @($datos.conceptos|Where-Object {$_.Código -eq $v.codigo -and (Fecha $_.'Vigencia Desde') -eq (Fecha $v.desdeAntes)}) ('origen '+$v.codigo)
    if($o.Fórmula -cne $v.formulaAnterior){throw ('La fórmula anterior difiere del respaldo: '+$v.codigo)}
    if(!$v.formula -or $v.formula.Length -gt 2048 -or !$v.formula.Contains('APL_AJUSTE_CIERRE')){throw ('Fórmula nueva inválida o sin selección configurada: '+$v.codigo)}
    if([datetime]$o.'Vigencia Hasta' -gt [datetime]'1753-01-01' -and [datetime]$o.'Vigencia Hasta' -lt [datetime]$v.desdeNuevo){throw ('La versión origen ya termina antes de la nueva: '+$v.codigo)}
    if(@($datos.conceptos|Where-Object {$_.Código -eq $v.codigo -and [datetime]$_.'Vigencia Desde' -gt [datetime]$v.desdeAntes}).Count){throw ('Existe una versión posterior no contemplada: '+$v.codigo)}
    $orig[$v.codigo]=$o
    $fs=@($datos.fracciones|Where-Object {$_.'Cód_ Concepto' -eq $v.codigo -and (Fecha $_.'Vigencia Desde') -eq (Fecha $v.desdeAntes)})
    # Clonar exactamente la versión, no recomponer acumuladores retirados de versiones antiguas.
    $fracsPlan+=@($fs)
}
if($fracsPlan.Count -ne 16 -or @($fracsPlan|Where-Object {$_.'Cód_ Concepto' -eq 'PROD_EMPRESA'}).Count){throw 'El plan requiere las16fracciones de1534/2003 y ninguna de PROD_EMPRESA.'}
$modelo=Una @($datos.fuentes|Where-Object 'Nombre Variable' -eq 'A_CUENTA_MAREA') 'fuente modelo'
if([int]$modelo.'Id_ Tabla' -ne 60011 -or [int]$modelo.'No_ Campo Valor' -ne 20){throw 'Cambió el esquema de la fuente modelo.'}
$modeloFiltro=Una @($datos.filtros|Select-Object -First 1) 'filtro modelo'
$fuentesPlan=@(
    [pscustomobject]@{nombre='APL_AJUSTE_CIERRE';descripcion='Selección configurada de cierre para ajuste de producción';tabla=60011;valor=20;agregado=1;filtros=@(
        [pscustomobject]@{campo=1;valor='{LIQ_NO}'},[pscustomobject]@{campo=3;valor=$target.'No_ Empleado'},
        [pscustomobject]@{campo=5;valor=$target.'No_ Proyecto'},[pscustomobject]@{campo=30;valor='CIERRE_MAREA'})},
    [pscustomobject]@{nombre='A_CTA_CCT_MAREA';descripcion='CCT devengado previamente al cierre de la misma marea';tabla=60012;valor=7;agregado=0;filtros=@(
        [pscustomobject]@{campo=16;valor='{EMP_NO}'},[pscustomobject]@{campo=18;valor='{JOB_NO}'},
        [pscustomobject]@{campo=30;valor='DEVENGADOS'},[pscustomobject]@{campo=22;valor='<>0'},
        [pscustomobject]@{campo=23;valor='<{FECHA_REF}'},[pscustomobject]@{campo=1;valor='<>{LIQ_NO}'},
        [pscustomobject]@{campo=3;valor='1013|1083|1053|1533|1534|1023'},[pscustomobject]@{campo=26;valor='0'})}
)
$plan=[ordered]@{servidor=$Servidor;base=$Base;compania=$Compania;extension=$ExtensionId.ToString();objetivo=$target;protegidas=@($datos.cabeceras.No_);periodos=$periodos;entidades=$entidades;versiones=$versiones;fuentes=$fuentesPlan;fracciones=$fracsPlan;controles=@($controles|Select-Object tabla,campo,archivo);configuracion_preservada=@('parametros','valores_param','atributos','tipos_atributo','variables_cfg')}
GuardarJson 'plan-configuracion-cierre.json' $plan
$pruebaPath=Join-Path $Backup 'prueba-configuracion-cierre.json'
$aux=@('historial-preconfig','tramos-preconfig')
function Firma {
    $archivos=@($requeridos+$aux|Sort-Object -Unique)
    $hs=@(foreach($n in $archivos){$p=Join-Path $Backup ($n+'.json');if(!(Test-Path -LiteralPath $p)){throw ('Falta evidencia de ensayo: '+$p)};[ordered]@{nombre=$n;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}})
    $hs+=@(foreach($n in $controlArchivos){[ordered]@{nombre=$n;sha256=(Get-FileHash -LiteralPath (Join-Path $Backup $n) -Algorithm SHA256).Hash}})
    $f=[ordered]@{script=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;formulas=(Get-FileHash -LiteralPath $PlanFormulas -Algorithm SHA256).Hash;plan=(ConvertTo-Json -InputObject $plan -Compress -Depth 16);respaldos=$hs}
    return ConvertTo-Json -InputObject $f -Compress -Depth 18
}
if($Aplicar){if(!(Test-Path -LiteralPath $pruebaPath)){throw 'Falta el ensayo completo con rollback.'};$prueba=Get-Content -LiteralPath $pruebaPath -Raw|ConvertFrom-Json;if(!$prueba.rollback -or $prueba.firma -cne (Firma)){throw 'Cambió el script, plan o respaldo desde el ensayo; repetir sin -Aplicar.'}}
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']=$Servidor;$builder['Initial Catalog']=$Base;$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=15
$cx=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$tx=$null;$schema=@{}
$counts=[ordered]@{fuentes=0;filtros=0;conceptos=0;fracciones=0;historial=0;vigencias_cerradas=0}
function Param($Cmd,[string]$Nombre,$Valor){
    if($null -eq $Valor){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::NVarChar,-1);$p.Value=[DBNull]::Value;return}
    if($Valor -is [datetime]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::DateTime)}
    elseif($Valor -is [bool]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::Bit)}
    elseif($Valor -is [int]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::Int)}
    elseif($Valor -is [decimal]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::Decimal);$p.Precision=38;$p.Scale=20}
    elseif($Valor -is [guid]){$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::UniqueIdentifier)}
    else{$p=$Cmd.Parameters.Add($Nombre,[Data.SqlDbType]::NVarChar,-1)}
    $p.Value=$Valor
}
function Cmd([string]$Sql,$Bindings=@{}){$c=$cx.CreateCommand();$c.Transaction=$tx;$c.CommandTimeout=120;$c.CommandText=$Sql;foreach($k in $Bindings.Keys){Param $c ('@'+$k) $Bindings[$k]};return $c}
function ClaveSQL($Claves,$Bindings){$a=@();$i=0;foreach($k in @($Claves.Keys|Sort-Object)){$n='k'+$i;$Bindings[$n]=$Claves[$k];$a+=(Q $k)+'=@'+$n;$i++};return $a-join' AND '}
function ListaSQL($Valores,[string]$Prefijo,$Bindings){$a=@();$i=0;foreach($v in $Valores){$n=$Prefijo+$i;$Bindings[$n]=$v;$a+='@'+$n;$i++};if(!$a.Count){throw 'Lista SQL vacía.'};return $a-join','}
function QueryRows([string]$Sql,$Bindings=@{}){$c=Cmd ('SELECT ('+$Sql+' FOR JSON PATH,INCLUDE_NULL_VALUES)') $Bindings;try{$j=[string]$c.ExecuteScalar();if(!$j){return @()};return @($j|ConvertFrom-Json)}finally{$c.Dispose()}}
function Rows([string]$Id,$Claves=@{}){$b=@{};$w=if($Claves.Count){' WHERE '+(ClaveSQL $Claves $b)}else{''};return @(QueryRows ('SELECT * FROM '+(Tabla $Id)+' WITH(UPDLOCK,HOLDLOCK)'+$w) $b)}
function AssertSet([string]$Id,$Claves,$Esperadas){$a=@(Rows $Id $Claves);if((CanonicoSet $a) -cne (CanonicoSet @($Esperadas))){throw ('Cambió el conjunto '+$Id+': '+(ConvertTo-Json $Claves -Compress))}}
function AssertRow([string]$Id,$Claves,$Anterior){AssertSet $Id $Claves @($Anterior)}
function Scoped([string]$Id){
    $b=@{emp=$target.'No_ Empleado'};$p=ListaSQL $periodos 'p' $b
    $h=Tabla cabeceras;$hint=' WITH(UPDLOCK,HOLDLOCK)';$scope='h.[No_ Empleado]=@emp AND h.[Cód_ Período] IN('+ $p +')'
    switch($Id){
        'cabeceras' {$sql='SELECT h.* FROM '+$h+' h'+$hint+' WHERE '+$scope}
        {$_ -in @('lineas','variables','uso_parametros','francos','tramos')} {$sql='SELECT d.* FROM '+(Tabla $Id)+' d'+$hint+' JOIN '+$h+' h'+$hint+' ON h.No_=d.[No_ Liquidación] WHERE '+$scope}
        'atributos' {$e=ListaSQL $entidades 'e' $b;$sql='SELECT * FROM '+(Tabla $Id)+$hint+' WHERE [Cód_ Entidad] IN('+ $e +')'}
        'valores_param' {$b.hasta=$mesHasta;$sql='SELECT * FROM '+(Tabla $Id)+$hint+' WHERE [Vigencia Desde]<=@hasta AND ([No_ Empleado]=N'''' OR [No_ Empleado]=@emp)'}
        'fracciones' {$cs=@(@($datos.fracciones.'Cód_ Concepto')+@($versiones.codigo)+@('ADIC_PROD_PESCA')|Sort-Object -Unique);$c=ListaSQL $cs 'c' $b;$sql='SELECT * FROM '+(Tabla $Id)+$hint+' WHERE [Cód_ Concepto] IN('+ $c +')'}
        'historial' {$cs=@($versiones.codigo|Sort-Object -Unique);$c=ListaSQL $cs 'c' $b;$sql='SELECT * FROM '+(Tabla $Id)+$hint+' WHERE [Cód_ Concepto] IN('+ $c +')'}
        default {$sql='SELECT * FROM '+(Tabla $Id)+$hint}
    }
    return @(QueryRows $sql $b)
}
function AssertScoped([string]$Id,$Esperadas){$actual=@(Scoped $Id);if((CanonicoSet $actual) -cne (CanonicoSet @($Esperadas))){GuardarJson ('guard-fallo-'+$Id+'.json') $actual;throw ('Cambió el conjunto respaldado: '+$Id)}}
function Schema([string]$Id){if(!$schema.ContainsKey($Id)){$a=@(QueryRows 'SELECT name,is_identity,is_computed,system_type_id FROM sys.columns WHERE object_id=OBJECT_ID(@obj) ORDER BY column_id' @{obj=(Tabla $Id)});if(!$a.Count){throw ('No existe tabla '+$Id)};$schema[$Id]=$a};return @($schema[$Id])}
function Clone([string]$Id,$Claves,$Cambios){
    $b=@{};$where=ClaveSQL $Claves $b;$nuevo=@{};foreach($k in $Cambios.Keys){$nuevo[$k]=$Cambios[$k]}
    $nuevo['$systemId']=[guid]::NewGuid();$nuevo['$systemCreatedAt']=[datetime]::UtcNow;$nuevo['$systemModifiedAt']=$nuevo['$systemCreatedAt'];$nuevo['$systemCreatedBy']=[guid]::Empty;$nuevo['$systemModifiedBy']=[guid]::Empty
    $cols=@();$sel=@();$i=0;foreach($col in @(Schema $Id|Where-Object {!$_.is_identity -and !$_.is_computed -and $_.system_type_id -ne 189})){$cols+=Q $col.name;if($nuevo.ContainsKey($col.name)){$n='v'+$i;$b[$n]=$nuevo[$col.name];$sel+='@'+$n;$i++}else{$sel+=Q $col.name}}
    $c=Cmd ('INSERT '+(Tabla $Id)+' ('+($cols-join',')+') SELECT '+($sel-join',')+' FROM '+(Tabla $Id)+' WHERE '+$where) $b
    try{if($c.ExecuteNonQuery() -ne 1){throw ('Clonación no unitaria: '+$Id)};$counts[$Id]++}finally{$c.Dispose()}
}
function CerrarVigencia($V,$Original){
    $b=@{codigo=$V.codigo;desde=[datetime]$V.desdeAntes;hasta=([datetime]$V.desdeNuevo).AddDays(-1);now=[datetime]::UtcNow;actor=[guid]::Empty}
    $c=Cmd ('UPDATE '+(Tabla conceptos)+' SET [Vigencia Hasta]=@hasta,[$systemModifiedAt]=@now,[$systemModifiedBy]=@actor WHERE Código=@codigo AND [Vigencia Desde]=@desde') $b
    try{if($c.ExecuteNonQuery() -ne 1){throw 'No se cerró una única vigencia.'};$counts.vigencias_cerradas++}finally{$c.Dispose()}
    $a=Una @(Rows conceptos @{Código=$V.codigo;'Vigencia Desde'=[datetime]$V.desdeAntes}) 'versión cerrada'
    foreach($p in $Original.PSObject.Properties){if($p.Name -notin @('timestamp','Vigencia Hasta','$systemModifiedAt','$systemModifiedBy')){if((ConvertTo-Json -InputObject $p.Value -Compress) -cne (ConvertTo-Json -InputObject $a.($p.Name) -Compress)){throw ('La versión anterior cambió un campo no autorizado: '+$p.Name)}}}
    if((Fecha $a.'Vigencia Hasta') -ne (Fecha $b.hasta)){throw 'El fin de vigencia no coincide con el plan.'}
}
function Audit($V,$Original){
    $b=@{cod=$V.codigo;vig=[datetime]$V.desdeNuevo;descr=$Original.Descripción;anterior=$Original.Fórmula;nueva=$V.formula;cond=$Original.Condición;now=[datetime]::UtcNow;id=[guid]::NewGuid();actor=[guid]::Empty}
    $sql='INSERT '+(Tabla historial)+' ([Cód_ Concepto],[Vigencia Desde],[Descripción Concepto],[Fecha Hora],Usuario,[Tipo Cambio],[Fórmula Anterior],[Fórmula Nueva],[Condición Anterior],[Condición Nueva],[Cambió Fórmula],[Cambió Condición],[Última Edición],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) VALUES(@cod,@vig,@descr,@now,N''CIERRE MAREA PARAMETRICO'',0,@anterior,@nueva,@cond,@cond,1,0,@now,@id,@now,@actor,@now,@actor)'
    $c=Cmd $sql $b;try{if($c.ExecuteNonQuery() -ne 1){throw 'No se registró auditoría.'};$counts.historial++}finally{$c.Dispose()}
}
function Libre([string]$Nombre){foreach($id in @('fuentes','filtros','variables_cfg','parametros','tipos_atributo','conceptos')){$field=if($id -eq 'conceptos'){'Código'}else{'Nombre Variable'};if(@(Rows $id @{$field=$Nombre}).Count){throw ('Nombre destino ocupado: '+$Nombre+'/'+$id)}}}
function AssertControles {
    foreach($control in $controles){$b=@{};$docs=ListaSQL @($datos.cabeceras.No_) 'doc' $b;$actual=@(QueryRows ('SELECT * FROM [dbo].'+(Q $control.tabla)+' WITH(UPDLOCK,HOLDLOCK) WHERE '+(Q $control.campo)+' IN('+ $docs +')') $b);if((CanonicoSet $actual) -cne (CanonicoSet $control.filas)){throw ('Cambió el control complementario: '+$control.archivo)}}
}
function AssertInvariantes {
    foreach($id in @('cabeceras','lineas','variables','atributos','parametros','valores_param','tipos_atributo','variables_cfg','uso_parametros','francos')){AssertScoped $id $datos[$id]}
    AssertScoped tramos $datos['tramos-preconfig']
    AssertControles
    # Todas las fuentes/filtros preexistentes se conservan; sólo se admiten las nuevas del plan.
    $nombres=@($fuentesPlan.nombre)
    foreach($id in @('fuentes','filtros')){$actual=@(Scoped $id|Where-Object {$_.'Nombre Variable' -notin $nombres});if((CanonicoSet $actual) -cne (CanonicoSet $datos[$id])){throw ('Cambió configuración preexistente: '+$Id)}}
}
try{
    $cx.Open();$tx=$cx.BeginTransaction([Data.IsolationLevel]::Serializable)
    $c=Cmd 'IF DB_NAME()<>@db THROW 51220,N''Base de datos inesperada'',1;' @{db=$Base};try{$null=$c.ExecuteNonQuery()}finally{$c.Dispose()}
    foreach($id in $requeridos){AssertScoped $id $datos[$id]}
    AssertControles
    foreach($id in @('filtros','historial')){if(@(Schema $id|Where-Object {$_.is_identity -and $_.name -in @('No_ Línea','No_ Entrada')}).Count -ne 1){throw ('Cambió la clave autoincremental de '+$Id)}}
    foreach($a in $aux){$id=$a.Replace('-preconfig','');$p=Join-Path $Backup ($a+'.json');if(!(Test-Path -LiteralPath $p)){if($Aplicar){throw ('Falta evidencia de ensayo: '+$a)};GuardarJson ($a+'.json') @(Scoped $id)};$datos[$a]=Leer $a;AssertScoped $id $datos[$a]}
    # El selector identifica una sola cabecera existente para ese empleado/proyecto.
    AssertSet cabeceras @{'No_ Empleado'=$target.'No_ Empleado';'No_ Proyecto'=$target.'No_ Proyecto';'Cód_ Tipo Liq_'='CIERRE_MAREA'} @($target)
    foreach($f in $fuentesPlan){Libre $f.nombre}
    foreach($v in $versiones){AssertSet conceptos @{Código=$v.codigo} @($datos.conceptos|Where-Object Código -eq $v.codigo);AssertSet fracciones @{'Cód_ Concepto'=$v.codigo} @($datos.fracciones|Where-Object 'Cód_ Concepto' -eq $v.codigo)}
    foreach($f in $fuentesPlan){
        Clone fuentes @{'Nombre Variable'=$modelo.'Nombre Variable'} @{'Nombre Variable'=$f.nombre;Descripción=$f.descripcion;'Id_ Tabla'=[int]$f.tabla;'No_ Campo Valor'=[int]$f.valor;'Función Agregado'=[int]$f.agregado;Activo=1;'Mostrar en Recibo'=0;'Etiqueta Recibo'='';'No_ Campo Fecha Inicio'=0;'No_ Campo Fecha Fin'=0;'Fin Efectivo'=0;'Tipo Dato'=0;'No_ Campo Clave'=0;'Orden Descendente'=0;'No_ Filtro 1'=0;'No_ Filtro 2'=0;'No_ Filtro 3'=0;'Filtro Valor 1'='';'Filtro Valor 2'='';'Filtro Valor 3'=''}
        foreach($fl in $f.filtros){Clone filtros @{'Nombre Variable'=$modeloFiltro.'Nombre Variable';'No_ Línea'=$modeloFiltro.'No_ Línea'} @{'Nombre Variable'=$f.nombre;'No_ Campo'=[int]$fl.campo;'Filtro Valor'=[string]$fl.valor}}
        $fs=Una @(Rows fuentes @{'Nombre Variable'=$f.nombre}) 'fuente nueva';if([int]$fs.'Id_ Tabla' -ne $f.tabla -or [int]$fs.'No_ Campo Valor' -ne $f.valor -or [int]$fs.'Función Agregado' -ne $f.agregado){throw 'La fuente nueva no coincide con el plan.'}
        $fls=@(Rows filtros @{'Nombre Variable'=$f.nombre}|ForEach-Object {[pscustomobject]@{campo=[int]$_.'No_ Campo';valor=[string]$_.'Filtro Valor'}});if((CanonicoSet $fls) -cne (CanonicoSet $f.filtros)){throw 'Los filtros nuevos no coinciden con el plan.'}
    }
    foreach($v in $versiones){
        $o=$orig[$v.codigo];$key=@{Código=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeAntes}
        Clone conceptos $key @{'Vigencia Desde'=[datetime]$v.desdeNuevo;Fórmula=$v.formula}
        $n=Una @(Rows conceptos @{Código=$v.codigo;'Vigencia Desde'=[datetime]$v.desdeNuevo}) 'concepto nuevo'
        foreach($p in $o.PSObject.Properties){if($p.Name -notin @('timestamp','Vigencia Desde','Fórmula','$systemId','$systemCreatedAt','$systemModifiedAt','$systemCreatedBy','$systemModifiedBy')){if((ConvertTo-Json -InputObject $p.Value -Compress) -cne (ConvertTo-Json -InputObject $n.($p.Name) -Compress)){throw ('El concepto nuevo cambió un campo no autorizado: '+$p.Name)}}}
        if($n.Fórmula -cne $v.formula){throw 'La fórmula insertada difiere del plan.'}
        foreach($fr in @($fracsPlan|Where-Object 'Cód_ Concepto' -eq $v.codigo)){
            $fk=@{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Vigencia Desde'=[datetime]$fr.'Vigencia Desde';'Cód_ Acumulador'=$fr.'Cód_ Acumulador'};Clone fracciones $fk @{'Vigencia Desde'=[datetime]$v.desdeNuevo}
            $fn=Una @(Rows fracciones @{'Cód_ Concepto'=$fr.'Cód_ Concepto';'Vigencia Desde'=[datetime]$v.desdeNuevo;'Cód_ Acumulador'=$fr.'Cód_ Acumulador'}) 'fracción nueva'
            foreach($p in $fr.PSObject.Properties){if($p.Name -notin @('timestamp','Vigencia Desde','$systemId','$systemCreatedAt','$systemModifiedAt','$systemCreatedBy','$systemModifiedBy')){if((ConvertTo-Json -InputObject $p.Value -Compress) -cne (ConvertTo-Json -InputObject $fn.($p.Name) -Compress)){throw ('La fracción nueva difiere en '+$p.Name)}}}
        }
        CerrarVigencia $v $o;Audit $v $o
    }
    if($counts.fuentes -ne 2 -or $counts.filtros -ne 12 -or $counts.conceptos -ne 3 -or $counts.fracciones -ne 16 -or $counts.historial -ne 3 -or $counts.vigencias_cerradas -ne 3){throw 'Cantidad de cambios distinta del plan.'}
    AssertInvariantes
    # Versiones ajenas, fracciones previas y auditorías previas continúan sin cambios.
    $keys=@($versiones|ForEach-Object {$_.codigo+'|'+(Fecha $_.desdeAntes)})
    $resto=@(Scoped conceptos|Where-Object {($_.Código+'|'+(Fecha $_.'Vigencia Desde')) -notin $keys -and !($_.Código -in $versiones.codigo -and (Fecha $_.'Vigencia Desde') -eq (Fecha $mesDesde))})
    $prevResto=@($datos.conceptos|Where-Object {($_.Código+'|'+(Fecha $_.'Vigencia Desde')) -notin $keys})
    if((CanonicoSet $resto) -cne (CanonicoSet $prevResto)){throw 'Cambió un concepto ajeno al plan.'}
    $prevFr=@(Scoped fracciones|Where-Object {!($_.'Cód_ Concepto' -in $versiones.codigo -and (Fecha $_.'Vigencia Desde') -eq (Fecha $mesDesde))})
    if((CanonicoSet $prevFr) -cne (CanonicoSet $datos.fracciones)){throw 'Cambió una fracción previa.'}
    foreach($a in $datos['historial-preconfig']){AssertRow historial @{'No_ Entrada'=$a.'No_ Entrada'} $a}
    if(@(Scoped historial).Count -ne $datos['historial-preconfig'].Count+3){throw 'Cambió la cantidad de auditorías fuera del plan.'}
    if($Aplicar){
        $tx.Commit();$tx.Dispose();$tx=$null
        foreach($id in @('conceptos','fracciones','fuentes','filtros','historial')){GuardarJson ('aplicado-'+$id+'.json') @(Scoped $id)}
        AssertInvariantes
        GuardarJson 'resultado-configuracion-cierre.json' ([ordered]@{aplicado=$true;documento=$Documento;cuentas=$counts;protegidas=@($datos.cabeceras.No_);utc=[datetime]::UtcNow})
        'Configuración aplicada; documentos y parámetros protegidos idénticos. Renovar caché y recalcular sólo el objetivo por BC.'
    }else{
        $tx.Rollback();$tx.Dispose();$tx=$null
        foreach($id in $requeridos){AssertScoped $id $datos[$id]}
        foreach($a in $aux){AssertScoped ($a.Replace('-preconfig','')) $datos[$a]}
        AssertControles
        foreach($f in $fuentesPlan){Libre $f.nombre}
        GuardarJson 'prueba-configuracion-cierre.json' ([ordered]@{rollback=$true;firma=(Firma);cuentas=$counts;protegidas=@($datos.cabeceras.No_);utc=[datetime]::UtcNow})
        'Ensayo completo revertido; firma y conservación de documentos/configuración verificadas.'
    }
    $counts|ConvertTo-Json -Compress
}finally{if($tx){try{$tx.Rollback()}finally{$tx.Dispose()}};$cx.Dispose()}
