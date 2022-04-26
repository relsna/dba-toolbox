SET NOCOUNT ON;



IF OBJECT_ID('dbi_services_audit.dbo.database_fileLatency', 'U') IS NOT NULL
	DROP TABLE dbi_services_audit.dbo.database_fileLatency;

CREATE TABLE dbi_services_audit.dbo.database_fileLatency
(
	[CaptureID] [INT] NOT NULL,
	[CaptureDate] [DATETIME2](7) NULL,
	[ReadLatency] [BIGINT] NULL,
	[WriteLatency] [BIGINT] NULL,
	[Latency] [BIGINT] NULL,
	[AvgBPerRead] [BIGINT] NULL,
	[AvgBPerWrite] [BIGINT] NULL,
	[AvgBPerTransfer] [BIGINT] NULL,
	[Drive] [NVARCHAR](2) NULL,
	[DB] [NVARCHAR](128) NULL,
	[database_id] [SMALLINT] NOT NULL,
	[file_id] [SMALLINT] NOT NULL,
	[sample_ms] [INT] NOT NULL,
	[num_of_reads] [BIGINT] NOT NULL,
	[num_of_bytes_read] [BIGINT] NOT NULL,
	[io_stall_read_ms] [BIGINT] NOT NULL,
	[num_of_writes] [BIGINT] NOT NULL,
	[num_of_bytes_written] [BIGINT] NOT NULL,
	[io_stall_write_ms] [BIGINT] NOT NULL,
	[io_stall] [BIGINT] NOT NULL,
	[size_on_disk_MB] [NUMERIC](25, 6) NULL,
	[file_handle] [VARBINARY](8) NOT NULL,
	[physical_name] [NVARCHAR](260) NOT NULL
);

DECLARE @CaptureID INT;

SELECT @CaptureID = COALESCE(MAX(CaptureID), 0)  FROM dbi_services_audit.dbo.database_fileLatency;

SET @CaptureID = @CaptureID + 1; 


INSERT INTO dbi_services_audit.dbo.database_fileLatency
(
	[CaptureID],
	[CaptureDate],
	[ReadLatency],
	[WriteLatency],
	[Latency],
	[AvgBPerRead],
	[AvgBPerWrite],
	[AvgBPerTransfer],
	[Drive],
	[DB],
	[database_id],
	[file_id],
	[sample_ms],
	[num_of_reads],
	[num_of_bytes_read],
	[io_stall_read_ms],
	[num_of_writes],
	[num_of_bytes_written],
	[io_stall_write_ms],
	[io_stall],
	[size_on_disk_MB],
	[file_handle],
	[physical_name]
)
SELECT 
    @CaptureID,
	GETDATE(),
	CASE 
		WHEN [num_of_reads] = 0 
			THEN 0 
		ELSE ([io_stall_read_ms]/[num_of_reads]) 
	END [ReadLatency],
	CASE 
		WHEN [io_stall_write_ms] = 0 
			THEN 0 
		ELSE ([io_stall_write_ms]/[num_of_writes]) 
	END [WriteLatency],
	CASE 
		WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
             THEN 0 
		ELSE ([io_stall]/([num_of_reads] + [num_of_writes])) 
	END [Latency],
	--avg bytes per IOP
	CASE 
		WHEN [num_of_reads] = 0 
			THEN 0 
		ELSE ([num_of_bytes_read]/[num_of_reads]) 
	END [AvgBPerRead],
	CASE 
		WHEN [io_stall_write_ms] = 0 
			THEN 0 
		ELSE ([num_of_bytes_written]/[num_of_writes]) 
	END [AvgBPerWrite],
	CASE 
		WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
			THEN 0 
		ELSE (([num_of_bytes_read] + [num_of_bytes_written])/([num_of_reads] + [num_of_writes])) 
	END [AvgBPerTransfer],
	LEFT([mf].[physical_name],2) [Drive],
	DB_NAME([vfs].[database_id]) [DB],
	[vfs].[database_id],
	[vfs].[file_id],
	[vfs].[sample_ms],
	[vfs].[num_of_reads],
	[vfs].[num_of_bytes_read],
	[vfs].[io_stall_read_ms],
	[vfs].[num_of_writes],
	[vfs].[num_of_bytes_written],
	[vfs].[io_stall_write_ms],
	[vfs].[io_stall],
	[vfs].[size_on_disk_bytes]/1024/1024. [size_on_disk_MB],
	[vfs].[file_handle],
	[mf].[physical_name]
FROM [sys].[dm_io_virtual_file_stats](NULL,NULL) AS vfs
JOIN [sys].[master_files] [mf] 
    ON [vfs].[database_id] = [mf].[database_id] 
    AND [vfs].[file_id] = [mf].[file_id]
ORDER BY [Latency] DESC;