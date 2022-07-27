/*
https://www.erikdarlingdata.com/sql-server/how-sql-server-2019-helps-you-find-queries-that-have-missing-index-requests/

help you find queries that use a lot of CPU and might could oughtta use an index

You should, as often as possible, execute the query and collect the actual execution plan to see where the time is spent before adding anything in.

*/


--	No Query Store
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



--	Query Store
--	https://www.erikdarlingdata.com/sql-server/finding-query-store-queries-with-missing-index-requests-in-sql-server-2019/
WITH
    queries AS
(
    SELECT TOP (100)
        parent_object_name = 
            ISNULL
            (
                OBJECT_NAME(qsq.object_id),
                'No Parent Object'
            ),
        qsqt.query_sql_text,
        query_plan = 
            TRY_CAST(qsp.query_plan AS xml),
        qsrs.first_execution_time,
        qsrs.last_execution_time,
        qsrs.count_executions,
        qsrs.avg_duration,
        qsrs.avg_cpu_time,
        qsp.query_plan_hash,
        qsq.query_hash
    FROM sys.query_store_runtime_stats AS qsrs
    JOIN sys.query_store_plan AS qsp
        ON qsp.plan_id = qsrs.plan_id
    JOIN sys.query_store_query AS qsq
        ON qsq.query_id = qsp.query_id
    JOIN sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
    WHERE qsrs.last_execution_time >= DATEADD(DAY, -7, SYSDATETIME())
    AND   qsrs.avg_cpu_time >= (10 * 1000)
    AND   qsq.is_internal_query = 0
    AND   qsp.is_online_index_plan = 0
    ORDER BY qsrs.avg_cpu_time DESC
)
SELECT
    qs.*
FROM queries AS qs
CROSS APPLY
(
    SELECT TOP (1)
        gqs.*
    FROM sys.dm_db_missing_index_group_stats_query AS gqs
    WHERE qs.query_hash = gqs.query_hash
    AND   qs.query_plan_hash = gqs.query_plan_hash
    ORDER BY
        gqs.last_user_seek DESC,
        gqs.last_user_scan DESC
) AS gqs
ORDER BY qs.avg_cpu_time DESC
OPTION(RECOMPILE);


