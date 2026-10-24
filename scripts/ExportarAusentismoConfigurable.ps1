[CmdletBinding()]
param([Parameter(Mandatory)][string]$Destino,[ValidateSet('antes','despues','prueba')][string]$Prefijo='antes')
$ErrorActionPreference='Stop'
$null=New-Item -ItemType Directory -Path $Destino -Force
$s='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$h='[dbo].[ArbuTest$Liquidación'+$s+']'
$queries=[ordered]@{
 conceptos='SELECT * FROM [dbo].[ArbuTest$Concepto Liquidación'+$s+'] ORDER BY Código,[Vigencia Desde]'
 fuentes='SELECT * FROM [dbo].[ArbuTest$Fuente Datos Liquidación'+$s+'] ORDER BY [Nombre Variable]'
 filtros='SELECT * FROM [dbo].[ArbuTest$Filtro Fuente Datos Liq_'+$s+'] ORDER BY [Nombre Variable],[No_ Línea]'
 variables='SELECT * FROM [dbo].[ArbuTest$Variable Sistema Liq_'+$s+'] ORDER BY [Nombre Variable]'
 parametros='SELECT * FROM [dbo].[ArbuTest$Parámetro'+$s+'] ORDER BY Código'
 valores='SELECT * FROM [dbo].[ArbuTest$Parámetro Vigente'+$s+'] ORDER BY [Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde]'
 convenios='SELECT * FROM [dbo].[ArbuTest$Convenio Colectivo'+$s+'] ORDER BY Código'
 fracciones='SELECT * FROM [dbo].[ArbuTest$Fracción Acumulador'+$s+'] ORDER BY [Cód_ Concepto],[Vigencia Desde],[Cód_ Acumulador]'
 cabeceras='SELECT * FROM '+$h+" WHERE [Cód_ Período] IN ('202601','202602') ORDER BY No_"
 lineas='SELECT l.* FROM [dbo].[ArbuTest$Línea Liquidación'+$s+"] l JOIN $h h ON h.No_=l.[No_ Liquidación] WHERE h.[Cód_ Período] IN ('202601','202602') ORDER BY l.[No_ Liquidación],l.[No_ Línea]"
 resumen='SELECT d.* FROM [dbo].[ArbuTest$Resumen Variable Liq_'+$s+"] d JOIN $h h ON h.No_=d.[No_ Liquidación] WHERE h.[Cód_ Período] IN ('202601','202602') AND (d.[Nombre Variable] LIKE '%ENF%' OR d.[Nombre Variable] LIKE '%ACC%' OR d.[Nombre Variable] LIKE '%AUS%') ORDER BY d.[No_ Liquidación],d.[Nombre Variable]"
 estados='SELECT * FROM [dbo].[ArbuTest$Estado Empleado'+$s+"] WHERE [Fecha Inicio]<='20260228' ORDER BY [No_ Mov_]"
 ledger='SELECT m.* FROM [dbo].[ArbuTest$Movimiento Franco Liq_'+$s+"] m WHERE m.[Fecha Devengamiento]<='20260228' ORDER BY m.[No_ Movimiento]"
}
$cx=[Data.SqlClient.SqlConnection]::new('Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15')
try{
 $cx.Open();$cmd=$cx.CreateCommand();$cmd.CommandTimeout=120
 foreach($q in $queries.GetEnumerator()){
  $cmd.CommandText='SELECT ('+$q.Value+' FOR JSON PATH,INCLUDE_NULL_VALUES)'
  $json=[string]$cmd.ExecuteScalar();if(!$json){$json='[]'}
  [IO.File]::WriteAllText((Join-Path $Destino ($Prefijo+'-'+$q.Key+'.json')),$json,[Text.UTF8Encoding]::new($false))
  Write-Output ($q.Key+' respaldado')
 }
}finally{$cx.Dispose()}
