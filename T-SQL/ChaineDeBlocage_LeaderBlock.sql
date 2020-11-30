--===========================================================================--
-- DÉTECTION DES CHAINES DE BLOCAGE                                          --
--===========================================================================--
-- Fredéric Brouard alias SQLpro                http://sqlpro.developpez.com --
-- Société SQL SPOT - http://www.sqlspot.com        2017-01-12 - version 1.0 --
--===========================================================================--


--___________________________________________________________________________--
-- PHASE 1 : requête SQL                                                     --
--¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯--

WITH 
/******************************************************************************
* Frédéric Brouard, alias SQLpro  -  MVP MS SQL Server - SQLpro[@]SQLspot.com *
*******************************************************************************
* DÉTECTION DES CHAINES DE BLOCAGE                                2017-01-12  *
* --------------------------------------------------------------------------- *
* Cette requête présente les sessions bloquant les autres sessions en         *
* déterminant la session à la tête d'une chaine de blocage (LEAD_BLOCKER)     *
* avec le nombre de sessions bloquées BLOCKED_SESSION_COUNT et la longueur    *
* maximale de la chaîne de blocage BLOCKED_DEEP.                              *
* Ceci permet de déterminer quelle session est à annuler en priorité en cas   *
* de blocage intempestif (utiliser la commande KILL qui termine la session    *
* fautive en forçant un ROLLBACK, colonne SQL_CMD)                            *
*******************************************************************************
* Le site sur le SQL et les SGBDR : http://sqlpro.developpez.com              *
* L'entreprise SQL SPOT :           http://www.sqlspot.com                    *
* Le livre sur SQL Server 2014 :    https://www.amazon.fr/dp/2212135920       *
******************************************************************************/
T_SESSION AS
(
-- on récupère les sessions en cours des utilisateurs
SELECT session_id, blocking_session_id
FROM   sys.dm_exec_requests AS tout
WHERE  session_id > 50
),
T_LEAD AS
(
-- on recherche les bloqueurs de tête
SELECT session_id, blocking_session_id
FROM   T_SESSION AS tout
WHERE  session_id > 50
  AND  blocking_session_id = 0
  AND  EXISTS(SELECT * 
              FROM   T_SESSION AS tin
              WHERE  tin.blocking_session_id = tout.session_id)
),
T_CHAIN AS
(
-- requête récursive pour trouver les chaines de blocage
SELECT session_id AS lead_session_id, session_id, blocking_session_id, 1 AS p
FROM   T_LEAD
UNION  ALL
SELECT C.lead_session_id, S.session_id, S.blocking_session_id, p+1 
FROM   T_CHAIN AS C
       JOIN T_SESSION AS S
            ON C.session_id = S.blocking_session_id
),
T_WEIGHT AS
(
-- calculs finaux
SELECT lead_session_id AS LEAD_BLOCKER, 
       COUNT(*) -1 AS BLOCKED_SESSION_COUNT, 
       MAX(p) - 1 AS BLOCKED_DEEP,
       'KILL ' + CAST(lead_session_id AS VARCHAR(16)) + ';' AS SQL_CMD
FROM   T_CHAIN
GROUP  BY lead_session_id
)
SELECT T.*,
       DB_NAME(r.database_id) AS database_name, host_name, program_name, 
       nt_user_name, 
       q.text AS sql_command,
       DATEDIFF(ms, last_request_start_time, 
                COALESCE(last_request_end_time, GETDATE())) AS duration_ms, 
       s.open_transaction_count, 
       r.cpu_time, r.reads, r.writes, r.logical_reads, r.total_elapsed_time 
FROM   T_WEIGHT AS T
       JOIN sys.dm_exec_sessions AS s 
            ON T.LEAD_BLOCKER = s.session_id
       JOIN sys.dm_exec_requests AS r 
            ON s.session_id = r.session_id
       OUTER APPLY sys.dm_exec_sql_text(sql_handle) AS q
ORDER  BY BLOCKED_SESSION_COUNT DESC, BLOCKED_DEEP DESC;
