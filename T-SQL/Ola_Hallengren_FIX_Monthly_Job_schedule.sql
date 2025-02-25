USE msdb;
GO

DECLARE @ScheduleID INT
DECLARE @ScheduleName NVARCHAR(128) = 'Monthly'

-- Vérifier si le schedule existe déjà
SELECT @ScheduleID = schedule_id
FROM msdb.dbo.sysschedules
WHERE name = @ScheduleName

PRINT @ScheduleID
-- Si le schedule n'existe pas, le créer
IF @ScheduleID IS NULL
BEGIN
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = @ScheduleName,
        @freq_type = 16,            -- Exécution mensuelle
        @freq_interval = 1,         -- Chaque 1er jour du mois
		@freq_recurrence_factor = 1, -- Chaque mois
        @freq_subday_type = 1,      -- Heure exacte
        @active_start_time = 010000 -- 01:00:00
    PRINT 'Schedule créé : ' + @ScheduleName
END
ELSE
BEGIN
    PRINT 'Le schedule existe déjà : ' + @ScheduleName
END

-- Récupérer à nouveau l'ID du schedule
SELECT @ScheduleID = schedule_id
FROM msdb.dbo.sysschedules
WHERE name = @ScheduleName

-- Liste des jobs à modifier
DECLARE @JobName NVARCHAR(128)
DECLARE job_cursor CURSOR FOR
SELECT name FROM msdb.dbo.sysjobs
WHERE name IN (
    'CommandLog Cleanup',
    'Output File Cleanup',
    'sp_delete_backuphistory',
    'sp_purge_jobhistory',
    'syspolicy_purge_history'
)

OPEN job_cursor
FETCH NEXT FROM job_cursor INTO @JobName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Vérifier si le job est déjà lié au schedule
    IF NOT EXISTS (
        SELECT *
        FROM msdb.dbo.sysjobschedules js
			JOIN msdb.dbo.sysjobs j 
				ON js.job_id = j.job_id
        WHERE j.name = @JobName
    )
    BEGIN
        -- Associer le job au schedule
        EXEC msdb.dbo.sp_attach_schedule
            @job_name = @JobName,
            @schedule_name = @ScheduleName
        PRINT 'Schedule ajouté au job : ' + @JobName
    END
    ELSE
    BEGIN
        PRINT 'Le job a déjà le schedule : ' + @JobName
    END

    FETCH NEXT FROM job_cursor INTO @JobName
END

CLOSE job_cursor
DEALLOCATE job_cursor
GO
