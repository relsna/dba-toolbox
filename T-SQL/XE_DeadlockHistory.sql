--	Get deadlock history from default XE:

SELECT
     xed.value('@timestamp', 'datetime2(3)') as CreationDate,
     xed.query('.') AS XEvent
FROM
(
     SELECT CAST([target_data] AS XML) AS TargetData
     FROM sys.dm_xe_session_targets AS st
     INNER JOIN sys.dm_xe_sessions AS s
            ON s.address = st.event_session_address
     WHERE s.name = N'system_health'
                 AND st.target_name = N'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData (xed)
ORDER BY CreationDate DESC


--	Get Query from SQL Handle :


select *
from sys.dm_exec_sql_text(0x02000000674d4308eac0db7235b07137325a36d39881da2f)



