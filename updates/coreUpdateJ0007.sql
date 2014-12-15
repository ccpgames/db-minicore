
EXEC zsystem.Versions_Start 'CORE.J', 0007, 'jorundur'
GO



---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_Finish') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Finish
GO
CREATE PROCEDURE zsystem.Versions_Finish
  @developer  varchar(20),
  @version    int,
  @userName   nvarchar(100)
AS
  SET NOCOUNT ON

  IF EXISTS(SELECT *
              FROM zsystem.versions
             WHERE developer = @developer AND [version] = @version AND userName = @userName AND firstDuration IS NOT NULL)
  BEGIN
    PRINT ''
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    PRINT '!!! DATABASE UPDATE HAS BEEN EXECUTED BEFORE !!!'
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    UPDATE zsystem.versions
       SET executionCount = executionCount + 1, lastDate = GETUTCDATE(),
           lastLoginName = SUSER_SNAME(), lastDuration = DATEDIFF(second, lastDate, GETUTCDATE()), executingSPID = NULL
     WHERE developer = @developer AND [version] = @version
  END
  ELSE
  BEGIN
    DECLARE @coreVersion int
    IF @developer != 'CORE'
      SELECT @coreVersion = MAX([version]) FROM zsystem.versions WHERE developer = 'CORE'

    UPDATE zsystem.versions 
       SET executionCount = executionCount + 1, coreVersion = @coreVersion,
           firstDuration = DATEDIFF(second, versionDate, GETUTCDATE()), executingSPID = NULL
     WHERE developer = @developer AND [version] = @version
  END

  PRINT ''
  PRINT '[EXEC zsystem.Versions_Finish ''' + @developer + ''', ' + CONVERT(varchar, @version) + ', ''' + @userName + '''] has completed'
  PRINT ''

  DECLARE @recipients varchar(max)
  SET @recipients = zsystem.Settings_Value('zsystem', 'Recipients-Updates')
  IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
  BEGIN
    DECLARE @subject nvarchar(255), @body nvarchar(max)
    SET @subject = 'Database update ' + @developer + '-' + CONVERT(varchar, @version) + ' applied on ' + DB_NAME()
    SET @body = NCHAR(13) + @subject + NCHAR(13)
                + NCHAR(13) + '  Developer: ' + @developer
                + NCHAR(13) + '    Version: ' + CONVERT(varchar, @version)
                + NCHAR(13) + '       User: ' + @userName
                + NCHAR(13) + NCHAR(13)
                + NCHAR(13) + '   Database: ' + DB_NAME()
                + NCHAR(13) + '       Host: ' + HOST_NAME()
                + NCHAR(13) + '      Login: ' + SUSER_SNAME()
                + NCHAR(13) + 'Application: ' + APP_NAME()
    EXEC zsystem.SendMail @recipients, @subject, @body
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MailServerInfo') IS NOT NULL
  DROP FUNCTION zutil.MailServerInfo
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.TimeStringSeconds') IS NOT NULL
  DROP FUNCTION zutil.TimeStringSeconds
GO
CREATE FUNCTION zutil.TimeStringSeconds(@timeString varchar(20))
RETURNS int
BEGIN
  DECLARE @seconds int, @minutesSeconds char(5), @hours varchar(14)

  SET @minutesSeconds = RIGHT(@timeString, 5)
  SET @hours = LEFT(@timeString, LEN(@timeString) - 6)

  SET @seconds = CONVERT(int, RIGHT(@minutesSeconds, 2))
  SET @seconds = @seconds + (CONVERT(int, LEFT(@minutesSeconds, 2) * 60))
  SET @seconds = @seconds + (CONVERT(int, @hours * 3600))

  RETURN @seconds
END
GO
GRANT EXEC ON zutil.TimeStringSeconds TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.info') IS NOT NULL
  DROP PROCEDURE zdm.info
GO
CREATE PROCEDURE zdm.info
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
    PRINT '  zdm.info ''mountpoints'''
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
           [rows] = SUM(CASE WHEN I.index_id IN (0, 1) THEN P.row_count ELSE 0 END),
           total_kb = SUM(P.reserved_page_count * 8), used_kb = SUM(P.used_page_count * 8), data_kb = SUM(P.in_row_data_page_count * 8),
           create_date = MIN(CONVERT(datetime2(0), O.create_date)), modify_date = MIN(CONVERT(datetime2(0), O.modify_date))
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR LOWER(S.name + '.' + O.name) LIKE @filter)
     GROUP BY I.[object_id], S.name, O.name
     ORDER BY S.name, O.name
  END

  ELSE IF @info = 'indexes'
  BEGIN
    SELECT I.[object_id], I.index_id, index_type = I.type_desc, [object_name] = S.name + '.' + O.name, index_name = I.name,
           [rows] = SUM(P.row_count),
           total_kb = SUM(P.reserved_page_count * 8), used_kb = SUM(P.used_page_count * 8), data_kb = SUM(P.in_row_data_page_count * 8),
           [partitions] = COUNT(*), I.fill_factor
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(I.name) LIKE @filter))
     GROUP BY I.[object_id], I.index_id, I.type_desc, I.fill_factor, S.name, O.name, I.name
     ORDER BY S.name, O.name, I.index_id
  END

  ELSE IF @info = 'views'
  BEGIN
    SELECT O.[object_id], [object_name] = S.name + '.' + O.name,
           create_date = CONVERT(datetime2(0), O.create_date), modify_date = CONVERT(datetime2(0), O.modify_date)
      FROM sys.objects O
        INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
     WHERE O.type_desc = 'VIEW'
       AND (@filter = '' OR LOWER(S.name + '.' + O.name) LIKE @filter)
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

  ELSE IF @info = 'mountpoints'
  BEGIN
    SELECT DISTINCT volume_mount_point = UPPER(V.volume_mount_point), V.file_system_type, V.logical_volume_name,
           total_size_GB = CONVERT(DECIMAL(18,2), V.total_bytes / 1073741824.0),
           available_size_GB = CONVERT(DECIMAL(18,2), V.available_bytes / 1073741824.0),
           [space_free_%] = CONVERT(DECIMAL(18,2), CONVERT(float, V.available_bytes) / CONVERT(float, V.total_bytes)) * 100
      FROM sys.master_files AS F WITH (NOLOCK)
        CROSS APPLY sys.dm_os_volume_stats(F.database_id, F.file_id) AS V
     WHERE @filter = '' OR LOWER(V.volume_mount_point) LIKE @filter OR LOWER(V.logical_volume_name) LIKE @filter
     ORDER BY UPPER(V.volume_mount_point)
    OPTION (RECOMPILE);
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
           [rows] = SUM(P.row_count),
           total_kb = SUM(P.reserved_page_count * 8),
           user_seeks = MAX(U.user_seeks), user_scans = MAX(U.user_scans), user_lookups = MAX(U.user_lookups), user_updates = MAX(U.user_updates),
           [partitions] = COUNT(*)
      FROM sys.indexes I
        INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
        INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
        LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id = DB_ID() AND U.[object_id] = I.[object_id] AND U.index_id = I.index_id
     WHERE O.type_desc = 'USER_TABLE' AND O.is_ms_shipped = 0
       AND (@filter = '' OR (LOWER(S.name + '.' + O.name) LIKE @filter OR LOWER(I.name) LIKE @filter))
     GROUP BY I.[object_id], I.index_id, I.type_desc, S.name, O.name, I.name
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


IF OBJECT_ID('zdm.i') IS NOT NULL
  DROP SYNONYM zdm.i
GO
CREATE SYNONYM zdm.i FOR zdm.info
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.mountpoints') IS NOT NULL
  DROP PROCEDURE zdm.mountpoints
GO
CREATE PROCEDURE zdm.mountpoints
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'mountpoints', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.t') IS NOT NULL
  DROP SYNONYM zdm.t
GO
CREATE SYNONYM zdm.t FOR zdm.topsql
GO



IF OBJECT_ID('zdm.topsqlp') IS NOT NULL
  DROP PROCEDURE zdm.topsqlp
GO
CREATE PROCEDURE zdm.topsqlp
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0) = GETDATE()

  IF NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id != 0)
  BEGIN
    -- No blocking, light version
    SELECT TOP (@rows) P.query_plan, start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.TimeString(ABS(DATEDIFF(second, R.start_time, @now))),
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
    DECLARE @topsql TABLE
    (
      query_plan                 xml,
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
         SELECT TOP (@rows) P.query_plan, start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.TimeString(ABS(DATEDIFF(second, R.start_time, @now))),
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

    SELECT 'Blocking info' AS Info, query_plan, start_time, run_time, session_id, blocking_id, logical_reads,
            [host_name], [program_name], login_name, database_name, [object_name],
            [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
            total_elapsed_time, reads, writes,
            open_transaction_count, open_resultset_count, percent_complete, database_id,
            [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM @topsql
      WHERE blocking_id IN (select session_id FROM @topsql) OR session_id IN (select blocking_id FROM @topsql)
      ORDER BY blocking_id, session_id

    SELECT query_plan, start_time, run_time, session_id, blocking_id, logical_reads,
           [host_name], [program_name], login_name, database_name, [object_name],
           [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
           total_elapsed_time, reads, writes,
           open_transaction_count, open_resultset_count, percent_complete, database_id,
           [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM @topsql
     ORDER BY start_time
  END
GO


IF OBJECT_ID('zdm.tp') IS NOT NULL
  DROP SYNONYM zdm.tp
GO
CREATE SYNONYM zdm.tp FOR zdm.topsqlp
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MinInt') IS NOT NULL
  DROP FUNCTION zutil.MinInt
GO
CREATE FUNCTION zutil.MinInt(@value1 int, @value2 int)
RETURNS int
BEGIN
  DECLARE @i int
  IF @value1 < @value2
    SET @i = @value1
  ELSE
    SET @i = @value2
  RETURN @i
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MinFloat') IS NOT NULL
  DROP FUNCTION zutil.MinFloat
GO
CREATE FUNCTION zutil.MinFloat(@value1 float, @value2 float)
RETURNS float
BEGIN
  DECLARE @f float
  IF @value1 < @value2
    SET @f = @value1
  ELSE
    SET @f = @value2
  RETURN @f
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.StringListToTable') IS NOT NULL
  DROP FUNCTION zutil.StringListToTable
GO
IF OBJECT_ID('zutil.StringListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.StringListToOrderedTable
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' AND [key] = 'EventsFilter')
  INSERT INTO zsystem.settings ([group], [key], [value], [description], defaultValue)
       VALUES ('zsystem', 'EventsFilter', '', 'Filter to use when listing zsystem.events using zsystem.Events_Select.  Note that the function system.Events_AppFilter needs to be added to implement the filter.', '')
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Events_Select
GO
CREATE PROCEDURE zsystem.Events_Select
  @filter   varchar(50) = '',
  @rows     smallint = 1000,
  @eventID  int = NULL,
  @text     nvarchar(450) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @eventID IS NULL SET @eventID = 2147483647

  DECLARE @stmt nvarchar(max)

  SET @stmt = 'SELECT TOP (@pRows) * FROM zsystem.eventsEx WHERE eventID < @pEventID'


  -- Application Hook!
  IF @filter != '' AND OBJECT_ID('system.Events_AppFilter') IS NOT NULL
  BEGIN
    DECLARE @where nvarchar(max)
    EXEC sp_executesql N'SELECT @p_where = system.Events_AppFilter(@p_filter)', N'@p_where nvarchar(max) OUTPUT, @p_filter varchar(50)', @where OUTPUT, @filter
    SET @stmt += @where
  END

  IF @text IS NOT NULL
  BEGIN
    SET @text = '%' + LOWER(@text) + '%'
    SET @stmt += ' AND (LOWER(eventTypeName) LIKE @pText OR taskName LIKE @pText OR fixedText LIKE @pText OR LOWER(eventText) LIKE @pText)'
  END

  SET @stmt += ' ORDER BY eventID DESC'

  EXEC sp_executesql @stmt, N'@pRows smallint, @pEventID int, @pText nvarchar(450)', @pRows = @rows, @pEventID = @eventID, @pText = @text
GO
GRANT EXEC ON zsystem.Events_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_SelectByEvent') IS NOT NULL
  DROP PROCEDURE zsystem.Events_SelectByEvent
GO
CREATE PROCEDURE zsystem.Events_SelectByEvent
  @eventID  int
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    DECLARE @eventDate datetime2(0), @parentID int
    SELECT @eventDate = eventDate, @parentID = parentID FROM zsystem.events WHERE eventID = @eventID
    IF @eventDate IS NULL
      RAISERROR ('Event not found', 16, 1)

    -- Setting from/to interval to 3 days, 1 day before and 1 day after
    DECLARE @fromID int, @toID int
    SET @fromID = zsystem.Identities_Int(2000100014, @eventDate, -1, 0)
    IF @fromID < 0
      RAISERROR ('Identity not found', 16, 1)
    SET @toID = zsystem.Identities_Int(2000100014, @eventDate, 2, 0) - 1
    IF @toID < 0 SET @toID = 2147483647

    -- Table for events returned
    DECLARE @events TABLE (eventID int NOT NULL PRIMARY KEY, eventLevel int NULL)

    -- Find top level parent event
    IF @parentID IS NOT NULL
    BEGIN
      DECLARE @nextParentID int = 0, @c tinyint = 0, @masterID int
      WHILE 1 = 1
      BEGIN
        SET @nextParentID = NULL
        SELECT @nextParentID = parentID FROM zsystem.events WHERE eventID = @parentID
        IF @nextParentID IS NULL
        BEGIN
          SET @masterID = @parentID
          BREAK
        END
        SET @parentID = @nextParentID
        SET @c += 1
        IF @c > 30
        BEGIN
          RAISERROR ('Recursion > 30 in search for master eventID', 16, 1)
          RETURN -1
        END
      END
      SET @eventID = @masterID
    END

    -- Initialize @events table with top level event(s)
    DECLARE @eventTypeID int, @referenceID int, @duration int
    DECLARE @startedEventID int, @completedEventID int
    SELECT @eventTypeID = eventTypeID, @referenceID = referenceID, @duration = duration FROM zsystem.events WHERE eventID = @eventID
    IF @eventTypeID IS NULL
      RAISERROR ('Event not found', 16, 1)
    IF @eventTypeID NOT BETWEEN 2000001001 AND 2000001004 -- Task started/info/completed/ERROR
    BEGIN
      -- Not a task event, simple initialize
      INSERT INTO @events (eventID, eventLevel) VALUES (@eventID, 1)
      SET @startedEventID = @eventID
      SET @completedEventID = @toID
    END
    ELSE
    BEGIN
      -- Find started and completed events
      IF @eventTypeID = 2000001001 -- Task started
      BEGIN
        SET @startedEventID = @eventID
        SET @referenceID = @eventID
      END
      ELSE
      BEGIN
        IF ISNULL(@referenceID, 0) > 0
          SET @startedEventID = @referenceID
        ELSE
        BEGIN
          SET @startedEventID = @eventID
          SET @referenceID = @eventID
        END
      END
      IF @eventTypeID = 2000001003 OR (@eventTypeID = 2000001004 AND @duration IS NOT NULL) -- Task completed / Task ERROR with duration set
        SET @completedEventID = @eventID
      ELSE
      BEGIN
        -- Find the completed event
        SELECT TOP 1 @completedEventID = eventID
          FROM zsystem.events
          WHERE eventID BETWEEN @eventID AND @toID
            AND (eventTypeID = 2000001003 OR (eventTypeID = 2000001004 AND duration IS NOT NULL)) AND referenceID = @referenceID
          ORDER BY eventID

        IF @completedEventID IS NULL
          SET @completedEventID = @toID
      END
      INSERT INTO @events (eventID, eventLevel)
           SELECT eventID, 1
             FROM zsystem.events
            WHERE eventID BETWEEN @startedEventID AND @completedEventID AND (eventID = @referenceID OR referenceID = @referenceID)
    END

    -- Recursively add child events
    DECLARE @eventLevel int = 1
    WHILE @eventLevel < 20
    BEGIN
      INSERT INTO @events (eventID, eventLevel)
           SELECT eventID, @eventLevel + 1
             FROM zsystem.events
            WHERE eventID BETWEEN @startedEventID AND @completedEventID AND parentID IN (SELECT eventID FROM @events WHERE eventLevel = @eventLevel)
      IF @@ROWCOUNT = 0
        BREAK
      SET @eventLevel += 1
    END

    -- Return all top level and child events
    SELECT X.eventLevel, E.*
      FROM @events X
        INNER JOIN zsystem.eventsEx E ON E.eventID = X.eventID
     ORDER BY E.eventID DESC
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.Events_SelectByEvent'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.Events_SelectByEvent TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Settings_Update
  @group              varchar(200), 
  @key                varchar(200), 
  @value              nvarchar(max),
  @userID             int = NULL,
  @insertIfNotExists  bit = 0
AS
  SET NOCOUNT ON

  BEGIN TRY
    DECLARE @allowUpdate bit
    SELECT @allowUpdate = allowUpdate FROM zsystem.settings WHERE [group] = @group AND [key] = @key
    IF @allowUpdate IS NULL AND @insertIfNotExists = 0
      RAISERROR ('Setting not found', 16, 1)
    IF @allowUpdate = 0 AND @insertIfNotExists = 0
      RAISERROR ('Update not allowed', 16, 1)

    DECLARE @fixedText nvarchar(450) = @group + '.' + @key

    BEGIN TRANSACTION

    IF @allowUpdate IS NULL AND @insertIfNotExists = 1
    BEGIN
      INSERT INTO zsystem.settings ([group], [key], value, [description]) VALUES (@group, @key, @value, '')

      EXEC zsystem.Events_Insert 2000000032, NULL, @userID, @fixedText=@fixedText, @eventText=@value
    END
    ELSE
    BEGIN
      UPDATE zsystem.settings
          SET value = @value
        WHERE [group] = @group AND [key] = @key AND [value] != @value
      IF @@ROWCOUNT > 0
        EXEC zsystem.Events_Insert 2000000031, NULL, @userID, @fixedText=@fixedText, @eventText=@value
    END

    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION
    EXEC zsystem.CatchError 'zsystem.Settings_Update'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.counters') AND [name] = 'autoDeleteMaxDays')
  ALTER TABLE zmetric.counters ADD autoDeleteMaxDays smallint NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30007 AND autoDeleteMaxDays IS NULL
UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30008 AND autoDeleteMaxDays IS NULL
UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30009 AND autoDeleteMaxDays IS NULL
UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30025 AND autoDeleteMaxDays IS NULL
UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30026 AND autoDeleteMaxDays IS NULL
UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30027 AND autoDeleteMaxDays IS NULL
UPDATE zmetric.counters SET autoDeleteMaxDays = 500 WHERE counterID = 30028 AND autoDeleteMaxDays IS NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'AutoDeleteMaxRows')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'AutoDeleteMaxRows', '50000', '50000', 'Max rows to delete when zmetric.counters.autoDeleteMaxDays (set to "0" to disable).  See proc zmetric.Counters_SaveStats.')
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

  --
  -- Auto delete old data
  --
  DECLARE @autoDeleteMaxRows int = zsystem.Settings_Value('zmetric', 'AutoDeleteMaxRows')
  IF @autoDeleteMaxRows < 1
    RETURN

  DECLARE @counterDate date, @counterDateTime datetime2(0)

  DECLARE @counterID smallint, @counterTable nvarchar(256), @autoDeleteMaxDays smallint

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT counterID, counterTable, autoDeleteMaxDays FROM zmetric.counters WHERE autoDeleteMaxDays > 0 ORDER BY counterID
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @counterID, @counterTable, @autoDeleteMaxDays
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @counterDate = DATEADD(day, -@autoDeleteMaxDays, GETDATE())
    SET @counterDateTime = @counterDate

    IF @counterTable = 'zmetric.keyCounters'
    BEGIN
      DELETE TOP (@autoDeleteMaxRows) FROM zmetric.keyCounters WHERE counterID = @counterID AND counterDate < @counterDate
      DELETE TOP (@autoDeleteMaxRows) FROM zmetric.keyTimeCounters WHERE counterID = @counterID AND counterDate < @counterDateTime
    END
    ELSE IF @counterTable = 'zmetric.subjectKeyCounters'
      DELETE TOP (@autoDeleteMaxRows) FROM zmetric.subjectKeyCounters WHERE counterID = @counterID AND counterDate < @counterDate
    ELSE IF @counterTable = 'zmetric.simpleCounters'
      DELETE TOP (@autoDeleteMaxRows) FROM zmetric.simpleCounters WHERE counterID = @counterID AND counterDate < @counterDateTime

    FETCH NEXT FROM @cursor INTO @counterID, @counterTable, @autoDeleteMaxDays
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO




---------------------------------------------------------------------------------------------------------------------------------


DELETE FROM zmetric.columns WHERE counterID = 30004
DELETE FROM zmetric.counters WHERE counterID = 30004
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ExecJob') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ExecJob
GO
IF OBJECT_ID('zsystem.Events_ProcStarted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcStarted
GO
IF OBJECT_ID('zsystem.Events_ProcCompleted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcCompleted
GO
IF OBJECT_ID('zsystem.Events_ProcInfo') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcInfo
GO
IF OBJECT_ID('zsystem.Events_ProcError') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcError
GO

IF OBJECT_ID('zsystem.Procedures_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Procedures_Select
GO
IF OBJECT_ID('zsystem.proceduresEx') IS NOT NULL
  DROP VIEW zsystem.proceduresEx
GO
IF OBJECT_ID('zsystem.procedures') IS NOT NULL
  DROP TABLE zsystem.procedures
GO

IF OBJECT_ID('zmetric.KeyCountersUnindexed_Update') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCountersUnindexed_Update
GO
IF OBJECT_ID('zmetric.KeyCountersUnindexed_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCountersUnindexed_Insert
GO
IF OBJECT_ID('zmetric.keyCountersUnindexedEx') IS NOT NULL
  DROP VIEW zmetric.keyCountersUnindexedEx
GO
IF OBJECT_ID('zmetric.keyCountersUnindexed') IS NOT NULL
  DROP TABLE zmetric.keyCountersUnindexed
GO


---------------------------------------------------------------------------------------------------------------------------------



EXEC zsystem.Versions_Finish 'CORE.J', 0007, 'jorundur'
GO
