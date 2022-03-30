
use master
go
IF OBJECT_ID('tempdb..#tempFilesInfo_sna') IS NOT NULL DROP TABLE #tempFilesInfo_sna

CREATE TABLE #tempFilesInfo_sna (
	[DatabaseName] [nvarchar](128) NULL,
	[file_id] [int] NOT NULL,
	[logical_name] [nvarchar](260) NOT NULL,
	[physical_name] [nvarchar](260) NOT NULL,
	[type_desc] [nvarchar](60) NULL,
	[state_desc] [nvarchar](60) NULL,
	[is_percent_growth] [bit] NOT NULL,
	[growth] [int] NOT NULL,
	[GrowthMB] [bigint] NULL,
	[TotalSizeMB] [bigint] NULL,
	[max_size] [bigint] NOT NULL,
	[FilegroupName] [nvarchar](128) NULL,
	[FilegroupType] [nvarchar](60) NULL,
	[f_spaceId] [int] NOT NULL,
	[fg_spaceId] [int] NULL
)
GO

DECLARE @cmd nvarchar(max)
DECLARE c1 cursor for
	select '
	USE ['+name+'];
	insert into #tempFilesInfo_sna
	SELECT '''+name+''' AS DatabaseName
		, f.[file_id]
		, f.[name]
		, f.physical_name
		, f.[type_desc]
		, state_desc
		, is_percent_growth
		, growth
		, CONVERT(bigint, growth/128.0) AS [GrowthMB]
		, CONVERT(bigint, size/128.0) AS [TotalSizeMB]
		, max_size
		, CASE WHEN f.data_space_id = 0 THEN ''Log'' ELSE fg.[name] END AS FilegroupName
		, CASE WHEN f.data_space_id = 0 THEN ''Log'' ELSE fg.[type_desc] END AS FilegroupType
		, f.data_space_id
		, fg.data_space_id
	FROM sys.database_files AS f
		left join ['+name+'].sys.filegroups AS fg
			on f.data_space_id = fg.data_space_id
	'
	from master..sysdatabases
	where DATABASEPROPERTYEX(name,'Updateability')='READ_WRITE'
	  and DATABASEPROPERTYEX(name,'Status')='ONLINE'
	  and dbid>4
open c1
fetch c1 into @cmd
while @@FETCH_STATUS=0
begin
	begin try
		exec sp_executesql @cmd
	end try
begin catch
PRINT ERROR_MESSAGE()
end catch
	fetch c1 into @cmd
end
close c1
deallocate c1

select *
	, 'ALTER DATABASE ['+DatabaseName+'] MODIFY FILE ( NAME = N'''+logical_name+''', SIZE = 65536KB , FILEGROWTH = 65536KB )'
	, '- Database file autogrowth settings on database '+DatabaseName+' - instance '+@@SERVERNAME+''
from #tempFilesInfo_sna 
where GrowthMB % 2 <> 0 or is_percent_growth = 1

IF OBJECT_ID('tempdb..#tempFilesInfo_sna') IS NOT NULL DROP TABLE #tempFilesInfo_sna




