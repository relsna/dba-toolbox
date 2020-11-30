--    ----
--    Before 2012
--    ----
USE [master]
GO
 
DECLARE @dbName SYSNAME = '<Database_Name, sysname, DB_Name>' --    Change DB name
DECLARE @sqlCmd VARCHAR(MAX) = ''
 
SELECT @sqlCmd = @sqlCmd + 'KILL ' + CAST(spid AS VARCHAR) + CHAR(13)
FROM master..sysprocesses 
WHERE dbid = db_id(@dbName)
 
PRINT @sqlCmd
EXEC (@sqlCmd)
GO

--    ----
--    From 2012
--    ----
USE [master]
GO
 
DECLARE @dbName SYSNAME = '<Database_Name, sysname, DB_Name>' --    Change DB name
DECLARE @sqlCmd VARCHAR(MAX) = ''
 
SELECT @sqlCmd = @sqlCmd + 'KILL ' + CAST(session_id AS VARCHAR) + CHAR(13)
FROM sys.dm_exec_sessions
WHERE DB_NAME(database_id) = @dbName
 
PRINT @sqlCmd
EXEC (@sqlCmd)
GO


