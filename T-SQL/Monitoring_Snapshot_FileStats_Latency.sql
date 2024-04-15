IF OBJECT_ID(N'tempdb..#Snapshot') IS NOT NULL
	DROP TABLE #Snapshot;
GO

CREATE TABLE #Snapshot
(
	database_id SMALLINT NOT NULL,
	file_id SMALLINT NOT NULL,
	num_of_reads BIGINT NOT NULL,
	num_of_bytes_read BIGINT NOT NULL,
	io_stall_read_ms BIGINT NOT NULL,
	num_of_writes BIGINT NOT NULL,
	num_of_bytes_written BIGINT NOT NULL,
	io_stall_write_ms BIGINT NOT NULL
);

INSERT INTO #Snapshot(database_id,file_id,num_of_reads,num_of_bytes_read
	,io_stall_read_ms,num_of_writes,num_of_bytes_written,io_stall_write_ms)
	SELECT database_id,file_id,num_of_reads,num_of_bytes_read
		,io_stall_read_ms,num_of_writes,num_of_bytes_written,io_stall_write_ms
	FROM sys.dm_io_virtual_file_stats(NULL,NULL)
OPTION (MAXDOP 1, RECOMPILE);

-- Set test interval (1 minute). Use larger intervals as needed
WAITFOR DELAY '00:01:00.000';

;WITH Stats(db_id, file_id, Reads, ReadBytes, Writes
	,WrittenBytes, ReadStall, WriteStall)
as
(
	SELECT
		s.database_id, s.file_id
		,fs.num_of_reads - s.num_of_reads
		,fs.num_of_bytes_read - s.num_of_bytes_read
		,fs.num_of_writes - s.num_of_writes
		,fs.num_of_bytes_written - s.num_of_bytes_written
		,fs.io_stall_read_ms - s.io_stall_read_ms
		,fs.io_stall_write_ms - s.io_stall_write_ms
	FROM
		#Snapshot s JOIN  sys.dm_io_virtual_file_stats(NULL, NULL) fs ON
			s.database_id = fs.database_id and s.file_id = fs.file_id
)
SELECT
	s.db_id AS [DB ID], d.name AS [Database]
	,mf.name AS [File Name], mf.physical_name AS [File Path]
	,mf.type_desc AS [Type], s.Reads 
	,CONVERT(DECIMAL(12,3), s.ReadBytes / 1048576.) AS [Read MB]
	,CONVERT(DECIMAL(12,3), s.WrittenBytes / 1048576.) AS [Written MB]
	,s.Writes, s.Reads + s.Writes AS [IO Count]
	,CONVERT(DECIMAL(5,2),100.0 * s.ReadBytes / 
			(s.ReadBytes + s.WrittenBytes)) AS [Read %]
	,CONVERT(DECIMAL(5,2),100.0 * s.WrittenBytes / 
			(s.ReadBytes + s.WrittenBytes)) AS [Write %]
	,s.ReadStall AS [Read Stall]
	,s.WriteStall AS [Write Stall]
	,CASE WHEN s.Reads = 0 
		THEN 0.000
		ELSE CONVERT(DECIMAL(12,3),1.0 * s.ReadStall / s.Reads) 
	END AS [Avg Read Stall] 
	,CASE WHEN s.Writes = 0 
		THEN 0.000
		ELSE CONVERT(DECIMAL(12,3),1.0 * s.WriteStall / s.Writes) 
	END AS [Avg Write Stall] 
FROM
	Stats s JOIN  sys.master_files mf WITH (NOLOCK) ON
		s.db_id = mf.database_id and
		s.file_id = mf.file_id
	JOIN  sys.databases d WITH (NOLOCK) ON 
		s.db_id = d.database_id  
WHERE -- Only display files with more than 20MB throughput. Increase with larger sample times
	(s.ReadBytes + s.WrittenBytes) > 20 * 1048576
ORDER BY
	s.db_id, s.file_id
OPTION (MAXDOP 1, RECOMPILE);