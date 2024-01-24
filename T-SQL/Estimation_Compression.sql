--COLLECT INDEX DATA
DROP TABLE IF EXISTS index_estimates_dbi_snaudet;
DROP TABLE IF EXISTS page_compression_estimates_dbi_snaudet;

select db_name() AS [database_name]
	, SCHEMA_NAME(o.schema_id) AS [schema_name]
	, o.[name] AS table_name
	, i.[name] AS index_name
	, i.index_id
	, i.type_desc
	, ps.row_count
	, ps.used_page_count*8/1024 AS SizeUsedMB
	, ps.reserved_page_count*8/1024 AS SizeReservedMB
	, p.data_compression_desc
	--, ius.user_scans
	INTO index_estimates_dbi_snaudet
from sys.objects AS o
	join sys.indexes AS i
		on o.object_id = i.object_id
	join sys.partitions AS p
		on p.index_id = i.index_id
		and p.object_id = o.object_id
	join sys.dm_db_partition_stats AS ps
		on ps.partition_id = p.partition_id
	--join sys.dm_db_index_usage_stats AS ius
	--	on ius.index_id = i.index_id
	--	and ius.object_id = i.object_id
where o.schema_id <> 4
  and ps.used_page_count*8/1024 > 2000 /* 2 GB or more */
order by ps.row_count desc
GO


--PREPARE ROW AND PAGE COMPRESSION
IF OBJECT_ID('page_compression_estimates_dbi_snaudet') IS NOT NULL
	DROP TABLE page_compression_estimates_dbi_snaudet;
GO

CREATE TABLE page_compression_estimates_dbi_snaudet (
	[object_name] SYSNAME NOT NULL
	,[schema_name] SYSNAME NOT NULL
	,index_id INT NOT NULL
	,partition_number INT NOT NULL
	,[size_with_current_compression_setting(KB)] BIGINT NOT NULL
	,[size_with_requested_compression_setting(KB)] BIGINT NOT NULL
	,[sample_size_with_current_compression_setting(KB)] BIGINT NOT NULL
	,[sample_size_with_requested_compression_setting(KB)] BIGINT NOT NULL
	);
GO

--DYNAMICALLY GENERATE OUTCOME
DECLARE @script_template NVARCHAR(max) = 'insert page_compression_estimates_dbi_snaudet exec sp_estimate_data_compression_savings ''##schema_name##'',''##table_name##'',NULL,NULL,''PAGE''';
DECLARE @executable_script NVARCHAR(max);
DECLARE @schema SYSNAME,@table SYSNAME;

DECLARE cur CURSOR FAST_FORWARD
FOR
SELECT [schema_name],[table_name]
FROM index_estimates_dbi_snaudet
GROUP BY [schema_name],[table_name];

OPEN cur;

FETCH NEXT
FROM cur
INTO @schema,@table;

WHILE (@@FETCH_STATUS = 0)
BEGIN
	SET @executable_script = REPLACE(REPLACE(@script_template, '##schema_name##', @schema), '##table_name##', @table);

	PRINT @executable_script;
	EXEC (@executable_script);

	FETCH NEXT
	FROM cur
	INTO @schema,@table;
END

CLOSE cur;
DEALLOCATE cur;

--SHOW RESULTS
SELECT
	CAST(getdate() AS DATE) collectionDate
	, @@servername AS InstanceName
	, i.[database_name]
	,'[' + i.schema_name + '].[' + i.table_name + ']' AS table_name
	,CASE 
		WHEN i.index_id > 0
			THEN '[' + idx.NAME + ']'
		ELSE NULL
		END AS index_name
	, i.type_desc
	, i.row_count
	, i.SizeUsedMB
	--	----
	, CAST([size_with_requested_compression_setting(KB)]/1024. AS INT) AS [Estimated_Compressed_Size_MB]
	--, [size_with_current_compression_setting(KB)]/1024. AS [size_with_current_compression_MB]
	, CAST(i.SizeUsedMB - [size_with_requested_compression_setting(KB)]/1024. AS INT) AS Estimated_Saving_MB
	, CAST(100 - p.[sample_size_with_requested_compression_setting(KB)] * 100.0 / p.[sample_size_with_current_compression_setting(KB)] AS DECIMAL(4,2))
		AS Compression_Saving_Pct
	--, p.[sample_size_with_requested_compression_setting(KB)] * 100.0 / p.[sample_size_with_current_compression_setting(KB)]
	,CASE 
	WHEN index_name IS NULL
		THEN CONCAT('ALTER TABLE [', i.schema_name, '].[', table_name, '] REBUILD WITH ( DATA_COMPRESSION = PAGE)')
		ELSE CONCAT('ALTER INDEX [', index_name, '] ON  [', i.schema_name, '].[', table_name, '] REBUILD WITH ( DATA_COMPRESSION = PAGE)')
	END AS [command]
FROM index_estimates_dbi_snaudet i
INNER JOIN page_compression_estimates_dbi_snaudet p ON i.schema_name = p.schema_name
	AND i.table_name = p.object_name
	AND i.index_id = p.index_id
INNER JOIN sys.indexes idx ON i.index_id = idx.index_id
	AND object_name(idx.object_id) = i.table_name
	AND idx.type_desc <> 'CLUSTERED COLUMNSTORE'
/* Estimated saving >5% and >2GB */
WHERE [size_with_requested_compression_setting(KB)]>102400
  and CAST(100 - p.[sample_size_with_requested_compression_setting(KB)] * 100.0 / p.[sample_size_with_current_compression_setting(KB)] AS DECIMAL(4,2)) > 5
  and CAST(i.SizeUsedMB - [size_with_requested_compression_setting(KB)]/1024. AS INT) > 2000
ORDER BY CAST(i.SizeUsedMB - [size_with_requested_compression_setting(KB)]/1024. AS INT) DESC

--CLEAN UP
DROP TABLE IF EXISTS index_estimates_dbi_snaudet;
DROP TABLE IF EXISTS page_compression_estimates_dbi_snaudet;
