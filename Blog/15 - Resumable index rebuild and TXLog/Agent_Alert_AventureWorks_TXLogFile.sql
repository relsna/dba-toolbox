USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'AventureWorks_TXLogFile', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=10, 
		@include_event_description_in=0, 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'Databases|Percent Log Used|AdventureWorks2019|>|50', 
		@job_id=N'63127281-fbbb-4716-ae70-30ef77d6f4ed'
GO


