--    ----
--    Generate ALTER DATABASE commands to set Data and Log File Size according to standards
--    Script working on all user databases
--    ----
 
SET NOCOUNT ON
 
DECLARE @DataFileSize varchar(20) =       128    --    MB
DECLARE @LogFileSize varchar(20) =        128    --    MB
 
IF EXISTS (SELECT name FROM tempdb.dbo.sysobjects WHERE name LIKE N'%#DBList%')
BEGIN
	DROP TABLE #DBList;
END
CREATE TABLE #DBList (
	DatabaseName VARCHAR(400),
	LogicalName VARCHAR(450),
	Type_Desc varchar(50)
);
 
INSERT INTO #DBList
	SELECT 
		db.name AS DatabaseName
		, mf.name AS LogicalFileName
		, mf.type_desc
		--, mf.size*8/1024
	FROM sys.master_files AS mf
		JOIN sys.databases AS db
			ON mf.database_id = db.database_id
	WHERE db.state_desc = 'ONLINE'
	  AND db.user_access_desc = 'MULTI_USER'
	  AND mf.database_id > 4
	  AND (
		(mf.type_desc = 'ROWS' AND mf.size*8/1024 < @DataFileSize)
		OR (mf.type_desc = 'LOG' AND mf.size*8/1024 < @LogFileSize)
	  )
	ORDER BY db.name;
 
DECLARE @db_name VARCHAR (400)
DECLARE @LogicalName VARCHAR(450)
DECLARE @FileSizeKB INT
DECLARE @Type_Desc varchar(50)
 
DECLARE @Size varchar(20)
WHILE (SELECT COUNT(*) FROM #DBList) > 0
	BEGIN
		SELECT TOP 1  @db_name = DatabaseName, @LogicalName = LogicalName, @Type_Desc = type_desc FROM #DBList
		IF (@Type_Desc = 'ROWS')
			BEGIN
				SET @Size = CAST(@DataFileSize AS varchar) + 'MB'
			END
		ELSE
			BEGIN
				SET @Size = CAST(@LogFileSize AS varchar) + 'MB'
			END
 
		PRINT 'ALTER DATABASE [' + @db_name + '] MODIFY FILE ( NAME = N''' + @LogicalName + ''', SIZE = '+@Size+' );'
		DELETE FROM #DBList WHERE @LogicalName = LogicalName
	END
 
IF EXISTS (SELECT name FROM tempdb.dbo.sysobjects WHERE name LIKE N'%#DBList%')
BEGIN
	DROP TABLE #DBList;
END
GO


--    ----
--    Generate ALTER DATABASE commands to set Data and Log FileGrowth according to standards
--    Script working on all user databases
--    ----
 
SET NOCOUNT ON
 
DECLARE @DataFileGrowth varchar(20) =   128    --    MB
DECLARE @LogFileGrowth varchar(20) =    128    --    MB
 
IF EXISTS (SELECT name FROM tempdb.dbo.sysobjects WHERE name LIKE N'%#DBList%')
BEGIN
	DROP TABLE #DBList;
END
CREATE TABLE #DBList (
	DatabaseName VARCHAR(400),
	LogicalName VARCHAR(450),
	FileGrowthKB INT,
	Type_Desc varchar(50)
);
 
INSERT INTO #DBList
	SELECT 
		db.name AS DatabaseName
		, mf.name AS LogicalFileName
		, mf.growth*8 AS FileGrowthKB
		, mf.type_desc
	FROM sys.master_files AS mf
		JOIN sys.databases AS db
			ON mf.database_id = db.database_id
	WHERE db.state_desc = 'ONLINE'
	  AND db.user_access_desc = 'MULTI_USER'
	  AND mf.database_id > 4
	  AND (mf.is_percent_growth = 1 
		OR (
			(mf.type_desc = 'ROWS' AND mf.growth*8/1024 < @DataFileGrowth)
			OR (mf.type_desc = 'LOG' AND mf.growth*8/1024 < @LogFileGrowth)
		)
	  )
	ORDER BY db.name;
 
DECLARE @db_name VARCHAR (400)
DECLARE @LogicalName VARCHAR(450)
DECLARE @FileSizeKB INT
DECLARE @Type_Desc varchar(50)
 
DECLARE @FileGrowth varchar(20)
WHILE (SELECT COUNT(*) FROM #DBList) > 0
	BEGIN
		SELECT TOP 1  @db_name = DatabaseName, @LogicalName = LogicalName, @Type_Desc = type_desc FROM #DBList
		IF (@Type_Desc = 'ROWS')
			BEGIN
				SET @FileGrowth = CAST(@DataFileGrowth AS varchar) + 'MB'
			END
		ELSE
			BEGIN
				SET @FileGrowth = CAST(@LogFileGrowth AS varchar) + 'MB'
			END
 
		PRINT 'ALTER DATABASE [' + @db_name + '] MODIFY FILE ( NAME = N''' + @LogicalName + ''', FILEGROWTH = '+@FileGrowth+' );'
		DELETE FROM #DBList WHERE @LogicalName = LogicalName
	END
 
IF EXISTS (SELECT name FROM tempdb.dbo.sysobjects WHERE name LIKE N'%#DBList%')
BEGIN
	DROP TABLE #DBList;
END