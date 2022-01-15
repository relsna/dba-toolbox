


--	Returns the Automatic Tuning options for this database.

select name, desired_state_desc, actual_state_desc, reason_desc
from sys.database_automatic_tuning_options


ALTER DATABASE AdventureWorks
	SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = OFF);




select *
from sys.dm_db_tuning_recommendations





--	----
--	Recommendation that can fix this issue
SELECT reason, score,
	 script = JSON_VALUE(details, '$.implementationDetails.script'),
	 planForceDetails.[query_id],
	 planForceDetails.[new plan_id],
	 planForceDetails.[recommended plan_id],
	 estimated_gain = (regressedPlanExecutionCount+recommendedPlanExecutionCount)*(regressedPlanCpuTimeAverage-recommendedPlanCpuTimeAverage)/1000000
FROM sys.dm_db_tuning_recommendations
	CROSS APPLY OPENJSON (Details, '$.planForceDetails')
		WITH ( [query_id] int '$.queryId',
			[new plan_id] int '$.regressedPlanId',
			[recommended plan_id] int '$.recommendedPlanId',
			regressedPlanErrorCount int,
			recommendedPlanErrorCount int,
			regressedPlanExecutionCount int,
			regressedPlanCpuTimeAverage float,
			recommendedPlanExecutionCount int,
			recommendedPlanCpuTimeAverage float ) as planForceDetails;





