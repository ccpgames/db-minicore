
IF OBJECT_ID('zdm.topsql') IS NOT NULL
  DROP PROCEDURE zdm.topsql
GO
CREATE PROCEDURE zdm.topsql
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0) = GETDATE()

  IF NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id != 0)
  BEGIN
    -- No blocking, light version
    SELECT TOP (@rows) start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.TimeString(ABS(DATEDIFF(second, R.start_time, @now))),
           R.session_id, blocking_id = R.blocking_session_id, R.logical_reads,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes,
           R.open_transaction_count, R.open_resultset_count, R.percent_complete, R.database_id,
           [object_id] = T.objectid, S.host_process_id, S.client_interface_name, R.[sql_handle], R.plan_handle
      FROM sys.dm_exec_requests R
        CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
        LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id
     ORDER BY R.start_time
  END
  ELSE
  BEGIN
    -- Blocking, add blocking info rowset
    DECLARE @topsql TABLE
    (
      start_time                 datetime2(0),
      run_time                   varchar(20),
      session_id                 smallint,
      blocking_id                smallint,
      logical_reads              bigint,
      [host_name]                nvarchar(128),
      [program_name]             nvarchar(128),
      login_name                 nvarchar(128),
      database_name              nvarchar(128),
      [object_name]              nvarchar(256),
      [text]                     nvarchar(max),
      command                    nvarchar(32),
      [status]                   nvarchar(30),
      estimated_completion_time  varchar(20),
      wait_time                  varchar(20),
      last_wait_type             nvarchar(60),
      cpu_time                   varchar(20),
      total_elapsed_time         varchar(20),
      reads                      bigint,
      writes                     bigint,
      open_transaction_count     int,
      open_resultset_count       int,
      percent_complete           real,
      database_id                smallint,
      [object_id]                int,
      host_process_id            int,
      client_interface_name      nvarchar(32),
      [sql_handle]               varbinary(64),
      plan_handle                varbinary(64)
    )

    INSERT INTO @topsql
         SELECT TOP (@rows) start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.TimeString(ABS(DATEDIFF(second, R.start_time, @now))),
                R.session_id, blocking_id = R.blocking_session_id, R.logical_reads,
                S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
                [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
                T.[text], R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
                wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
                total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes,
                R.open_transaction_count, R.open_resultset_count, R.percent_complete, R.database_id,
                [object_id] = T.objectid, S.host_process_id, S.client_interface_name, R.[sql_handle], R.plan_handle
           FROM sys.dm_exec_requests R
             CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
             LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id

    SELECT 'Blocking info' AS Info, start_time, run_time, session_id, blocking_id, logical_reads,
            [host_name], [program_name], login_name, database_name, [object_name],
            [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
            total_elapsed_time, reads, writes,
            open_transaction_count, open_resultset_count, percent_complete, database_id,
            [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM @topsql
      WHERE blocking_id IN (select session_id FROM @topsql) OR session_id IN (select blocking_id FROM @topsql)
      ORDER BY blocking_id, session_id

    SELECT start_time, run_time, session_id, blocking_id, logical_reads,
           [host_name], [program_name], login_name, database_name, [object_name],
           [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
           total_elapsed_time, reads, writes,
           open_transaction_count, open_resultset_count, percent_complete, database_id,
           [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM @topsql
     ORDER BY start_time
  END
GO


IF OBJECT_ID('zdm.t') IS NOT NULL
  DROP SYNONYM zdm.t
GO
CREATE SYNONYM zdm.t FOR zdm.topsql
GO
