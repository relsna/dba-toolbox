
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

--	----
--	BACKUP PROD
--	----
--					todo

--!! PowerShell ...

--	----
--	RESTORE TO TEST/DEV
--	----
--					todo

--	----
--	ADD DB TO AG
--	----
--	
:CONNECT $(PrimaryRep)

DECLARE @PrimaryBackupPath NVARCHAR(4000)

--	Backup to NAS instead of Local backup
set @PrimaryBackupPath = '\\...\IT\Backups\SQL'

--	----
--	FULL BACKUP
--	----
declare @backupString varchar(600)

select @backupString = 
'BACKUP DATABASE [$(DatabaseName)] 
TO DISK = '''+@PrimaryBackupPath+'\$(DatabaseName)_AGsync.bak'' WITH INIT, COMPRESSION'

print @backupString
exec(@backupString)

--	----
--	LOG BACKUP
--	----
select @backupString = 
'BACKUP LOG [$(DatabaseName)] 
TO DISK = '''+@PrimaryBackupPath+'\$(DatabaseName)_AGsync.trn'' WITH INIT, COMPRESSION'

print @backupString
exec(@backupString)

go
--	add to AG
use master
go
alter availability group [$(AvailabilityGroup)] add database [$(DatabaseName)];
go
use [$(DatabaseName)]
go
exec dbo.sp_changedbowner @loginame = N'sa', @map = false
go

--	
:CONNECT $(SecondaryRep)

DECLARE @PrimaryBackupPath NVARCHAR(4000) 
--	Backup to NAS instead of Local backup
set @PrimaryBackupPath = '\\...\IT\Backups\SQL'

--	----
--	RESTORE FULL
--	----
declare @backupString varchar(600)

select @backupString = 
'EXECUTE AS login=''sa''
RESTORE DATABASE [$(DatabaseName)] 
FROM DISK = '''+@PrimaryBackupPath+'\$(DatabaseName)_AGsync.bak'' WITH NORECOVERY
REVERT'

print @backupString
exec(@backupString)

--	----
--	RESTORE LOG
--	----

select @backupString = 
'EXECUTE AS login=''sa''
RESTORE LOG [$(DatabaseName)] 
FROM DISK = '''+@PrimaryBackupPath+'\$(DatabaseName)_AGsync.trn'' WITH NORECOVERY
REVERT'

print @backupString
exec(@backupString)

go
--	add to AG
use master
go
ALTER DATABASE [$(DatabaseName)] SET HADR AVAILABILITY GROUP = [$(AvailabilityGroup)];
go

