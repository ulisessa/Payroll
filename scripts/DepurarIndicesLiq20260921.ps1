param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$outDir = Join-Path $PSScriptRoot 'diagnostico-sql-20260921'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$conn = New-Object System.Data.SqlClient.SqlConnection 'Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Application Name=Codex Payroll Index Review;Connect Timeout=10'
$conn.Open()
function Query([string]$sql) {
    $cmd = $conn.CreateCommand(); $cmd.CommandTimeout = 30; $cmd.CommandText = $sql
    $dt = New-Object System.Data.DataTable
    $reader = $cmd.ExecuteReader()
    try { $dt.Load($reader) } finally { $reader.Dispose(); $cmd.Dispose() }
    return ,$dt
}
function Q([string]$s) { return '[' + $s.Replace(']',']]') + ']' }
try {
    $meta = Query @'
SET NOCOUNT ON;
SELECT i.index_id,i.name,i.is_unique,i.is_disabled,i.has_filter,i.fill_factor,i.is_padded,i.allow_row_locks,i.allow_page_locks,
       SCHEMA_NAME(t.schema_id) AS schema_name,t.name AS table_name,ds.name AS data_space,
       p.data_compression_desc,s.no_recompute,
       COALESCE(u.user_seeks,0)+COALESCE(u.user_scans,0)+COALESCE(u.user_lookups,0) AS reads, u.user_updates,
       (SELECT c.name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column FROM sys.index_columns ic
        JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
        WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id
        ORDER BY ic.is_included_column,ic.key_ordinal,ic.index_column_id FOR JSON PATH) AS cols
FROM sys.tables t JOIN sys.indexes i ON i.object_id=t.object_id
JOIN sys.data_spaces ds ON ds.data_space_id=i.data_space_id
JOIN sys.partitions p ON p.object_id=i.object_id AND p.index_id=i.index_id AND p.partition_number=1
JOIN sys.stats s ON s.object_id=i.object_id AND s.stats_id=i.index_id
LEFT JOIN sys.dm_db_index_usage_stats u ON u.database_id=DB_ID() AND u.object_id=i.object_id AND u.index_id=i.index_id
WHERE t.name=N'ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890' AND i.index_id>0;
'@
    $pairs = [ordered]@{
        'missing_index_419_418'='missing_index_964_963'
        'missing_index_459_458'='missing_index_471_470'
        'missing_index_390_389'='missing_index_471_470'
        'missing_index_392_391'='missing_index_471_470'
        'missing_index_634_633'='missing_index_620_619'
        'missing_index_512_511'='missing_index_603_602'
    }
    $rollback = @('USE [Migr2013R2];','SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;')
    $drops = @(); $summary = @()
    foreach($name in $pairs.Keys) {
        $source = @($meta.Rows | Where-Object name -eq $name)
        $target = @($meta.Rows | Where-Object name -eq $pairs[$name])
        if($source.Count -ne 1 -or $target.Count -ne 1) { throw "Missing source or replacement: $name" }
        $a=$source[0]; $b=$target[0]
        if($a.is_unique -or $a.is_disabled -or $a.has_filter -or $b.is_disabled -or $b.has_filter) { throw "Unsupported index: $name" }
        $ac=@($a.cols|ConvertFrom-Json); $bc=@($b.cols|ConvertFrom-Json)
        $ak=@($ac|Where-Object { -not $_.is_included_column }); $bk=@($bc|Where-Object { -not $_.is_included_column })
        if($ak.Count -gt $bk.Count) { throw "Not covered: $name" }
        for($j=0;$j -lt $ak.Count;$j++) { if($ak[$j].name -ne $bk[$j].name -or $ak[$j].is_descending_key -ne $bk[$j].is_descending_key) { throw "Key mismatch: $name" } }
        foreach($col in $ac) { if($col.name -notin $bc.name) { throw "Missing covered column: $name" } }
        $table=(Q $a.schema_name)+'.'+(Q $a.table_name)
        $keys=($ak|ForEach-Object { (Q $_.name) + $(if($_.is_descending_key){' DESC'}else{' ASC'}) }) -join ', '
        $inc=@($ac|Where-Object is_included_column)
        $include=if($inc.Count){' INCLUDE ('+(($inc|ForEach-Object {Q $_.name}) -join ', ')+')'}else{''}
        $options='FILLFACTOR = '+$a.fill_factor+', PAD_INDEX = '+$(if($a.is_padded){'ON'}else{'OFF'})+', ALLOW_ROW_LOCKS = '+$(if($a.allow_row_locks){'ON'}else{'OFF'})+', ALLOW_PAGE_LOCKS = '+$(if($a.allow_page_locks){'ON'}else{'OFF'})+', STATISTICS_NORECOMPUTE = '+$(if($a.no_recompute){'ON'}else{'OFF'})+', DATA_COMPRESSION = '+$a.data_compression_desc
        $rollback += 'CREATE NONCLUSTERED INDEX '+(Q $name)+' ON '+$table+' ('+$keys+')'+$include+' WITH ('+$options+') ON '+(Q $a.data_space)+';'
        $drops += 'DROP INDEX '+(Q $name)+' ON '+$table+';'
        $summary += [pscustomobject]@{Removed=$name;Retained=$pairs[$name];Reads=$a.reads;Updates=$a.user_updates}
    }
    if(-not $Apply) {
        $meta | Select-Object -Property * -ExcludeProperty RowError,RowState,Table,ItemArray,HasErrors | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'indexes-before.json') -Encoding UTF8
        $rollback | Set-Content -LiteralPath (Join-Path $outDir 'restore.sql') -Encoding UTF8
        $drops | Set-Content -LiteralPath (Join-Path $outDir 'drops.sql') -Encoding UTF8
        $summary | Export-Csv -LiteralPath (Join-Path $outDir 'selection.csv') -NoTypeInformation -Encoding UTF8
        $summary | Format-Table -AutoSize
        Write-Output 'Prepared only; no SQL changes.'
    } else {
        $saved=Get-Content -LiteralPath (Join-Path $outDir 'restore.sql')
        if(($saved -join "`n") -ne ($rollback -join "`n")) { throw 'Definitions changed since backup; prepare again.' }
        $batch="SET XACT_ABORT ON; SET LOCK_TIMEOUT 5000; BEGIN TRY BEGIN TRANSACTION;`n"+($drops -join "`n")+"`nCOMMIT; END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH;"
        $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=30; $cmd.CommandText=$batch
        [void]$cmd.ExecuteNonQuery(); $cmd.Dispose()
        $verification=Query @'
SELECT i.name,i.is_disabled FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id
WHERE t.name=N'ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890' AND i.index_id>0;
'@
        if(@($verification.Rows|Where-Object {$_.name -in $pairs.Keys}).Count) { throw 'Removed indexes still present.' }
        foreach($keep in $pairs.Values) { if(-not @($verification.Rows|Where-Object {$_.name -eq $keep -and -not $_.is_disabled}).Count) {throw "Replacement missing: $keep"} }
        $result=[pscustomobject]@{Time=(Get-Date -Format o);Removed=$pairs.Count;Before=$meta.Rows.Count;After=$verification.Rows.Count;Status='Verified'}
        $result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $outDir 'result.json') -Encoding UTF8
        $result|Format-List
    }
} finally { $conn.Dispose() }
