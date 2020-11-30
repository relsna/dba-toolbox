SELECT *,
	[DirtyPageCount] * 8 / 1024 AS [DirtyPageMB],
	[CleanPageCount] * 8 / 1024 AS [CleanPageMB]
FROM
	(SELECT 
		(CASE WHEN ([database_id] = 32767)
			THEN N'Resource Database'
			ELSE DB_NAME ([database_id]) END) AS [DatabaseName], 
		SUM (CASE WHEN ([is_modified] = 1)
			THEN 1 ELSE 0 END) AS [DirtyPageCount], 
		SUM (CASE WHEN ([is_modified] = 1)
			THEN 0 ELSE 1 END) AS [CleanPageCount]
	FROM sys.dm_os_buffer_descriptors
	GROUP BY [database_id]) AS [buffers]
ORDER BY [DatabaseName]


/*
Par Table au sein d'une DB 
*/

SELECT
	OBJECT_NAME ([p].[object_id]) AS [ObjectName],
	[p].[index_id],
	[i].[name],
	[i].[type_desc],
	[au].[type_desc],
	[DirtyPageCount],
	[CleanPageCount],
	[DirtyPageCount] * 8 / 1024 AS [DirtyPageMB],
	[CleanPageCount] * 8 / 1024 AS [CleanPageMB]
FROM
	(SELECT
		[allocation_unit_id],
		SUM (CASE WHEN ([is_modified] = 1)
			THEN 1 ELSE 0 END) AS [DirtyPageCount], 
		SUM (CASE WHEN ([is_modified] = 1)
			THEN 0 ELSE 1 END) AS [CleanPageCount]
	FROM sys.dm_os_buffer_descriptors
	WHERE [database_id] = DB_ID (N'UltraAIMS')
	GROUP BY [allocation_unit_id]) AS [buffers]
INNER JOIN sys.allocation_units AS [au]
	ON [au].[allocation_unit_id] = [buffers].[allocation_unit_id]
INNER JOIN sys.partitions AS [p]
	ON [au].[container_id] = [p].[partition_id]
INNER JOIN sys.indexes AS [i]
	ON [i].[index_id] = [p].[index_id]
		AND [p].[object_id] = [i].[object_id]
WHERE [p].[object_id] > 100
ORDER BY [ObjectName], [p].[index_id];
GO

