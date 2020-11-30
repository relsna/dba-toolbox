
--	----
--	Environnement Cible 
--	TEST / DEV 	
--	----

:SETVAR PrimaryRep			PrimaryInstance
:SETVAR SecondaryRep		SecondaryInstance
:SETVAR DatabaseName		DbName
:SETVAR AvailabilityGroup	listenerName



:CONNECT $(SecondaryRep)

use master
go
alter database [$(DatabaseName)] set hadr off;
go
drop database [$(DatabaseName)]
go


:CONNECT $(PrimaryRep)

--	backup avant refresh
use master
go

declare @laDate char(8)
select @laDate = convert(varchar, getdate(), 112)

declare @backupString varchar(600)

set @backupString = 
'backup database [$(DatabaseName)]
to disk = ''\\...\IT\Backups\SQL\$(DatabaseName)_AvantRefresh_'+@laDate+'.bak''
with copy_only, compression, checksum, stats=5, init'

exec(@backupString)
go

--	remove from AG
use master
go
alter availability group [$(AvailabilityGroup)] remove database [$(DatabaseName)];
go
--use master
--go
--drop database [$(DatabaseName)]