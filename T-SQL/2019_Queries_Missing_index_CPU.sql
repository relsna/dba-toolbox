/*
https://www.erikdarlingdata.com/sql-server/how-sql-server-2019-helps-you-find-queries-that-have-missing-index-requests/

help you find queries that use a lot of CPU and might could oughtta use an index

You should, as often as possible, execute the query and collect the actual execution plan to see where the time is spent before adding anything in.

*/

SELECT TOP (50)
    query_text = 
        SUBSTRING
        (
            st.text,
            qs.statement_start_offset / 2 + 1,
            CASE qs.statement_start_offset
                 WHEN -1 
                 THEN DATALENGTH(st.text)
                 ELSE qs.statement_end_offset
            END - qs.statement_start_offset / 2 + 1
        ),
    qp.query_plan,
    qs.creation_time,
    qs.last_execution_time,
    qs.execution_count,
    qs.max_worker_time,
    avg_worker_time = 
        (qs.total_worker_time / qs.execution_count),
    qs.max_grant_kb,
    qs.max_used_grant_kb,
    qs.total_spills
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
CROSS APPLY
(
    SELECT TOP (1)
        gqs.*
    FROM sys.dm_db_missing_index_group_stats_query AS gqs
    WHERE qs.query_hash = gqs.query_hash
    AND   qs.query_plan_hash = gqs.query_plan_hash
    AND   qs.sql_handle = gqs.last_sql_handle
    ORDER BY
        gqs.last_user_seek DESC,
        gqs.last_user_scan DESC
) AS gqs
ORDER BY qs.max_worker_time DESC
OPTION(RECOMPILE);