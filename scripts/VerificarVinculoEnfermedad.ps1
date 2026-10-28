<# Verifica únicamente respaldos antes/después, sin conectarse a SQL ni operar BC.
   Las salidas se guardan en el respaldo privado. Las diferencias externas al alcance
   se informan como cambios concurrentes y no se confunden con las invariantes aprobadas. #>
[CmdletBinding()]
param(
    [string]$Backup = (Join-Path (Split-Path -Parent $PSScriptRoot) '.snapshots\enfermedad-vinculo-20261013'),
    [string]$CasosOracle = (Join-Path (Split-Path -Parent $PSScriptRoot) '.snapshots\enfermedad-febrero-20261013\oracle-casos-febrero.json')
)
$ErrorActionPreference = 'Stop'
$Backup = (Resolve-Path -LiteralPath $Backup).Path
$fallos = [Collections.Generic.List[string]]::new()
$concurrentes = [Collections.Generic.List[object]]::new()
$contextos = [Collections.Generic.List[object]]::new()
$eneroConservadoGlobal = $true

function Exigir([bool]$Condicion, [string]$Mensaje) {
    if (!$Condicion) { $fallos.Add($Mensaje) }
}
function Leer([string]$Etapa, [string]$Nombre) {
    $ruta = Join-Path $Backup ($Etapa + '-' + $Nombre + '.json')
    if (!(Test-Path -LiteralPath $ruta)) { throw ('Falta el respaldo: ' + $ruta) }
    return @(Get-Content -LiteralPath $ruta -Raw | ConvertFrom-Json)
}
function Canonico($Fila, [string[]]$Excluir = @()) {
    $objeto = [ordered]@{}
    foreach ($p in @($Fila.PSObject.Properties | Sort-Object Name)) {
        if ($p.Name -notin $Excluir) { $objeto[$p.Name] = $p.Value }
    }
    return ConvertTo-Json -InputObject $objeto -Depth 10 -Compress
}
function Huella($Filas, [string[]]$Excluir = @()) {
    $texto = (@($Filas | ForEach-Object { Canonico $_ $Excluir } | Sort-Object) -join "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($texto))) }
    finally { $sha.Dispose() }
}
function Indice($Filas, [string]$Campo) {
    $resultado = @{}
    foreach ($fila in $Filas) {
        $clave = [string]$fila.$Campo
        if (!$resultado.ContainsKey($clave)) { $resultado[$clave] = [Collections.Generic.List[object]]::new() }
        $resultado[$clave].Add($fila)
    }
    return $resultado
}
function FilasDoc($Indice, [string]$Documento) {
    if ($Indice.ContainsKey($Documento)) { return $Indice[$Documento].ToArray() }
    return @()
}
function Fecha($Valor) { return ([datetime]$Valor).ToString('yyyy-MM-dd') }
function Casi([decimal]$A, [decimal]$B, [decimal]$Tolerancia = .01) { return [math]::Abs($A - $B) -le $Tolerancia }
function Suma($Filas, [string]$Campo) {
    $total = [decimal]0
    foreach ($fila in $Filas) { $total += [decimal]$fila.$Campo }
    return $total
}
function Valor($Variables, [string]$Nombre) {
    if ($null -ne $Variables -and $Variables.ContainsKey($Nombre)) { return [decimal]$Variables[$Nombre] }
    return [decimal]0
}
function Normalizar([string]$Formula) { return [regex]::Replace($Formula.ToUpperInvariant(), '\s+', '') }

$casos = @(Get-Content -LiteralPath $CasosOracle -Raw | ConvertFrom-Json)
$empleados = @($casos.ID_EMPLEADO | Sort-Object -Unique)
if ($empleados.Count -ne 23 -or @($empleados | Where-Object { $_ -notmatch '^\d{5}$' }).Count) {
    throw 'Se requieren los 23 empleados auditados de Meta4.'
}
$cabEneroA = Leer antes cabenero
$cabEneroD = Leer despues cabenero
$cabFebA = Leer antes cabfebrero
$cabFebD = Leer despues cabfebrero
$mapEmpleado = @{}
foreach ($cab in @($cabEneroA) + @($cabEneroD) + @($cabFebA) + @($cabFebD)) {
    $mapEmpleado[[string]$cab.No_] = [string]$cab.'No_ Empleado'
}

function CompararPorDocumento($Antes, $Despues, [string]$Campo, [string]$Conjunto, [bool]$EsEnero) {
    $a = Indice $Antes $Campo
    $d = Indice $Despues $Campo
    foreach ($doc in @(@($a.Keys) + @($d.Keys) | Sort-Object -Unique)) {
        $empleado = [string]$mapEmpleado[$doc]
        if ($EsEnero -and $empleado -eq '80668') { continue }
        if (!$EsEnero -and $empleado -in $empleados) { continue }
        $filasA = @(FilasDoc $a $doc)
        $filasD = @(FilasDoc $d $doc)
        if ((Huella $filasA) -eq (Huella $filasD)) { continue }
        if ($EsEnero) { $script:eneroConservadoGlobal = $false }
        if ($empleado -in $empleados) {
            $fallos.Add($Conjunto + ': cambió un documento de enero que debía conservarse: ' + $doc)
        } else {
            $concurrentes.Add([pscustomobject]@{conjunto=$Conjunto;documento=$doc;empleado=$empleado;filas_antes=$filasA.Count;filas_despues=$filasD.Count})
        }
    }
}
CompararPorDocumento $cabEneroA $cabEneroD 'No_' 'cabenero' $true
CompararPorDocumento $cabFebA $cabFebD 'No_' 'cabfebrero-fuera-alcance' $false

# Las cabeceras de febrero del alcance conservan documento y estado; sus importes se recalculan.
$cabFebAI = @{}
$cabFebDI = @{}
foreach ($cab in $cabFebA) { $cabFebAI[[string]$cab.No_] = $cab }
foreach ($cab in $cabFebD) { $cabFebDI[[string]$cab.No_] = $cab }
foreach ($doc in @(@($cabFebAI.Keys) + @($cabFebDI.Keys) | Sort-Object -Unique)) {
    if ([string]$mapEmpleado[$doc] -notin $empleados) { continue }
    Exigir ($cabFebAI.ContainsKey($doc) -and $cabFebDI.ContainsKey($doc)) ('Se agregó o perdió un documento de febrero del alcance: ' + $doc)
    if ($cabFebAI.ContainsKey($doc) -and $cabFebDI.ContainsKey($doc)) {
        Exigir ([int]$cabFebAI[$doc].Estado -eq [int]$cabFebDI[$doc].Estado) ('Cambió el estado de cálculo en febrero: ' + $doc)
    }
}

foreach ($nombre in @('cabhistoria','historia','meta4')) {
    Exigir ((Huella (Leer antes $nombre)) -eq (Huella (Leer despues $nombre))) ('Cambió el respaldo histórico previo: ' + $nombre)
}
$basesHistA = @(Leer antes historiareal | Where-Object { $_.'Cód_ Tipo Liq_' -eq 'HIST_REMUN' })
$basesHistD = @(Leer despues historiareal | Where-Object { $_.'Cód_ Tipo Liq_' -eq 'HIST_REMUN' })
Exigir ((Huella $basesHistA) -eq (Huella $basesHistD)) 'Cambió la base de algún histórico migrado.'

$estA = Leer antes estados
$estD = Leer despues estados
$ea = @{}; $ed = @{}
foreach ($r in $estA) { $ea[[string]$r.'No_ Mov_'] = $r }
foreach ($r in $estD) { $ed[[string]$r.'No_ Mov_'] = $r }
Exigir ($ea.ContainsKey('304856') -and $ed.ContainsKey('304856')) 'Falta el episodio AU1 original que debía prolongarse.'
if ($ea.ContainsKey('304856') -and $ed.ContainsKey('304856')) {
    $ignorados = @('Fecha Fin','timestamp','$systemModifiedAt','$systemModifiedBy')
    Exigir ((Canonico $ea['304856'] $ignorados) -ceq (Canonico $ed['304856'] $ignorados)) 'El episodio AU1 cambió campos distintos de su fin y metadatos de edición.'
    Exigir ((Fecha $ed['304856'].'Fecha Fin') -eq '2026-03-15') 'AU1 no finaliza el 15/03/2026.'
}
Exigir ($ea.ContainsKey('341543') -and !$ed.ContainsKey('341543')) 'El ACT manual de enero debía retirarse exactamente una vez.'
Exigir ($ea.ContainsKey('308744') -and $ed.ContainsKey('308744')) 'Falta el ACT siguiente de marzo.'
if ($ea.ContainsKey('308744') -and $ed.ContainsKey('308744')) {
    Exigir ((Canonico $ea['308744']) -ceq (Canonico $ed['308744'])) 'Se alteró el ACT del 16/03 que debía preservarse completo.'
}
foreach ($mov in @(@($ea.Keys) + @($ed.Keys) | Sort-Object -Unique)) {
    if ($mov -in @('304856','341543')) { continue }
    Exigir ($ea.ContainsKey($mov) -and $ed.ContainsKey($mov)) ('Estado agregado o eliminado fuera de la restauración: ' + $mov)
    if ($ea.ContainsKey($mov) -and $ed.ContainsKey($mov)) {
        Exigir ((Canonico $ea[$mov]) -ceq (Canonico $ed[$mov])) ('Cambió un estado fuera de la restauración: ' + $mov)
    }
}

$conceptosA = Leer antes conceptos
$conceptosD = Leer despues conceptos
$enf = @($conceptosD | Where-Object { $_.'Código' -eq '4110' -and (Fecha $_.'Vigencia Desde') -eq '2026-02-02' })
Exigir ($enf.Count -eq 1) 'Falta una única vigencia de febrero del 4110.'
if ($enf.Count -eq 1) {
    $baseEsperada = 'IF(TIPOEMPL = 2, #PROM_ENF_MES, BASE_AUSENTISMO)'
    Exigir ((Normalizar $enf[0].'Variable Base') -ceq (Normalizar $baseEsperada)) 'La base visible del 4110 no distingue tripulantes y tierra.'
    Exigir ($enf[0].Fórmula -match '#PROM_ENF_MES' -and $enf[0].Fórmula -match 'BASE_AUSENTISMO') 'La fórmula 4110 no conserva sus dos ramas de base.'
}
$virtual = @($conceptosD | Where-Object { $_.'Código' -eq 'PROM_ENF_MES' -and (Fecha $_.'Vigencia Desde') -eq '2026-02-02' })
$promEsperado = 'IF(MESES_AUS >= 12, IF(DIV_PROM_ENF_12 > 0, (ENF_BASE_12 + ENF_NR_12) / IFZERO(DIV_PROM_ENF_12, 1), 0), IF(DIV_PROM_ENF_6 > 0, (ENF_BASE_6 + ENF_NR_6) / IFZERO(DIV_PROM_ENF_6, 1), 0))'
Exigir ($virtual.Count -eq 1) 'Falta una única vigencia del promedio específico de enfermedad.'
if ($virtual.Count -eq 1) {
    Exigir ((Normalizar $virtual[0].Fórmula) -ceq (Normalizar $promEsperado)) 'El promedio específico no usa el vínculo vigente y el divisor diario.'
    Exigir ([int]$virtual[0].'Tipo Concepto' -eq 6 -and [int]$virtual[0].'Es Acumulador' -eq 0) 'El promedio debe continuar siendo exclusivamente virtual.'
}
$fracD = Leer despues fracciones
$fJan = @($fracD | Where-Object { $_.'Cód_ Concepto' -eq '4110' -and (Fecha $_.'Vigencia Desde') -eq '2026-01-01' })
$fFeb = @($fracD | Where-Object { $_.'Cód_ Concepto' -eq '4110' -and (Fecha $_.'Vigencia Desde') -eq '2026-02-02' })
Exigir ($fJan.Count -eq 8 -and $fFeb.Count -eq 8) 'Las versiones de enero y febrero del 4110 deben tener ocho fracciones.'
$sinVigencia = @('timestamp','Vigencia Desde','$systemId','$systemCreatedAt','$systemCreatedBy','$systemModifiedAt','$systemModifiedBy')
Exigir ((Huella $fJan $sinVigencia) -eq (Huella $fFeb $sinVigencia)) 'Las ocho fracciones del 4110 cambiaron de composición.'

$lineasEA = Leer antes lineasenero
$lineasED = Leer despues lineasenero
CompararPorDocumento $lineasEA $lineasED 'No_ Liquidación' 'lineasenero' $true
$lineasFA = Leer antes lineasfebrero
$lineasFD = Leer despues lineasfebrero
CompararPorDocumento $lineasFA $lineasFD 'No_ Liquidación' 'lineasfebrero-fuera-alcance' $false
$laE = Indice $lineasEA 'No_ Liquidación'; $ldE = Indice $lineasED 'No_ Liquidación'
$laF = Indice $lineasFA 'No_ Liquidación'; $ldF = Indice $lineasFD 'No_ Liquidación'

# Antigüedad: conservar el importe, la base visible y los porcentajes de 2/3 cargados previamente.
foreach ($mes in @('enero','febrero')) {
    $cabs = if ($mes -eq 'enero') { $cabEneroD } else { $cabFebD }
    $a = if ($mes -eq 'enero') { $laE } else { $laF }
    $d = if ($mes -eq 'enero') { $ldE } else { $ldF }
    $docs = @($cabs | Where-Object { $_.'No_ Empleado' -eq '80668' }).No_
    foreach ($doc in $docs) {
        $antA = @(FilasDoc $a $doc | Where-Object { $_.'Cód_ Concepto' -eq '1053' })
        $antD = @(FilasDoc $d $doc | Where-Object { $_.'Cód_ Concepto' -eq '1053' })
        $campos = @('Cód_ Concepto','Importe','Cantidad','Base Cálculo','Vigencia Concepto')
        $pA = @($antA | Select-Object $campos); $pD = @($antD | Select-Object $campos)
        Exigir ((Huella $pA) -eq (Huella $pD)) ('Cambió la antigüedad salarial de 80668 en ' + $mes)
    }
    $actuales = @($docs | ForEach-Object { FilasDoc $d $_ } | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    $objetivo = if ($mes -eq 'enero') { [decimal]1531955.30 } else { [decimal]1543561.03 }
    Exigir (Casi (Suma $actuales Cantidad) 30 .0001) ('80668 no tiene treinta días de enfermedad en ' + $mes)
    Exigir (Casi (Suma $actuales Importe) $objetivo .01) ('80668 no concilia enfermedad con Meta4 en ' + $mes)
    if ($mes -eq 'febrero') {
        $ded = @($docs | ForEach-Object { FilasDoc $d $_ } | Where-Object { $_.'Cód_ Concepto' -eq '4115' })
        $aus = @($docs | ForEach-Object { FilasDoc $d $_ } | Where-Object { $_.'Cód_ Concepto' -eq '4703' })
        Exigir (Casi (Suma $ded Importe) (-1543561.03) .01) '80668 no conserva el descuento espejo de enfermedad en febrero.'
        Exigir (Casi (Suma $aus Importe) 0 .0001) '80668 mantiene un descuento por ausencia 4703 ajeno a la licencia restaurada.'
    }
}

$variables = Leer despues variables
$varsDoc = @{}
foreach ($v in $variables) {
    $doc = [string]$v.'No_ Liquidación'
    if (!$varsDoc.ContainsKey($doc)) { $varsDoc[$doc] = @{} }
    $varsDoc[$doc][[string]$v.'Nombre Variable'] = [decimal]$v.Valor
}
foreach ($cab in @($cabFebD | Where-Object { $_.'No_ Empleado' -in $empleados })) {
    $doc = [string]$cab.No_
    $antes4110 = @(FilasDoc $laF $doc | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    $actual4110 = @(FilasDoc $ldF $doc | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    if ($cab.'No_ Empleado' -ne '80668') {
        Exigir (Casi (Suma $antes4110 Cantidad) (Suma $actual4110 Cantidad) .0001) ('Cambió la cantidad de enfermedad de otro empleado: ' + $doc)
    }
    if ((Suma $actual4110 Cantidad) -le 0) { continue }
    Exigir ($actual4110.Count -eq 1) ('4110 no tiene una única línea en ' + $doc)
    $v = $varsDoc[$doc]
    Exigir ($null -ne $v) ('Falta el contexto recalculado de ' + $doc)
    if ($null -eq $v) { continue }
    if ((Valor $v TIPOEMPL) -ne 2) {
        foreach ($fila in $actual4110) { Exigir (Casi ([decimal]$fila.'Base Cálculo') (Valor $v BASE_AUSENTISMO) .001) ('La base visible de tierra no coincide con BASE_AUSENTISMO: ' + $doc) }
        if ($cab.'No_ Empleado' -eq '80668') {
            $aportantes = @(FilasDoc $ldF $doc | Where-Object { $_.'Cód_ Concepto' -in @('1003','1053','2103','2703') })
            Exigir (Casi (Suma $aportantes Importe) (Valor $v BASE_AUSENTISMO) .01) 'BASE_AUSENTISMO de 80668 no conserva básico, antigüedad, presentismo y zona.'
        }
        continue
    }
    foreach ($coef in @('COEF_TANGONERO','COEF_POTERO')) {
        Exigir ($v.ContainsKey($coef) -and (Casi (Valor $v $coef) 1 .0000001)) ('El contexto embarcado no lee coeficiente uno en febrero: ' + $doc + '/' + $coef)
    }
    $largo = if ((Valor $v MESES_AUS) -ge 12) { '12' } else { '6' }
    $num = (Valor $v ('ENF_BASE_' + $largo)) + (Valor $v ('ENF_NR_' + $largo))
    $div = Valor $v ('DIV_PROM_ENF_' + $largo)
    Exigir ($v.ContainsKey('DIV_PROM_ENF_' + $largo)) ('No se sembró o calculó el divisor de vínculo actual: ' + $doc)
    $esperado = if ($div -gt 0) { $num / $div } else { [decimal]0 }
    $prom = @(FilasDoc $ldF $doc | Where-Object { $_.'Cód_ Concepto' -eq 'PROM_ENF_MES' })
    Exigir ($prom.Count -eq 1) ('Falta el promedio virtual recalculado en ' + $doc)
    if ($prom.Count -eq 1) { Exigir (Casi ([decimal]$prom[0].Importe) $esperado .001) ('PROM_ENF_MES no coincide con su numerador/divisor en ' + $doc) }
    foreach ($fila in $actual4110) {
        Exigir ((Fecha $fila.'Vigencia Concepto') -eq '2026-02-02') ('Se utilizó una vigencia vieja de enfermedad en ' + $doc)
        Exigir (Casi ([decimal]$fila.'Base Cálculo') $esperado .001) ('La base visible de enfermedad no coincide con el promedio en ' + $doc)
    }
    $contextos.Add([pscustomobject]@{empleado=$cab.'No_ Empleado';documento=$doc;largo=$largo;numerador=$num;divisor=$div;promedio=$esperado})
}

$matriz = foreach ($empleado in $empleados) {
    $docs = @($cabFebD | Where-Object { $_.'No_ Empleado' -eq $empleado }).No_
    $a = @($docs | ForEach-Object { FilasDoc $laF $_ } | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    $d = @($docs | ForEach-Object { FilasDoc $ldF $_ } | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    $montoM4 = [decimal]0
    foreach ($m in @($casos | Where-Object { $_.ID_EMPLEADO -eq $empleado })) {
        $montoM4 += [decimal]::Parse([string]$m.ENFERMEDAD,[Globalization.CultureInfo]::InvariantCulture)
    }
    $montoA = Suma $a Importe; $montoD = Suma $d Importe
    [pscustomobject]@{empleado=$empleado;meta4=$montoM4;bc_antes=$montoA;bc_despues=$montoD;diferencia=$montoD-$montoM4;cantidad_antes=(Suma $a Cantidad);cantidad_despues=(Suma $d Cantidad);coincide=(Casi $montoD $montoM4 .1)}
}
foreach ($caso in @(@('00191',[decimal]1681299.63),@('04185',[decimal]5488463.99),@('04850',[decimal]241569.82))) {
    $m = @($matriz | Where-Object { $_.empleado -eq $caso[0] })
    Exigir ($m.Count -eq 1) ('Falta el caso específico de conciliación: ' + $caso[0])
    if ($m.Count -eq 1) { Exigir (Casi ([decimal]$m[0].bc_despues) ([decimal]$caso[1]) .01) ('El caso específico no concilia al centavo: ' + $caso[0]) }
}
$matriz = @($matriz | Sort-Object @{Expression={[math]::Abs($_.diferencia)};Descending=$true})
$coincidencias = @($matriz | Where-Object coincide).Count
$reporte = [ordered]@{
    verificado=($fallos.Count -eq 0);fallos=$fallos.ToArray();enero_global_excepto_80668_conservado=$eneroConservadoGlobal;
    cambios_concurrentes=$concurrentes.ToArray();coincidencias_meta4_hasta_10_centavos=$coincidencias;
    coincidencias_esperadas_informativas=18;contextos=$contextos.ToArray();matriz=$matriz;
    residuales=@($matriz | Where-Object { !$_.coincide })
}
[IO.File]::WriteAllText((Join-Path $Backup 'verificacion-vinculo-enfermedad.json'),
    (ConvertTo-Json -InputObject $reporte -Depth 10),[Text.UTF8Encoding]::new($false))
Write-Output ('Casos conciliados con Meta4 (hasta $0,10): ' + $coincidencias + '/23. Diferencias pendientes: ' + @($reporte.residuales).Count)
Write-Output ('Cambios concurrentes fuera del alcance: ' + $concurrentes.Count + '. Enero global, salvo 80668, conservado: ' + $eneroConservadoGlobal)
if ($fallos.Count) { throw ('Verificación fallida: ' + ($fallos -join ' | ')) }
Write-Output 'Invariantes del alcance aprobadas. El reporte conserva las diferencias residuales sin atribuirles una causa no verificada.'
