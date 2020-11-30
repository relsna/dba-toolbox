
--	----
--	Environnement Cible 
--	TEST / DEV 	
--	----

:SETVAR PrimaryRep			AG-TI-SQL01\WEB
:SETVAR SecondaryRep		AG-TI-SQL02\WEB
:SETVAR DatabaseName		testSNU
:SETVAR AvailabilityGroup	l-prd-web-ag01

--	----
--	ADD DB TO AG
--	----
--	
:CONNECT $(PrimaryRep)

DECLARE @PrimaryBackupPath NVARCHAR(4000)

--	Backup to NAS instead of Local backup
set @PrimaryBackupPath = '\\gva.tld\aig\IT\Backups\SQL'



--	----
--	SET DB TO FULL
--	----

ALTER DATABASE [$(DatabaseName)] SET RECOVERY FULL

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
set @PrimaryBackupPath = '\\gva.tld\aig\IT\Backups\SQL'

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
'RESTORE LOG [$(DatabaseName)] 
FROM DISK = '''+@PrimaryBackupPath+'\$(DatabaseName)_AGsync.trn'' WITH NORECOVERY'

print @backupString
exec(@backupString)

go
--	add to AG
use master
go
ALTER DATABASE [$(DatabaseName)] SET HADR AVAILABILITY GROUP = [$(AvailabilityGroup)];
go

