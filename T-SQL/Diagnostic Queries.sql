
--	----
--	Number of Single use Cached Plans (ad-hoc cache bloat)
--	limit : 40,009 per bucket / 160K total

SELECT objtype,
    cacheobjtype,
    AVG(usecounts) AS Avg_UseCount,
    SUM(refcounts) AS NbSingleUseCachedPlans,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS SizeInMB
FROM sys.dm_exec_cached_plans
WHERE objtype = 'Adhoc' AND usecounts = 1
GROUP BY objtype, cacheobjtype;

SELECT objtype,
    cacheobjtype,
    Count(*) AS CountPlans,
    SUM(refcounts) AS SumRefcounts,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS SizeInMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype, cacheobjtype
ORDER BY CountPlans DESC;

--	----
--	Snapshots I/O latency
--	----

USE [master]
GO
DROP TABLE IF EXISTS #dbi_snaudet_latency_snapshot;

CREATE TABLE #dbi_snaudet_latency_snapshot (
	database_id SMALLINT NOT NULL,
	file_id SMALLINT NOT NULL,
	num_of_reads BIGINT NOT NULL,
	num_of_bytes_read BIGINT NOT NULL,
	io_stall_read_ms BIGINT NOT NULL,
	num_of_writes BIGINT NOT NULL,
	num_of_bytes_written BIGINT NOT NULL,
	io_stall_write_ms BIGINT NOT NULL
);

INSERT INTO #dbi_snaudet_latency_snapshot(database_id,file_id,num_of_reads,num_of_bytes_read
	,io_stall_read_ms,num_of_writes,num_of_bytes_written,io_stall_write_ms)
	SELECT database_id,file_id,num_of_reads,num_of_bytes_read
		,io_stall_read_ms,num_of_writes,num_of_bytes_written,io_stall_write_ms
	FROM sys.dm_io_virtual_file_stats(NULL,NULL)
OPTION (MAXDOP 1, RECOMPILE);

SELECT * FROM #dbi_snaudet_latency_snapshot

-- Set test interval (1 minute). Use larger intervals as needed
WAITFOR DELAY '00:00:30.000';

;WITH CTEStats(db_id, file_id, Reads, ReadBytes, Writes
	,WrittenBytes, ReadStall, WriteStall) AS (
	SELECT
		s.database_id, s.file_id
		,fs.num_of_reads - s.num_of_reads
		,fs.num_of_bytes_read - s.num_of_bytes_read
		,fs.num_of_writes - s.num_of_writes
		,fs.num_of_bytes_written - s.num_of_bytes_written
		,fs.io_stall_read_ms - s.io_stall_read_ms
		,fs.io_stall_write_ms - s.io_stall_write_ms
	FROM #dbi_snaudet_latency_snapshot AS s 
        JOIN  sys.dm_io_virtual_file_stats(NULL, NULL) AS fs 
            ON s.database_id = fs.database_id 
            and s.file_id = fs.file_id
)
SELECT
	s.db_id AS [DB ID], d.name AS [Database]
	,mf.name AS [File Name], mf.physical_name AS [File Path]
	,mf.type_desc AS [Type], s.Reads 
	,CONVERT(DECIMAL(12,3), s.ReadBytes / 1048576.) AS [Read MB]
	,CONVERT(DECIMAL(12,3), s.WrittenBytes / 1048576.) AS [Written MB]
	,s.Writes, s.Reads + s.Writes AS [IO Count]
	,CONVERT(DECIMAL(5,2),100.0 * s.ReadBytes / (s.ReadBytes + s.WrittenBytes)) AS [Read %]
	,CONVERT(DECIMAL(5,2),100.0 * s.WrittenBytes / (s.ReadBytes + s.WrittenBytes)) AS [Write %]
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
FROM CTEStats AS s 
    JOIN sys.master_files AS mf
        ON s.db_id = mf.database_id
        and s.file_id = mf.file_id
	JOIN sys.databases AS d 
        ON s.db_id = d.database_id  
WHERE (s.ReadBytes + s.WrittenBytes) > 0
/*
-- Only display files with more than 20MB throughput. Increase with larger sample times
WHERE (s.ReadBytes + s.WrittenBytes) > 20 * 1048576
*/
ORDER BY s.db_id, s.file_id
OPTION (MAXDOP 1, RECOMPILE);






--	----
--	I/O related performance counter
--	----
IF OBJECT_ID(N'tempdb..#PerfCntrs') IS NOT NULL
	DROP TABLE #PerfCntrs;
GO

CREATE TABLE #PerfCntrs
(
	collected_time DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
	object_name SYSNAME NOT NULL,
	counter_name SYSNAME NOT NULL,
	instance_name SYSNAME NOT NULL,
	cntr_value BIGINT NOT NULL,
	PRIMARY KEY (object_name, counter_name, instance_name)
);

;WITH Counters(obj_name, ctr_name)
AS
(
	SELECT C.obj_name, C.ctr_name
	FROM 
	(
		VALUES
			('SQLServer:Buffer Manager','Checkpoint pages/sec')
			,('SQLServer:Buffer Manager','Background writer pages/sec')
			,('SQLServer:Buffer Manager','Lazy writes/sec')
			,('SQLServer:Buffer Manager','Page reads/sec')
			,('SQLServer:Buffer Manager','Page writes/sec')
			,('SQLServer:Buffer Manager','Readahead pages/sec')
			,('SQLServer:Databases','Log Flushes/sec') -- For all DBs
			,('SQLServer:Databases','Log Bytes Flushed/sec') -- For all DBs
			,('SQLServer:Databases','Log Flush Write Time (ms)') -- For all DBs
			,('SQLServer:Databases','Transactions/sec') -- For all DBs
			,('SQLServer:SQL Statistics','Batch Requests/sec') 
	) C(obj_name, ctr_name)
)
INSERT INTO #PerfCntrs(object_name,counter_name,instance_name,cntr_value)
	SELECT 
		pc.object_name, pc.counter_name, pc.instance_name, pc.cntr_value
	FROM 
		sys.dm_os_performance_counters pc WITH (NOLOCK) JOIN Counters c ON
			pc.counter_name = c.ctr_name AND pc.object_name = c.obj_name;

WAITFOR DELAY '00:00:01.000';

;WITH Counters(obj_name, ctr_name)
AS
(
	SELECT C.obj_name, C.ctr_name
	FROM 
	(
		VALUES
			('SQLServer:Buffer Manager','Checkpoint pages/sec')
			,('SQLServer:Buffer Manager','Background writer pages/sec')
			,('SQLServer:Buffer Manager','Lazy writes/sec')
			,('SQLServer:Buffer Manager','Page reads/sec')
			,('SQLServer:Buffer Manager','Page writes/sec')
			,('SQLServer:Buffer Manager','Readahead pages/sec')
			,('SQLServer:Databases','Log Flushes/sec') -- For all DBs
			,('SQLServer:Databases','Log Bytes Flushed/sec') -- For all DBs
			,('SQLServer:Databases','Log Flush Write Time (ms)') -- For all DBs
			,('SQLServer:Databases','Transactions/sec') -- For all DBs
			,('SQLServer:SQL Statistics','Batch Requests/sec') 
	) C(obj_name, ctr_name)
)
SELECT 
	pc.object_name, pc.counter_name, pc.instance_name
	,CASE pc.cntr_type
		WHEN 272696576 THEN 
			(pc.cntr_value - h.cntr_value) * 1000 / 
				DATEDIFF(MILLISECOND,h.collected_time,SYSDATETIME())
		WHEN 65792 THEN 
			pc.cntr_value
		ELSE NULL
	END as cntr_value
FROM 
	sys.dm_os_performance_counters pc WITH (NOLOCK) JOIN Counters c ON
		pc.counter_name = c.ctr_name AND pc.object_name = c.obj_name
	JOIN #PerfCntrs h ON
		pc.object_name = h.object_name AND
		pc.counter_name = h.counter_name AND
		pc.instance_name = h.instance_name
ORDER BY
	pc.object_name, pc.counter_name, pc.instance_name
OPTION (RECOMPILE);	


--	----
--	PAGE Compression success rate
--	----
SELECT DISTINCT object_name (i.object_id) AS [Table],
    i.name AS [Index],
    p.partition_number AS [Partition],
    page_compression_attempt_count,
    page_compression_success_count,
    page_compression_success_count * 1.0 / page_compression_attempt_count AS [SuccessRate]
FROM sys.indexes AS i
    INNER JOIN sys.partitions AS p
        ON p.object_id = i.object_id
    CROSS APPLY sys.dm_db_index_operational_stats(db_id(), i.object_id, i.index_id, p.partition_number) AS ios
WHERE p.data_compression = 2
  AND page_compression_attempt_count > 0
ORDER BY [SuccessRate];





