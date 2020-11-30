;with eX AS (
    select CAST(t.target_data AS XML) AS targetDataXML, t.*
    from sys.dm_xe_sessions AS s
            join sys.dm_xe_session_targets AS t
                on s.address = t.event_session_address
    where s.name = 'Login_Failed'
        and t.target_name = 'ring_buffer'
)
    SELECT
            xed.event_data.value('(@timestamp)[1]', 'datetime2') AS EventTimestamp
            , xed.event_data.value('(data[@name="message"]/value)[1]', 'nvarchar(250)') AS EventMessage
            , xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'nvarchar(250)') AS client_app_name
            , xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'nvarchar(250)') AS client_hostname
            , xed.event_data.value('(action[@name="database_id"]/value)[1]', 'int') AS database_id
    FROM eX
        CROSS APPLY targetDataXML.nodes('//RingBufferTarget/event') AS xed (event_data)
