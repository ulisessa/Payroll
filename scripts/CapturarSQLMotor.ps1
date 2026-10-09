param([ValidateRange(10,900)][int]$Seconds=600)
$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot ('captura-motor-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $dir | Out-Null
$cn=New-Object System.Data.SqlClient.SqlConnection 'Server=tcp:mimir.arbumasa.com,1433;Database=Migr2013R2;Integrated Security=True;Application Name=Codex Payroll Capture;Connect Timeout=10'
$cn.Open()
function Scalar($sql){$c=$cn.CreateCommand();$c.CommandTimeout=15;$c.CommandText=$sql;try{return $c.ExecuteScalar()}finally{$c.Dispose()}}
$name='CodexPayroll_'+[guid]::NewGuid().ToString('N')
$created=$false
try {
    $db=[int](Scalar 'SELECT DB_ID()')
    # Both ad-hoc and sp_executesql statements; only payroll table statements >=10ms.
    $filter="([sqlserver].[database_id]=($db) AND [duration]>=(10000) AND [sqlserver].[like_i_sql_unicode_string]([statement],N'%ArbuTest%Liquidaci%'))"
    $event="ACTION(sqlserver.session_id,sqlserver.client_app_name) WHERE $filter"
    [void](Scalar "CREATE EVENT SESSION [$name] ON SERVER ADD EVENT sqlserver.sql_statement_completed($event), ADD EVENT sqlserver.sp_statement_completed($event) ADD TARGET package0.ring_buffer(SET max_memory=1024) WITH(MAX_MEMORY=2048 KB,MAX_DISPATCH_LATENCY=1 SECONDS,STARTUP_STATE=OFF);")
    $created=$true
    [void](Scalar "ALTER EVENT SESSION [$name] ON SERVER STATE=START;")
    Write-Output "Captura activa por $Seconds segundos. Salida: $dir"
    $until=[DateTime]::UtcNow.AddSeconds($Seconds)
    $n=0
    while([DateTime]::UtcNow -lt $until){
        $xml=Scalar "SELECT CONVERT(nvarchar(max),t.target_data) FROM sys.dm_xe_session_targets t JOIN sys.dm_xe_sessions s ON s.address=t.event_session_address WHERE s.name=N'$name' AND t.target_name='ring_buffer';"
        if($xml){[IO.File]::WriteAllText((Join-Path $dir ('events-{0:D4}.xml' -f $n)),[string]$xml)}
        $waits=Scalar "SELECT SYSUTCDATETIME() AS captured_utc,r.session_id,r.blocking_session_id,r.wait_type,r.wait_time,r.cpu_time,r.total_elapsed_time,r.reads,r.logical_reads,r.writes FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE r.database_id=DB_ID() AND r.session_id<>@@SPID AND t.text LIKE N'%ArbuTest%Liquidaci%' FOR JSON PATH;"
        [IO.File]::WriteAllText((Join-Path $dir ('waits-{0:D4}.json' -f $n)),[string]$waits)
        $n++; Start-Sleep -Seconds 2
    }
    # Export before stopping: stopping destroys the ring buffer.
    $xml=Scalar "SELECT CONVERT(nvarchar(max),t.target_data) FROM sys.dm_xe_session_targets t JOIN sys.dm_xe_sessions s ON s.address=t.event_session_address WHERE s.name=N'$name' AND t.target_name='ring_buffer';"
    if($xml){[IO.File]::WriteAllText((Join-Path $dir 'events-final.xml'),[string]$xml)}
} finally {
    if($created){try{[void](Scalar "DROP EVENT SESSION [$name] ON SERVER;")}catch{Write-Warning "Limpiar manualmente la sesión $name : $_"}}
    $cn.Dispose()
}
# Snapshots overlap: deduplicate events by timestamp, session, event name and contents.
# Inspect RingBufferTarget truncated/droppedCount before drawing completeness conclusions.
