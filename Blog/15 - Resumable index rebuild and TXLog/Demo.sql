--	----
--	Rebuild index
--	----
ALTER INDEX IX_ProductId_TransactionDate ON bigTransactionHistory REBUILD
	WITH (ONLINE=ON);
go

--	----
--	Check Log file size and usage
--	----
USE [AdventureWorks2019]
go
select total_log_size_in_bytes/1024/1024 AS TotalLogSizeMB
	, (total_log_size_in_bytes - used_log_space_in_bytes)/1024/1024 AS FreeSpaceMB
    , used_log_space_in_bytes/1024./1024  as UsedLogSpaceMB,
    used_log_space_in_percent
from sys.dm_db_log_space_usage;
go
/*
TotalLogSizeMB	FreeSpaceMB	UsedLogSpaceMB		used_log_space_in_percent
3583			15			3568.08593750000	99,55618
*/

--	----
--	Reset Log file to 2GB
--	----
USE [AdventureWorks2019]
go
backup log [AdventureWorks2019] to disk = 'NUL'
go
GO
DBCC SHRINKFILE (N'AdventureWorks2017_log' , 2048)
GO
--	----
--	Check Log file size and usage
--	----
select *
from IndexToMaintain;

--	----
--	Run Rebuild index Job
--	----

--	----
--	Check Job history + backups + Check Log file size and usage
--	----
USE [AdventureWorks2019]
go
select total_log_size_in_bytes/1024/1024 AS TotalLogSizeMB
	, (total_log_size_in_bytes - used_log_space_in_bytes)/1024/1024 AS FreeSpaceMB
    , used_log_space_in_bytes/1024./1024  as UsedLogSpaceMB,
    used_log_space_in_percent
from sys.dm_db_log_space_usage;
go

