
--	----
--	Backup sur le NAS
--	Nom fichier bak : INSTANCE_BDD_YYYYMMDD_HHMM.bak
--	----


:SETVAR InstanceName		instanceName
:SETVAR DatabaseName		dbName


:CONNECT $(InstanceName)

declare @backupString varchar(600)
declare @laDate varchar(15) = CONCAT(convert(varchar, getdate(), 112), '_', RIGHT(CONCAT('0',datepart(hour, getdate())), 2), RIGHT(CONCAT('0',datepart(minute, getdate())), 2))
declare @Inst varchar(50) = REPLACE(REPLACE(@@SERVERNAME, '-', ''), '\', '')

select @backupString = 
'BACKUP DATABASE [$(DatabaseName)] 
TO DISK = ''\\...\Backups\SQL\'+@Inst+'_$(DatabaseName)_'+@laDate+'.bak'' 
WITH COPY_ONLY, INIT, COMPRESSION, CHECKSUM, STATS=10'

print @backupString
exec(@backupString)
