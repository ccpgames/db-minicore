
EXEC zsystem.Versions_Start 'CORE.J', 0004, 'jorundur'
GO



---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Versions_Check
  @developer  varchar(20) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @developers TABLE (developer varchar(20))

  IF @developer IS NULL
  BEGIN
    INSERT INTO @developers (developer)
         SELECT DISTINCT developer FROM zsystem.versions
  END
  ELSE
    INSERT INTO @developers (developer) VALUES (@developer)

  DECLARE @version int, @firstVersion int

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT developer FROM @developers ORDER BY developer
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @developer
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SELECT @firstVersion = MIN([version]) - 1 FROM zsystem.versions WHERE developer = @developer;

    WITH CTE (rowID, versionID, [version]) AS
    (
      SELECT ROW_NUMBER() OVER(ORDER BY [version]),
             [version] - @firstVersion, [version]
        FROM zsystem.versions
        WHERE developer = @developer
    )
    SELECT @version = MAX([version]) FROM CTE WHERE rowID = versionID

    SELECT developer,
           info = CASE WHEN [version] = @version THEN 'LAST CONTINUOUS VERSION' ELSE 'MISSING PRIOR VERSIONS' END,
           [version], versionDate, userName, executionCount, lastDate, coreVersion,
           firstDuration = zutil.TimeString(firstDuration), lastDuration = zutil.TimeString(lastDuration)
      FROM zsystem.versions
     WHERE developer = @developer AND [version] >= @version


    FETCH NEXT FROM @cursor INTO @developer
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Paul Randal (http://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts)

IF OBJECT_ID('zdm.waitstats') IS NOT NULL
  DROP PROCEDURE zdm.waitstats
GO
CREATE PROCEDURE zdm.waitstats
  @percentageThreshold tinyint = 95
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  ;WITH waits AS
  (
    SELECT wait_type,
           wait_time_ms,
           resource_wait_time_ms = wait_time_ms - signal_wait_time_ms,
           signal_wait_time_ms,
           waiting_tasks_count,
           percentage = 100.0 * wait_time_ms / SUM (wait_time_ms) OVER(),
           rowNum = ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC)
      FROM sys.dm_os_wait_stats
     WHERE wait_type NOT IN (N'CLR_SEMAPHORE',      N'LAZYWRITER_SLEEP',            N'RESOURCE_QUEUE',   N'SQLTRACE_BUFFER_FLUSH',
                               N'SLEEP_TASK',       N'SLEEP_SYSTEMTASK',            N'WAITFOR',          N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
                               N'CHECKPOINT_QUEUE', N'REQUEST_FOR_DEADLOCK_SEARCH', N'XE_TIMER_EVENT',   N'XE_DISPATCHER_JOIN',
                               N'LOGMGR_QUEUE',     N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'BROKER_TASK_STOP', N'CLR_MANUAL_EVENT',
                               N'CLR_AUTO_EVENT',   N'DISPATCHER_QUEUE_SEMAPHORE',  N'TRACEWRITE',       N'XE_DISPATCHER_WAIT',
                               N'BROKER_TO_FLUSH',  N'BROKER_EVENTHANDLER',         N'FT_IFTSHC_MUTEX',  N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
                               N'DIRTY_PAGE_POLL',  N'SP_SERVER_DIAGNOSTICS_SLEEP')
  )
  SELECT W1.wait_type,
         W1.wait_time_ms,
         W1.resource_wait_time_ms,
         W1.signal_wait_time_ms,
         W1.waiting_tasks_count,
         percentage = CAST(W1.percentage AS DECIMAL (14, 2)),
         avg_wait_time_ms = CAST((W1.wait_time_ms / CONVERT(float, W1.waiting_tasks_count)) AS DECIMAL (14, 4)),
         avg_resource_wait_time_ms = CAST((W1.resource_wait_time_ms / CONVERT(float, W1.waiting_tasks_count)) AS DECIMAL (14, 4)),
         avg_signal_wait_time_ms = CAST((W1.signal_wait_time_ms / CONVERT(float, W1.waiting_tasks_count)) AS DECIMAL (14, 4))
    FROM waits AS W1
      INNER JOIN waits AS W2 ON W2.rowNum <= W1.rowNum
   GROUP BY W1.rowNum, W1.wait_type, W1.wait_time_ms, W1.resource_wait_time_ms, W1.signal_wait_time_ms, W1.waiting_tasks_count, W1.percentage
     HAVING SUM(W2.percentage) - W1.percentage < @percentageThreshold
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zdm.topsql
  @rows  smallint = 30
  WITH EXECUTE AS OWNER
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0) = GETDATE()

  IF NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id != 0)
  BEGIN
    -- No blocking, light version
    SELECT TOP (@rows) start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.DateDiffString(R.start_time, @now),
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
    SELECT TOP (@rows) start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.DateDiffString(R.start_time, @now),
           R.session_id, blocking_id = R.blocking_session_id, R.logical_reads,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes,
           R.open_transaction_count, R.open_resultset_count, R.percent_complete, R.database_id,
           [object_id] = T.objectid, S.host_process_id, S.client_interface_name, R.[sql_handle], R.plan_handle
      INTO #topsql
      FROM sys.dm_exec_requests R
        CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
        LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id

    SELECT 'Blocking info' AS Info, start_time, run_time, session_id, blocking_id, logical_reads,
            [host_name], [program_name], login_name, database_name, [object_name],
            [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
            total_elapsed_time, reads, writes,
            open_transaction_count, open_resultset_count, percent_complete, database_id,
            [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM #topsql
      WHERE blocking_id IN (select session_id FROM #topsql) OR session_id IN (select blocking_id FROM #topsql)
      ORDER BY blocking_id, session_id

    SELECT start_time, run_time, session_id, blocking_id, logical_reads,
           [host_name], [program_name], login_name, database_name, [object_name],
           [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
           total_elapsed_time, reads, writes,
           open_transaction_count, open_resultset_count, percent_complete, database_id,
           [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM #topsql
     ORDER BY start_time
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zdm.topsqlp
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0) = GETDATE()

  IF NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id != 0)
  BEGIN
    -- No blocking, light version
    SELECT TOP (@rows) P.query_plan, start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.DateDiffString(R.start_time, @now),
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
        CROSS APPLY sys.dm_exec_query_plan(R.plan_handle) P
        LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id
     ORDER BY R.start_time
  END
  ELSE
  BEGIN
    -- Blocking, add blocking info rowset
    SELECT TOP (@rows) P.query_plan, start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.DateDiffString(R.start_time, @now),
           R.session_id, blocking_id = R.blocking_session_id, R.logical_reads,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes,
           R.open_transaction_count, R.open_resultset_count, R.percent_complete, R.database_id,
           [object_id] = T.objectid, S.host_process_id, S.client_interface_name, R.[sql_handle], R.plan_handle
      INTO #topsql
      FROM sys.dm_exec_requests R
        CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
        CROSS APPLY sys.dm_exec_query_plan(R.plan_handle) P
        LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id

    SELECT 'Blocking info' AS Info, query_plan, start_time, run_time, session_id, blocking_id, logical_reads,
            [host_name], [program_name], login_name, database_name, [object_name],
            [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
            total_elapsed_time, reads, writes,
            open_transaction_count, open_resultset_count, percent_complete, database_id,
            [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM #topsql
      WHERE blocking_id IN (select session_id FROM #topsql) OR session_id IN (select blocking_id FROM #topsql)
      ORDER BY blocking_id, session_id

    SELECT query_plan, start_time, run_time, session_id, blocking_id, logical_reads,
           [host_name], [program_name], login_name, database_name, [object_name],
           [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
           total_elapsed_time, reads, writes,
           open_transaction_count, open_resultset_count, percent_complete, database_id,
           [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM #topsql
     ORDER BY start_time
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zdm.info
  @info    varchar(100) = '',
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @info = ''
  BEGIN
    PRINT 'AVAILABLE OPTIONS...'
    PRINT '  zdm.info ''tables'''
    PRINT '  zdm.info ''indexes'''
    PRINT '  zdm.info ''views'''
    PRINT '  zdm.info ''functions'''
    PRINT '  zdm.info ''procs'''
    PRINT '  zdm.info ''filegroups'''
    PRINT '  zdm.info ''partitions'''
    PRINT '  zdm.info ''index stats'''
    PRINT '  zdm.info ''proc stats'''
    PRINT '  zdm.info ''indexes by filegroup'''
    PRINT '  zdm.info ''indexes by allocation type'''
    RETURN
  END

  IF @filter != ''
    SET @filter = '%' + LOWER(@filter) + '%'

  IF @info = 'tables'
  BEGIN
    SELECT I.[object_id], [object_name] = S.name + '.' + O.name,
           [rows] = SUM(CASE WHEN I.index_id IN (0, 1) AND A.type_desc = 'IN_ROW_DATA' THEN P.[rows] ELSE 0 END),
           total_kb = SUM(A.total_pages * 8), used_kb = SUM(A.used_pages * 8), data_kb = SUM(A.data_pages * 8),
           create_date = MIN(CONVERT(datetime2(0), O.create_date)), modify_date = MIN(CONVERT(datetime2(0), O.modify_date))
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
          INNER JOIN sys.allocation_units A ON A.container_id = P.[partition_id]
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR LOWER(S.name + '.' + O.name) LIKE @filter)
     GROUP BY I.[object_id], S.name, O.name
     ORDER BY S.name, O.name
  END

  ELSE IF @info = 'indexes'
  BEGIN
    SELECT I.[object_id], I.index_id, index_type = I.type_desc, [object_name] = S.name + '.' + O.name, index_name = I.name,
           [rows] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN P.[rows] ELSE 0 END),
           total_kb = SUM(A.total_pages * 8), used_kb = SUM(A.used_pages * 8), data_kb = SUM(A.data_pages * 8),
           [partitions] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN 1 ELSE 0 END),
           [compression] = CASE WHEN P.data_compression_desc = 'NONE' THEN '' ELSE P.data_compression_desc END,
           [filegroup] = F.name, I.fill_factor
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
          INNER JOIN sys.allocation_units A ON A.container_id = P.[partition_id]
            INNER JOIN sys.filegroups F ON F.data_space_id = A.data_space_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(I.name) LIKE @filter OR LOWER(F.name) LIKE @filter))
     GROUP BY I.[object_id], I.index_id, I.type_desc, I.fill_factor, S.name, O.name, I.name, P.data_compression_desc, F.name
     ORDER BY S.name, O.name, I.index_id
  END

  ELSE IF @info = 'views'
  BEGIN
    SELECT O.[object_id], [object_name] = S.name + '.' + O.name,
           create_date = CONVERT(datetime2(0), O.create_date), modify_date = CONVERT(datetime2(0), O.modify_date)
      FROM sys.objects O
        INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
     WHERE O.type_desc = 'VIEW'
       AND (@filter = '' OR S.name + '.' + O.name LIKE @filter)
     ORDER BY S.name, O.name
  END

  ELSE IF @info = 'functions'
  BEGIN
    SELECT O.[object_id], [object_name] = S.name + '.' + O.name, function_type = O.type_desc,
           create_date = CONVERT(datetime2(0), O.create_date), modify_date = CONVERT(datetime2(0), O.modify_date)
      FROM sys.objects O
        INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
     WHERE O.type_desc IN ('SQL_SCALAR_FUNCTION', 'SQL_TABLE_VALUED_FUNCTION', 'SQL_INLINE_TABLE_VALUED_FUNCTION')
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(O.type_desc) LIKE @filter))
     ORDER BY S.name, O.name
  END

  ELSE IF @info IN ('procs', 'procedures')
  BEGIN
    SELECT O.[object_id], [object_name] = S.name + '.' + O.name,
           create_date = CONVERT(datetime2(0), O.create_date), modify_date = CONVERT(datetime2(0), O.modify_date)
      FROM sys.objects O
        INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
     WHERE O.type_desc = 'SQL_STORED_PROCEDURE'
       AND (@filter = '' OR LOWER(S.name + '.' + O.name) LIKE @filter)
     ORDER BY S.name, O.name
  END

  ELSE IF @info = 'filegroups'
  BEGIN
    SELECT [filegroup] = F.name, total_kb = SUM(A.total_pages * 8), used_kb = SUM(A.used_pages * 8), data_kb = SUM(A.data_pages * 8)
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
        INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
          INNER JOIN sys.allocation_units A ON A.container_id = P.[partition_id]
            INNER JOIN sys.filegroups F ON F.data_space_id = A.data_space_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR LOWER(F.name) LIKE @filter)
     GROUP BY F.name
     ORDER BY F.name
  END

  ELSE IF @info = 'partitions'
  BEGIN
    SELECT I.[object_id], [object_name] = S.name + '.' + O.name, index_name = I.name, [filegroup_name] = F.name,
           partition_scheme = PS.name, partition_function = PF.name, P.partition_number, P.[rows], boundary_value = PRV.value,
           PF.boundary_value_on_right, [data_compression] = P.data_compression_desc
       FROM sys.partition_schemes PS
         INNER JOIN sys.indexes I ON I.data_space_id = PS.data_space_id
           INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
             INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
           INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
             INNER JOIN sys.destination_data_spaces DDS on DDS.partition_scheme_id = PS.data_space_id and DDS.destination_id = P.partition_number
               INNER JOIN sys.filegroups F ON F.data_space_id = DDS.data_space_id
         INNER JOIN sys.partition_functions PF ON PF.function_id = PS.function_id
           INNER JOIN sys.partition_range_values PRV on PRV.function_id = PF.function_id AND PRV.boundary_id = P.partition_number
     WHERE @filter = '' OR LOWER(S.name + '.' + O.name) LIKE @filter
     ORDER BY S.name, O.name, I.index_id, P.partition_number
  END

  ELSE IF @info = 'index stats'
  BEGIN
    SELECT I.[object_id], I.index_id, index_type = I.type_desc, [object_name] = S.name + '.' + O.name, index_name = I.name,
           [rows] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN P.[rows] ELSE 0 END),
           total_kb = SUM(A.total_pages * 8),
           user_seeks = MAX(U.user_seeks), user_scans = MAX(U.user_scans), user_lookups = MAX(U.user_lookups), user_updates = MAX(U.user_updates),
           [partitions] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN 1 ELSE 0 END),
           [filegroup] = F.name
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
          INNER JOIN sys.allocation_units A ON A.container_id = P.[partition_id]
            INNER JOIN sys.filegroups F ON F.data_space_id = A.data_space_id
        LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id = DB_ID() AND U.[object_id] = I.[object_id] AND U.index_id = I.index_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(I.name) LIKE @filter OR LOWER(F.name) LIKE @filter))
     GROUP BY I.[object_id], I.index_id, I.type_desc, S.name, O.name, I.name, F.name
     ORDER BY S.name, O.name, I.index_id
  END

  ELSE IF @info IN ('proc stats', 'procedure stats')
  BEGIN
    SELECT O.[object_id], [object_name] = S.name + '.' + O.name,
           P.execution_count, P.total_worker_time, P.total_elapsed_time, P.total_logical_reads, P.total_logical_writes,
           P.max_worker_time, P.max_elapsed_time, P.max_logical_reads, P.max_logical_writes,
           P.last_execution_time, P.cached_time
      FROM sys.objects O
        INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        LEFT JOIN sys.dm_exec_procedure_stats P ON P.database_id = DB_ID() AND P.[object_id] = O.[object_id]
     WHERE O.type_desc = 'SQL_STORED_PROCEDURE'
       AND (@filter = '' OR LOWER(S.name + '.' + O.name) LIKE @filter)
     ORDER BY S.name, O.name
  END

  ELSE IF @info = 'indexes by filegroup'
  BEGIN
    SELECT [filegroup] = F.name, I.[object_id], I.index_id, index_type = I.type_desc, [object_name] = S.name + '.' + O.name, index_name = I.name,
           [rows] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN P.[rows] ELSE 0 END),
           total_kb = SUM(A.total_pages * 8), used_kb = SUM(A.used_pages * 8), data_kb = SUM(A.data_pages * 8),
           [partitions] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN 1 ELSE 0 END),
           [compression] = CASE WHEN P.data_compression_desc = 'NONE' THEN '' ELSE P.data_compression_desc END
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
          INNER JOIN sys.allocation_units A ON A.container_id = P.[partition_id]
            INNER JOIN sys.filegroups F ON F.data_space_id = A.data_space_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(I.name) LIKE @filter OR LOWER(F.name) LIKE @filter))
     GROUP BY F.name, I.[object_id], I.index_id, I.type_desc, S.name, O.name, I.name, P.data_compression_desc
     ORDER BY F.name, S.name, O.name, I.index_id
  END

  ELSE IF @info = 'indexes by allocation type'
  BEGIN
    SELECT allocation_type = A.type_desc,
           I.[object_id], I.index_id, index_type = I.type_desc, [object_name] = S.name + '.' + O.name, index_name = I.name,
           [rows] = SUM(CASE WHEN A.type_desc = 'IN_ROW_DATA' THEN P.[rows] ELSE 0 END),
           total_kb = SUM(A.total_pages * 8), used_kb = SUM(A.used_pages * 8), data_kb = SUM(A.data_pages * 8),
           [partitions] = COUNT(*),
           [compression] = CASE WHEN P.data_compression_desc = 'NONE' THEN '' ELSE P.data_compression_desc END,
           [filegroup] = F.name
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
          INNER JOIN sys.allocation_units A ON A.container_id = P.[partition_id]
            INNER JOIN sys.filegroups F ON F.data_space_id = A.data_space_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(I.name) LIKE @filter OR LOWER(F.name) LIKE @filter OR LOWER(A.type_desc) LIKE @filter))
     GROUP BY A.type_desc, F.name, I.[object_id], I.index_id, I.type_desc, S.name, O.name, I.name, P.data_compression_desc
     ORDER BY A.type_desc, S.name, O.name, I.index_id
  END

  ELSE
  BEGIN
    PRINT 'OPTION NOT AVAILAIBLE !!!'
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.partitions') IS NOT NULL
  DROP PROCEDURE zdm.partitions
GO
CREATE PROCEDURE zdm.partitions
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'partitions', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.panic') IS NOT NULL
  DROP PROCEDURE zdm.panic
GO
CREATE PROCEDURE zdm.panic
AS
  SET NOCOUNT ON

  PRINT ''
  PRINT '#######################'
  PRINT '# DBA Panic Checklist #'
  PRINT '#######################'
  PRINT ''
  PRINT 'Web page: http://wiki/display/db/DBA+Panic+Checklist'
  PRINT ''
  PRINT '------------------------------------------------'
  PRINT 'STORED PROCEDURES TO USE IN A PANIC SITUATION...'
  PRINT '------------------------------------------------'
  PRINT '  zdm.topsql        /  zdm.topsqlp'
  PRINT '  zdm.counters'
  PRINT '  zdm.sessioninfo   /  zdm.processinfo'
  PRINT '  zdm.transactions'
  PRINT '  zdm.applocks'
  PRINT '  zdm.memory'
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.BigintListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.BigintListToOrderedTable
GO
CREATE FUNCTION zutil.BigintListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(bigint, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.BigintListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.BigintListToTable') IS NOT NULL
  DROP FUNCTION zutil.BigintListToTable
GO
CREATE FUNCTION zutil.BigintListToTable(@list varchar(max))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(bigint, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.BigintListToTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.CharListToOrderedTable
GO
CREATE FUNCTION zutil.CharListToOrderedTable(@list nvarchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                string = SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToOrderedTableTrim') IS NOT NULL
  DROP FUNCTION zutil.CharListToOrderedTableTrim
GO
CREATE FUNCTION zutil.CharListToOrderedTableTrim(@list nvarchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                string = LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToOrderedTableTrim TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToTable') IS NOT NULL
  DROP FUNCTION zutil.CharListToTable
GO
CREATE FUNCTION zutil.CharListToTable(@list nvarchar(max))
  RETURNS TABLE
  RETURN SELECT string = SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToTableTrim') IS NOT NULL
  DROP FUNCTION zutil.CharListToTableTrim
GO
CREATE FUNCTION zutil.CharListToTableTrim(@list nvarchar(max))
  RETURNS TABLE
  RETURN SELECT string = LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToTableTrim TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.DateListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.DateListToOrderedTable
GO
CREATE FUNCTION zutil.DateListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                dateValue = CONVERT(datetime2(0), SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.DateListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.DateListToTable') IS NOT NULL
  DROP FUNCTION zutil.DateListToTable
GO
CREATE FUNCTION zutil.DateListToTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT dateValue = CONVERT(datetime2(0), SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.DateListToTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.FloatListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.FloatListToOrderedTable
GO
CREATE FUNCTION zutil.FloatListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(float, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.FloatListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.FloatListToTable') IS NOT NULL
  DROP FUNCTION zutil.FloatListToTable
GO
CREATE FUNCTION zutil.FloatListToTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(float, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.FloatListToTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.IntListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.IntListToOrderedTable
GO
CREATE FUNCTION zutil.IntListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(int, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.IntListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.IntListToTable') IS NOT NULL
  DROP FUNCTION zutil.IntListToTable
GO
CREATE FUNCTION zutil.IntListToTable(@list varchar(max))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(int, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.IntListToTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.MoneyListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.MoneyListToOrderedTable
GO
CREATE FUNCTION zutil.MoneyListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(money, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.MoneyListToOrderedTable TO zzp_server
GO

---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.StringListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.StringListToOrderedTable
GO
CREATE FUNCTION zutil.StringListToOrderedTable(@list nvarchar(MAX), @trim smallint=1)
  -- ################################################################################################
  -- ## This function has been deprecated                                                          ##
  -- ## The reason is that its mysteriously very slow when using DISTINCT because of the CASE part ##
  -- ## Use zutil.CharListToTable and zutil.CharListToTableTrim                                    ##
  -- ################################################################################################
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                string = CASE WHEN @trim = 1 THEN LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
                                             ELSE SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n) END
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.StringListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.StringListToTable') IS NOT NULL
  DROP FUNCTION zutil.StringListToTable
GO
CREATE FUNCTION zutil.StringListToTable(@list nvarchar(max), @trim smallint = 1)
  -- ################################################################################################
  -- ## This function has been deprecated                                                          ##
  -- ## The reason is that its mysteriously very slow when using DISTINCT because of the CASE part ##
  -- ## Use zutil.CharListToTable and zutil.CharListToTableTrim                                    ##
  -- ################################################################################################
  RETURNS TABLE
  RETURN SELECT string = CASE WHEN @trim = 1 THEN LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
                                             ELSE SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n) END
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.StringListToTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.events') AND [name] = 'referenceID')
  ALTER TABLE zsystem.events ADD referenceID int NULL
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.events') AND [name] = 'date_1')
  ALTER TABLE zsystem.events ADD date_1 date NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.eventsEx') IS NOT NULL
  DROP VIEW zsystem.eventsEx
GO
CREATE VIEW zsystem.eventsEx
AS
  SELECT E.eventID, E.eventDate, E.eventTypeID, ET.eventTypeName, E.duration,
         E.int_1, E.int_2, E.int_3, E.int_4, E.int_5, E.int_6, E.int_7, E.int_8, E.int_9, E.eventText,
         procedureName = CASE WHEN E.eventTypeID IN (2000000001, 2000000002, 2000000003, 2000000004) THEN S.schemaName + '.' + P.procedureName ELSE NULL END,
         jobName = CASE WHEN E.eventTypeID IN (2000000021, 2000000022, 2000000023, 2000000024) THEN J.jobName ELSE NULL END,
         E.referenceID, E.date_1
    FROM zsystem.events E
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = E.eventTypeID
      LEFT JOIN zsystem.procedures P ON P.procedureID = E.int_1
        LEFT JOIN zsystem.schemas S ON S.schemaID = P.schemaID
      LEFT JOIN zsystem.jobs J ON J.jobID = E.int_1
GO
GRANT SELECT ON zsystem.eventsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.Events_Insert
GO
CREATE PROCEDURE zsystem.Events_Insert
  @eventTypeID  int,
  @duration     int = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @eventText    nvarchar(max) = NULL,
  @returnRow    bit = 0,
  @referenceID  int = NULL,
  @date_1       date = NULL
AS
  SET NOCOUNT ON

  DECLARE @eventID int

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText, referenceID, date_1)
       VALUES (@eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @referenceID, @date_1)

  SET @eventID = SCOPE_IDENTITY()

  IF @returnRow = 1
    SELECT eventID = @eventID
GO
GRANT EXEC ON zsystem.Events_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.tables') AND [name] = 'keyDateUTC')
  ALTER TABLE zsystem.tables ADD keyDateUTC bit NOT NULL DEFAULT 1
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.tablesEx') IS NOT NULL
  DROP VIEW zsystem.tablesEx
GO
CREATE VIEW zsystem.tablesEx
AS
  SELECT fullName = S.schemaName + '.' + T.tableName,
         T.schemaID, S.schemaName, T.tableID, T.tableName, T.[description],
         T.tableType, T.logIdentity, T.copyStatic,
         T.keyID, T.keyID2, T.keyID3, T.sequence, T.keyName, T.keyDate, T.keyDateUTC,
         T.textTableID, T.textKeyID, T.textTableID2, T.textKeyID2, T.textTableID3, T.textKeyID3,
         T.link, T.disableEdit, T.disableDelete, T.disabledDatasets, T.revisionOrder, T.obsolete, T.denormalized
    FROM zsystem.tables T
      LEFT JOIN zsystem.schemas S ON S.schemaID = T.schemaID
GO
GRANT SELECT ON zsystem.tablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.Identities_Insert
GO
CREATE PROCEDURE zsystem.Identities_Insert
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @identityDate date
  SET @identityDate = DATEADD(minute, 5, GETUTCDATE())

  DECLARE @maxi int, @maxb bigint, @stmt nvarchar(4000), @objectID int

  DECLARE @tableID int, @tableName nvarchar(256), @keyID nvarchar(128), @keyDate nvarchar(128), @logIdentity tinyint

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT T.tableID, QUOTENAME(S.schemaName) + '.' + QUOTENAME(T.tableName), QUOTENAME(T.keyID), T.keyDate, T.logIdentity
          FROM zsystem.tables T
            INNER JOIN zsystem.schemas S ON S.schemaID = T.schemaID
         WHERE T.logIdentity IN (1, 2) AND ISNULL(T.keyID, '') != ''
         ORDER BY tableID
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @objectID = OBJECT_ID(@tableName)
    IF @objectID IS NOT NULL
    BEGIN
      IF @keyDate IS NOT NULL
      BEGIN
        IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = @objectID AND name = @keyDate)
          SET @keyDate = QUOTENAME(@keyDate)
        ELSE
          SET @keyDate = NULL
      END

      IF @logIdentity = 1
      BEGIN
        SET @maxi = NULL
        SET @stmt = 'SELECT TOP 1 @p_maxi = ' + @keyID + ' FROM ' + @tableName
        IF @keyDate IS NOT NULL
          SET @stmt = @stmt + ' WHERE ' + @keyDate + ' < @p_date'
        SET @stmt = @stmt + ' ORDER BY ' + @keyID + ' DESC'
        EXEC sp_executesql @stmt, N'@p_maxi int OUTPUT, @p_date datetime2(0)', @maxi OUTPUT, @identityDate
        IF @maxi IS NOT NULL
        BEGIN
          SET @maxi = @maxi + 1
          INSERT INTO zsystem.identities (tableID, identityDate, identityInt)
               VALUES (@tableID, @identityDate, @maxi)
        END
      END
      ELSE
      BEGIN
        SET @maxb = NULL
        SET @stmt = 'SELECT TOP 1 @p_maxb = ' + @keyID + ' FROM ' + @tableName
        IF @keyDate IS NOT NULL
          SET @stmt = @stmt + ' WHERE ' + @keyDate + ' < @p_date'
        SET @stmt = @stmt + ' ORDER BY ' + @keyID + ' DESC'
        EXEC sp_executesql @stmt, N'@p_maxb bigint OUTPUT, @p_date datetime2(0)', @maxb OUTPUT, @identityDate
        IF @maxb IS NOT NULL
        BEGIN
          SET @maxb = @maxb + 1
          INSERT INTO zsystem.identities (tableID, identityDate, identityBigInt)
               VALUES (@tableID, @identityDate, @maxb)
        END
      END
    END

    FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Jobs_Exec') IS NOT NULL
  DROP PROCEDURE zsystem.Jobs_Exec
GO
CREATE PROCEDURE zsystem.Jobs_Exec
  @group  nvarchar(100) = 'SCHEDULE',
  @part   smallint = NULL
AS
  -- This proc must be called every 10 minutes in a SQL Agent job, no more and no less
  -- @part...
  --   NULL: Use hour:minute (typically used for group SCHEDULE)
  --      0: Execute all parts (typically used for group DOWNTIME)
  --     >0: Execute only that part (typically used for group DOWNTIME)
  -- When @part is NULL...
  --   If week/day/hour/minute is NULL job executes every time the proc is called (every 10 minutes)
  --   If week/day/hour is NULL job executes every hour on the minutes set
  SET NOCOUNT ON

  DECLARE @now datetime2(0), @day tinyint
  SELECT @now = GETUTCDATE(), @day = DATEPART(weekday, @now)

  DECLARE @week tinyint, @r real
  SET @r = DAY(@now) / 7.0
  IF @r <= 1.0 SET @week = 1
  ELSE IF @r <= 2.0 SET @week = 2
  ELSE IF @r <= 3.0 SET @week = 3
  ELSE IF @r <= 4.0 SET @week = 4

  DECLARE @cursor CURSOR

  IF @part IS NULL
  BEGIN
    DECLARE @hour tinyint, @minute tinyint
    SELECT @hour = DATEPART(hour, @now), @minute = (DATEPART(minute, @now) / 10) * 10

    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND [disabled] = 0 AND
                 (([week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] IS NULL)
                  OR
                  ([week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] = @minute)
                  OR
                  ([hour] = @hour AND [minute] = @minute AND ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)))
           ORDER BY orderID
  END
  ELSE IF @part = 0
  BEGIN
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND [disabled] = 0 AND
                 ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)
           ORDER BY part, orderID
  END
  ELSE
  BEGIN
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND part = @part AND [disabled] = 0 AND
                 ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)
           ORDER BY part, orderID
  END

  DECLARE @jobID int, @jobName nvarchar(200), @sql nvarchar(max), @logStarted bit, @logCompleted bit
  DECLARE @duration int, @startTime datetime2(0)

  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  WHILE @@FETCH_STATUS = 0
  BEGIN
    -- Job started event
    SET @startTime = GETUTCDATE()
    IF @logStarted = 1
      INSERT INTO zsystem.events (eventTypeID, int_1) VALUES (2000000021, @jobID)

    -- Job execute 
    BEGIN TRY
      EXEC sp_executesql @sql
    END TRY
    BEGIN CATCH
      -- Job ERROR event
      SET @duration = DATEDIFF(second, @startTime, GETUTCDATE())
      INSERT INTO zsystem.events (eventTypeID, duration, int_1, eventText) VALUES (2000000024, @duration, @jobID, ERROR_MESSAGE())

      DECLARE @objectName nvarchar(256)
      SET @objectName = 'zsystem.Jobs_Exec: ' + @jobName
      EXEC zsystem.CatchError @objectName
    END CATCH

    -- Job completed event
    SET @duration = DATEDIFF(second, @startTime, GETUTCDATE())
    IF @logCompleted = 1
      INSERT INTO zsystem.events (eventTypeID, duration, int_1) VALUES (2000000023, @duration, @jobID)

    FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100014)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], logIdentity, keyID, keyDate)
       VALUES (2000000001, 2000100014, 'events', 'Core - System - Events', 1, 'eventID', 'eventDate')
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000034)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description])
       VALUES (2000000034, 'Operations', 'Special schema record, not actually a schema but rather pointing to the Operations database, allowing ops to register procs.')
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'label')
  ALTER TABLE zsystem.lookupTables ADD label nvarchar(200) 
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupTablesEx') IS NOT NULL
  DROP VIEW zsystem.lookupTablesEx
GO
CREATE VIEW zsystem.lookupTablesEx
AS
  SELECT L.lookupTableID, L.lookupTableName, L.lookupTableIdentifier, L.[description], L.schemaID, S.schemaName, L.tableID, T.tableName,
         L.sourceForID, L.[source], L.lookupID, L.parentID, L.parentLookupTableID, parentLookupTableName = L2.lookupTableName,
         L.link, L.label, L.hidden, L.obsolete
    FROM zsystem.lookupTables L
      LEFT JOIN zsystem.schemas S ON S.schemaID = L.schemaID
      LEFT JOIN zsystem.tables T ON T.tableID = L.tableID
      LEFT JOIN zsystem.lookupTables L2 ON L2.lookupTableID = L.parentLookupTableID
GO
GRANT SELECT ON zsystem.lookupTablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.LookupTables_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.LookupTables_Insert
GO
CREATE PROCEDURE zsystem.LookupTables_Insert
  @lookupTableID          int = NULL,            -- NULL means MAX-UNDER-2000000000 + 1
  @lookupTableName        nvarchar(200),
  @description            nvarchar(max) = NULL,
  @schemaID               int = NULL,            -- Link lookup table to a schema, just info
  @tableID                int = NULL,            -- Link lookup table to a table, just info
  @source                 nvarchar(200) = NULL,  -- Description of data source, f.e. table name
  @lookupID               nvarchar(200) = NULL,  -- Description of lookupID column
  @parentID               nvarchar(200) = NULL,  -- Description of parentID column
  @parentLookupTableID    int = NULL,
  @link                   nvarchar(500) = NULL,  -- If a link to a web page is needed
  @lookupTableIdentifier  varchar(500) = NULL,
  @sourceForID            varchar(20) = NULL,    -- EXTERNAL/TEXT/MAX
  @label                  nvarchar(200) = NULL   -- If a label is needed instead of lookup text
AS
  SET NOCOUNT ON

  IF @lookupTableID IS NULL
    SELECT @lookupTableID = MAX(lookupTableID) + 1 FROM zsystem.lookupTables WHERE lookupTableID < 2000000000
  IF @lookupTableID IS NULL SET @lookupTableID = 1

  IF @lookupTableIdentifier IS NULL SET @lookupTableIdentifier = @lookupTableID

  INSERT INTO zsystem.lookupTables
              (lookupTableID, lookupTableName, [description], schemaID, tableID, [source], lookupID, parentID, parentLookupTableID,
               link, lookupTableIdentifier, sourceForID, label)
       VALUES (@lookupTableID, @lookupTableName, @description, @schemaID, @tableID, @source, @lookupID, @parentID, @parentLookupTableID,
               @link, @lookupTableIdentifier, @sourceForID, @label)

  SELECT lookupTableID = @lookupTableID
GO
GRANT EXEC ON zsystem.LookupTables_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.groups') AND [name] = 'parentGroupID')
  ALTER TABLE zmetric.groups ADD parentGroupID smallint NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


EXEC zdm.DropDefaultConstraint 'zmetric.counters', 'procedureOrder'
ALTER TABLE zmetric.counters ADD DEFAULT 200 FOR procedureOrder
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.counters') AND [name] = 'counterTable')
  ALTER TABLE zmetric.counters ADD counterTable nvarchar(256) NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.counters') AND [name] = 'userName')
  ALTER TABLE zmetric.counters ADD userName varchar(200) NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.counters') AND [name] = 'config')
  ALTER TABLE zmetric.counters ADD config varchar(max) NULL
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.columns') AND [name] = 'counterTable')
  ALTER TABLE zmetric.columns ADD counterTable nvarchar(256) NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.Counters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_Insert
GO
CREATE PROCEDURE zmetric.Counters_Insert
  @counterType           char(1) = 'D',         -- C:Column, D:Date, S:Simple, T:Time
  @counterID             smallint = NULL,       -- NULL means MAX-UNDER-30000 + 1
  @counterName           nvarchar(200),
  @groupID               smallint = NULL,
  @description           nvarchar(max) = NULL,
  @subjectLookupTableID  int = NULL,            -- Lookup table for subjectID, pointing to zsystem.lookupTables/Values
  @keyLookupTableID      int = NULL,            -- Lookup table for keyID, pointing to zsystem.lookupTables/Values
  @source                nvarchar(200) = NULL,  -- Description of data source, f.e. table name
  @subjectID             nvarchar(200) = NULL,  -- Description of subjectID column
  @keyID                 nvarchar(200) = NULL,  -- Description of keyID column
  @absoluteValue         bit = 0,               -- If set counter stores absolute value
  @shortName             nvarchar(50) = NULL,
  @order                 smallint = 0,
  @procedureName         nvarchar(500) = NULL,  -- Procedure called to get data for the counter
  @procedureOrder        tinyint = 255,
  @parentCounterID       smallint = NULL,
  @baseCounterID         smallint = NULL,
  @counterIdentifier     varchar(500) = NULL,
  @published             bit = 1,
  @sourceType            varchar(20) = NULL,    -- Used f.e. on EVE Metrics to say if counter comes from DB or DOOBJOB
  @units                 varchar(20) = NULL
AS
  SET NOCOUNT ON

  IF @counterID IS NULL
    SELECT @counterID = MAX(counterID) + 1 FROM zmetric.counters WHERE counterID < 30000
  IF @counterID IS NULL SET @counterID = 1

  IF @counterIdentifier IS NULL SET @counterIdentifier = @counterID

  INSERT INTO zmetric.counters
              (counterID, counterName, groupID, [description], subjectLookupTableID, keyLookupTableID, [source], subjectID, keyID,
               absoluteValue, shortName, [order], procedureName, procedureOrder, parentCounterID, baseCounterID, counterType,
               counterIdentifier, published, sourceType, units)
       VALUES (@counterID, @counterName, @groupID, @description, @subjectLookupTableID, @keyLookupTableID, @source, @subjectID, @keyID,
               @absoluteValue, @shortName, @order, @procedureName, @procedureOrder, @parentCounterID, @baseCounterID, @counterType,
               @counterIdentifier, @published, @sourceType, @units)

  SELECT counterID = @counterID
GO
GRANT EXEC ON zmetric.Counters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- this table is intended for normal key counters
--
-- normal key counters are key counters where you need to get top x records ordered by value (f.e. leaderboards)
-- a typical usage is to save daily historical data in zmetric.keyCountersUnindexed and weekl/monthly/total in zmetric.keyCounters

IF OBJECT_ID('zmetric.keyCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.keyCounters
  (
    counterID    smallint  NOT NULL,  -- Counter, poining to zmetric.counters
    counterDate  date      NOT NULL,  -- Date
    columnID     tinyint   NOT NULL,  -- Column if used, pointing to zmetric.columns, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting by country, 0 if not used
    value        float     NOT NULL,  -- Value
    --
    CONSTRAINT keyCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX keyCounters_IX_CounterDate ON zmetric.keyCounters (counterID, counterDate, columnID, value)
END
GRANT SELECT ON zmetric.keyCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- this table is intended for daily key counters
--
-- an index on value is not needed as we wont be having "who was best today" leaderboards
-- this means that we can store daily historical data in a much lighter way
-- the only difference between this table and zmetric.keyCounters is that there is only a primary key and no extra index
-- a typical usage is to save daily historical data in zmetric.keyCountersUnindexed and weekl/monthly/total in zmetric.keyCounters

IF OBJECT_ID('zmetric.keyCountersUnindexed') IS NULL
BEGIN
  CREATE TABLE zmetric.keyCountersUnindexed
  (
    counterID    smallint  NOT NULL,  -- counter, poining to zmetric.counters
    counterDate  date      NOT NULL,
    columnID     tinyint   NOT NULL,  -- column if used, pointing to zmetric.columns, 0 if not used
    keyID        int       NOT NULL,  -- key if used, f.e. if counting users by country, 0 if not used
    value        float     NOT NULL,
    --
    CONSTRAINT keyCountersUnindexed_PK PRIMARY KEY CLUSTERED (counterID, columnID, keyID, counterDate)
  )
END
GRANT SELECT ON zmetric.keyCountersUnindexed TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- this table is intended for time detail of data stored in zmetric.keyCounters
--
-- the only difference between this table and zmetric.keyCounters is that counterDate is datetime2(0) and there is only a primary key and no extra index

IF OBJECT_ID('zmetric.keyTimeCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.keyTimeCounters
  (
    counterID    smallint      NOT NULL,  -- counter, poining to zmetric.counters
    counterDate  datetime2(0)  NOT NULL,
    columnID     tinyint       NOT NULL,  -- column if used, pointing to zmetric.columns, 0 if not used
    keyID        int           NOT NULL,  -- key if used, f.e. if counting by country, 0 if not used
    value        float         NOT NULL,
    --
    CONSTRAINT keyTimeCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, keyID, counterDate)
  )
END
GRANT SELECT ON zmetric.keyTimeCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- this table is intended for subject/key counters
--
-- this is basically a two-key version of zmetric.keyCounters where it was decided to use subjectID/keyID instead of keyID/keyID2

IF OBJECT_ID('zmetric.subjectKeyCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.subjectKeyCounters
  (
    counterID    smallint  NOT NULL,  -- counter, poining to zmetric.counters
    counterDate  date      NOT NULL,
    columnID     tinyint   NOT NULL,  -- column if used, pointing to zmetric.columns, 0 if not used
    subjectID    int       NOT NULL,  -- subject if used, f.e. if counting for user or character, 0 if not used
    keyID        int       NOT NULL,  -- key if used, f.e. if counting kills for character per solar system, 0 if not used
    value        float     NOT NULL,
    --
    CONSTRAINT subjectKeyCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, subjectID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX subjectKeyCounters_IX_CounterDate ON zmetric.subjectKeyCounters (counterID, counterDate, columnID, value)
END
GRANT SELECT ON zmetric.subjectKeyCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.groupsEx') IS NOT NULL
  DROP VIEW zmetric.groupsEx
GO
CREATE VIEW zmetric.groupsEx
AS
  WITH CTE ([level], fullName, parentGroupID, groupID, groupName, [description], [order]) AS
  (
      SELECT [level] = 1, fullName = CONVERT(nvarchar(4000), groupName),
             parentGroupID, groupID, groupName, [description], [order]
        FROM zmetric.groups G
       WHERE parentGroupID IS NULL
      UNION ALL
      SELECT CTE.[level] + 1, CTE.fullName + N', ' + CONVERT(nvarchar(4000), X.groupName),
             X.parentGroupID, X.groupID, X.groupName,  X.[description], X.[order]
        FROM CTE
          INNER JOIN zmetric.groups X ON X.parentGroupID = CTE.groupID
  )
  SELECT [level], fullName, parentGroupID, groupID, groupName, [description], [order]
    FROM CTE
GO
GRANT SELECT ON zmetric.groupsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.countersEx') IS NOT NULL
  DROP VIEW zmetric.countersEx
GO
CREATE VIEW zmetric.countersEx
AS
  SELECT C.groupID, G.groupName, C.counterID, C.counterName, C.counterType, C.counterTable, C.counterIdentifier, C.[description],
         C.subjectLookupTableID, subjectLookupTableIdentifier = LS.lookupTableIdentifier, subjectLookupTableName = LS.lookupTableName,
         C.keyLookupTableID, keyLookupTableIdentifier = LK.lookupTableIdentifier, keyLookupTableName = LK.lookupTableName,
         C.sourceType, C.[source], C.subjectID, C.keyID, C.absoluteValue, C.shortName,
         groupOrder = G.[order], C.[order], C.procedureName, C.procedureOrder, C.parentCounterID, C.createDate,
         C.baseCounterID, C.hidden, C.published, C.units, C.obsolete
    FROM zmetric.counters C
      LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
      LEFT JOIN zsystem.lookupTables LS ON LS.lookupTableID = C.subjectLookupTableID
      LEFT JOIN zsystem.lookupTables LK ON LK.lookupTableID = C.keyLookupTableID
GO
GRANT SELECT ON zmetric.countersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.columnsEx') IS NOT NULL
  DROP VIEW zmetric.columnsEx
GO
CREATE VIEW zmetric.columnsEx
AS
  SELECT C.groupID, G.groupName, O.counterID, C.counterName, O.columnID, O.columnName, O.[description], O.units, O.counterTable, O.[order]
    FROM zmetric.columns O
      LEFT JOIN zmetric.counters C ON C.counterID = O.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
GO
GRANT SELECT ON zmetric.columnsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.dateCountersEx') IS NOT NULL
  DROP VIEW zmetric.dateCountersEx
GO
CREATE VIEW zmetric.dateCountersEx
AS
  SELECT C.groupID, G.groupName, DC.counterID, C.counterName, DC.counterDate,
         DC.subjectID, subjectText = COALESCE(O.columnName, LS.[fullText], LS.lookupText),
         DC.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), DC.[value]
    FROM zmetric.dateCounters DC
      LEFT JOIN zmetric.counters C ON C.counterID = DC.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = DC.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = DC.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = DC.counterID AND CONVERT(int, O.columnID) = DC.subjectID
GO
GRANT SELECT ON zmetric.dateCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.simpleCountersEx') IS NOT NULL
  DROP VIEW zmetric.simpleCountersEx
GO
CREATE VIEW zmetric.simpleCountersEx
AS
  SELECT C.groupID, G.groupName, SC.counterID, C.counterName, SC.counterDate, SC.value
    FROM zmetric.simpleCounters SC
      LEFT JOIN zmetric.counters C ON C.counterID = SC.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
GO
GRANT SELECT ON zmetric.simpleCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.keyCountersEx') IS NOT NULL
  DROP VIEW zmetric.keyCountersEx
GO
CREATE VIEW zmetric.keyCountersEx
AS
  SELECT C.groupID, G.groupName, K.counterID, C.counterName, K.counterDate, K.columnID, O.columnName,
         K.keyID, keyText = ISNULL(L.[fullText], L.lookupText), K.[value]
    FROM zmetric.keyCounters K
      LEFT JOIN zmetric.counters C ON C.counterID = K.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = C.keyLookupTableID AND L.lookupID = K.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = K.counterID AND O.columnID = K.columnID
GO
GRANT SELECT ON zmetric.keyCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.keyCountersUnindexedEx') IS NOT NULL
  DROP VIEW zmetric.keyCountersUnindexedEx
GO
CREATE VIEW zmetric.keyCountersUnindexedEx
AS
  SELECT C.groupID, G.groupName, K.counterID, C.counterName, K.counterDate, K.columnID, O.columnName,
         K.keyID, keyText = ISNULL(L.[fullText], L.lookupText), K.[value]
    FROM zmetric.keyCountersUnindexed K
      LEFT JOIN zmetric.counters C ON C.counterID = K.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = C.keyLookupTableID AND L.lookupID = K.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = K.counterID AND O.columnID = K.columnID
GO
GRANT SELECT ON zmetric.keyCountersUnindexedEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.keyTimeCountersEx') IS NOT NULL
  DROP VIEW zmetric.keyTimeCountersEx
GO
CREATE VIEW zmetric.keyTimeCountersEx
AS
  SELECT C.groupID, G.groupName, T.counterID, C.counterName, T.counterDate, T.columnID, O.columnName,
         T.keyID, keyText = ISNULL(L.[fullText], L.lookupText), T.[value]
    FROM zmetric.keyTimeCounters T
      LEFT JOIN zmetric.counters C ON C.counterID = T.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = C.keyLookupTableID AND L.lookupID = T.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = T.counterID AND O.columnID = T.columnID
GO
GRANT SELECT ON zmetric.keyTimeCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.subjectKeyCountersEx') IS NOT NULL
  DROP VIEW zmetric.subjectKeyCountersEx
GO
CREATE VIEW zmetric.subjectKeyCountersEx
AS
  SELECT C.groupID, G.groupName, SK.counterID, C.counterName, SK.counterDate, SK.columnID, O.columnName,
         SK.subjectID, subjectText = ISNULL(LS.[fullText], LS.lookupText), SK.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), SK.[value]
    FROM zmetric.subjectKeyCounters SK
      LEFT JOIN zmetric.counters C ON C.counterID = SK.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = SK.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = SK.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = SK.counterID AND O.columnID = SK.columnID
GO
GRANT SELECT ON zmetric.subjectKeyCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCountersUnindexed_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCountersUnindexed_Insert
GO
CREATE PROCEDURE zmetric.KeyCountersUnindexed_Insert
  @counterID    smallint,
  @columnID     tinyint = 0,
  @keyID        int = 0,
  @value        float,
  @interval     char(1) = 'D', -- D:Day, W:Week, M:Month, Y:Year
  @counterDate  date = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  INSERT INTO zmetric.keyCountersUnindexed (counterID, counterDate, columnID, keyID, value)
       VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
GO
GRANT EXEC ON zmetric.KeyCountersUnindexed_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCountersUnindexed_Update') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCountersUnindexed_Update
GO
CREATE PROCEDURE zmetric.KeyCountersUnindexed_Update
  @counterID    smallint,
  @columnID     tinyint = 0,
  @keyID        int = 0,
  @value        float,
  @interval     char(1) = 'D', -- D:Day, W:Week, M:Month, Y:Year
  @counterDate  date = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  UPDATE zmetric.keyCountersUnindexed
      SET value = value + @value
    WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.keyCountersUnindexed (counterID, counterDate, columnID, keyID, value)
          VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.keyCountersUnindexed
         SET value = value + @value
       WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.KeyCountersUnindexed_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.KeyCountersUnindexed_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_Insert
GO
CREATE PROCEDURE zmetric.KeyCounters_Insert
  @counterID    smallint,
  @columnID     tinyint = 0,
  @keyID        int = 0,
  @value        float,
  @interval     char(1) = 'D', -- D:Day, W:Week, M:Month, Y:Year
  @counterDate  date = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
       VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
GO
GRANT EXEC ON zmetric.KeyCounters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_Update
GO
CREATE PROCEDURE zmetric.KeyCounters_Update
  @counterID    smallint,
  @columnID     tinyint = 0,
  @keyID        int = 0,
  @value        float,
  @interval     char(1) = 'D', -- D:Day, W:Week, M:Month, Y:Year
  @counterDate  date = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  UPDATE zmetric.keyCounters
      SET value = value + @value
    WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
          VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.keyCounters
         SET value = value + @value
       WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.KeyCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.KeyCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_InsertMulti') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_InsertMulti
GO
CREATE PROCEDURE zmetric.KeyCounters_InsertMulti
  @counterID      smallint,
  @interval       char(1) = 'D',  -- D:Day, W:Week, M:Month, Y:Year
  @counterDate    date = NULL,
  @lookupTableID  int,
  @keyID          int = NULL,     -- If NULL then zsystem.Texts_ID is used
  @keyText        nvarchar(450),
  @value1         float = NULL,
  @value2         float = NULL,
  @value3         float = NULL,
  @value4         float = NULL,
  @value5         float = NULL,
  @value6         float = NULL,
  @value7         float = NULL,
  @value8         float = NULL,
  @value9         float = NULL,
  @value10        float = NULL
AS
  -- Set values for multiple columns
  -- @value1 goes into columnID = 1, @value2 goes into columnID = 2 and so on
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  IF @keyText IS NOT NULL
    EXEC @keyID = zsystem.LookupValues_Update @lookupTableID, @keyID, @keyText

  IF ISNULL(@value1, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 1, @keyID, @value1)

  IF ISNULL(@value2, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 2, @keyID, @value2)

  IF ISNULL(@value3, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 3, @keyID, @value3)

  IF ISNULL(@value4, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 4, @keyID, @value4)

  IF ISNULL(@value5, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 5, @keyID, @value5)

  IF ISNULL(@value6, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 6, @keyID, @value6)

  IF ISNULL(@value7, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 7, @keyID, @value7)

  IF ISNULL(@value8, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 8, @keyID, @value8)

  IF ISNULL(@value9, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 9, @keyID, @value9)

  IF ISNULL(@value10, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 10, @keyID, @value10)
GO
GRANT EXEC ON zmetric.KeyCounters_InsertMulti TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_UpdateMulti') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_UpdateMulti
GO
CREATE PROCEDURE zmetric.KeyCounters_UpdateMulti
  @counterID      smallint,
  @interval       char(1) = 'D',  -- D:Day, W:Week, M:Month, Y:Year
  @counterDate    date = NULL,
  @lookupTableID  int,
  @keyID          int = NULL,     -- If NULL then zsystem.Texts_ID is used
  @keyText        nvarchar(450),
  @value1         float = NULL,
  @value2         float = NULL,
  @value3         float = NULL,
  @value4         float = NULL,
  @value5         float = NULL,
  @value6         float = NULL,
  @value7         float = NULL,
  @value8         float = NULL,
  @value9         float = NULL,
  @value10        float = NULL
AS
  -- Set values for multiple columns
  -- @value1 goes into columnID = 1, @value2 goes into columnID = 2 and so on
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  IF @keyText IS NOT NULL
    EXEC @keyID = zsystem.LookupValues_Update @lookupTableID, @keyID, @keyText

  IF ISNULL(@value1, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value1 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 1 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 1, @keyID, @value1)
  END

  IF ISNULL(@value2, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value2 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 2 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 2, @keyID, @value2)
  END

  IF ISNULL(@value3, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value3 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 3 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 3, @keyID, @value3)
  END

  IF ISNULL(@value4, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value4 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 4 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 4, @keyID, @value4)
  END

  IF ISNULL(@value5, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value5 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 5 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 5, @keyID, @value5)
  END

  IF ISNULL(@value6, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value6 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 6 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 6, @keyID, @value6)
  END

  IF ISNULL(@value7, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value7 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 7 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 7, @keyID, @value7)
  END

  IF ISNULL(@value8, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value8 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 8 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 8, @keyID, @value8)
  END

  IF ISNULL(@value9, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value9 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 9 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 9, @keyID, @value9)
  END

  IF ISNULL(@value10, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value10 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 10 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 10, @keyID, @value10)
  END
GO
GRANT EXEC ON zmetric.KeyCounters_UpdateMulti TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


update zsystem.jobs set [sql] = 'EXEC zmetric.Counters_SaveStats' WHERE jobID = 2000000011 and [sql] like '%zmetric.ColumnCounters_SaveStats%'
delete from zsystem.jobs where jobID = 2000000012 AND [sql] like '%zmetric.IndexStats_Mail%'
go


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveIndexStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveIndexStats', '0', '0', 'Save index stats daily to zmetric.keyCounters (set to "1" to activate)')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveFileStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveFileStats', '0', '0', 'Save file stats daily to zmetric.keyCounters (set to "1" to activate).  Note that file stats are saved for server so only one database needs to save file stats.')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveWaitStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveWaitStats', '0', '0', 'Save wait stats daily to zmetric.keyCounters (set to "1" to activate)  Note that waits stats are saved for server so only one database needs to save wait stats.')
GO


---------------------------------------------------------------------------------------------------------------------------------


-- core.db.waitTypes
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000008)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000008, 'core.db.waitTypes', 'DB - Wait types')
GO

-- core.db.waitStats
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30025)
  INSERT INTO zmetric.counters (counterID, counterTable, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30025, 'zmetric.keyCounters', 'core.db.waitStats', 'DB - Wait statistics', 'Wait statistics saved daily by job. Note that most columns contain accumulated counts.', 2000000008)
GO
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30025)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30025, 1, 'waiting_tasks_count', 'Accumulated count'), (30025, 2, 'wait_time_ms', 'Accumulated count'), (30025, 3, 'signal_wait_time_ms', 'Accumulated count')
GO


---------------------------------------------------------------------------------------------------------------------------------



--update zmetric.counters set counterTable = 'OBSOLETE' where counterID = 30001 and counterIdentifier = 'core.db.obsolete30001' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'OBSOLETE' where counterID = 30002 and counterIdentifier = 'core.db.obsolete30002' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30003 and counterIdentifier = 'core.voice' AND counterTable IS NULL
update zmetric.counters set counterTable = 'zmetric.keyCounters', counterIdentifier = 'core.dbsvc.procStats', counterName = 'DB Service Metrics - Proc statistics' where counterID = 30004 and counterIdentifier = 'core.db.procStats' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30005 and counterIdentifier = 'core.cache.tableCache' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30006 and counterIdentifier = 'core.cache.recordCache' AND counterTable IS NULL
update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30007 and counterIdentifier = 'core.db.indexStats' AND counterTable IS NULL
update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30008 and counterIdentifier = 'core.db.tableStats' AND counterTable IS NULL
update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30009 and counterIdentifier = 'core.db.fileStats' AND counterTable IS NULL

--update zmetric.counters set counterTable = 'zmetric.simpleCounters' where counterID = 30010 and counterIdentifier = 'core.online.characterSessions' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.simpleCounters' where counterID = 30011 and counterIdentifier = 'core.online.userSessions' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.simpleCounters' where counterID = 30012 and counterIdentifier = 'core.online.crestCharacterSessions' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.simpleCounters' where counterID = 30013 and counterIdentifier = 'core.online.crestUserSessions' AND counterTable IS NULL

--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30021 and counterIdentifier = 'core.machoNet.solReceived' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30022 and counterIdentifier = 'core.machoNet.solSent' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30023 and counterIdentifier = 'core.machoNet.proxyReceived' AND counterTable IS NULL
--update zmetric.counters set counterTable = 'zmetric.keyCounters' where counterID = 30024 and counterIdentifier = 'core.machoNet.proxySent' AND counterTable IS NULL
go


update zsystem.lookupTables set lookupTableName = 'DB - Procs' where lookupTableID = 2000000001 and lookupTableName = 'DB Metrics - Procs'
--update zsystem.lookupTables set lookupTableName = 'Cache - TableCaches' where lookupTableID = 2000000002 and lookupTableName = 'Cache Metrics - TableCaches'
--update zsystem.lookupTables set lookupTableName = 'Cache - RecordCaches' where lookupTableID = 2000000003 and lookupTableName = 'Cache Metrics - RecordCaches'
--update zsystem.lookupTables set lookupTableName = 'machoNet - Functions' where lookupTableID = 2000000004 and lookupTableName = 'machoNet Metrics - Functions'
update zsystem.lookupTables set lookupTableName = 'DB - Indexes' where lookupTableID = 2000000005 and lookupTableName = 'DB Metrics - Indexes'
update zsystem.lookupTables set lookupTableName = 'DB - Tables' where lookupTableID = 2000000006 and lookupTableName = 'DB Metrics - Tables'
update zsystem.lookupTables set lookupTableName = 'DB - Filegroups' where lookupTableID = 2000000007 and lookupTableName = 'DB Metrics - Filegroups'
go

update zmetric.counters set counterName = 'DB Service - Proc statistics' where counterID = 30004 and counterName = 'DB Service Metrics - Proc statistics'
--update zmetric.counters set counterName = 'Cache - TableCache' where counterID = 30005 and counterName = 'Cache Metrics - TableCache'
--update zmetric.counters set counterName = 'Cache - RecordCache' where counterID = 30006 and counterName = 'Cache Metrics - RecordCache'
update zmetric.counters set counterName = 'DB - Index statistics' where counterID = 30007 and counterName = 'DB Metrics - Index statistics'
update zmetric.counters set counterName = 'DB - Table statistics' where counterID = 30008 and counterName = 'DB Metrics - Table statistics'
update zmetric.counters set counterName = 'DB - File statistics' where counterID = 30009 and counterName = 'DB Metrics - File statistics'
--update zmetric.counters set counterName = 'machoNet - Sol received' where counterID = 30021 and counterName = 'machoNet Metrics - Sol received'
--update zmetric.counters set counterName = 'machoNet - Sol sent' where counterID = 30022 and counterName = 'machoNet Metrics - Sol sent'
--update zmetric.counters set counterName = 'machoNet - Proxy received' where counterID = 30023 and counterName = 'machoNet Metrics - Proxy received'
--update zmetric.counters set counterName = 'machoNet - Proxy sent' where counterID = 30024 and counterName = 'machoNet Metrics - Proxy sent'
go



---------------------------------------------------------------------------------------------------------------------------------

update zsystem.jobs set orderID = -7 where jobID = 2000000031 and jobName = 'CORE - zsystem - interval overflow alert' and orderID = -10
go


---------------------------------------------------------------------------------------------------------------------------------

-- core.db.procStats
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30026)
  INSERT INTO zmetric.counters (counterID, counterTable, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30026, 'zmetric.keyCounters', 'core.db.procStats', 'DB - Proc statistics', 'Proc statistics saved daily by job. Note that most columns contain accumulated counts.', 2000000001)
GO
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30026)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30026, 1, 'execution_count', 'Accumulated count'), (30026, 2, 'total_logical_reads', 'Accumulated count'), (30026, 3, 'total_logical_writes', 'Accumulated count'),
              (30026, 4, 'total_worker_time', 'Accumulated count'), (30026, 5, 'total_elapsed_time', 'Accumulated count')
GO

IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveProcStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveProcStats', '0', '0', 'Save proc stats daily to zmetric.keyCounters (set to "1" to activate).')
GO


---------------------------------------------------------------------------------------------------------------------------------


update zsystem.settings set [description] = 'Save index stats daily to zmetric.keyCounters (set to "1" to activate).' where [group] = 'zmetric' AND [key] = 'SaveIndexStats'
update zsystem.settings set [description] = 'Save wait stats daily to zmetric.keyCounters (set to "1" to activate).  Note that waits stats are saved for server so only one database needs to save wait stats.' where [group] = 'zmetric' AND [key] = 'SaveWaitStats'
go


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000009)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000009, 'core.db.perfCounters', 'DB - Performance counters')
GO


IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30027)
  INSERT INTO zmetric.counters (counterID, counterTable, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30027, 'zmetric.keyCounters', 'core.db.perfCountersTotal', 'DB - Performance counters - Total', 'Total performance counters saved daily by job (see proc zmetric.KeyCounters_SavePerfCounters). Note that value saved is accumulated count.', 2000000009)
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30028)
  INSERT INTO zmetric.counters (counterID, counterTable, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30028, 'zmetric.keyCounters', 'core.db.perfCountersInstance', 'DB - Performance counters - Instance', 'Instance performance counters saved daily by job (see proc zmetric.KeyCounters_SavePerfCounters). Note that value saved is accumulated count.', 2000000009)
GO


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SavePerfCountersTotal')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SavePerfCountersTotal', '0', '0', 'Save total performance counters daily to zmetric.keyCounters (set to "1" to activate).')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SavePerfCountersInstance')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SavePerfCountersInstance', '0', '0', 'Save instance performance counters daily to zmetric.keyCounters (set to "1" to activate).')
GO


---------------------------------------------------------------------------------------------------------------------------------


update zmetric.counters
   set [description] = 'Index statistics saved daily by job (see proc zmetric.KeyCounters_SaveIndexStats). Note that user columns contain accumulated counts.'
 where counterID = 30007
update zmetric.counters
   set [description] = 'Table statistics saved daily by job (see proc zmetric.KeyCounters_SaveIndexStats). Note that user columns contain accumulated counts.'
 where counterID = 30008
update zmetric.counters
   set [description] = 'File statistics saved daily by job (see proc zmetric.KeyCounters_SaveFileStats). Note that all columns except size_kb contain accumulated counts.'
 where counterID = 30009
update zmetric.counters
   set [description] = 'Wait statistics saved daily by job (see proc zmetric.KeyCounters_SaveWaitStats). Note that all columns contain accumulated counts.'
 where counterID = 30025
update zmetric.counters
   set [description] = 'Proc statistics saved daily by job (see proc zmetric.KeyCounters_SaveProcStats). Note that all columns contain accumulated counts.'
 where counterID = 30026
go


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.Counters_ReportDates') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_ReportDates
GO
CREATE PROCEDURE zmetric.Counters_ReportDates
  @counterID      smallint,
  @counterDate    date = NULL,
  @seek           char(1) = NULL -- NULL / O:Older / N:Newer
AS
  -- Get date to use for zmetric.Counters_ReportData
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @counterID IS NULL
      RAISERROR ('@counterID not set', 16, 1)

    IF @seek IS NOT NULL AND @seek NOT IN ('O', 'N')
      RAISERROR ('Only seek types O and N are supported', 16, 1)

    DECLARE @counterTable nvarchar(256), @counterType char(1)
    SELECT @counterTable = counterTable, @counterType = counterType FROM zmetric.counters  WHERE counterID = @counterID
    IF @counterTable IS NULL AND @counterType = 'D'
        SET @counterTable = 'zmetric.dateCounters'
    IF @counterTable IS NULL OR @counterTable NOT IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters', 'zmetric.dateCounters')
      RAISERROR ('Counter table not supported', 16, 1)

    DECLARE @dateRequested date, @dateReturned date

    IF @counterDate IS NULL
    BEGIN
      SET @dateRequested = DATEADD(day, -1, GETDATE())

      IF @counterTable = 'zmetric.dateCounters'
        SELECT TOP 1 @dateReturned = counterDate FROM zmetric.dateCounters WHERE counterID = @counterID ORDER BY counterDate DESC
      ELSE IF @counterTable = 'zmetric.subjectKeyCounters'
        SELECT TOP 1 @dateReturned = counterDate FROM zmetric.subjectKeyCounters WHERE counterID = @counterID ORDER BY counterDate DESC
      ELSE
        SELECT TOP 1 @dateReturned = counterDate FROM zmetric.keyCounters WHERE counterID = @counterID ORDER BY counterDate DESC
    END
    ELSE
    BEGIN
      SET @dateRequested = @counterDate

      IF @seek IS NULL
        SET @dateReturned = @counterDate
      ELSE
      BEGIN
        IF @counterTable = 'zmetric.dateCounters'
        BEGIN
          IF NOT EXISTS(SELECT * FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate = @counterDate)
          BEGIN
            IF @seek = 'O'
              SELECT TOP 1 @dateReturned = counterDate FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate < @counterDate ORDER BY counterDate DESC
            ELSE
              SELECT TOP 1 @dateReturned = counterDate FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate > @counterDate ORDER BY counterDate
          END
        END
        ELSE IF @counterTable = 'zmetric.subjectKeyCounters'
        BEGIN
          IF NOT EXISTS(SELECT * FROM zmetric.subjectKeyCounters WHERE counterID = @counterID AND counterDate = @counterDate)
          BEGIN
            IF @seek = 'O'
              SELECT TOP 1 @dateReturned = counterDate FROM zmetric.subjectKeyCounters WHERE counterID = @counterID AND counterDate < @counterDate ORDER BY counterDate DESC
            ELSE
              SELECT TOP 1 @dateReturned = counterDate FROM zmetric.subjectKeyCounters WHERE counterID = @counterID AND counterDate > @counterDate ORDER BY counterDate
          END
        END
        ELSE
        BEGIN
          IF NOT EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = @counterID AND counterDate = @counterDate)
          BEGIN
            IF @seek = 'O'
              SELECT TOP 1 @dateReturned = counterDate FROM zmetric.keyCounters WHERE counterID = @counterID AND counterDate < @counterDate ORDER BY counterDate DESC
            ELSE
              SELECT TOP 1 @dateReturned = counterDate FROM zmetric.keyCounters WHERE counterID = @counterID AND counterDate > @counterDate ORDER BY counterDate
          END
        END
      END
    END

    IF @dateReturned IS NULL
      SET @dateReturned = @dateRequested

    SELECT dateRequested = @dateRequested, dateReturned = @dateReturned
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.Counters_ReportDates'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zmetric.Counters_ReportDates TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.Counters_ReportData') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_ReportData
GO
CREATE PROCEDURE zmetric.Counters_ReportData
  @counterID      smallint,
  @fromDate       date = NULL,
  @toDate         date = NULL,
  @rows           int = 20,
  @orderColumnID  smallint = NULL,
  @orderDesc      bit = 1,
  @lookupText     nvarchar(1000) = NULL
AS
  -- Create dynamic SQL to return report used on INFO - Metrics
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @counterID IS NULL
      RAISERROR ('@counterID not set', 16, 1)

    IF @fromDate IS NULL
      RAISERROR ('@fromDate not set', 16, 1)

    IF @rows > 10000
      RAISERROR ('@rows over limit', 16, 1)

    IF @toDate IS NOT NULL AND @toDate = @fromDate
      SET @toDate = NULL

    DECLARE @counterTable nvarchar(256), @counterType char(1), @subjectLookupTableID int, @keyLookupTableID int
    SELECT @counterTable = counterTable, @counterType = counterType, @subjectLookupTableID = subjectLookupTableID, @keyLookupTableID = keyLookupTableID
      FROM zmetric.counters
     WHERE counterID = @counterID
    IF @counterTable IS NULL AND @counterType = 'D'
      SET @counterTable = 'zmetric.dateCounters'
    IF @counterTable IS NULL OR @counterTable NOT IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters', 'zmetric.dateCounters')
      RAISERROR ('Counter table not supported', 16, 1)
    IF @subjectLookupTableID IS NOT NULL AND @keyLookupTableID IS NULL
      RAISERROR ('Counter is not valid, subject lookup set and key lookup not set', 16, 1)
    IF @counterTable = 'zmetric.keyCounters' AND (@subjectLookupTableID IS NOT NULL OR @keyLookupTableID IS NULL)
      RAISERROR ('Key counter is not valid, subject lookup set or key lookup not set', 16, 1)
    IF @counterTable = 'zmetric.subjectKeyCounters' AND (@subjectLookupTableID IS NULL OR @keyLookupTableID IS NULL)
      RAISERROR ('Subject/Key counter is not valid, subject lookup or key lookup not set', 16, 1)

    DECLARE @sql nvarchar(max)

    IF @subjectLookupTableID IS NOT NULL AND @keyLookupTableID IS NOT NULL
    BEGIN
      -- Subject + Key, Single column
      IF @counterType != 'D'
        RAISERROR ('Counter is not valid, subject and key lookup set and counter not of type D', 16, 1)
      SET @sql = 'SELECT TOP (@pRows) C.subjectID, subjectText = ISNULL(S.fullText, S.lookupText), C.keyID, keyText = ISNULL(K.fullText, K.lookupText), '
      IF @toDate IS NULL
        SET @sql = @sql + 'C.value'
      ELSE
        SET @sql = @sql + 'value = SUM(C.value)'
      SET @sql = @sql + CHAR(13) + ' FROM ' + @counterTable + ' C'
      SET @sql = @sql + CHAR(13) + ' LEFT JOIN zsystem.lookupValues S ON S.lookupTableID = @pSubjectLookupTableID AND S.lookupID = C.subjectID'
      SET @sql = @sql + CHAR(13) + ' LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
      SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
      IF @toDate IS NULL
        SET @sql = @sql + 'C.counterDate = @pFromDate'
      ELSE
        SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate'

      -- *** *** *** temporarily hard coding columnID = 0 *** *** ***
      IF @counterTable = 'zmetric.subjectKeyCounters'
        SET @sql = @sql + ' AND C.columnID = 0'

      IF @lookupText IS NOT NULL AND @lookupText != ''
        SET @sql = @sql + ' AND (ISNULL(S.fullText, S.lookupText) LIKE ''%'' + @pLookupText + ''%'' OR ISNULL(K.fullText, K.lookupText) LIKE ''%'' + @pLookupText + ''%'')'
      IF @toDate IS NOT NULL
        SET @sql = @sql + CHAR(13) + ' GROUP BY C.subjectID, ISNULL(S.fullText, S.lookupText), C.keyID, ISNULL(K.fullText, K.lookupText)'
      SET @sql = @sql + CHAR(13) + ' ORDER BY 5'
      IF @orderDesc = 1
        SET @sql = @sql + ' DESC'
      EXEC sp_executesql @sql,
                         N'@pRows int, @pCounterID smallint, @pSubjectLookupTableID int, @pKeyLookupTableID int, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)',
                         @rows, @counterID, @subjectLookupTableID, @keyLookupTableID, @fromDate, @toDate, @lookupText
    END
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.columns WHERE counterID = @counterID)
      BEGIN
        -- Multiple columns (Single value / Multiple key values)
        DECLARE @columnID tinyint, @columnName nvarchar(200), @orderBy nvarchar(200), @sql2 nvarchar(max) = '', @alias nvarchar(10)
        IF @keyLookupTableID IS NULL
          SET @sql = 'SELECT TOP 1 '
        ELSE
          SET @sql = 'SELECT TOP (@pRows) C.keyID, keyText = ISNULL(K.fullText, K.lookupText)'
         SET @sql2 = ' FROM ' + @counterTable + ' C'
        IF @keyLookupTableID IS NOT NULL
          SET @sql2 = @sql2 + CHAR(13) + '    LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
        DECLARE @cursor CURSOR
        SET @cursor = CURSOR LOCAL FAST_FORWARD
          FOR SELECT columnID, columnName FROM zmetric.columns WHERE counterID = @counterID ORDER BY [order], columnID
        OPEN @cursor
        FETCH NEXT FROM @cursor INTO @columnID, @columnName
        WHILE @@FETCH_STATUS = 0
        BEGIN
          IF @orderColumnID IS NULL SET @orderColumnID = @columnID
          IF @columnID = @orderColumnID SET @orderBy = @columnName
          SET @alias = 'C'
          IF @columnID != @orderColumnID
            SET @alias = @alias + CONVERT(nvarchar, @columnID)
          IF @sql != 'SELECT TOP 1 '
            SET @sql = @sql + ',' + CHAR(13) + '       '
          SET @sql = @sql + '[' + @columnName + '] = '
          IF @toDate IS NULL
            SET @sql = @sql + 'ISNULL(' + @alias + '.value, 0)'
          ELSE
            SET @sql = @sql + 'SUM(ISNULL(' + @alias + '.value, 0))'
          IF @columnID = @orderColumnID
            SET @orderBy = '[' + @columnName + ']'
          ELSE
          BEGIN
            SET @sql2 = @sql2 + CHAR(13) + '    LEFT JOIN ' + @counterTable + ' ' + @alias + ' ON ' + @alias + '.counterID = C.counterID'

            IF @counterTable IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters')
              SET @sql2 = @sql2 + ' AND ' + @alias + '.columnID = ' + CONVERT(nvarchar, @columnID)

            IF @counterTable IN ('zmetric.subjectKeyCounters', 'zmetric.dateCounters')
              SET @sql2 = @sql2 + ' AND ' + @alias + '.subjectID = ' + CONVERT(nvarchar, @columnID)

            SET @sql2 = @sql2 + ' AND ' + @alias + '.counterDate = C.counterDate AND ' + @alias + '.keyID = C.keyID'
          END
          FETCH NEXT FROM @cursor INTO @columnID, @columnName
        END
        CLOSE @cursor
        DEALLOCATE @cursor
        SET @sql = @sql + CHAR(13) + @sql2
        SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
        IF @toDate IS NULL
          SET @sql = @sql + 'C.counterDate = @pFromDate AND'
        ELSE
          SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate AND'

        IF @counterTable IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters')
          SET @sql = @sql + ' C.columnID = ' + CONVERT(nvarchar, @orderColumnID)

        IF @counterTable IN ('zmetric.subjectKeyCounters', 'zmetric.dateCounters')
          SET @sql = @sql + ' C.subjectID = ' + CONVERT(nvarchar, @orderColumnID)

        IF @keyLookupTableID IS NOT NULL
        BEGIN
          IF @lookupText IS NOT NULL AND @lookupText != ''
            SET @sql = @sql + ' AND ISNULL(K.fullText, K.lookupText) LIKE ''%'' + @pLookupText + ''%'''
          IF @toDate IS NOT NULL
            SET @sql = @sql + CHAR(13) + ' GROUP BY C.keyID, ISNULL(K.fullText, K.lookupText)'
          SET @sql = @sql + CHAR(13) + ' ORDER BY ' + @orderBy
          IF @orderDesc = 1
            SET @sql = @sql + ' DESC'
        END
        SET @sql = @sql + CHAR(13) + 'OPTION (FORCE ORDER)'
        EXEC sp_executesql @sql,
                           N'@pRows int, @pCounterID smallint, @pKeyLookupTableID int, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)',
                           @rows, @counterID, @keyLookupTableID, @fromDate, @toDate, @lookupText
      END
      ELSE
      BEGIN
        -- Single column
        IF @keyLookupTableID IS NULL
        BEGIN
          -- Single value, Single column
          SET @sql = 'SELECT TOP 1 '
          IF @toDate IS NULL
            SET @sql = @sql + 'value'
          ELSE
            SET @sql = @sql + 'value = SUM(value)'
          SET @sql = @sql + ' FROM ' + @counterTable + ' WHERE counterID = @pCounterID AND '
          IF @toDate IS NULL
            SET @sql = @sql + 'counterDate = @pFromDate'
          ELSE
            SET @sql = @sql + 'counterDate BETWEEN @pFromDate AND @pToDate'
          EXEC sp_executesql @sql, N'@pCounterID smallint, @pFromDate date, @pToDate date', @counterID, @fromDate, @toDate
        END
        ELSE
        BEGIN
          -- Multiple key values, Single column (not using WHERE subjectID = 0 as its not in the index, trusting that its always 0)
          SET @sql = 'SELECT TOP (@pRows) C.keyID, keyText = ISNULL(K.fullText, K.lookupText), '
          IF @toDate IS NULL
            SET @sql = @sql + 'C.value'
          ELSE
            SET @sql = @sql + 'value = SUM(C.value)'
          SET @sql = @sql + CHAR(13) + '  FROM ' + @counterTable + ' C'
          SET @sql = @sql + CHAR(13) + '    LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
          SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
          IF @toDate IS NULL
            SET @sql = @sql + 'C.counterDate = @pFromDate'
          ELSE
            SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate'
          IF @lookupText IS NOT NULL AND @lookupText != ''
            SET @sql = @sql + ' AND ISNULL(K.fullText, K.lookupText) LIKE ''%'' + @pLookupText + ''%'''
          IF @toDate IS NOT NULL
            SET @sql = @sql + CHAR(13) + ' GROUP BY C.keyID, ISNULL(K.fullText, K.lookupText)'
          SET @sql = @sql + CHAR(13) + ' ORDER BY 3'
          IF @orderDesc = 1
            SET @sql = @sql + ' DESC'
          EXEC sp_executesql @sql,
                             N'@pRows int, @pCounterID smallint, @pKeyLookupTableID int, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)',
                             @rows, @counterID, @keyLookupTableID, @fromDate, @toDate, @lookupText
        END
      END
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.Counters_ReportData'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zmetric.Counters_ReportData TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_SaveIndexStats') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SaveIndexStats
GO
CREATE PROCEDURE zmetric.KeyCounters_SaveIndexStats
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SaveIndexStats') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
    BEGIN
      DELETE FROM zmetric.keyCounters WHERE counterID = 30007 AND counterDate = @counterDate
      DELETE FROM zmetric.keyCounters WHERE counterID = 30008 AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30007 AND counterDate = @counterDate)
        RAISERROR ('Index stats data exists', 16, 1)
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30008 AND counterDate = @counterDate)
        RAISERROR ('Table stats data exists', 16, 1)
    END

    DECLARE @indexStats TABLE
    (
      tableName    nvarchar(450)  NOT NULL,
      indexName    nvarchar(450)  NOT NULL,
      [rows]       bigint         NOT NULL,
      total_kb     bigint         NOT NULL,
      used_kb      bigint         NOT NULL,
      data_kb      bigint         NOT NULL,
      user_seeks   bigint         NULL,
      user_scans   bigint         NULL,
      user_lookups bigint         NULL,
      user_updates bigint         NULL
    )
    INSERT INTO @indexStats (tableName, indexName, [rows], total_kb, used_kb, data_kb, user_seeks, user_scans, user_lookups, user_updates)
         SELECT S.name + '.' + T.name, ISNULL(I.name, 'HEAP'),
                SUM(CASE WHEN A.[type] = 1 THEN P.[rows] ELSE 0 END),  -- IN_ROW_DATA 
                SUM(A.total_pages * 8), SUM(A.used_pages * 8), SUM(A.data_pages * 8),
                MAX(U.user_seeks), MAX(U.user_scans), MAX(U.user_lookups), MAX(U.user_updates)
           FROM sys.tables T
             INNER JOIN sys.schemas S ON S.[schema_id] = T.[schema_id]
             INNER JOIN sys.indexes I ON I.[object_id] = T.[object_id]
               INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
                 INNER JOIN sys.allocation_units A ON A.container_id = P.partition_id
               LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id = DB_ID() AND U.[object_id] = I.[object_id] AND U.index_id = I.index_id
          WHERE T.is_ms_shipped != 1
          GROUP BY S.name, T.name, I.name
          ORDER BY S.name, T.name, I.name

    DECLARE @rows bigint, @total_kb bigint, @used_kb bigint, @data_kb bigint,
            @user_seeks bigint, @user_scans bigint, @user_lookups bigint, @user_updates bigint,
            @keyText nvarchar(450), @keyID int

    -- INDEX STATISTICS
    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT tableName + '.' + indexName, [rows], total_kb, used_kb, data_kb, user_seeks, user_scans, user_lookups, user_updates
            FROM @indexStats
           ORDER BY tableName, indexName
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC zmetric.KeyCounters_InsertMulti 30007, 'D', @counterDate, 2000000005, NULL, @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates

      FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    END
    CLOSE @cursor
    DEALLOCATE @cursor

    -- TABLE STATISTICS
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT tableName, MAX([rows]), SUM(total_kb), SUM(used_kb), SUM(data_kb), MAX(user_seeks), MAX(user_scans), MAX(user_lookups), MAX(user_updates)
            FROM @indexStats
           GROUP BY tableName
           ORDER BY tableName
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC zmetric.KeyCounters_InsertMulti 30008, 'D', @counterDate, 2000000006, NULL, @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates

      FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    END
    CLOSE @cursor
    DEALLOCATE @cursor

    -- MAIL
    DECLARE @recipients varchar(max)
    SET @recipients = zsystem.Settings_Value('zmetric', 'Recipients-IndexStats')
    IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
    BEGIN
      DECLARE @subtractDate date
      SET @subtractDate = DATEADD(day, -1, @counterDate)

      -- SEND MAIL...
      DECLARE @subject nvarchar(255)
      SET @subject = HOST_NAME() + '.' + DB_NAME() + ': Index Statistics'

      DECLARE @body nvarchar(MAX)
      SET @body = 
        -- rows
          N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' rows</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">table</th><th>rows</th><th>total_MB</th><th>used_MB</th><th>data_MB</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP (@rows) td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C1.value, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C2.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C3.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C4.value / 1024, 1), ''
          FROM zmetric.keyCounters C1
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000006 AND L.lookupID = C1.keyID
            LEFT JOIN zmetric.keyCounters C2 ON C2.counterID = C1.counterID AND C2.counterDate = C1.counterDate AND C2.columnID = 2 AND C2.keyID = C1.keyID
            LEFT JOIN zmetric.keyCounters C3 ON C3.counterID = C1.counterID AND C3.counterDate = C1.counterDate AND C3.columnID = 3 AND C3.keyID = C1.keyID
            LEFT JOIN zmetric.keyCounters C4 ON C4.counterID = C1.counterID AND C4.counterDate = C1.counterDate AND C4.columnID = 4 AND C4.keyID = C1.keyID
         WHERE C1.counterID = 30008 AND C1.counterDate = @counterDate AND C1.columnID = 1
         ORDER BY C1.value DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- total_MB
        + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' total_MB</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">table</th><th>total_MB</th><th>used_MB</th><th>data_MB</th><th>rows</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP (@rows) td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C2.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C3.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C4.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C1.value, 1), ''
          FROM zmetric.keyCounters C2
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000006 AND L.lookupID = C2.keyID
            LEFT JOIN zmetric.keyCounters C3 ON C3.counterID = C2.counterID AND C3.counterDate = C2.counterDate AND C3.columnID = 3 AND C3.keyID = C2.keyID
            LEFT JOIN zmetric.keyCounters C4 ON C4.counterID = C2.counterID AND C4.counterDate = C2.counterDate AND C4.columnID = 4 AND C4.keyID = C2.keyID
            LEFT JOIN zmetric.keyCounters C1 ON C1.counterID = C2.counterID AND C1.counterDate = C2.counterDate AND C1.columnID = 1 AND C1.keyID = C2.keyID
         WHERE C2.counterID = 30008 AND C2.counterDate = @counterDate AND C2.columnID = 2
         ORDER BY C2.value DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_seeks (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_seeks</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP (@rows) td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C5.value - ISNULL(C5B.value, 0), 1), ''
          FROM zmetric.keyCounters C5
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C5.keyID
            LEFT JOIN zmetric.keyCounters C5B ON C5B.counterID = C5.counterID AND C5B.counterDate = @subtractDate AND C5B.columnID = C5.columnID AND C5B.keyID = C5.keyID
         WHERE C5.counterID = 30007 AND C5.counterDate = @counterDate AND C5.columnID = 5
         ORDER BY (C5.value - ISNULL(C5B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_scans (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_scans</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP (@rows) td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C6.value - ISNULL(C6B.value, 0), 1), ''
          FROM zmetric.keyCounters C6
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C6.keyID
            LEFT JOIN zmetric.keyCounters C6B ON C6B.counterID = C6.counterID AND C6B.counterDate = @subtractDate AND C6B.columnID = C6.columnID AND C6B.keyID = C6.keyID
         WHERE C6.counterID = 30007 AND C6.counterDate = @counterDate AND C6.columnID = 6
         ORDER BY (C6.value - ISNULL(C6B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_lookups (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_lookups</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP (@rows) td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C7.value - ISNULL(C7B.value, 0), 1), ''
          FROM zmetric.keyCounters C7
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C7.keyID
            LEFT JOIN zmetric.keyCounters C7B ON C7B.counterID = C7.counterID AND C7B.counterDate = @subtractDate AND C7B.columnID = C7.columnID AND C7B.keyID = C7.keyID
         WHERE C7.counterID = 30007 AND C7.counterDate = @counterDate AND C7.columnID = 7
         ORDER BY (C7.value - ISNULL(C7B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_updates (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_updates</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP (@rows) td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C8.value - ISNULL(C8B.value, 0), 1), ''
          FROM zmetric.keyCounters C8
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C8.keyID
            LEFT JOIN zmetric.keyCounters C8B ON C8B.counterID = C8.counterID AND C8B.counterDate = @subtractDate AND C8B.columnID = C8.columnID AND C8B.keyID = C8.keyID
         WHERE C8.counterID = 30007 AND C8.counterDate = @counterDate AND C8.columnID = 8
         ORDER BY (C8.value - ISNULL(C8B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

      EXEC zsystem.SendMail @recipients, @subject, @body, 'HTML'
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SaveIndexStats'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_SaveProcStats') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SaveProcStats
GO
CREATE PROCEDURE zmetric.KeyCounters_SaveProcStats
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SaveProcStats') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30026 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30026 AND counterDate = @counterDate)
        RAISERROR ('Proc stats data exists', 16, 1)
    END

    -- PROC STATISTICS
    DECLARE @object_name nvarchar(300), @execution_count bigint, @total_logical_reads bigint, @total_logical_writes bigint, @total_worker_time bigint, @total_elapsed_time bigint

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT S.name + '.' + O.name, SUM(P.execution_count), SUM(P.total_logical_reads), SUM(P.total_logical_writes), SUM(P.total_worker_time), SUM(P.total_elapsed_time)
            FROM sys.dm_exec_procedure_stats P
              INNER JOIN sys.objects O ON O.[object_id] = P.[object_id]
                INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
           WHERE P.database_id = DB_ID()
           GROUP BY S.name + '.' + O.name
           ORDER BY 1
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @object_name, @execution_count, @total_logical_reads, @total_logical_writes, @total_worker_time, @total_elapsed_time
    WHILE @@FETCH_STATUS = 0
    BEGIN
      -- removing digits at the end of string (max two digits)
      IF CHARINDEX(RIGHT(@object_name, 1), '0123456789') > 0
        SET @object_name = LEFT(@object_name, LEN(@object_name) - 1)
      IF CHARINDEX(RIGHT(@object_name, 1), '0123456789') > 0
        SET @object_name = LEFT(@object_name, LEN(@object_name) - 1)

      EXEC zmetric.KeyCounters_UpdateMulti 30026, 'D', @counterDate, 2000000001, NULL, @object_name, @execution_count, @total_logical_reads, @total_logical_writes, @total_worker_time, @total_elapsed_time

      FETCH NEXT FROM @cursor INTO @object_name, @execution_count, @total_logical_reads, @total_logical_writes, @total_worker_time, @total_elapsed_time
    END
    CLOSE @cursor
    DEALLOCATE @cursor
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SaveProcStats'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_SaveFileStats') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SaveFileStats
GO
CREATE PROCEDURE zmetric.KeyCounters_SaveFileStats
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SaveFileStats') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30009 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30009 AND counterDate = @counterDate)
        RAISERROR ('File stats data exists', 16, 1)
    END

    -- FILE STATISTICS
    DECLARE @database_name nvarchar(200), @file_type nvarchar(20), @filegroup_name nvarchar(200),
            @reads bigint, @reads_kb bigint, @io_stall_read bigint, @writes bigint, @writes_kb bigint, @io_stall_write bigint, @size_kb bigint,
            @keyText nvarchar(450)

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT database_name = D.name,
                 file_type = CASE WHEN M.type_desc = 'ROWS' THEN 'DATA' ELSE M.type_desc END,
                 [filegroup_name] = F.name,
                 SUM(S.num_of_reads), SUM(S.num_of_bytes_read) / 1024, SUM(S.io_stall_read_ms),
                 SUM(S.num_of_writes), SUM(S.num_of_bytes_written) / 1024, SUM(S.io_stall_write_ms),
                 SUM(S.size_on_disk_bytes) / 1024
            FROM sys.dm_io_virtual_file_stats(NULL, NULL) S
              LEFT JOIN sys.databases D ON D.database_id = S.database_id
              LEFT JOIN sys.master_files M ON M.database_id = S.database_id AND M.[file_id] = S.[file_id]
                LEFT JOIN sys.filegroups F ON S.database_id = DB_ID() AND F.data_space_id = M.data_space_id
           GROUP BY D.name, M.type_desc, F.name
           ORDER BY database_name, M.type_desc DESC
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @database_name, @file_type, @filegroup_name, @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @keyText = @database_name + ' :: ' + ISNULL(@filegroup_name, @file_type)

      EXEC zmetric.KeyCounters_InsertMulti 30009, 'D', @counterDate, 2000000007, NULL, @keyText,  @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb

      FETCH NEXT FROM @cursor INTO @database_name, @file_type, @filegroup_name, @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb
    END
    CLOSE @cursor
    DEALLOCATE @cursor
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SaveFileStats'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_SaveWaitStats') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SaveWaitStats
GO
CREATE PROCEDURE zmetric.KeyCounters_SaveWaitStats
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SaveWaitStats') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30025 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30025 AND counterDate = @counterDate)
        RAISERROR ('Wait stats data exists', 16, 1)
    END

    -- WAIT STATISTICS
    DECLARE @wait_type nvarchar(100), @waiting_tasks_count bigint, @wait_time_ms bigint, @signal_wait_time_ms bigint

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms FROM sys.dm_os_wait_stats WHERE waiting_tasks_count > 0
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @wait_type, @waiting_tasks_count, @wait_time_ms, @signal_wait_time_ms
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC zmetric.KeyCounters_InsertMulti 30025, 'D', @counterDate, 2000000008, NULL, @wait_type,  @waiting_tasks_count, @wait_time_ms, @signal_wait_time_ms

      FETCH NEXT FROM @cursor INTO @wait_type, @waiting_tasks_count, @wait_time_ms, @signal_wait_time_ms
    END
    CLOSE @cursor
    DEALLOCATE @cursor
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SaveWaitStats'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_SavePerfCountersInstance') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SavePerfCountersInstance
GO
CREATE PROCEDURE zmetric.KeyCounters_SavePerfCountersInstance
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SavePerfCountersInstance') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30028 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30028 AND counterDate = @counterDate)
        RAISERROR ('Performance counters instance data exists', 16, 1)
    END

    -- PERFORMANCE COUNTERS INSTANCE
    DECLARE @object_name nvarchar(200), @counter_name nvarchar(200), @cntr_value bigint, @keyID int, @keyText nvarchar(450)

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT REPLACE(RTRIM([object_name]), 'SQLServer:', ''), RTRIM(counter_name), cntr_value
            FROM sys.dm_os_performance_counters
           WHERE cntr_type = 272696576 AND cntr_value != 0 AND instance_name = DB_NAME()
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @keyText = @object_name + ' :: ' + @counter_name

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, @keyText

      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30028, @counterDate, 0, @keyID, @cntr_value)

      FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    END
    CLOSE @cursor
    DEALLOCATE @cursor
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SavePerfCountersInstance'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.KeyCounters_SavePerfCountersTotal') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SavePerfCountersTotal
GO
CREATE PROCEDURE zmetric.KeyCounters_SavePerfCountersTotal
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SavePerfCountersTotal') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30027 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30027 AND counterDate = @counterDate)
        RAISERROR ('Performance counters total data exists', 16, 1)
    END

    -- PERFORMANCE COUNTERS TOTAL
    DECLARE @object_name nvarchar(200), @counter_name nvarchar(200), @cntr_value bigint, @keyID int, @keyText nvarchar(450)

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT REPLACE(RTRIM([object_name]), 'SQLServer:', ''),
                 CASE WHEN [object_name] = 'SQLServer:SQL Errors' THEN RTRIM(instance_name) ELSE RTRIM(counter_name) END,
                 cntr_value
            FROM sys.dm_os_performance_counters
           WHERE cntr_type = 272696576
             AND cntr_value != 0
             AND (    ([object_name] = 'SQLServer:Access Methods' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Buffer Manager' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:General Statistics' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Latches' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Access Methods' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:SQL Statistics' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Databases' AND instance_name = '_Total')
                   OR ([object_name] = 'SQLServer:Locks' AND instance_name = '_Total')
                   OR ([object_name] = 'SQLServer:SQL Errors' AND instance_name != '_Total')
                 )
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @keyText = @object_name + ' :: ' + @counter_name

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, @keyText

      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @cntr_value)

      FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    END
    CLOSE @cursor
    DEALLOCATE @cursor

    -- ADDING A FEW SYSTEM FUNCTIONS TO THE MIX
    DECLARE @pack_received int, @pack_sent int, @packet_errors int, @total_read int, @total_write int, @total_errors int
    SELECT @pack_received = @@PACK_RECEIVED, @pack_sent = @@PACK_SENT, @packet_errors = @@PACKET_ERRORS,
           @total_read = @@TOTAL_READ, @total_write = @@TOTAL_WRITE, @total_errors = @@TOTAL_ERRORS

    EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@PACK_RECEIVED'
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @pack_received)

    EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@PACK_SENT'
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @pack_sent)

    IF @packet_errors != 0
    BEGIN
      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@PACKET_ERRORS'
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @packet_errors)
    END

    EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@TOTAL_READ'
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @total_read)

    EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@TOTAL_WRITE'
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @total_write)

    IF @total_errors != 0
    BEGIN
      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@TOTAL_ERRORS'
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @total_errors)
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SavePerfCountersTotal'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.Counters_SaveStats') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_SaveStats
GO
CREATE PROCEDURE zmetric.Counters_SaveStats
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zmetric.KeyCounters_SaveIndexStats
  EXEC zmetric.KeyCounters_SaveProcStats
  EXEC zmetric.KeyCounters_SaveFileStats
  EXEC zmetric.KeyCounters_SaveWaitStats
  EXEC zmetric.KeyCounters_SavePerfCountersTotal
  EXEC zmetric.KeyCounters_SavePerfCountersInstance
GO


---------------------------------------------------------------------------------------------------------------------------------


-- migrate core data
if not exists(select * from zmetric.keyCounters where counterID > 30000) and OBJECT_ID('zmetric.columnCounters') is not null
begin
  -- core.db.indexStats
  insert into zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
       select counterID, counterDate, columnID, keyID, value from zmetric.columnCounters where counterID = 30007 order by counterID, counterDate, columnID, keyID
  delete from zmetric.columnCounters where counterID = 30007

  -- core.db.tableStats
  insert into zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
       select counterID, counterDate, columnID, keyID, value from zmetric.columnCounters where counterID = 30008 order by counterID, counterDate, columnID, keyID
  delete from zmetric.columnCounters where counterID = 30008

  -- core.db.fileStats
  insert into zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
       select counterID, counterDate, columnID, keyID, value from zmetric.columnCounters where counterID = 30009 order by counterID, counterDate, columnID, keyID
  delete from zmetric.columnCounters where counterID = 30009

  -- core.dbsvc.procStats
  insert into zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
       select counterID, counterDate, columnID, keyID, value from zmetric.columnCounters where counterID = 30004 order by counterID, columnID, keyID, counterDate
  delete from zmetric.columnCounters where counterID = 30004

  update statistics zmetric.keyCounters
  update statistics zmetric.keyCountersUnindexed
end
go


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.collectionCounters') IS NOT NULL
BEGIN
  if exists(select * from zmetric.collectionCounters)
    select * into _zmetric_collectionCounters_BEFORE_MINI_CORE_VERSION_3 from zmetric.collectionCounters
END
GO

IF OBJECT_ID('zmetric.collections') IS NOT NULL
BEGIN
  if exists(select * from zmetric.collections)
    select * into _zmetric_collections_BEFORE_MINI_CORE_VERSION_3 from zmetric.collections
END
GO

IF OBJECT_ID('zmetric.columnCounters') IS NOT NULL
BEGIN
  if exists(select * from zmetric.columnCounters)
    select * into _zmetric_columnCounters_BEFORE_MINI_CORE_VERSION_3 from zmetric.columnCounters
END
GO

IF OBJECT_ID('zmetric.timeCounters') IS NOT NULL
BEGIN
  if exists(select * from zmetric.timeCounters)
    select * into _zmetric_timeCounters_BEFORE_MINI_CORE_VERSION_3 from zmetric.timeCounters
END
GO


IF OBJECT_ID('zmetric.Counters_Report') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_Report
GO
IF OBJECT_ID('zmetric.ColumnCounters_SaveStats') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_SaveStats
GO
IF OBJECT_ID('zmetric.IndexStats_Mail') IS NOT NULL
  DROP PROCEDURE zmetric.IndexStats_Mail
GO
IF OBJECT_ID('zmetric.IndexStats_Save') IS NOT NULL
  DROP PROCEDURE zmetric.IndexStats_Save
GO
IF OBJECT_ID('zmetric.collectionCountersEx') IS NOT NULL
  DROP VIEW zmetric.collectionCountersEx
GO
IF OBJECT_ID('zmetric.collectionsEx') IS NOT NULL
  DROP VIEW zmetric.collectionsEx
GO
IF OBJECT_ID('zmetric.collectionCounters') IS NOT NULL
  DROP TABLE zmetric.collectionCounters
GO
IF OBJECT_ID('zmetric.collections') IS NOT NULL
  DROP TABLE zmetric.collections
GO

IF OBJECT_ID('zmetric.ColumnCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_Insert
GO
IF OBJECT_ID('zmetric.ColumnCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_Update
GO
IF OBJECT_ID('zmetric.ColumnCounters_UpdateMulti') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_UpdateMulti
GO
IF OBJECT_ID('zmetric.columnCountersEx') IS NOT NULL
  DROP VIEW zmetric.columnCountersEx
GO
IF OBJECT_ID('zmetric.columnCounters') IS NOT NULL
  DROP TABLE zmetric.columnCounters
GO
IF OBJECT_ID('zmetric.TimeCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.TimeCounters_Insert
GO
IF OBJECT_ID('zmetric.TimeCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.TimeCounters_Update
GO
IF OBJECT_ID('zmetric.timeCountersEx') IS NOT NULL
  DROP VIEW zmetric.timeCountersEx
GO
IF OBJECT_ID('zmetric.timeCounters') IS NOT NULL
  DROP TABLE zmetric.timeCounters
GO


---------------------------------------------------------------------------------------------------------------------------------



EXEC zsystem.Versions_Finish 'CORE.J', 0004, 'jorundur'
GO
