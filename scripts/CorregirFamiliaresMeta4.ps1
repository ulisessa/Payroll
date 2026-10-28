<# Corrige sólo clasificaciones verificadas contra el maestro y las fórmulas de Meta4.
   Payload privado: empleados revisados y cambios con clave, tipo anterior/nuevo,
   parentesco, nacimiento y alta/baja impositiva esperados (ISO yyyy-MM-dd).
   Preview valida la escritura dentro de una transacción que revierte.
   Aplicar respalda, corrige, reinicia la caché y recalcula cada mes completo.
   No altera fechas, porcentajes, parentescos ni declaraciones posteriores. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PayloadPath,[switch]$Aplicar)
$ErrorActionPreference='Stop'
$payload=Get-Content -LiteralPath $PayloadPath -Raw | ConvertFrom-Json
$raiz=Split-Path -Parent $PSScriptRoot
if($payload.periodo -ne '202601'){throw 'La revisión corresponde a enero 2026.'}
if(@($payload.empleados).Count -ne 14 -or @($payload.cambios).Count -ne 6){throw 'Revisar el alcance confirmado: 14 casos y seis clasificaciones.'}
if(@($payload.empleados | Sort-Object -Unique).Count -ne 14){throw 'Hay empleados repetidos.'}
$conexion=[System.Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
$sufijo='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$base='[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972]'
$ext='[ArbuTest$Employee Relative$437dbf0e-84ff-417a-965d-ed2bb9650972$ext]'
$tipo='[Cód_ Tipo Ded_'+$sufijo+']'
$alta='[Fecha alta impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb]'
$baja='[Fecha baja impuesto$a423950b-02e9-4ee0-ab32-61517ce330cb]'
$cab='[ArbuTest$Liquidación'+$sufijo+']'
function LeerJson([string]$Consulta){
 $cmd=$conexion.CreateCommand();$cmd.CommandTimeout=120;$cmd.CommandText='SELECT ('+$Consulta+' FOR JSON PATH, INCLUDE_NULL_VALUES)'
 try {$texto=[string]$cmd.ExecuteScalar();if(!$texto){$texto='[]'};$null=ConvertFrom-Json -InputObject $texto;return $texto}finally{$cmd.Dispose()}
}
function Exportar([string]$Etapa){
 $consultas=[ordered]@{
  familiares_base="SELECT r.* FROM $base r WHERE r.[Employee No_] IN ($scope) ORDER BY r.[Employee No_],r.[Line No_]"
  familiares_ext="SELECT r.* FROM $ext r WHERE r.[Employee No_] IN ($scope) ORDER BY r.[Employee No_],r.[Line No_]"
  cabeceras="SELECT h.* FROM $cab h WHERE h.[No_ Empleado] IN ($scope) AND h.[Cód_ Período]='202601' ORDER BY h.No_"
  enero_completo="SELECT h.* FROM $cab h WHERE h.[Cód_ Período]='202601' AND h.[Cód_ Tipo Liq_]<>'HIST_REMUN' ORDER BY h.No_"
 }
 foreach($item in @(@('lineas','Línea Liquidación'),@('variables','Resumen Variable Liq_'),@('detalle','Detalle Ganancias Liq_'),@('francos','Movimiento Franco Liq_'))){
  $consultas[$item[0]]='SELECT d.* FROM [ArbuTest$'+$item[1]+$sufijo+"] d JOIN $cab h ON h.No_=d.[No_ Liquidación] WHERE h.[No_ Empleado] IN ($scope) AND h.[Cód_ Período]='202601'"
 }
 foreach($item in $consultas.GetEnumerator()){
  [IO.File]::WriteAllText((Join-Path $backup ($Etapa+'-'+$item.Key+'.json')),(LeerJson $item.Value),[Text.UTF8Encoding]::new($false))
 }
}
try {
 $conexion.Open()
 # Sólo identificadores de empleado numéricos provenientes del payload verificado.
 foreach($emp in $payload.empleados){if($emp -notmatch '^\d{5}$'){throw 'Identificador de empleado inválido.'}}
 $scope=($payload.empleados | ForEach-Object {"'"+$_+"'"}) -join ','
 $casos=LeerJson "SELECT h.[No_ Empleado] Empleado,MIN(h.No_) Documento FROM $cab h WHERE h.[No_ Empleado] IN ($scope) AND h.[Cód_ Período]='202601' AND h.Estado=1 AND h.[Cód_ Tipo Liq_]<>'HIST_REMUN' GROUP BY h.[No_ Empleado] ORDER BY h.[No_ Empleado]" | ConvertFrom-Json
 $afectados=@($payload.cambios.empleado | Sort-Object -Unique)
 $recalcular=@($casos | Where-Object Empleado -In $afectados)
 if($recalcular.Count -ne $afectados.Count){throw 'Falta el mes calculado de un empleado afectado.'}
 if($Aplicar){
  $backup=Join-Path $raiz ('.snapshots/familiares-ganancias-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
  $null=New-Item -ItemType Directory -Path $backup
  Copy-Item -LiteralPath $PayloadPath -Destination (Join-Path $backup 'payload.json')
  $recalcular | ConvertTo-Json | Set-Content (Join-Path $backup 'casos.json') -Encoding utf8
  Exportar 'antes'
  Write-Output "Respaldo privado: $backup"
 }
 $tx=$conexion.BeginTransaction()
 try {
  $cmd=$conexion.CreateCommand();$cmd.Transaction=$tx;$cmd.CommandTimeout=120
  $cmd.CommandText="IF EXISTS(SELECT 1 FROM $cab h WITH (UPDLOCK,HOLDLOCK) WHERE h.[No_ Empleado] IN ($scope) AND h.[Cód_ Tipo Liq_]<>'HIST_REMUN' AND ((h.[Cód_ Período]='202601' AND h.Estado>1) OR (h.[Fecha Liquidación]>='20260201' AND h.Estado<>0))) THROW 52200,'Hay resultados protegidos o posteriores: revisar cadena de recálculo.',1;"
  $null=$cmd.ExecuteNonQuery()
  foreach($fila in $payload.cambios){
   if($fila.empleado -notin $payload.empleados){throw 'Cambio fuera del alcance.'}
   if(!(($fila.anterior -eq '' -and $fila.nuevo -eq 'CONYUGE' -and $fila.parentesco -eq 'CC') -or ($fila.anterior -eq 'HIJO_INC' -and $fila.nuevo -eq 'HIJO' -and $fila.parentesco -eq 'HI'))){throw 'Clasificación fuera de las correcciones verificadas.'}
   $cmd.Parameters.Clear()
   foreach($campo in @('empleado','anterior','nuevo','parentesco')){
    $null=$cmd.Parameters.Add('@'+$campo,[System.Data.SqlDbType]::NVarChar,20);$cmd.Parameters['@'+$campo].Value=[string]$fila.$campo
   }
   $null=$cmd.Parameters.Add('@linea',[System.Data.SqlDbType]::Int);$cmd.Parameters['@linea'].Value=[int]$fila.linea
   foreach($campo in @('nacimiento','alta','baja')){
    $null=$cmd.Parameters.Add('@'+$campo,[System.Data.SqlDbType]::DateTime)
    $cmd.Parameters['@'+$campo].Value=[datetime]::ParseExact([string]$fila.$campo,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
   }
   $cmd.CommandText="IF NOT EXISTS(SELECT 1 FROM [ArbuTest`$Parámetro$sufijo] WHERE Código=@nuevo) THROW 52201,'Falta el tipo de deducción.',1;
UPDATE e SET e.$tipo=@nuevo FROM $ext e WITH (UPDLOCK,HOLDLOCK) JOIN $base r ON r.[Employee No_]=e.[Employee No_] AND r.[Line No_]=e.[Line No_]
WHERE e.[Employee No_]=@empleado AND e.[Line No_]=@linea AND e.$tipo=@anterior AND r.[Relative Code]=@parentesco AND r.[Birth Date]=@nacimiento AND e.$alta=@alta AND e.$baja=@baja;
IF @@ROWCOUNT<>1 THROW 52202,'El familiar cambió respecto de la revisión: detener.',1;"
   $null=$cmd.ExecuteNonQuery()
  }
  if($Aplicar){$tx.Commit()}else{$tx.Rollback()}
 }catch{$tx.Rollback();throw}finally{$cmd.Dispose();$tx.Dispose()}
 if(!$Aplicar){Write-Output 'Simulación validada y revertida: seis clasificaciones, seis meses completos a recalcular.';return}
 Exportar 'datos'
 # Escritura SQL externa: renovar la caché antes de recalcular.
 $servicio=[System.ServiceProcess.ServiceController]::new('MicrosoftDynamicsNavServer$BC252','mimir')
 try {
  $servicio.Stop();$servicio.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,[timespan]::FromSeconds(60))
  $servicio.Start();$servicio.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(60))
 }finally{$servicio.Dispose()}
 Write-Output 'BC252 reiniciado; clasificaciones actualizadas disponibles.'
 foreach($caso in $recalcular){
  & (Join-Path $PSScriptRoot 'RecalcularMesEmpleado.ps1') -Numero $caso.Documento
  Write-Output ('Mes recalculado: '+$caso.Empleado)
 }
 Exportar 'despues'
 Write-Output 'Seis clasificaciones aplicadas y meses completos recalculados.'
}finally{$conexion.Dispose()}
