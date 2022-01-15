
--	----
--	Demo set up
--	----
USE [master]
go
RESTORE DATABASE [AdventureWorks] 
FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Backup\AdventureWorks2019.bak' 
WITH  FILE = 1
,  MOVE N'AdventureWorks2017' TO N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\AdventureWorks2019.mdf'
,  MOVE N'AdventureWorks2017_log' TO N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\AdventureWorks2019_log.ldf'
,  REPLACE, STATS = 5
go



use [AdventureWorks]
go

DROP PROC IF EXISTS dbo.GetAverageSalary;
DROP TABLE IF EXISTS dbo.Employees;
go

create table dbo.Employees (
	ID int not null,
	Number varchar(32) not null,
	Name varchar(100) not null,
	Salary money not null,
	Country varchar(64) not null,
	constraint PK_Employees	primary key clustered(ID)
);

;with N1(C) as (select 0 union all select 0) -- 2 rows
,N2(C) as (select 0 from N1 as T1 cross join N1 as T2) -- 4 rows
,N3(C) as (select 0 from N2 as T1 cross join N2 as T2) -- 16 rows
,N4(C) as (select 0 from N3 as T1 cross join N3 as T2) -- 256 rows
,N5(C) as (select 0 from N4 as T1 cross join N4 as T2 ) -- 65,536 rows
,Nums(Num) as (select row_number() over (order by (select null)) from N5)
insert into dbo.Employees(ID, Number, Name, Salary, Country)
	select 
		Num, 
		convert(varchar(5),Num), 
		'USA Employee: ' + convert(varchar(5),Num), 
		40000,
		'USA'
	from Nums;

;with N1(C) as (select 0 union all select 0) -- 2 rows
,N2(C) as (select 0 from N1 as T1 cross join N1 as T2) -- 4 rows
,N3(C) as (select 0 from N2 as T1 cross join N2 as T2) -- 16 rows
,Nums(Num) as (select row_number() over (order by (select null)) from N3)
insert into dbo.Employees(ID, Number, Name, Salary, Country)
	select 
		65536 + Num, 
		convert(varchar(5),65536 + Num), 
		'France Employee: ' + convert(varchar(5),Num), 
		40000,
		'France'
	from Nums;

create nonclustered index IDX_Employees_Country
on dbo.Employees(Country);
go




















--	----
--	Show SP and data

create proc dbo.GetAverageSalary @Country varchar(64)
as
	select Avg(Salary) as [Avg Salary]
	from dbo.Employees
	where Country = @Country;
go


select Count(*) AS nbEmployees, Country
from dbo.Employees
group by Country;





















--	----
--	Clear Query Store

ALTER DATABASE AdventureWorks SET QUERY_STORE = ON;
go
ALTER DATABASE [AdventureWorks] 
SET QUERY_STORE (
	OPERATION_MODE = READ_WRITE
	, QUERY_CAPTURE_MODE = ALL
	, INTERVAL_LENGTH_MINUTES = 1
)
go
ALTER DATABASE AdventureWorks SET QUERY_STORE CLEAR;
go
ALTER DATABASE AdventureWorks SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = OFF)
go
use AdventureWorks
go
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
go














--	----
--	Activer "Include Actual Execution Plan"

-- Situation normale
set statistics io on

exec dbo.GetAverageSalary @Country='USA';
exec dbo.GetAverageSalary @Country='France';










-- Plan regression
use AdventureWorks
go
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;


set statistics io on

exec dbo.GetAverageSalary @Country='France';
exec dbo.GetAverageSalary @Country='USA';

set statistics io off
go

--	plan optimizé pour France
--	extrèmement ineficace pour USA

--	USA =>			Clustered Index Scan
--	France =>	Nested Loop + Key lookup




--	----
--	Query Store
--	Report: Queries With High Variation
--	Logical Reads & Std deviation

alter database scoped configuration clear procedure_cache
go
exec dbo.GetAverageSalary @Country='USA';
exec dbo.GetAverageSalary @Country='France';
go 50
alter database scoped configuration clear procedure_cache
go
exec dbo.GetAverageSalary @Country='France';
exec dbo.GetAverageSalary @Country='USA';
go 50











--	Forcer un plan
exec sp_query_store_force_plan 
	@query_id = 1
	, @plan_id = 1;


--	Unforce
EXEC sp_query_store_unforce_plan 
	@query_id = 1
	, @plan_id = 1;










select * from sys.query_store_query_text
select * from sys.query_context_settings
select * from sys.query_store_query
select * from sys.query_store_plan
select * from sys.query_store_runtime_stats_interval
select * from sys.query_store_runtime_stats
select * from sys.query_store_wait_stats



