

use AdventureWorks2019
go

CREATE TABLE IndexToMaintain (
	id int identity primary key
	, DatabaseName varchar(100) not null
	, TableName varchar(100) not null
	, IndexName varchar(100) not null
	, RebuildStatus bit default 0
);
go

insert into IndexToMaintain(DatabaseName, TableName, IndexName)
	values ('AdventureWorks2019', 'bigTransactionHistory', 'IX_ProductId_TransactionDate');
go


select * 
from IndexToMaintain;
go



use AdventureWorks2019
go
update IndexToMaintain set RebuildStatus = 0;


update IndexToMaintain set RebuildStatus = 1;



