WITH
      --get full path to current system_health trace file
      CurrentSystemHealthTraceFile AS (
        SELECT CAST(target_data AS xml).value('(/EventFileTarget/File/@name)[1]', 'varchar(255)') AS FileName
        FROM sys.dm_xe_session_targets
        WHERE
            target_name = 'event_file'
            AND CAST(target_data AS xml).value('(/EventFileTarget/File/@name)[1]', 'varchar(255)') LIKE '%\system[_]health%'
    )
      --get trace folder name and add base name of system_health trace file with wildcard
    , BaseSystemHealthFileName AS (
        SELECT 
            REVERSE(SUBSTRING(REVERSE(FileName), CHARINDEX(N'\', REVERSE(FileName)), 255)) + N'system_health*.xel' AS FileNamePattern
        FROM CurrentSystemHealthTraceFile
        )
      --get xml_deadlock_report events from all system_health trace files
    , DeadLockReports AS (
        SELECT CAST(event_data AS xml) AS event_data
        FROM BaseSystemHealthFileName
        CROSS APPLY sys.fn_xe_file_target_read_file ( FileNamePattern, NULL, NULL, NULL) AS xed
        WHERE xed.object_name like 'xml_deadlock_report'
    )
--display 10 most recent deadlocks
SELECT TOP 30
      DATEADD(hour, DATEDIFF(hour, SYSUTCDATETIME(), SYSDATETIME()), event_data.value('(/event/@timestamp)[1]', 'datetime2')) AS LocalTime
    , event_data AS DeadlockReport
FROM DeadLockReports
ORDER BY LocalTime DESC;