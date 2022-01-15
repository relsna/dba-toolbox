

go
DROP PROC IF EXISTS qsh.GetAverageSalary;
DROP TABLE IF EXISTS qsh.Employees;
DROP SCHEMA IF EXISTS qsh;
go

create schema qsh;
go
create table qsh.Employees (
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
insert into qsh.Employees(ID, Number, Name, Salary, Country)
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
insert into qsh.Employees(ID, Number, Name, Salary, Country)
	select 
		65536 + Num, 
		convert(varchar(5),65536 + Num), 
		'France Employee: ' + convert(varchar(5),Num), 
		40000,
		'France'
	from Nums;

create nonclustered index IDX_Employees_Country
on qsh.Employees(Country);
go









--	----
--	Show SP and data

create proc qsh.GetAverageSalary @Country varchar(64)
as
	select Avg(Salary) as [Avg Salary]
	from qsh.Employees
	where Country = @Country;
go


select Count(*) AS nbEmployees, Country
from qsh.Employees
group by Country;










--	Vérifier l'état de Query Store
SELECT actual_state_desc
FROM sys.database_query_store_options;









--	Liste des Query Store hints
SELECT	query_hint_id
		, query_id
		, query_hint_text
		, last_query_hint_failure_reason_desc
		, source
		, source_desc
FROM sys.query_store_query_hints;













--	----
--	Activer "Include Actual Execution Plan"

-- Situation normale
set statistics io on

exec qsh.GetAverageSalary @Country='USA';
exec qsh.GetAverageSalary @Country='France';










-- Plan regression
use DataFrogs
go
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;


set statistics io on

exec qsh.GetAverageSalary @Country='France';
exec qsh.GetAverageSalary @Country='USA';

set statistics io off
go

--	plan optimizé pour France
--	extrèmement ineficace pour USA

--	USA =>			Clustered Index Scan
--	France =>	Nested Loop + Key lookup






SELECT query_sql_text, q.query_id
FROM sys.query_store_query_text AS qt 
	JOIN sys.query_store_query AS q 
		ON 	qt.query_text_id = q.query_text_id 
WHERE query_sql_text like N'%from qsh.Employees%' 
  and query_sql_text not like N'%query_store%'
  and OBJECT_NAME(q.object_id) IS NOT NULL;
GO




EXEC sys.sp_query_store_set_hints 
	@query_id=269
	, @query_hints  = N'OPTION(RECOMPILE)';
GO




--	Liste des Query Store hints
SELECT	query_hint_id
		, query_id
		, query_hint_text
		, last_query_hint_failure_reason_desc
		, source
		, source_desc
FROM sys.query_store_query_hints;







exec qsh.GetAverageSalary @Country='USA';
exec qsh.GetAverageSalary @Country='France';





EXEC sp_query_store_clear_hints 
	@query_id=269;
GO










--	----
--	Contourner un Query Hint existant (code applicatif)
--	----

set statistics time on


select Count(distinct Salary) 
from [dbo].[Employees_3]
where Country = 'USA'
OPTION(MAXDOP 1)

--	CPU time = 94 ms,  elapsed time = 2595 ms.



SELECT query_sql_text, q.query_id
FROM sys.query_store_query_text AS qt 
	JOIN sys.query_store_query AS q 
		ON 	qt.query_text_id = q.query_text_id 
WHERE query_sql_text like N'%OPTION(MAXDOP 1)%' 
  and query_sql_text not like N'%query_store%';




EXEC sys.sp_query_store_set_hints 
	@query_id=184
	, @query_hints = N'OPTION(MAXDOP 0)';
go



--	Liste des Query Store hints
SELECT	query_hint_id
		, query_id
		, query_hint_text
		, last_query_hint_failure_reason_desc
		, source
		, source_desc
FROM sys.query_store_query_hints;




select Count(distinct Salary) 
from [dbo].[Employees_3]
where Country = 'USA'
OPTION(MAXDOP 1)

--	CPU time = 188 ms,  elapsed time = 1756 ms.


EXEC sp_query_store_clear_hints 
	@query_id=184;
GO