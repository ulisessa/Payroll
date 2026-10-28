<# Sin -Aplicar prepara, mide y prueba la escritura con rollback.
   Con -Aplicar exige un preview previo, respalda, crea vigencia del 5010,
   normaliza los valores fiscales a unidad mensual, reinicia BC252 y recalcula
   los meses afectados más un control positivo.
   No importa el reintegro como novedad ni modifica el cálculo de LIQ_FINAL. #>
[CmdletBinding()]
param([switch]$Aplicar,[Parameter(Mandatory)][string]$Backup)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$null=New-Item -ItemType Directory -Path $Backup -Force
$cx=[Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
$s='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$h='[ArbuTest$Liquidación'+$s+']'
$consultas=[ordered]@{
 conceptos='SELECT * FROM [ArbuTest$Concepto Liquidación'+$s+'] ORDER BY Código,[Vigencia Desde]'
 fracciones='SELECT * FROM [ArbuTest$Fracción Acumulador'+$s+'] WHERE [Cód_ Concepto]=''5010'' ORDER BY [Vigencia Desde],[Cód_ Acumulador]'
 historial='SELECT * FROM [ArbuTest$Historial Fórmula Concepto'+$s+'] WHERE [Cód_ Concepto]=''5010'' ORDER BY [No_ Entrada]'
 enero="SELECT * FROM $h WHERE [Cód_ Período]='202601' ORDER BY No_"
 febrero="SELECT * FROM $h WHERE [Cód_ Período]='202602' AND [Cód_ Tipo Liq_]<>'HIST_REMUN' ORDER BY No_"
 parametros='SELECT * FROM [ArbuTest$Parámetro Vigente'+$s+'] ORDER BY [Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde]'
 escala='SELECT * FROM [ArbuTest$Tabla Escalonada Det_'+$s+'] WHERE Código=''TAB_IMP_4CAT'' AND [Vigencia Desde]=''20260201'' ORDER BY [Límite Inferior]'
 deducciones='SELECT d.[No_ Liquidación],d.Tipo,d.Código,d.[Importe Total] FROM [ArbuTest$Detalle Ganancias Liq_'+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[Cód_ Período]='202602' ORDER BY d.[No_ Liquidación],d.Tipo,d.Código"
 trazas='SELECT d.[No_ Liquidación],d.[Fuente Parámetros],d.Importe FROM [ArbuTest$Línea Liquidación'+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[Cód_ Período]='202602' AND d.[Cód_ Concepto]='5010' ORDER BY d.[No_ Liquidación],d.[No_ Línea]"
 meta4='SELECT h.[No_ Empleado] empleado,SUM(COALESCE(v.Valor,0)) impuesto FROM [ArbuTest$Hist_ Liq_ Meta4'+$s+'] h LEFT JOIN [ArbuTest$Valor Hist_ Meta4'+$s+'] v ON v.[No_ Entrada]=h.[No_ Entrada] AND v.[No_ Columna]=(SELECT No_ FROM [ArbuTest$Columna Hist_ Meta4'+$s+'] WHERE [Nombre Columna]=''IMPUESTO'' AND [Tabla Origen]=''M4T_ACUMULADO_RL'') WHERE h.Año=2026 AND h.Mes=2 AND h.[Contador Liq_]>0 GROUP BY h.[No_ Empleado] ORDER BY h.[No_ Empleado]'
}
foreach($par in @(@('lineas','Línea Liquidación'),@('variables','Resumen Variable Liq_'),@('francos','Movimiento Franco Liq_'),@('novedades','Novedad Liquidación'))){
 if($par[0] -eq 'novedades'){$consultas[$par[0]]='SELECT * FROM [ArbuTest$'+$par[1]+$s+'] WHERE [Cód_ Período]=''202602'' ORDER BY [No_ Movimiento]'}
 elseif($par[0] -eq 'lineas'){$consultas[$par[0]]='SELECT d.[No_ Liquidación],d.[Cód_ Concepto],d.[Vigencia Concepto],d.[Es Devengo],d.[Cód_ Convenio],d.[Cód_ Categoría],d.Importe,d.Cantidad,d.[Base Cálculo] FROM [ArbuTest$'+$par[1]+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[Cód_ Período]='202602' AND d.[Cód_ Concepto] NOT LIKE '%[^0-9]%' ORDER BY d.[No_ Liquidación],d.[Cód_ Concepto],d.[No_ Línea]"}
 elseif($par[0] -eq 'variables'){$consultas[$par[0]]='SELECT d.[No_ Liquidación],d.[Nombre Variable],d.Valor FROM [ArbuTest$'+$par[1]+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[Cód_ Período]='202602' AND d.[Nombre Variable] IN ('YTD_HAB_GRAV_ANUAL','BASE_IG4','YTD_HAB_EXTORD_ANUAL','YTD_SAC_DEV','BASE_EXT_IG4','BASE_SAC_DEV','SS_LIQUIDADO','SS_SAC_DEV','YTD_SS_LIQUIDADO','YTD_SS_SAC_DEV','CUOTA_SINDICAL_RET','YTD_CUOTA_SINDICAL','MNI_ANUAL','DESP_4CAT_ANUAL','DEDUC_GANANCIAS','MES_ANUAL','YTD_RETENIDO_ANUAL') ORDER BY d.[No_ Liquidación],d.[Nombre Variable]"}
 else{$consultas[$par[0]]='SELECT d.* FROM [ArbuTest$'+$par[1]+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[Cód_ Período]='202602'"}
}
function Exportar([string]$Etapa){
 $cmd.Parameters.Clear()
 foreach($item in $consultas.GetEnumerator()){
  $cmd.CommandText='SELECT ('+$item.Value+' FOR JSON PATH, INCLUDE_NULL_VALUES)'
  $json=[string]$cmd.ExecuteScalar();if(!$json){$json='[]'}
  [IO.File]::WriteAllText((Join-Path $Backup ($Etapa+'-'+$item.Key+'.json')),$json,[Text.UTF8Encoding]::new($false))
 }
}
function Leer($tabla){return @(Get-Content (Join-Path $Backup ('antes-'+$tabla+'.json')) -Raw|ConvertFrom-Json)}
function Limitar([decimal]$Total,[decimal]$Retenido){return [math]::Max($Total-$Retenido,-[math]::Max($Retenido,0))}
try{
 $cx.Open();$cmd=$cx.CreateCommand();$cmd.CommandTimeout=120
 if(!$Aplicar){Exportar antes}
 elseif(!(Test-Path (Join-Path $Backup 'propuesta.json'))){throw 'Ejecutar primero el preview en este respaldo.'}
 $conceptos=Leer conceptos
 $fuente=@($conceptos|Where-Object Código -EQ '5010'|Sort-Object 'Vigencia Desde' -Descending)[0]
 if(([datetime]$fuente.'Vigencia Desde').Date -ne [datetime]'2026-01-01'){throw 'La fórmula vigente cambió.'}
 $original=[string]$fuente.Fórmula
 $patron='(\)\s*-\s*YTD_RETENIDO_ANUAL\s*,\s*)0(\s*\)\s*,\s*PRECISION_REDONDEO\s*\)\s*\)\s*)$'
 if([regex]::Matches($original,$patron).Count -ne 1){throw 'No coincide la limitación mensual esperada.'}
 $nueva=[regex]::Replace($original,$patron,'${1}-MAX(YTD_RETENIDO_ANUAL, 0)${2}')
 # La rama anual queda byte a byte igual; sólo cambia el piso de la rama mensual.
 if($nueva.Substring(0,$nueva.IndexOf(', round(')) -cne $original.Substring(0,$original.IndexOf(', round('))){throw 'Se modificó la rama final.'}
 $props=[pscustomobject]@{desde='2026-02-01';anterior=$original;nueva=$nueva}
 if(!$Aplicar){$props|ConvertTo-Json -Depth 4|Set-Content (Join-Path $Backup 'propuesta.json') -Encoding utf8}
 $vars=Leer variables;$cab=Leer febrero;$lineas=Leer lineas;$escala=Leer escala;$meta4=Leer meta4;$detalles=Leer deducciones
 $familia=@{};$gastos=@{};foreach($det in $detalles){if($det.Tipo -eq 0){$familia[$det.'No_ Liquidación']+=[decimal]$det.'Importe Total'}elseif($det.Tipo -eq 1){$gastos[$det.'No_ Liquidación']+=[decimal]$det.'Importe Total'}}
 function ImpuestoTramo([decimal]$Base){
  if($Base -le 0){return [decimal]0};$tramos=@($escala|Where-Object {[decimal]$_.'Límite Inferior' -le $Base -and ([decimal]$_.'Límite Superior' -eq 0 -or [decimal]$_.'Límite Superior' -ge $Base)}|Sort-Object 'Límite Inferior');if(!$tramos.Count){throw 'Base sin tramo.'};$tramo=$tramos[-1];return [decimal]$tramo.'Monto Fijo'+([decimal]$tramo.Porcentaje/100)*($Base-[decimal]$tramo.'Límite Inferior')
 }
 $mapa=@{};foreach($v in $vars){$doc=$v.'No_ Liquidación';if(!$mapa.ContainsKey($doc)){$mapa[$doc]=@{}};$mapa[$doc][$v.'Nombre Variable']=[decimal]$v.Valor}
 $impuestos=@{};foreach($l in $lineas){if($l.'Cód_ Concepto' -eq '5010'){$impuestos[$l.'No_ Liquidación']+=[decimal]$l.Importe}}
 $resultados=@()
 foreach($c in @($cab|Where-Object {$_.Estado -eq 1 -and $_.'Cód_ Tipo Liq_' -ne 'LIQ_FINAL'})){
  $v=$mapa[$c.No_];if(!$v){throw 'Falta contexto guardado.'}
  $base=[decimal]0
  foreach($nombre in @('YTD_HAB_GRAV_ANUAL','BASE_IG4','YTD_HAB_EXTORD_ANUAL','YTD_SAC_DEV','BASE_EXT_IG4','BASE_SAC_DEV')){$base+=[decimal]$v[$nombre]}
  foreach($nombre in @('SS_LIQUIDADO','SS_SAC_DEV','YTD_SS_LIQUIDADO','YTD_SS_SAC_DEV','CUOTA_SINDICAL_RET','YTD_CUOTA_SINDICAL')){$base-=[decimal]$v[$nombre]}
  $ded=([decimal]$v['MNI_ANUAL']+[decimal]$v['DESP_4CAT_ANUAL']+[decimal]$v['DEDUC_GANANCIAS'])*[decimal]$v['MES_ANUAL']
  $base-=$ded+$ded/12
  $total=ImpuestoTramo $base
  $retenido=[decimal]$v['YTD_RETENIDO_ANUAL'];$viejo=[math]::Round([math]::Max($total-$retenido,0),4,[MidpointRounding]::AwayFromZero)
  $actual=[decimal]$impuestos[$c.No_]
  if([math]::Abs($viejo-$actual) -ge .02){throw ('El contexto no reproduce el cálculo actual: '+$c.No_)}
  if([math]::Abs([decimal]$v['DEDUC_GANANCIAS']-([decimal]$familia[$c.No_]+[decimal]$gastos[$c.No_])) -ge .01){throw 'El detalle no reproduce la deducción.'}
  # Familia y catálogos ya acumulados: normalizarlos antes de que la fórmula
  # multiplique por MES_ANUAL. Los gastos personales mantienen su unidad.
  $mes=[decimal]$v['MES_ANUAL'];if($mes -ne 2){throw 'La proyección corresponde a febrero.'}
  $dedNuevo=([decimal]$v['MNI_ANUAL']/$mes+[decimal]$v['DESP_4CAT_ANUAL']/$mes+[decimal]$familia[$c.No_]/$mes+[decimal]$gastos[$c.No_])*$mes
  $baseNueva=$base+$ded+$ded/12-$dedNuevo-$dedNuevo/12
  $totalNuevo=ImpuestoTramo $baseNueva
  $previsto=[math]::Round((Limitar $totalNuevo $retenido),4,[MidpointRounding]::AwayFromZero)
  $m=@($meta4|Where-Object empleado -EQ $c.'No_ Empleado')
  $resultados+=[pscustomobject]@{empleado=$c.'No_ Empleado';documento=$c.No_;anterior=$actual;previsto=$previsto;retenido=$retenido;impuestoTotal=$totalNuevo;meta4=if($m.Count){$m[0].impuesto}else{$null}}
 }
 # Casos de borde: devolver íntegramente, ningún saldo, devolución parcial, retención positiva.
 if((Limitar 0 100) -ne -100 -or (Limitar 0 0) -ne 0 -or (Limitar 60 100) -ne -40 -or (Limitar 150 100) -ne 50 -or (Limitar 0 -10) -lt 0){throw 'Falló un límite de devolución.'}
 $casos=@($resultados|Where-Object {[math]::Abs($_.previsto-$_.anterior) -ge .01})
 $clave=@($casos|Where-Object empleado -EQ '00406')
 if(!$Aplicar){$resultados|ConvertTo-Json -Depth 4|Set-Content (Join-Path $Backup 'proyeccion.json') -Encoding utf8;$casos|ConvertTo-Json -Depth 4|Set-Content (Join-Path $Backup 'afectados.json') -Encoding utf8}
 if($clave.Count -ne 1 -or [math]::Abs($clave[0].previsto-(-772462.47)) -ge .02){throw ('El caso original no concilia; previsto: '+$clave[0].previsto)}
 'Liquidaciones verificadas contra su cálculo actual: '+$resultados.Count+'; afectadas: '+$casos.Count+'; con devolución prevista: '+@($casos|Where-Object previsto -LT 0).Count
 $clave|Format-Table empleado,anterior,previsto,meta4
 $sql=Get-Content (Join-Path $PSScriptRoot 'CorregirDevolucionGananciasMensual.sql') -Raw
 if($Aplicar){$sql=$sql.Replace('DECLARE @Aplicar bit=0,','DECLARE @Aplicar bit=1,')}
 $cmd.Parameters.Clear();$null=$cmd.Parameters.Add('@FormulaAnterior',[Data.SqlDbType]::NVarChar,2048);$cmd.Parameters['@FormulaAnterior'].Value=$original
 $null=$cmd.Parameters.Add('@FormulaNueva',[Data.SqlDbType]::NVarChar,2048);$cmd.Parameters['@FormulaNueva'].Value=$nueva;$cmd.CommandText=$sql;$null=$cmd.ExecuteNonQuery()
 if(!$Aplicar){Exportar simulacion;foreach($nombre in $consultas.Keys){if((Get-FileHash (Join-Path $Backup ('antes-'+$nombre+'.json'))).Hash -ne (Get-FileHash (Join-Path $Backup ('simulacion-'+$nombre+'.json'))).Hash){throw ('Rollback no coincide: '+$nombre)}};'Preview aprobado: contexto reproducido, límites comprobados y escritura revertida.';return}
 $servicio=[ServiceProcess.ServiceController]::new('MicrosoftDynamicsNavServer$BC252','mimir')
 try{$servicio.Stop();$servicio.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped,[timespan]::FromSeconds(60));$servicio.Start();$servicio.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(60))}finally{$servicio.Dispose()}
 'Servicio BC252 reiniciado.'
 $empleados=@($casos|Group-Object empleado|ForEach-Object {$_.Group[0]})
 $control=@($resultados|Where-Object {$_.anterior -gt 0 -and [math]::Abs($_.previsto-$_.anterior) -lt .01}|Select-Object -First 1)
 $empleados+=@($control)
 $empleados|ConvertTo-Json -Depth 4|Set-Content (Join-Path $Backup 'recalculados.json') -Encoding utf8
 foreach($caso in $empleados){& (Join-Path $PSScriptRoot 'RecalcularMesEmpleado.ps1') -Numero $caso.documento;'Mes recalculado: '+$caso.empleado}
 Exportar despues
 & (Join-Path $PSScriptRoot 'VerificarDevolucionGananciasMensual.ps1') -Backup $Backup
 'Corrección mensual aplicada y meses afectados recalculados.'
}finally{$cx.Dispose()}
