param([ValidateSet('Before','After')][string]$Phase='Before')
$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'comparacion-enero-2026'
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$file=Join-Path $dir ($Phase+'.json')
if(Test-Path $file){throw "Ya existe $file; conservar la referencia antes de repetir."}
$cn=New-Object System.Data.SqlClient.SqlConnection 'Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Application Name=Codex Payroll Snapshot;Connect Timeout=10'
$cn.Open()
function Query($sql){$cmd=$cn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=60;$dt=New-Object System.Data.DataTable;$r=$cmd.ExecuteReader();try{$dt.Load($r)}finally{$r.Dispose();$cmd.Dispose()};return ,$dt}
function Q($s){return '['+$s.Replace(']',']]')+']'}
$suffix='$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
$header=Q ('ArbuTest$Liquidación'+$suffix)
$period=Q ('ArbuTest$Período Liquidación'+$suffix)
$selectLiq="SELECT h.[No_] FROM dbo.$header h JOIN dbo.$period p ON p.[Código]=h.[Cód_ Período] WHERE p.[Año]=2026 AND p.[Mes]=1"
try{
    $ids=Query $selectLiq
    if($ids.Rows.Count -ne 519){throw "Se esperaban 519 liquidaciones y se encontraron $($ids.Rows.Count)."}
    $result=[ordered]@{CapturedUtc=[DateTime]::UtcNow.ToString('o');Liquidaciones=@($ids.Rows|ForEach-Object {$_[0]}|Sort-Object);Tables=@{}}
    foreach($name in @('Liquidación','Línea Liquidación','Detalle Variable Línea Liq_','Resumen Variable Liq_','Detalle Ganancias Liq_')){
        $table='ArbuTest$'+$name+$suffix
        $escaped=$table.Replace("'","''")
        $cols=Query "SELECT c.name FROM sys.columns c WHERE c.object_id=OBJECT_ID(N'dbo.$escaped') AND c.system_type_id<>189 AND c.name NOT LIKE N'`$system%' AND c.is_identity=0 ORDER BY c.column_id"
        if(-not $cols.Rows.Count){throw "Tabla no encontrada: $table"}
        # Exclude generated entry numbers from Ganancias; preserve duplicates as repeated hashes.
        $names=@($cols.Rows|ForEach-Object {$_[0]}|Where-Object {-not ($name -eq 'Detalle Ganancias Liq_' -and $_ -eq 'No_ Entrada')})
        $projection=($names|ForEach-Object {'t.'+(Q $_)}) -join ','
        $key=if($name -eq 'Liquidación'){'No_'}else{'No_ Liquidación'}
        $rows=Query ('SELECT CONVERT(varchar(64),HASHBYTES(''SHA2_256'',(SELECT '+$projection+' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)),2) AS hash FROM dbo.'+(Q $table)+' t WHERE t.'+(Q $key)+' IN ('+$selectLiq+')')
        $result.Tables[$name]=@($rows.Rows|ForEach-Object {$_.hash}|Sort-Object)
    }
    $result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $file -Encoding UTF8
    if($Phase -eq 'After'){
        $before=Get-Content -Raw (Join-Path $dir 'Before.json')|ConvertFrom-Json
        foreach($name in $result.Tables.Keys){$old=@($before.Tables.$name);$new=@($result.Tables[$name]);[pscustomobject]@{Table=$name;Before=$old.Count;After=$new.Count;Identical=(($old -join '|') -ceq ($new -join '|'))}}
    }else{Write-Output "Referencia guardada: 519 liquidaciones, $file"}
}finally{$cn.Dispose()}
