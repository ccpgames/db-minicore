
IF OBJECT_ID('zdm.processinfo') IS NOT NULL
  DROP PROCEDURE zdm.processinfo
GO
CREATE PROCEDURE zdm.processinfo
  @hostName     nvarchar(100) = '',
  @programName  nvarchar(100) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF CONVERT(varchar, SERVERPROPERTY('productversion')) LIKE '10.%'
  BEGIN
    -- SQL 2008 does not have database_id in sys.dm_exec_sessions
    EXEC sp_executesql N'
      SELECT [db_name] = DB_NAME(P.[dbid]), S.[program_name], S.[host_name], S.host_process_id, S.login_name, session_count = COUNT(*)
        FROM sys.dm_exec_sessions S
          LEFT JOIN sys.sysprocesses P ON P.spid = S.session_id
       WHERE P.[dbid] != 0 AND S.[host_name] LIKE @hostName + ''%'' AND S.[program_name] LIKE @programName + ''%''
       GROUP BY DB_NAME(P.[dbid]), S.[program_name], S.[host_name], S.host_process_id, S.login_name
       ORDER BY [db_name], S.[program_name], S.login_name, COUNT(*) DESC, S.[host_name]', N'@hostName nvarchar(100), @programName nvarchar(100)', @hostName, @programName
  END
  ELSE
  BEGIN
    EXEC sp_executesql N'
      SELECT [db_name] = DB_NAME(database_id), [program_name], [host_name], host_process_id, login_name, session_count = COUNT(*)
        FROM sys.dm_exec_sessions
       WHERE database_id != 0 AND [host_name] LIKE @hostName + ''%'' AND [program_name] LIKE @programName + ''%''
       GROUP BY DB_NAME(database_id), [program_name], [host_name], host_process_id, login_name
       ORDER BY [db_name], [program_name], login_name, COUNT(*) DESC, [host_name]', N'@hostName nvarchar(100), @programName nvarchar(100)', @hostName, @programName
  END
GO
