
IF OBJECT_ID('zdm.sessioninfo') IS NOT NULL
  DROP PROCEDURE zdm.sessioninfo
GO
CREATE PROCEDURE zdm.sessioninfo
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF CONVERT(varchar, SERVERPROPERTY('productversion')) LIKE '10.%'
  BEGIN
    -- SQL 2008 does not have database_id in sys.dm_exec_sessions
    EXEC sp_executesql N'
      SELECT [db_name] = DB_NAME(P.[dbid]), S.[program_name], S.login_name,
             host_count = COUNT(DISTINCT S.[host_name]),
             process_count = COUNT(DISTINCT S.[host_name] + CONVERT(nvarchar, S.host_process_id)),
             session_count = COUNT(*)
        FROM sys.dm_exec_sessions S
          LEFT JOIN sys.sysprocesses P ON P.spid = S.session_id
       WHERE P.[dbid] != 0
       GROUP BY DB_NAME(P.[dbid]), S.[program_name], S.login_name
       ORDER BY COUNT(*) DESC'
  END
  ELSE
  BEGIN
    EXEC sp_executesql N'
      SELECT [db_name] = DB_NAME(database_id), [program_name], login_name,
             host_count = COUNT(DISTINCT [host_name]),
             process_count = COUNT(DISTINCT [host_name] + CONVERT(nvarchar, host_process_id)),
             session_count = COUNT(*)
        FROM sys.dm_exec_sessions
       WHERE database_id != 0
       GROUP BY DB_NAME(database_id), [program_name], login_name
       ORDER BY COUNT(*) DESC'
  END
GO
