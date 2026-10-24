<# Verificación de respaldos antes/después. No conecta ni escribe en SQL.
   Distingue las invariantes del alcance de las modificaciones concurrentes fuera de él. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Backup,
    [Parameter(Mandatory)][string]$CasosOracle
)
$ErrorActionPreference = 'Stop'
$fallos = [Collections.Generic.List[string]]::new()
$concurrentes = [Collections.Generic.List[object]]::new()
function Exigir([bool]$Condicion, [string]$Mensaje) {
    if (!$Condicion) { $fallos.Add($Mensaje) }
}
function Leer([string]$Etapa, [string]$Nombre) {
    $path = Join-Path $Backup ($Etapa + '-' + $Nombre + '.json')
    if (!(Test-Path -LiteralPath $path)) { throw ('Falta el respaldo: ' + $path) }
    return @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}
function Canonico($Fila, [string[]]$Excluir = @()) {
    $obj = [ordered]@{}
    foreach ($prop in @($Fila.PSObject.Properties | Sort-Object Name)) {
        if ($prop.Name -notin $Excluir) { $obj[$prop.Name] = $prop.Value }
    }
    return ConvertTo-Json -InputObject $obj -Depth 8 -Compress
}
function Huella($Filas, [string[]]$Excluir = @()) {
    $texto = (@($Filas | ForEach-Object { Canonico $_ $Excluir } | Sort-Object) -join "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($texto))) }
    finally { $sha.Dispose() }
}
function Indice($Filas, [string]$Campo) {
    $idx = @{}
    foreach ($fila in $Filas) {
        $key = [string]$fila.$Campo
        if (!$idx.ContainsKey($key)) { $idx[$key] = [Collections.Generic.List[object]]::new() }
        $idx[$key].Add($fila)
    }
    return $idx
}
function CompararDocumentos($Antes, $Despues, [string]$Campo, [string]$Etiqueta, $AlcanceEstricto) {
    $a = Indice $Antes $Campo
    $d = Indice $Despues $Campo
    foreach ($key in @(@($a.Keys) + @($d.Keys) | Sort-Object -Unique)) {
        if ((Huella @($a[$key])) -ne (Huella @($d[$key]))) {
            if ($AlcanceEstricto.ContainsKey($key)) { $fallos.Add($Etiqueta + ': cambió ' + $key) }
            else { $concurrentes.Add([pscustomobject]@{conjunto=$Etiqueta;documento=$key;antes=@($a[$key]).Count;despues=@($d[$key]).Count}) }
        }
    }
}
function Fecha($Valor) { return ([datetime]$Valor).ToString('yyyy-MM-dd') }
function Casi([decimal]$A, [decimal]$B, [decimal]$Tolerancia) { return [math]::Abs($A - $B) -le $Tolerancia }

$casos = @(Get-Content -LiteralPath $CasosOracle -Raw | ConvertFrom-Json)
$empleados = @($casos.ID_EMPLEADO | Sort-Object -Unique)
if ($empleados.Count -ne 23 -or @($empleados | Where-Object { $_ -notmatch '^\d{5}$' }).Count) { throw 'Se esperan los 23 casos de febrero de Oracle.' }
$activos = @($empleados | Where-Object { $_ -ne '80668' })
$cabAntes = Leer antes cabfebrero
$cabDespues = Leer despues cabfebrero
$cabEnerAntes = Leer antes cabenero
$cabEnerDespues = Leer despues cabenero
$eneroEstricto = @{}
foreach ($cab in @($cabEnerAntes) + @($cabEnerDespues)) {
    if ($cab.'No_ Empleado' -in $empleados) { $eneroEstricto[[string]$cab.No_] = $true }
}
CompararDocumentos $cabEnerAntes $cabEnerDespues 'No_' 'cabenero' $eneroEstricto
$enerLineAntes = Leer antes lineasenero
$enerLineDespues = Leer despues lineasenero
CompararDocumentos $enerLineAntes $enerLineDespues 'No_ Liquidación' 'lineasenero' $eneroEstricto
$estadosAntes = Leer antes estados
$estadosDespues = Leer despues estados
Exigir ((Huella $estadosAntes) -eq (Huella $estadosDespues)) 'Cambiaron los estados de los 23 empleados, incluido el ACT manual de 80668.'

$histCabAntes = Leer antes cabhistoria
$histCabDespues = Leer despues cabhistoria
$histCabD = @{}
foreach ($cab in $histCabDespues) { $histCabD[[string]$cab.No_] = $cab }
foreach ($cab in $histCabAntes) {
    Exigir ($histCabD.ContainsKey([string]$cab.No_)) ('Falta una cabecera histórica anterior: ' + $cab.No_)
    if ($histCabD.ContainsKey([string]$cab.No_)) { Exigir ((Canonico $cab) -ceq (Canonico $histCabD[[string]$cab.No_])) ('Cambió una cabecera histórica anterior: ' + $cab.No_) }
}
$histCabA = @{}
foreach ($cab in $histCabAntes) { $histCabA[[string]$cab.No_] = $true }
$nuevosHist = @($histCabDespues | Where-Object { !$histCabA.ContainsKey([string]$_.No_) })
$esperadosHist = @('AUS-02737-202411','AUS-03986-202411','AUS-03986-202412')
Exigir ($nuevosHist.Count -eq 3) 'Deben existir solamente las tres nuevas cabeceras históricas de ausentismo.'
foreach ($cab in $nuevosHist) {
    Exigir ($cab.No_ -in $esperadosHist) ('Cabecera histórica nueva inesperada: ' + $cab.No_)
    foreach ($campo in @('Total Haberes','Total Descuentos','Total Contribuciones','Neto a Pagar','Haberes Ordinarios Gravados')) {
        Exigir ([decimal]$cab.$campo -eq 0) ('La cabecera histórica tiene importe económico: ' + $cab.No_ + '/' + $campo)
    }
    Exigir ($cab.'Cód_ Tipo Liq_' -eq 'HIST_REMUN') ('Tipo incorrecto del histórico nuevo: ' + $cab.No_)
}
$histAntes = Leer antes historia
$histDespues = Leer despues historia
$histD = @{}
foreach ($linea in $histDespues) { $histD[[string]$linea.'No_ Línea'] = $linea }
foreach ($linea in $histAntes) {
    $key = [string]$linea.'No_ Línea'
    Exigir ($histD.ContainsKey($key)) ('Falta una línea histórica anterior: ' + $key)
    if ($histD.ContainsKey($key)) { Exigir ((Canonico $linea) -ceq (Canonico $histD[$key])) ('Cambió una línea histórica anterior: ' + $key) }
}
$histA = @{}
foreach ($linea in $histAntes) { $histA[[string]$linea.'No_ Línea'] = $true }
$ajustes = @($histDespues | Where-Object { !$histA.ContainsKey([string]$_.'No_ Línea') })
foreach ($linea in $ajustes) {
    Exigir ($linea.'Cód_ Concepto' -eq 'AJ_HIST_AUS') ('Concepto histórico nuevo inesperado: ' + $linea.'Cód_ Concepto')
    Exigir ([int]$linea.'Tipo Concepto' -eq 6 -and [int]$linea.'Imprime en Recibo' -eq 0 -and [int]$linea.'Es Devengo' -eq 0) ('El ajuste histórico debe ser exclusivamente informativo: ' + $linea.'No_ Liquidación')
}
$histRealAntes = @(Leer antes historiareal | Where-Object { $_.'Cód_ Concepto' -in @('BASE_PROMEDIO','BASE_PROMEDIO_NR') })
$histRealDespues = @(Leer despues historiareal | Where-Object { $_.'Cód_ Concepto' -in @('BASE_PROMEDIO','BASE_PROMEDIO_NR') })
Exigir ((Huella $histRealAntes) -eq (Huella $histRealDespues)) 'Se modificó BASE_PROMEDIO/BASE_PROMEDIO_NR anterior a febrero.'

$fuentesAntes = Leer antes fuentes
$fuentesDespues = Leer despues fuentes
$filtrosAntes = Leer antes filtros
$filtrosDespues = Leer despues filtros
$promOriginales = @('PROM_AUS_12','PROM_AUS_6','PROM_AUS_12_NR','PROM_AUS_6_NR')
Exigir ((Huella @($fuentesAntes | Where-Object { $_.'Nombre Variable' -in $promOriginales })) -eq (Huella @($fuentesDespues | Where-Object { $_.'Nombre Variable' -in $promOriginales }))) 'Cambiaron las fuentes originales PROM_AUS.'
Exigir ((Huella @($filtrosAntes | Where-Object { $_.'Nombre Variable' -in $promOriginales })) -eq (Huella @($filtrosDespues | Where-Object { $_.'Nombre Variable' -in $promOriginales }))) 'Cambiaron los filtros originales PROM_AUS.'
$conceptosAntes = Leer antes conceptos
$conceptosDespues = Leer despues conceptos
$ene4110 = @($conceptosAntes | Where-Object { $_.'Código' -eq '4110' -and (Fecha $_.'Vigencia Desde') -eq '2026-01-01' })
$ene4110D = @($conceptosDespues | Where-Object { $_.'Código' -eq '4110' -and (Fecha $_.'Vigencia Desde') -eq '2026-01-01' })
$feb4110 = @($conceptosDespues | Where-Object { $_.'Código' -eq '4110' -and (Fecha $_.'Vigencia Desde') -eq '2026-02-01' })
Exigir ($ene4110.Count -eq 1 -and $ene4110D.Count -eq 1 -and $feb4110.Count -eq 1) 'No hay una única versión enero/febrero de 4110.'
if ($ene4110.Count -eq 1 -and $ene4110D.Count -eq 1 -and $feb4110.Count -eq 1) {
    Exigir ($ene4110D[0].Fórmula -ceq $ene4110[0].Fórmula) 'Cambió la fórmula de enfermedad de enero.'
    Exigir ((Fecha $ene4110D[0].'Vigencia Hasta') -eq '2026-01-31') 'La fórmula de enero no termina el 31/01/2026.'
    Exigir ($feb4110[0].Fórmula -ceq $ene4110[0].Fórmula.Replace('#PROM_AUS_MES','#PROM_ENF_MES')) 'La fórmula de febrero no utiliza exclusivamente la nueva base de enfermedad.'
    Exigir ($feb4110[0].'Variable Base' -eq '#PROM_ENF_MES') 'La base visible del 4110 de febrero no referencia PROM_ENF_MES.'
}
$fracAntes = Leer antes fracciones
$fracDespues = Leer despues fracciones
$fracEne = @($fracAntes | Where-Object { (Fecha $_.'Vigencia Desde') -eq '2026-01-01' })
$fracFeb = @($fracDespues | Where-Object { (Fecha $_.'Vigencia Desde') -eq '2026-02-01' })
Exigir ($fracEne.Count -eq 8 -and $fracFeb.Count -eq 8) 'No están las ocho fracciones del 4110 copiadas a febrero.'
$fracCampos = @('Vigencia Desde','timestamp','$systemId','$systemCreatedAt','$systemCreatedBy','$systemModifiedAt','$systemModifiedBy')
Exigir ((Huella $fracEne $fracCampos) -eq (Huella $fracFeb $fracCampos)) 'Las fracciones de febrero no conservan los destinos/porcentajes/filtros de enero.'

$lineasAntes = Leer antes lineasfebrero
$lineasDespues = Leer despues lineasfebrero
$liAntes = Indice $lineasAntes 'No_ Liquidación'
$liDespues = Indice $lineasDespues 'No_ Liquidación'
$docsActivos = @($cabDespues | Where-Object { $_.'No_ Empleado' -in $activos -and $_.'Cód_ Tipo Liq_' -ne 'HIST_REMUN' })
$docsActivosIds = @{}
foreach ($cab in $docsActivos) { $docsActivosIds[[string]$cab.No_] = $true }
$cabFebA = @{}
foreach ($cab in $cabAntes) { $cabFebA[[string]$cab.No_] = $cab }
foreach ($cab in $docsActivos) {
    Exigir ($cabFebA.ContainsKey([string]$cab.No_)) ('Documento de febrero nuevo inesperado en el alcance: ' + $cab.No_)
    if ($cabFebA.ContainsKey([string]$cab.No_)) { Exigir ([int]$cab.Estado -eq [int]$cabFebA[[string]$cab.No_].Estado) ('Cambió el estado de liquidación: ' + $cab.No_) }
}
# Todo cambio fuera de los 22 recálculos se separa; 80668 exige invariancia explícita.
$fueraAntes = @($cabAntes | Where-Object { !$docsActivosIds.ContainsKey([string]$_.No_) })
$fueraDespues = @($cabDespues | Where-Object { !$docsActivosIds.ContainsKey([string]$_.No_) })
$manual = @{}
foreach ($cab in @($cabAntes) + @($cabDespues)) { if ($cab.'No_ Empleado' -eq '80668') { $manual[[string]$cab.No_] = $true } }
CompararDocumentos $fueraAntes $fueraDespues 'No_' 'cabfebrero-fuera-alcance' $manual
CompararDocumentos @($lineasAntes | Where-Object { !$docsActivosIds.ContainsKey([string]$_.'No_ Liquidación') }) @($lineasDespues | Where-Object { !$docsActivosIds.ContainsKey([string]$_.'No_ Liquidación') }) 'No_ Liquidación' 'lineasfebrero-fuera-alcance' $manual
$variables = Leer despues variables
$varsDoc = @{}
foreach ($v in $variables) {
    $doc = [string]$v.'No_ Liquidación'
    if (!$varsDoc.ContainsKey($doc)) { $varsDoc[$doc] = @{} }
    $varsDoc[$doc][[string]$v.'Nombre Variable'] = [decimal]$v.Valor
}
$contextos = [Collections.Generic.List[object]]::new()
foreach ($cab in $docsActivos) {
    $doc = [string]$cab.No_
    $antes4110 = @($liAntes[$doc] | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    $despues4110 = @($liDespues[$doc] | Where-Object { $_.'Cód_ Concepto' -eq '4110' })
    $cantidadAntes = [decimal](@($antes4110 | Measure-Object Cantidad -Sum)[0].Sum)
    $cantidadDespues = [decimal](@($despues4110 | Measure-Object Cantidad -Sum)[0].Sum)
    Exigir ($cantidadAntes -eq $cantidadDespues) ('Cambió la cantidad de enfermedad: ' + $doc)
    if ($cantidadDespues -eq 0) { continue }
    Exigir ($despues4110.Count -eq 1) ('4110 no es una única línea: ' + $doc)
    foreach ($linea in $despues4110) { Exigir ((Fecha $linea.'Vigencia Concepto') -eq '2026-02-01') ('Se leyó una fórmula antigua de 4110: ' + $doc) }
    $v = $varsDoc[$doc]
    Exigir ($null -ne $v) ('Falta contexto de cálculo: ' + $doc)
    if ($null -eq $v) { continue }
    if ([decimal]$v['TIPOEMPL'] -eq 2) {
        foreach ($coef in @('COEF_TANGONERO','COEF_POTERO')) {
            Exigir ($v.ContainsKey($coef) -and (Casi ([decimal]$v[$coef]) 1 .0000001)) ('El contexto sigue leyendo coeficiente distinto de 1: ' + $doc + '/' + $coef)
        }
    }
    $ventana = if ([decimal]$v['MESES_AUS'] -ge 12) { '12' } else { '6' }
    $num = [decimal]$v['PROM_AUS_' + $ventana] + [decimal]$v['AUS_AJUSTE_HIST_' + $ventana] + [decimal]$v['AUS_NO_REM_ACT_' + $ventana]
    $div = [math]::Max([decimal]1, [decimal]$v['MESES_PROM_AUS_' + $ventana])
    $esperado = $num / $div
    $prom = @($liDespues[$doc] | Where-Object { $_.'Cód_ Concepto' -eq 'PROM_ENF_MES' })
    Exigir ($prom.Count -eq 1) ('Falta una única línea PROM_ENF_MES: ' + $doc)
    if ($prom.Count -eq 1) { Exigir (Casi ([decimal]$prom[0].Importe) $esperado .0003) ('PROM_ENF_MES no coincide con numerador/divisor del contexto: ' + $doc) }
    if ($despues4110.Count -eq 1) { Exigir (Casi ([decimal]$despues4110[0].'Base Cálculo') $esperado .0003) ('La base visible 4110 no coincide con PROM_ENF_MES: ' + $doc) }
    $contextos.Add([pscustomobject]@{empleado=$cab.'No_ Empleado';documento=$doc;ventana=$ventana;numerador=$num;divisor=$div;promedio=$esperado;coef_tangonero=$v['COEF_TANGONERO'];coef_potero=$v['COEF_POTERO']})
}
$matriz = foreach ($empleado in $empleados) {
    $docs = @($cabDespues | Where-Object { $_.'No_ Empleado' -eq $empleado }).No_
    $lA = @($lineasAntes | Where-Object { $_.'No_ Liquidación' -in $docs -and $_.'Cód_ Concepto' -eq '4110' })
    $lD = @($lineasDespues | Where-Object { $_.'No_ Liquidación' -in $docs -and $_.'Cód_ Concepto' -eq '4110' })
    $m = @($casos | Where-Object { $_.ID_EMPLEADO -eq $empleado })
    $montoM4 = [decimal]0
    foreach ($x in $m) { $montoM4 += [decimal]::Parse([string]$x.ENFERMEDAD, [Globalization.CultureInfo]::InvariantCulture) }
    $montoA = [decimal](@($lA | Measure-Object Importe -Sum)[0].Sum)
    $montoD = [decimal](@($lD | Measure-Object Importe -Sum)[0].Sum)
    [pscustomobject]@{empleado=$empleado;meta4=$montoM4;bc_antes=$montoA;bc_despues=$montoD;diferencia=$montoD-$montoM4;cantidad_antes=[decimal](@($lA|Measure-Object Cantidad -Sum)[0].Sum);cantidad_despues=[decimal](@($lD|Measure-Object Cantidad -Sum)[0].Sum);recalculado=($empleado -ne '80668')}
}
$caso00191 = @($matriz | Where-Object empleado -eq '00191')[0]
Exigir (Casi $caso00191.bc_despues 1681299.63 .02) '00191 no coincide con el importe Meta4 de 1.681.299,63.'
Exigir ($caso00191.cantidad_despues -eq 11) '00191 no conserva sus 11 días de enfermedad.'
$base00191 = @($contextos | Where-Object empleado -eq '00191')
Exigir ($base00191.Count -eq 1) '00191 no tiene un único contexto de enfermedad.'
if ($base00191.Count -eq 1) { Exigir (Casi ([decimal]$base00191[0].promedio) 4585362.627272727 .02) '00191 no utiliza la nueva base mensual de aproximadamente 4.585.362,63.' }
$matriz = @($matriz | Sort-Object @{Expression={[math]::Abs($_.diferencia)};Descending=$true})
$reporte = [ordered]@{verificado=($fallos.Count -eq 0);fallos=$fallos.ToArray();cambios_concurrentes=$concurrentes.ToArray();ajustes_historicos=$ajustes.Count;cabeceras_historicas_nuevas=$nuevosHist.Count;contextos=$contextos.ToArray();matriz=$matriz;diferencias_mayores_1=@($matriz | Where-Object { [math]::Abs($_.diferencia) -gt 1 })}
[IO.File]::WriteAllText((Join-Path $Backup 'verificacion-enfermedad.json'), (ConvertTo-Json -InputObject $reporte -Depth 10), [Text.UTF8Encoding]::new($false))
$matriz | Format-Table empleado,meta4,bc_antes,bc_despues,diferencia,cantidad_despues,recalculado -AutoSize
Write-Output ('Cabeceras nuevas: ' + $nuevosHist.Count + '; ajustes informativos: ' + $ajustes.Count + '; cambios fuera de alcance detectados: ' + $concurrentes.Count)
if ($fallos.Count) { throw ('Verificación fallida: ' + ($fallos -join ' | ')) }
Write-Output 'Verificación del alcance aprobada. Las diferencias residuales de importe se informan para revisión, sin asumir que las ventanas laborales son iguales.'
