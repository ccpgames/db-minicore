
EXEC zsystem.Versions_Start 'CORE.J', 0005, 'jorundur'
GO



---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.SendMail') IS NOT NULL
  DROP PROCEDURE zsystem.SendMail
GO
CREATE PROCEDURE zsystem.SendMail
  @recipients   varchar(max),
  @subject      nvarchar(255),
  @body         nvarchar(max),
  @body_format  varchar(20) = NULL
AS
  SET NOCOUNT ON

  -- Azure does not support msdb.dbo.sp_send_dbmail
  IF CONVERT(varchar(max), SERVERPROPERTY('edition')) NOT LIKE '%Azure%'
  BEGIN
    EXEC sp_executesql N'EXEC msdb.dbo.sp_send_dbmail NULL, @p_recipients, NULL, NULL, @p_subject, @p_body, @p_body_format',
                       N'@p_recipients varchar(max), @p_subject nvarchar(255), @p_body nvarchar(max), @p_body_format  varchar(20)',
                       @p_recipients = @recipients, @p_subject = @subject, @p_body = @body, @p_body_format = @body_format
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_Start') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Start
GO
CREATE PROCEDURE zsystem.Versions_Start
  @developer  nvarchar(20),
  @version    int,
  @userName   nvarchar(100)
AS
  SET NOCOUNT ON

  DECLARE @currentVersion int
  SELECT @currentVersion = MAX([version]) FROM zsystem.versions WHERE developer = @developer
  IF @currentVersion != @version - 1
  BEGIN
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    PRINT '!!! DATABASE NOT OF CORRECT VERSION !!!'
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  END

  IF NOT EXISTS(SELECT * FROM zsystem.versions WHERE developer = @developer AND [version] = @version)
  BEGIN
    INSERT INTO zsystem.versions (developer, [version], versionDate, userName, loginName, executionCount, executingSPID)
         VALUES (@developer, @version, GETUTCDATE(), @userName, SUSER_SNAME(), 0, @@SPID)
  END
  ELSE
  BEGIN
    UPDATE zsystem.versions 
       SET lastDate = GETUTCDATE(), executingSPID = @@SPID 
     WHERE developer = @developer AND [version] = @version
  END
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
                + zutil.MailServerInfo()
    EXEC zsystem.SendMail @recipients, @subject, @body
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.PrintMax') IS NOT NULL
  DROP PROCEDURE zsystem.PrintMax
GO
CREATE PROCEDURE zsystem.PrintMax
  @str  nvarchar(max)
AS
  SET NOCOUNT ON

  IF @str IS NULL
    RETURN

  WHILE (LEN(@str) > 4000)
  BEGIN
    PRINT LEFT(@str, 4000)
    SET @str = SUBSTRING(@str, 4001, LEN(@str) - 4000)
  END
  PRINT @str
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.SendLongRunningMail') IS NOT NULL
  DROP PROCEDURE zdm.SendLongRunningMail
GO
CREATE PROCEDURE zdm.SendLongRunningMail
  @minutes  smallint = 10,
  @rows     tinyint = 10
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @recipients varchar(max)
  SET @recipients = zsystem.Settings_Value('zdm', 'Recipients-LongRunning')
  IF @recipients = '' RETURN

  DECLARE @ignoreSQL nvarchar(max)
  SET @ignoreSQL = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL')

  DECLARE @session_id int, @start_time datetime2(0), @text nvarchar(max)

  DECLARE @stmt nvarchar(max), @cursor CURSOR
  SET @stmt = '
SET @p_cursor = CURSOR LOCAL FAST_FORWARD
  FOR SELECT TOP (@p_rows) R.session_id, R.start_time, S.[text]
        FROM sys.dm_exec_requests R
          CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) S
       WHERE R.session_id != @@SPID AND R.start_time < DATEADD(minute, -@p_minutes, GETDATE())'
  IF @ignoreSQL != ''
    SELECT @stmt = @stmt + ' AND S.[text] NOT LIKE ''' + string + '''' FROM zutil.CharListToTable(@ignoreSQL)
  SET @stmt = @stmt + '
         ORDER BY R.start_time
OPEN @p_cursor'

  EXEC sp_executesql @stmt, N'@p_cursor CURSOR OUTPUT, @p_rows tinyint, @p_minutes smallint', @cursor OUTPUT, @rows, @minutes
  FETCH NEXT FROM @cursor INTO @session_id, @start_time, @text
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @text = CHAR(13) + '   getdate: ' + CONVERT(nvarchar, GETDATE(), 120)
              + CHAR(13) + 'start_time: ' + CONVERT(nvarchar, @start_time, 120)
              + CHAR(13) + 'session_id: ' + CONVERT(nvarchar, @session_id)
              + CHAR(13) + CHAR(13) + @text
    EXEC zsystem.SendMail @recipients, 'LONG RUNNING SQL', @text

    FETCH NEXT FROM @cursor INTO @session_id, @start_time, @text
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.describe') IS NOT NULL
  DROP PROCEDURE zdm.describe
GO
CREATE PROCEDURE zdm.describe
  @objectName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @schemaID int, @schemaName nvarchar(128), @objectID int,
          @type char(2), @typeDesc nvarchar(60),
          @createDate datetime2(0), @modifyDate datetime2(0), @isMsShipped bit,
          @i int, @text nvarchar(max), @parentID int

  SET @i = CHARINDEX('.', @objectName)
  IF @i > 0
  BEGIN
    SET @schemaName = SUBSTRING(@objectName, 1, @i - 1)
    SET @objectName = SUBSTRING(@objectName, @i + 1, 256)
    IF CHARINDEX('.', @objectName) > 0
    BEGIN
      RAISERROR ('Object name invalid', 16, 1)
      RETURN -1
    END

    SELECT @schemaID = [schema_id] FROM sys.schemas WHERE LOWER(name) = LOWER(@schemaName)
    IF @schemaID IS NULL
    BEGIN
      RAISERROR ('Schema not found', 16, 1)
      RETURN -1
    END
  END

  IF @schemaID IS NULL
  BEGIN
    SELECT TOP 2 @objectID = [object_id], @type = [type], @typeDesc = type_desc,
                 @createDate = create_date, @modifyDate = modify_date, @isMsShipped = is_ms_shipped
      FROM sys.objects
     WHERE LOWER(name) = LOWER(@objectName)
  END
  ELSE
  BEGIN
    SELECT TOP 2 @objectID = [object_id], @type = [type], @typeDesc = type_desc,
                 @createDate = create_date, @modifyDate = modify_date, @isMsShipped = is_ms_shipped
      FROM sys.objects
     WHERE [schema_id] = @schemaID AND LOWER(name) = LOWER(@objectName)
  END
  IF @@ROWCOUNT = 1
  BEGIN
    IF @schemaID IS NULL
      SELECT @schemaID = [schema_id] FROM sys.objects WHERE [object_id] = @objectID
    IF @schemaName IS NULL
      SELECT @schemaName = name FROM sys.schemas WHERE [schema_id] = @schemaID

    IF @type IN ('V', 'P', 'FN', 'IF') -- View, Procedure, Scalar Function, Table Function
    BEGIN
      PRINT ''
      SET @text = OBJECT_DEFINITION(OBJECT_ID(@schemaName + '.' + @objectName))
      EXEC zsystem.PrintMax @text
    END
    ELSE IF @type = 'C' -- Check Constraint
    BEGIN
      PRINT ''
      SELECT @text = [definition], @parentID = parent_object_id
        FROM sys.check_constraints
       WHERE [object_id] = @objectID
      EXEC zsystem.PrintMax @text
    END
    ELSE IF @type = 'D' -- Default Constraint
    BEGIN
      PRINT ''
      SELECT @text = C.name + ' = ' + DC.[definition], @parentID = DC.parent_object_id
        FROM sys.default_constraints DC
          INNER JOIN sys.columns C ON C.[object_id] = DC.parent_object_id AND C.column_id = DC.parent_column_id
       WHERE DC.[object_id] = @objectID
      EXEC zsystem.PrintMax @text
    END
    ELSE IF @type IN ('U', 'IT', 'S', 'PK') -- User Table, Internal Table, System Table, Primary Key
    BEGIN
      DECLARE @tableID int, @rows bigint
      IF @type = 'PK' -- Primary Key
      BEGIN
        SELECT [object_id], [object_name] = @schemaName + '.' + @objectName, [type], type_desc, create_date, modify_date, is_ms_shipped, parent_object_id
          FROM sys.objects
         WHERE [object_id] = @objectID

        SELECT @parentID = parent_object_id FROM sys.objects  WHERE [object_id] = @objectID
        SET @tableID = @parentID
      END
      ELSE
        SET @tableID = @objectID

      SELECT @rows = SUM(P.row_count)
        FROM sys.indexes I
          INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
       WHERE I.[object_id] = @tableID AND I.index_id IN (0, 1)

      SELECT [object_id], [object_name] = @schemaName + '.' + @objectName, [type], type_desc, [rows] = @rows, create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [object_id] = @tableID

      SELECT C.column_id, column_name = C.name, [type_name] = TYPE_NAME(C.system_type_id), C.max_length, C.[precision], C.scale,
             C.collation_name, C.is_nullable, C.is_identity, [default] = D.[definition]
        FROM sys.columns C
          LEFT JOIN sys.default_constraints D ON D.parent_object_id = C.[object_id] AND D.parent_column_id = C.column_id
       WHERE C.[object_id] = @tableID
       ORDER BY C.column_id

      SELECT index_id, index_name = name, [type], type_desc, is_unique, is_primary_key, is_unique_constraint, has_filter, fill_factor, has_filter, filter_definition
        FROM sys.indexes
       WHERE [object_id] = @tableID
       ORDER BY index_id

      SELECT index_name = I.name, IC.key_ordinal, column_name = C.name, IC.is_included_column
        FROM sys.indexes I
          INNER JOIN sys.index_columns IC ON IC.[object_id] = I.[object_id] AND IC.index_id = I.index_id
            INNER JOIN sys.columns C ON C.[object_id] = IC.[object_id] AND C.column_id = IC.column_id
       WHERE I.[object_id] = @tableID
       ORDER BY I.index_id, IC.key_ordinal
    END
    ELSE
    BEGIN
      PRINT ''
      PRINT 'EXTRA INFORMATION NOT AVAILABLE FOR THIS TYPE OF OBJECT!'
    END

    IF @type NOT IN ('U', 'IT', 'S', 'PK')
    BEGIN
      PRINT REPLICATE('_', 100)
      IF @isMsShipped = 1
        PRINT 'THIS IS A MICROSOFT OBJECT'

      IF @parentID IS NOT NULL
        PRINT '  PARENT: ' + OBJECT_SCHEMA_NAME(@parentID) + '.' + OBJECT_NAME(@parentID)

      PRINT '    Name: ' + @schemaName + '.' + @objectName
      PRINT '    Type: ' + @typeDesc
      PRINT ' Created: ' + CONVERT(varchar, @createDate, 120)
      PRINT 'Modified: ' + CONVERT(varchar, @modifyDate, 120)
    END
  END
  ELSE
  BEGIN
    IF @schemaID IS NULL
    BEGIN
      SELECT O.[object_id], [object_name] = S.name + '.' + O.name, O.[type], O.type_desc, O.parent_object_id,
             O.create_date, O.modify_date, O.is_ms_shipped
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE LOWER(O.name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY CASE O.[type] WHEN 'U' THEN '_A' WHEN 'V' THEN '_B' WHEN 'P' THEN '_C' WHEN 'FN' THEN '_D' WHEN 'IF' THEN '_E' WHEN 'PK' THEN '_F' ELSE O.[type] END,
                LOWER(S.name), LOWER(O.name)
    END
    ELSE
    BEGIN
      SELECT [object_id], [object_name] = @schemaName + '.' + name, [type], type_desc, parent_object_id,
             create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [schema_id] = @schemaID AND LOWER(name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY CASE [type] WHEN 'U' THEN '_A' WHEN 'V' THEN '_B' WHEN 'P' THEN '_C' WHEN 'FN' THEN '_D' WHEN 'IF' THEN '_E' WHEN 'PK' THEN '_F' ELSE [type] END,
                LOWER(name)
    END
  END
GO


IF OBJECT_ID('zdm.d') IS NOT NULL
  DROP SYNONYM zdm.d
GO
CREATE SYNONYM zdm.d FOR zdm.describe
GO


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


---------------------------------------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.topsql') IS NOT NULL
  DROP PROCEDURE zdm.topsql
GO
CREATE PROCEDURE zdm.topsql
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
GRANT EXEC ON zdm.topsql TO zzp_server
GO


IF OBJECT_ID('zdm.t') IS NOT NULL
  DROP SYNONYM zdm.t
GO
CREATE SYNONYM zdm.t FOR zdm.topsql
GO


---------------------------------------------------------------------------------------------------------------------------------


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


IF OBJECT_ID('zdm.StartTrace') IS NOT NULL
  DROP PROCEDURE zdm.StartTrace
GO
CREATE PROCEDURE zdm.StartTrace
  @fileName         nvarchar(200),
  @minutes          smallint,
  @duration         bigint = NULL,
  @reads            bigint = NULL,
  @writes           bigint = NULL,
  @cpu              int = NULL,
  @rowCounts        bigint = NULL,
  @objectName       nvarchar(100) = NULL,
  @hostName         nvarchar(100) = NULL,
  @clientProcessID  nvarchar(100) = NULL,
  @databaseName     nvarchar(100) = NULL,
  @loginName        nvarchar(100) = NULL,
  @logicalOperator  int = 0,
  @maxFileSize      bigint = 4096
AS
  SET NOCOUNT ON

  -- Create trace
  DECLARE @rc int, @traceID int, @stopTime datetime2(0)
  SET @stopTime = DATEADD(minute, @minutes, GETDATE())
  EXEC @rc = sp_trace_create @traceID OUTPUT, 0, @fileName, @maxFileSize, @stopTime
  IF @rc != 0
  BEGIN
    RAISERROR ('Error in sp_trace_create (ErrorCode = %d)', 16, 1, @rc)
    RETURN -1
  END

  -- Event: RPC:Completed
  DECLARE @off bit, @on bit
  SELECT @off = 0, @on = 1
  EXEC sp_trace_setevent @traceID, 10, 14, @on  -- StartTime
  EXEC sp_trace_setevent @traceID, 10, 15, @on  -- EndTime
  EXEC sp_trace_setevent @traceID, 10, 34, @on  -- ObjectName
  EXEC sp_trace_setevent @traceID, 10,  1, @on  -- TextData
  EXEC sp_trace_setevent @traceID, 10, 13, @on  -- Duration
  EXEC sp_trace_setevent @traceID, 10, 16, @on  -- Reads
  EXEC sp_trace_setevent @traceID, 10, 17, @on  -- Writes
  EXEC sp_trace_setevent @traceID, 10, 18, @on  -- CPU
  EXEC sp_trace_setevent @traceID, 10, 48, @on  -- RowCounts
  EXEC sp_trace_setevent @traceID, 10,  8, @on  -- HostName
  EXEC sp_trace_setevent @traceID, 10,  9, @on  -- ClientProcessID
  EXEC sp_trace_setevent @traceID, 10, 12, @on  -- SPID
  EXEC sp_trace_setevent @traceID, 10, 10, @on  -- ApplicationName
  EXEC sp_trace_setevent @traceID, 10, 11, @on  -- LoginName
  EXEC sp_trace_setevent @traceID, 10, 35, @on  -- DatabaseName
  EXEC sp_trace_setevent @traceID, 10, 31, @on  -- Error

  -- Event: SQL:BatchCompleted
  IF @objectName IS NULL
  BEGIN
    EXEC sp_trace_setevent @traceID, 12, 14, @on  -- StartTime
    EXEC sp_trace_setevent @traceID, 12, 15, @on  -- EndTime
    EXEC sp_trace_setevent @traceID, 12, 34, @on  -- ObjectName
    EXEC sp_trace_setevent @traceID, 12,  1, @on  -- TextData
    EXEC sp_trace_setevent @traceID, 12, 13, @on  -- Duration
    EXEC sp_trace_setevent @traceID, 12, 16, @on  -- Reads
    EXEC sp_trace_setevent @traceID, 12, 17, @on  -- Writes
    EXEC sp_trace_setevent @traceID, 12, 18, @on  -- CPU
    EXEC sp_trace_setevent @traceID, 12, 48, @on  -- RowCounts
    EXEC sp_trace_setevent @traceID, 12,  8, @on  -- HostName
    EXEC sp_trace_setevent @traceID, 12,  9, @on  -- ClientProcessID
    EXEC sp_trace_setevent @traceID, 12, 12, @on  -- SPID
    EXEC sp_trace_setevent @traceID, 12, 10, @on  -- ApplicationName
    EXEC sp_trace_setevent @traceID, 12, 11, @on  -- LoginName
    EXEC sp_trace_setevent @traceID, 12, 35, @on  -- DatabaseName
    EXEC sp_trace_setevent @traceID, 12, 31, @on  -- Error
  END

  -- Filter: Duration
  IF @duration > 0
  BEGIN
    SET @duration = @duration * 1000
    EXEC sp_trace_setfilter @traceID, 13, @logicalOperator, 4, @duration
  END
  -- Filter: Reads
  IF @reads > 0
    EXEC sp_trace_setfilter @traceID, 16, @logicalOperator, 4, @reads
  -- Filter: Writes
  IF @writes > 0
    EXEC sp_trace_setfilter @traceID, 17, @logicalOperator, 4, @writes
  -- Filter: CPU
  IF @cpu > 0
    EXEC sp_trace_setfilter @traceID, 18, @logicalOperator, 4, @cpu
  -- Filter: RowCounts
  IF @rowCounts > 0
    EXEC sp_trace_setfilter @traceID, 48, @logicalOperator, 4, @rowCounts
  -- Filter: ObjectName
  IF @objectName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 34, @logicalOperator, 6, @objectName
  -- Filter: HostName
  IF @hostName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 8, @logicalOperator, 6, @hostName
  -- Filter: ClientProcessID
  IF @clientProcessID > 0
    EXEC sp_trace_setfilter @traceID, 9, @logicalOperator, 0, @clientProcessID
  -- Filter: DatabaseName
  IF @databaseName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 35, @logicalOperator, 6, @databaseName
  -- Filter: LoginName
  IF @loginName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 11, @logicalOperator, 6, @loginName

  -- Start trace
  EXEC sp_trace_setstatus @traceID, 1

  -- Return traceID and some extra help info
  SELECT traceID = @traceID,
         [To list active traces] = 'SELECT * FROM sys.traces',
         [To stop trace before minutes are up] = 'EXEC sp_trace_setstatus ' + CONVERT(varchar, @traceID) + ', 0;EXEC sp_trace_setstatus ' + CONVERT(varchar, @traceID) + ', 2'
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001001)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001001, 'Task started', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001002)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001002, 'Task info', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001003)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001003, 'Task completed', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001004)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001004, 'Task ERROR', '')
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.events') AND [name] = 'taskID')
  ALTER TABLE zsystem.events ADD taskID int NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.events') AND [name] = 'textID')
  ALTER TABLE zsystem.events ADD textID int NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


-- *** taskID under 100 mills are reserved for fixed taskID's                                                    ***
-- *** taksID over 100 mills are automagically generated from taskName if taskName used not found over 100 mills ***

IF OBJECT_ID('zsystem.tasks') IS NULL
BEGIN
  CREATE TABLE zsystem.tasks
  (
    taskID         int                                          NOT NULL,
    taskName       nvarchar(450)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]  nvarchar(max)                                NULL,
    --
    CONSTRAINT tasks_PK PRIMARY KEY CLUSTERED (taskID)
  )

  CREATE NONCLUSTERED INDEX tasks_IX_Name ON zsystem.tasks (taskName)
END
GRANT SELECT ON zsystem.tasks TO zzp_server
GO


IF NOT EXISTS(SELECT * FROM zsystem.tasks WHERE taskID = 100000000)
  INSERT INTO zsystem.tasks (taskID, taskName, [description])
       VALUES (100000000, 'DUMMY TASK - 100 MILLS', 'A dummy task to make MAX(taskID) start over 100 mills')
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
  @date_1       date = NULL,
  @taskID       int = NULL,
  @textID       int = NULL,
  @fixedText    nvarchar(450) = NULL
AS
  SET NOCOUNT ON

  DECLARE @eventID int

  IF @textID IS NULL AND @fixedText IS NOT NULL
    EXEC @textID = zsystem.Texts_ID @fixedText

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText, referenceID, date_1, taskID, textID)
       VALUES (@eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @referenceID, @date_1, @taskID, @textID)

  SET @eventID = SCOPE_IDENTITY()

  IF @returnRow = 1
    SELECT eventID = @eventID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Tasks_DynamicID') IS NOT NULL
  DROP PROCEDURE zsystem.Tasks_DynamicID
GO
CREATE PROCEDURE zsystem.Tasks_DynamicID
  @taskName  nvarchar(450)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @taskID int
  SELECT @taskID = taskID FROM zsystem.tasks WHERE taskName = @taskName AND taskID > 100000000
  IF @taskID IS NULL
  BEGIN
    SELECT @taskID = MAX(taskID) + 1 FROM zsystem.tasks

    INSERT INTO zsystem.tasks (taskID, taskName) VALUES (@taskID, @taskName)
  END
  RETURN @taskID
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Update taskID for old PROCEDURE events in zsystem.events
  SET NOCOUNT ON

  declare @procedures table (procedureID int)
  insert into @procedures (procedureID)
       select distinct int_1 from zsystem.events where eventTypeID between 2000000001 and 2000000004 and taskID is null

  DECLARE @procedureID int, @taskName nvarchar(450), @taskID int

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT procedureID, fullName FROM zsystem.proceduresEx WHERE procedureID IN (SELECT procedureID FROM @procedures)
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @procedureID, @taskName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

    UPDATE zsystem.events SET taskID = @taskID WHERE eventTypeID BETWEEN 2000000001 and 2000000004 AND int_1 = @procedureID AND taskID IS NULL

    FETCH NEXT FROM @cursor INTO @procedureID, @taskName
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  SET NOCOUNT OFF
GO


-- Update taskID for old JOB events in zsystem.events
  SET NOCOUNT ON

  declare @jobs table (jobID int)
  insert into @jobs (jobID)
       select distinct int_1 from zsystem.events where eventTypeID between 2000000021 and 2000000024 and taskID is null

  DECLARE @jobID int, @taskName nvarchar(450), @taskID int

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT jobID, jobName FROM zsystem.jobs WHERE jobID IN (SELECT jobID FROM @jobs)
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @jobID, @taskName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

    UPDATE zsystem.events SET taskID = @taskID WHERE eventTypeID BETWEEN 2000000021 and 2000000024 AND int_1 = @jobID AND taskID IS NULL

    FETCH NEXT FROM @cursor INTO @jobID, @taskName
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  SET NOCOUNT OFF
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.eventsEx') IS NOT NULL
  DROP VIEW zsystem.eventsEx
GO
CREATE VIEW zsystem.eventsEx
AS
  SELECT E.eventID, E.eventDate, E.eventTypeID, ET.eventTypeName, E.taskID, T.taskName, fixedText = X.[text], E.eventText,
         E.duration, E.referenceID, E.date_1, E.int_1, E.int_2, E.int_3, E.int_4, E.int_5, E.int_6, E.int_7, E.int_8, E.int_9
    FROM zsystem.events E
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = E.eventTypeID
      LEFT JOIN zsystem.tasks T ON T.taskID = E.taskID
      LEFT JOIN zsystem.texts X ON X.textID = E.textID
GO
GRANT SELECT ON zsystem.eventsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_TaskStarted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_TaskStarted
GO
CREATE PROCEDURE zsystem.Events_TaskStarted
  @taskName     nvarchar(450) = NULL,
  @fixedText    nvarchar(450) = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL,
  @taskID       int = NULL,
  @eventTypeID  int = 2000001001,
  @returnRow    bit = 0
AS
  SET NOCOUNT ON

  IF @taskID IS NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  DECLARE @eventID int

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, NULL, @date_1, @taskID, NULL, @fixedText

  RETURN @eventID
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_TaskCompleted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_TaskCompleted
GO
CREATE PROCEDURE zsystem.Events_TaskCompleted
  @eventID      int = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL,
  @taskID       int = NULL,
  @taskName     nvarchar(450) = NULL,
  @fixedText    nvarchar(450) = NULL,
  @duration     int = NULL,
  @eventTypeID  int = 2000001003,
  @returnRow    bit = 0
AS
  SET NOCOUNT ON

  DECLARE @textID int

  IF @eventID IS NOT NULL AND @taskID IS NULL AND @duration IS NULL
  BEGIN
    DECLARE @eventDate datetime2(0)
    SELECT @taskID = taskID, @textID = textID, @eventDate = eventDate FROM zsystem.events WHERE eventID = @eventID
    IF @eventDate IS NOT NULL
    BEGIN
      SET @duration = DATEDIFF(second, @eventDate, GETUTCDATE())
      IF @duration < 0 SET @duration = 0
    END
  END

  IF @taskID IS NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText

  RETURN @eventID
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_TaskInfo') IS NOT NULL
  DROP PROCEDURE zsystem.Events_TaskInfo
GO
CREATE PROCEDURE zsystem.Events_TaskInfo
  @eventID      int = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL,
  @taskID       int = NULL,
  @taskName     nvarchar(450) = NULL,
  @fixedText    nvarchar(450) = NULL,
  @eventTypeID  int = 2000001002,
  @returnRow    bit = 0
AS
  SET NOCOUNT ON

  DECLARE @textID int

  IF @eventID IS NOT NULL AND @taskID IS NULL
    SELECT @taskID = taskID, @textID = textID FROM zsystem.events WHERE eventID = @eventID

  IF @taskID IS NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText

  RETURN @eventID
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_TaskError') IS NOT NULL
  DROP PROCEDURE zsystem.Events_TaskError
GO
CREATE PROCEDURE zsystem.Events_TaskError
  @eventID      int = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL,
  @taskID       int = NULL,
  @taskName     nvarchar(450) = NULL,
  @fixedText    nvarchar(450) = NULL,
  @eventTypeID  int = 2000001004,
  @returnRow    bit = 0
AS
  SET NOCOUNT ON

  DECLARE @textID int

  IF @eventID IS NOT NULL AND @taskID IS NULL
    SELECT @taskID = taskID, @textID = textID FROM zsystem.events WHERE eventID = @eventID

  IF @taskID IS NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText

  RETURN @eventID
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ProcStarted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcStarted
GO
CREATE PROCEDURE zsystem.Events_ProcStarted
  @schemaName     nvarchar(128),
  @procedureName  nvarchar(128),
  @int_2          int = NULL,
  @int_3          int = NULL,
  @int_4          int = NULL,
  @int_5          int = NULL,
  @int_6          int = NULL,
  @int_7          int = NULL,
  @int_8          int = NULL,
  @int_9          int = NULL,
  @eventText      nvarchar(max) = NULL,
  @referenceID    int = NULL,
  @date_1         date = NULL
AS
  -- *** THIS PROC IS DEPRECATED ***
  SET NOCOUNT ON

  DECLARE @taskName nvarchar(450) = @schemaName + '.' + @procedureName

  EXEC zsystem.Events_TaskStarted @taskName, NULL, @eventText, NULL, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ProcCompleted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcCompleted
GO
CREATE PROCEDURE zsystem.Events_ProcCompleted
  @schemaName     nvarchar(128),
  @procedureName  nvarchar(128),
  @duration       int = NULL,
  @int_2          int = NULL,
  @int_3          int = NULL,
  @int_4          int = NULL,
  @int_5          int = NULL,
  @int_6          int = NULL,
  @int_7          int = NULL,
  @int_8          int = NULL,
  @int_9          int = NULL,
  @eventText      nvarchar(max) = NULL,
  @referenceID    int = NULL,
  @date_1         date = NULL
AS
  -- *** THIS PROC IS DEPRECATED ***
  SET NOCOUNT ON

  DECLARE @taskName nvarchar(450) = @schemaName + '.' + @procedureName

  EXEC zsystem.Events_TaskCompleted NULL, @eventText, NULL, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1, NULL, @taskName, NULL, @duration
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ProcInfo') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcInfo
GO
CREATE PROCEDURE zsystem.Events_ProcInfo
  @schemaName     nvarchar(128),
  @procedureName  nvarchar(128),
  @int_2          int = NULL,
  @int_3          int = NULL,
  @int_4          int = NULL,
  @int_5          int = NULL,
  @int_6          int = NULL,
  @int_7          int = NULL,
  @int_8          int = NULL,
  @int_9          int = NULL,
  @eventText      nvarchar(max) = NULL,
  @referenceID    int = NULL,
  @date_1         date = NULL
AS
  -- *** THIS PROC IS DEPRECATED ***
  SET NOCOUNT ON

  DECLARE @taskName nvarchar(450) = @schemaName + '.' + @procedureName

  EXEC zsystem.Events_TaskInfo NULL, @eventText, NULL, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1, NULL, @taskName
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ProcError') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ProcError
GO
CREATE PROCEDURE zsystem.Events_ProcError
  @schemaName     nvarchar(128),
  @procedureName  nvarchar(128),
  @int_2          int = NULL,
  @int_3          int = NULL,
  @int_4          int = NULL,
  @int_5          int = NULL,
  @int_6          int = NULL,
  @int_7          int = NULL,
  @int_8          int = NULL,
  @int_9          int = NULL,
  @eventText      nvarchar(max) = NULL,
  @referenceID    int = NULL,
  @date_1         date = NULL
AS
  -- *** THIS PROC IS DEPRECATED ***
  SET NOCOUNT ON

  DECLARE @taskName nvarchar(450) = @schemaName + '.' + @procedureName

  EXEC zsystem.Events_TaskError NULL, @eventText, NULL, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1, NULL, @taskName
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_JobInfo') IS NOT NULL
  DROP PROCEDURE zsystem.Events_JobInfo
GO
CREATE PROCEDURE zsystem.Events_JobInfo
  @jobID        int,
  @fixedText    nvarchar(450) = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL
AS
  SET NOCOUNT ON

  DECLARE @taskName nvarchar(450)
  SELECT @taskName = jobName FROM zsystem.jobs WHERE jobID = @jobID

  DECLARE @eventID int

  EXEC @eventID = zsystem.Events_TaskInfo NULL, @eventText, @jobID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1, NULL, @taskName, @fixedText, 2000000022

  RETURN @eventID
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ExecJob') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ExecJob
GO
CREATE PROCEDURE zsystem.Events_ExecJob
  @jobID        int,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @eventText    nvarchar(max) = NULL,
  @referenceID  int = NULL,
  @date_1       date = NULL
AS
  -- *** THIS PROC IS DEPRECATED ***
  SET NOCOUNT ON

  EXEC zsystem.Events_JobInfo @jobID, NULL, @eventText, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1
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

  DECLARE @jobID int, @jobName nvarchar(200), @sql nvarchar(max), @logStarted bit, @logCompleted bit, @eventID int, @eventText nvarchar(max)

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

  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  WHILE @@FETCH_STATUS = 0
  BEGIN
    -- Job started event
    IF @logStarted = 1
      EXEC @eventID = zsystem.Events_TaskStarted @jobName, @int_1=@jobID, @eventTypeID=2000000021

    -- Job execute 
    BEGIN TRY
      EXEC sp_executesql @sql
    END TRY
    BEGIN CATCH
      -- Job ERROR event
      SET @eventText = ERROR_MESSAGE()
      EXEC zsystem.Events_TaskError @eventID, @eventText, @int_1=@jobID, @eventTypeID=2000000024

      DECLARE @objectName nvarchar(256)
      SET @objectName = 'zsystem.Jobs_Exec: ' + @jobName
      EXEC zsystem.CatchError @objectName
    END CATCH

    -- Job completed event
    IF @logCompleted = 1
      EXEC zsystem.Events_TaskCompleted @eventID, @int_1=@jobID, @eventTypeID=2000000023

    FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM sys.indexes WHERE [object_id] = OBJECT_ID('zsystem.tables') AND [name] = 'tables_IX_Schema')
  DROP INDEX tables_IX_Schema ON zsystem.tables
GO


---------------------------------------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM sys.indexes WHERE [object_id] = OBJECT_ID('zsystem.procedures') AND [name] = 'procedures_IX_Schema')
  DROP INDEX procedures_IX_Schema ON zsystem.procedures
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Columns_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Columns_Select
GO
CREATE PROCEDURE zsystem.Columns_Select
  @schemaName  nvarchar(128),
  @tableName   nvarchar(128),
  @tableID     int = NULL
AS
  SET NOCOUNT ON

  IF @tableID IS NULL SET @tableID = zsystem.Tables_ID(@schemaName, @tableName)

  -- Using COLLATE so SQL works on Azure
  SELECT columnName = c.[name], c.system_type_id, c.max_length, c.is_nullable,
         c2.[readonly], c2.lookupTable, c2.lookupID, c2.lookupName, c2.lookupWhere, c2.html, c2.localizationGroupID
    FROM sys.columns c
      LEFT JOIN zsystem.columns c2 ON c2.tableID = @tableID AND c2.columnName COLLATE Latin1_General_BIN = c.[name] COLLATE Latin1_General_BIN
   WHERE c.[object_id] = OBJECT_ID(@schemaName + '.' + @tableName) AND ISNULL(c2.obsolete, 0) = 0
   ORDER BY c.column_id
GO
GRANT EXEC ON zsystem.Columns_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Intervals_OverflowAlert') IS NOT NULL
  DROP PROCEDURE zsystem.Intervals_OverflowAlert
GO
CREATE PROCEDURE zsystem.Intervals_OverflowAlert
  @alertLevel  real = 0.05 -- default alert level (we alert when less than 5% of the ids are left)
AS
  SET NOCOUNT ON

  IF EXISTS (SELECT * FROM zsystem.intervals WHERE (maxID - currentID) / CONVERT(real, (maxID - minID)) <= @alertLevel)
  BEGIN
    DECLARE @recipients varchar(max)
    SET @recipients = zsystem.Settings_Value('zsystem', 'Recipients-Operations-Software')

    IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
    BEGIN
      DECLARE @intervalID int
      DECLARE @intervalName nvarchar(400)
      DECLARE @maxID int
      DECLARE @currentID int
      DECLARE @body nvarchar(max)

      DECLARE @cursor CURSOR
      SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT intervalID, intervalName, maxID, currentID
            FROM zsystem.intervals
           WHERE (maxID - currentID) / CONVERT(real, (maxID - minID)) <= @alertLevel
      OPEN @cursor
      FETCH NEXT FROM @cursor INTO @intervalID, @intervalName, @maxID, @currentID
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @body = N'ID''s for the interval: <b>' + @intervalName  + N' (intervalID: '
                  + CONVERT(nvarchar, @intervalID) + N')</b> is getting low.<br>'
                  + N'The current counter is now at ' + CONVERT(nvarchar, @currentID) + N' and the maximum it can '
                  + N'get up to is ' + CONVERT(nvarchar, @maxID) + N', so we will run out after '
                  + CONVERT(nvarchar, (@maxID-@currentID)) + N' ID''s.<br><br>'
                  + N'We need to find another range for it very soon, so please don''t just ignore this mail! <br><br>'
                  + N'That was all <br>  Your friendly automatic e-mail sender'

        EXEC zsystem.SendMail @recipients, 'INTERVAL OVERFLOW ALERT!', @body, 'HTML'
        FETCH NEXT FROM @cursor INTO @intervalID, @intervalName, @maxID, @currentID
      END
      CLOSE @cursor
      DEALLOCATE @cursor
    END
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zmetric.counters') AND [name] = 'modifyDate')
BEGIN
  ALTER TABLE zmetric.counters ADD modifyDate datetime2(0) NOT NULL DEFAULT GETUTCDATE()

  EXEC sp_executesql N'UPDATE zmetric.counters SET modifyDate = createDate'
END
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
  @units                 varchar(20) = NULL,
  @counterTable          nvarchar(256) = NULL,
  @userName              varchar(200) = NULL
AS
  SET NOCOUNT ON

  IF @counterID IS NULL
    SELECT @counterID = MAX(counterID) + 1 FROM zmetric.counters WHERE counterID < 30000
  IF @counterID IS NULL SET @counterID = 1

  IF @counterIdentifier IS NULL SET @counterIdentifier = @counterID

  INSERT INTO zmetric.counters
              (counterID, counterName, groupID, [description], subjectLookupTableID, keyLookupTableID, [source], subjectID, keyID,
               absoluteValue, shortName, [order], procedureName, procedureOrder, parentCounterID, baseCounterID, counterType,
               counterIdentifier, published, sourceType, units, counterTable, userName)
       VALUES (@counterID, @counterName, @groupID, @description, @subjectLookupTableID, @keyLookupTableID, @source, @subjectID, @keyID,
               @absoluteValue, @shortName, @order, @procedureName, @procedureOrder, @parentCounterID, @baseCounterID, @counterType,
               @counterIdentifier, @published, @sourceType, @units, @counterTable, @userName)

  SELECT counterID = @counterID
GO
GRANT EXEC ON zmetric.Counters_Insert TO zzp_server
GO


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
        SELECT TOP 1 @dateReturned = counterDate FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate <= @dateRequested ORDER BY counterDate DESC
      ELSE IF @counterTable = 'zmetric.subjectKeyCounters'
        SELECT TOP 1 @dateReturned = counterDate FROM zmetric.subjectKeyCounters WHERE counterID = @counterID AND counterDate <= @dateRequested ORDER BY counterDate DESC
      ELSE
        SELECT TOP 1 @dateReturned = counterDate FROM zmetric.keyCounters WHERE counterID = @counterID AND counterDate <= @dateRequested ORDER BY counterDate DESC
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
    IF @counterTable = 'zmetric.keyCounters' AND @subjectLookupTableID IS NOT NULL
      RAISERROR ('Key counter is not valid, subject lookup set', 16, 1)
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
                SUM(P.row_count),
                SUM(P.reserved_page_count * 8), SUM(P.used_page_count * 8), SUM(P.in_row_data_page_count * 8),
                MAX(U.user_seeks), MAX(U.user_scans), MAX(U.user_lookups), MAX(U.user_updates)
           FROM sys.tables T
             INNER JOIN sys.schemas S ON S.[schema_id] = T.[schema_id]
             INNER JOIN sys.indexes I ON I.[object_id] = T.[object_id]
               INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
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
          N'<h3><font color=blue>Top 30 rows</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">table</th><th>rows</th><th>total_MB</th><th>used_MB</th><th>data_MB</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
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
        + N'<h3><font color=blue>Top 30 total_MB</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">table</th><th>total_MB</th><th>used_MB</th><th>data_MB</th><th>rows</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
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
        + N'<h3><font color=blue>Top 30 user_seeks</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C5.value - ISNULL(C5B.value, 0), 1), ''
          FROM zmetric.keyCounters C5
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C5.keyID
            LEFT JOIN zmetric.keyCounters C5B ON C5B.counterID = C5.counterID AND C5B.counterDate = @subtractDate AND C5B.columnID = C5.columnID AND C5B.keyID = C5.keyID
         WHERE C5.counterID = 30007 AND C5.counterDate = @counterDate AND C5.columnID = 5
         ORDER BY (C5.value - ISNULL(C5B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_scans (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_scans</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C6.value - ISNULL(C6B.value, 0), 1), ''
          FROM zmetric.keyCounters C6
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C6.keyID
            LEFT JOIN zmetric.keyCounters C6B ON C6B.counterID = C6.counterID AND C6B.counterDate = @subtractDate AND C6B.columnID = C6.columnID AND C6B.keyID = C6.keyID
         WHERE C6.counterID = 30007 AND C6.counterDate = @counterDate AND C6.columnID = 6
         ORDER BY (C6.value - ISNULL(C6B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_lookups (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_lookups</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C7.value - ISNULL(C7B.value, 0), 1), ''
          FROM zmetric.keyCounters C7
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C7.keyID
            LEFT JOIN zmetric.keyCounters C7B ON C7B.counterID = C7.counterID AND C7B.counterDate = @subtractDate AND C7B.columnID = C7.columnID AND C7B.keyID = C7.keyID
         WHERE C7.counterID = 30007 AND C7.counterDate = @counterDate AND C7.columnID = 7
         ORDER BY (C7.value - ISNULL(C7B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_updates (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_updates</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
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
    -- Azure does not support @@PACK_RECEIVED, @@PACK_SENT, @@PACKET_ERRORS, @@TOTAL_READ, @@TOTAL_WRITE and @@TOTAL_ERRORS
    IF CONVERT(varchar(max), SERVERPROPERTY('edition')) NOT LIKE '%Azure%'
    BEGIN
      DECLARE @pack_received int, @pack_sent int, @packet_errors int, @total_read int, @total_write int, @total_errors int

      EXEC sp_executesql N'
        SELECT @pack_received = @@PACK_RECEIVED, @pack_sent = @@PACK_SENT, @packet_errors = @@PACKET_ERRORS,
               @total_read = @@TOTAL_READ, @total_write = @@TOTAL_WRITE, @total_errors = @@TOTAL_ERRORS',
        N'@pack_received int OUTPUT, @pack_sent int OUTPUT, @packet_errors int OUTPUT, @total_read int OUTPUT, @total_write int OUTPUT, @total_errors int OUTPUT',
        @pack_received OUTPUT, @pack_sent OUTPUT, @packet_errors OUTPUT, @total_read OUTPUT, @total_write OUTPUT, @total_errors OUTPUT

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
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SavePerfCountersTotal'
    RETURN -1
  END CATCH
GO


---------------------------------------------------------------------------------------------------------------------------------


-- FIX FOR AZURE (Tables without a clustered index are not supported)
IF NOT EXISTS(SELECT * FROM sys.indexes WHERE [object_id] = OBJECT_ID('zsystem.lookupValues') AND name = 'lookupValues_PK')
BEGIN
  EXEC sp_rename 'zsystem.lookupValues', 'lookupValues_AZURE'

  CREATE TABLE zsystem.lookupValues
  (
    lookupTableID  int                                           NOT NULL,
    lookupID       int                                           NOT NULL,
    lookupText     nvarchar(1000)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]  nvarchar(max)                                 NULL,
    parentID       int                                           NULL,
    [fullText]     nvarchar(1000)  COLLATE Latin1_General_CI_AI  NULL,
    --
    CONSTRAINT lookupValues_PK PRIMARY KEY CLUSTERED (lookupTableID, lookupID)
  )
  GRANT SELECT ON zsystem.lookupValues TO zzp_server

  INSERT INTO zsystem.lookupValues (lookupTableID, lookupID, lookupText, [description], parentID, [fullText])
       SELECT lookupTableID, lookupID, lookupText, [description], parentID, [fullText] FROM zsystem.lookupValues_AZURE ORDER BY lookupTableID, lookupID

  DROP TABLE zsystem.lookupValues_AZURE
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND name = 'lookupTableIdentifier' AND collation_name != 'Latin1_General_CI_AI')
BEGIN
  DROP INDEX lookupTables_UQ_Identifier ON zsystem.lookupTables
  ALTER TABLE zsystem.lookupTables ALTER COLUMN lookupTableIdentifier varchar(500) COLLATE Latin1_General_CI_AI NOT NULL
  CREATE UNIQUE NONCLUSTERED INDEX lookupTables_UQ_Identifier ON zsystem.lookupTables (lookupTableIdentifier)
END
GO


IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.tables') AND name = 'disableEdit' AND is_nullable = 1)
BEGIN
  UPDATE zsystem.tables SET disableEdit = 0 WHERE disableEdit IS NULL
  ALTER TABLE zsystem.tables ALTER COLUMN disableEdit bit NOT NULL
END
GO


IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.tables') AND name = 'disableDelete' AND is_nullable = 1)
BEGIN
  UPDATE zsystem.tables SET disableDelete = 0 WHERE disableDelete IS NULL
  ALTER TABLE zsystem.tables ALTER COLUMN disableDelete bit NOT NULL
END
GO


IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.tables') AND name = 'obsolete' AND is_nullable = 1)
BEGIN
  UPDATE zsystem.tables SET obsolete = 0 WHERE obsolete IS NULL
  ALTER TABLE zsystem.tables ALTER COLUMN obsolete bit NOT NULL
END
GO


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



EXEC zsystem.Versions_Finish 'CORE.J', 0005, 'jorundur'
GO
