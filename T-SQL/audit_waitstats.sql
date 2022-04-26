SET NOCOUNT ON;

IF ((DB_ID('dbi_services_audit') IS NULL) OR (DB_ID('dbi_services_audit') IS NOT NULL AND OBJECT_ID('dbi_services_audit.dbo.audit_0000_9999') IS NULL))
BEGIN
	RAISERROR('dbi_services_audit database doesn''t exist or it is already used by another application', 16, 1);
	RETURN;
END


IF OBJECT_ID('dbi_services_audit.dbo.server_waitstats', 'U') IS NOT NULL
	DROP TABLE dbi_services_audit.dbo.server_waitstats; 

CREATE TABLE dbi_services_audit.dbo.server_waitstats
(
	CaptureDate DATETIME2(7) NOT NULL,
	CaptureID INT NOT NULL,
	ServerName sysname not null,
	wait_type NVARCHAR(60) NOT NULL,
	WaitS BIGINT NOT NULL,
	ResourceS BIGINT NOT NULL,
	SignalS BIGINT NOT NULL,
	WaitCount BIGINT NOT NULL,
	Percentage DECIMAL(5, 2) NOT NULL,
	AvgWait_S DECIMAL(15, 5) NOT NULL,
	AvgRes_S DECIMAL(15, 5) NOT NULL,
	AvgSig_S DECIMAL(15, 5) NOT NULL
);


IF OBJECT_ID('dbi_services_audit.dbo.server_latchstats', 'U') IS NOT NULL
	DROP TABLE dbi_services_audit.dbo.server_latchstats; 

CREATE TABLE dbi_services_audit.dbo.server_latchstats
(
	CaptureDate DATETIME2(7) NOT NULL,
	CaptureID INT NOT NULL,
	ServerName sysname NOT NULL,
	LatchClass NVARCHAR(120) NOT NULL,
	WaitS BIGINT NOT NULL,
	WaitCount BIGINT NOT NULL,
	Percentage DECIMAL(5, 2) NOT NULL,
	AvgWait_S DECIMAL(15, 5) NOT NULL
);


DECLARE @CaptureID INT;
 
SELECT @CaptureID = MAX(CaptureID) 
FROM dbi_services_audit.dbo.server_waitstats;
 
--PRINT (@CaptureID);
 
IF @CaptureID IS NULL	
BEGIN
  SET @CaptureID = 1;
END
ELSE
BEGIN
  SET @CaptureID = @CaptureID + 1;
END  

;WITH Waits AS
    (SELECT
        wait_type,
        wait_time_ms / 1000.0 AS WaitS,
        (wait_time_ms - signal_wait_time_ms) / 1000.0 AS ResourceS,
        signal_wait_time_ms / 1000.0 AS SignalS,
        waiting_tasks_count AS WaitCount,
        100.0 * wait_time_ms / SUM (wait_time_ms) OVER() AS Percentage,
        ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS RowNum
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        N'BROKER_EVENTHANDLER',              N'BROKER_RECEIVE_WAITFOR',
        N'BROKER_TASK_STOP',                 N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER',               N'CHECKPOINT_QUEUE',
        N'CHKPT',                            N'CLR_AUTO_EVENT',
        N'CLR_MANUAL_EVENT',                 N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT',               N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE',            N'DBMIRRORING_CMD',
        N'DIRTY_PAGE_POLL',                  N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC',                         N'FSAGENT',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT',      N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL',                N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT',             N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK',                  N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP',                   N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE',                     N'ONDEMAND_TASK_QUEUE',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'REQUEST_FOR_DEADLOCK_SEARCH',      N'RESOURCE_QUEUE',
        N'SERVER_IDLE_CHECK',                N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP',                  N'SLEEP_DCOMSTARTUP',
        N'SLEEP_MASTERDBREADY',              N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED',             N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK',                 N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP',              N'SNI_HTTP_ACCEPT',
        N'SP_SERVER_DIAGNOSTICS_SLEEP',      N'SQLTRACE_BUFFER_FLUSH',
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES',            N'WAIT_FOR_RESULTS',
        N'WAITFOR',                          N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_HOST_WAIT',               N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_CKPT_CLOSE',              N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT',               N'XE_TIMER_EVENT',
		N'QDS_SHUTDOWN_QUEUE')
    AND [waiting_tasks_count] > 0
)
INSERT INTO dbi_services_audit.dbo.server_waitstats (
 CaptureID, CaptureDate, ServerName, wait_type, WaitS, ResourceS, SignalS, WaitCount, 
 Percentage, AvgWait_S, AvgRes_S, AvgSig_S)
SELECT
	@CaptureID,
	GETDATE() AS CaptureDate,
	@@SERVERNAME,
    MAX ([W1].[wait_type]) AS [WaitType],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95;


;WITH [Latches] AS
    (SELECT
        [latch_class],
        [wait_time_ms] / 1000.0 AS [WaitS],
        [waiting_requests_count] AS [WaitCount],
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_latch_stats
    WHERE [latch_class] NOT IN (
        N'BUFFER')
    AND [wait_time_ms] > 0
    )
INSERT INTO dbi_services_audit.dbo.server_latchstats 
(CaptureID, CaptureDate, ServerName, LatchClass, WaitS, WaitCount, Percentage, AvgWait_S)
SELECT
	@CaptureID,
	GETDATE() AS CaptureDate,
	@@SERVERNAME,
    [W1].[latch_class] AS [LatchClass], 
    CAST ([W1].[WaitS] AS DECIMAL(14, 2)) AS [Wait_S],
    [W1].[WaitCount] AS [WaitCount],
    CAST ([W1].[Percentage] AS DECIMAL(14, 2)) AS [Percentage],
    CAST (([W1].[WaitS] / [W1].[WaitCount]) AS DECIMAL (14, 4)) AS [AvgWait_S]
FROM [Latches] AS [W1]
INNER JOIN [Latches] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
WHERE [W1].[WaitCount] > 0
GROUP BY [W1].[RowNum], [W1].[latch_class], [W1].[WaitS], [W1].[WaitCount], [W1].[Percentage]
HAVING SUM ([W2].[Percentage]) - [W1].[Percentage] < 95;
GO 