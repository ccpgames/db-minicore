
EXEC zsystem.Versions_Start 'CORE.J', 0003, 'jorundur'
GO



---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_FirstExecution') IS NOT NULL
  DROP FUNCTION zsystem.Versions_FirstExecution
GO
CREATE FUNCTION zsystem.Versions_FirstExecution()
RETURNS bit
BEGIN
  IF EXISTS(SELECT * FROM zsystem.versions WHERE executingSPID = @@SPID AND firstDuration IS NULL)
    RETURN 1
  RETURN 0
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

  DECLARE @reversed nvarchar(max), @break int

  WHILE (LEN(@str) > 4000)
  BEGIN
    SET @reversed = REVERSE(LEFT(@str, 4000))

    SET @break = CHARINDEX(CHAR(10) + CHAR(13), @reversed)

    PRINT LEFT(@str, 4000 - @break + 1)

    SET @str = RIGHT(@str, LEN(@str) - 4000 + @break - 1)
  END

  IF LEN(@str) > 0
    PRINT @str
GO


---------------------------------------------------------------------------------------------------------------------------------


DECLARE @tableName   nvarchar(256) = 'zsystem.settings'
DECLARE @columnName  nvarchar(128) = 'orderID'
DECLARE @sql nvarchar(4000)
SELECT @sql = 'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + OBJECT_NAME(default_object_id)
  FROM sys.columns
 WHERE [object_id] = OBJECT_ID(@tableName) AND [name] = @columnName AND default_object_id != 0
EXEC (@sql)
GO
UPDATE zsystem.settings SET orderID = 0 WHERE orderID IS NULL
ALTER TABLE zsystem.settings ALTER COLUMN orderID int NOT NULL
ALTER TABLE zsystem.settings ADD DEFAULT 0 FOR orderID
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
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

      SELECT @rows = SUM(P.[rows])
        FROM sys.indexes I
          INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
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

      SELECT index_name = I.name, IC.index_column_id, column_name = C.name, IC.is_included_column
        FROM sys.indexes I
          INNER JOIN sys.index_columns IC ON IC.[object_id] = I.[object_id] AND IC.index_id = I.index_id
            INNER JOIN sys.columns C ON C.[object_id] = IC.[object_id] AND C.column_id = IC.column_id
       WHERE I.[object_id] = @tableID
       ORDER BY I.index_id, IC.index_column_id
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


IF OBJECT_ID('zdm.i') IS NOT NULL
  DROP SYNONYM zdm.i
GO
CREATE SYNONYM zdm.i FOR zdm.info
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.filegroups') IS NOT NULL
  DROP PROCEDURE zdm.filegroups
GO
CREATE PROCEDURE zdm.filegroups
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.info 'filegroups', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.functions') IS NOT NULL
  DROP PROCEDURE zdm.functions
GO
CREATE PROCEDURE zdm.functions
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'functions', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.indexes') IS NOT NULL
  DROP PROCEDURE zdm.indexes
GO
CREATE PROCEDURE zdm.indexes
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.info 'indexes', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.procs') IS NOT NULL
  DROP PROCEDURE zdm.procs
GO
CREATE PROCEDURE zdm.procs
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'procs', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.tables') IS NOT NULL
  DROP PROCEDURE zdm.tables
GO
CREATE PROCEDURE zdm.tables
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'tables', @filter
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.views') IS NOT NULL
  DROP PROCEDURE zdm.views
GO
CREATE PROCEDURE zdm.views
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.info 'views', @filter
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
           R.session_id, blocking_id = R.blocking_session_id,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes, R.logical_reads,
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
           R.session_id, blocking_id = R.blocking_session_id,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes, R.logical_reads,
           R.open_transaction_count, R.open_resultset_count, R.percent_complete, R.database_id,
           [object_id] = T.objectid, S.host_process_id, S.client_interface_name, R.[sql_handle], R.plan_handle
      INTO #topsql
      FROM sys.dm_exec_requests R
        CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
        LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id

    SELECT 'Blocking info' AS Info, [start_time], [run_time], [session_id], [blocking_id],
            [host_name], [program_name], [login_name], [database_name], [object_name],
            [text], [command], [status], [estimated_completion_time], [wait_time], [last_wait_type], [cpu_time],
            [total_elapsed_time], [reads], [writes], [logical_reads],
            [open_transaction_count], [open_resultset_count], [percent_complete], [database_id],
            [object_id], [host_process_id], [client_interface_name], [sql_handle], [plan_handle]
      FROM #topsql
      WHERE blocking_id IN (select session_id FROM #topsql) OR session_id IN (select blocking_id FROM #topsql)
      ORDER BY blocking_id, session_id

    SELECT start_time, run_time, session_id, blocking_id,
           [host_name], [program_name], login_name, database_name, [object_name],
           [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
           total_elapsed_time, reads, writes, logical_reads,
           open_transaction_count, open_resultset_count, percent_complete, database_id,
           [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM #topsql
     ORDER BY start_time
  END
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
    SELECT TOP (@rows) start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.DateDiffString(R.start_time, @now),
           R.session_id, blocking_id = R.blocking_session_id,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], P.query_plan, R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes, R.logical_reads,
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
    SELECT TOP (@rows) start_time = CONVERT(datetime2(0), R.start_time), run_time = zutil.DateDiffString(R.start_time, @now),
           R.session_id, blocking_id = R.blocking_session_id,
           S.[host_name], S.[program_name], S.login_name, database_name = DB_NAME(R.database_id),
           [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
           T.[text], P.query_plan, R.command, R.[status], estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
           wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type, cpu_time = zutil.TimeString(R.cpu_time / 1000),
           total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000), R.reads, R.writes, R.logical_reads,
           R.open_transaction_count, R.open_resultset_count, R.percent_complete, R.database_id,
           [object_id] = T.objectid, S.host_process_id, S.client_interface_name, R.[sql_handle], R.plan_handle
      INTO #topsql
      FROM sys.dm_exec_requests R
        CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
        CROSS APPLY sys.dm_exec_query_plan(R.plan_handle) P
        LEFT JOIN sys.dm_exec_sessions S ON S.session_id = R.session_id

    SELECT 'Blocking info' AS Info, [start_time], [run_time], [session_id], [blocking_id],
            [host_name], [program_name], [login_name], [database_name], [object_name],
            [text], [command], [status], [estimated_completion_time], [wait_time], [last_wait_type], [cpu_time],
            [total_elapsed_time], [reads], [writes], [logical_reads],
            [open_transaction_count], [open_resultset_count], [percent_complete], [database_id],
            [object_id], [host_process_id], [client_interface_name], [sql_handle], [plan_handle]
      FROM #topsql
      WHERE blocking_id IN (select session_id FROM #topsql) OR session_id IN (select blocking_id FROM #topsql)
      ORDER BY blocking_id, session_id

    SELECT start_time, run_time, session_id, blocking_id,
           [host_name], [program_name], login_name, database_name, [object_name],
           [text], command, [status], estimated_completion_time, wait_time, last_wait_type, cpu_time,
           total_elapsed_time, reads, writes, logical_reads,
           open_transaction_count, open_resultset_count, percent_complete, database_id,
           [object_id], host_process_id, client_interface_name, [sql_handle], plan_handle
      FROM #topsql
     ORDER BY start_time
  END
GO


IF OBJECT_ID('zdm.tp') IS NOT NULL
  DROP SYNONYM zdm.tp
GO
CREATE SYNONYM zdm.tp FOR zdm.topsqlp
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.objects') IS NOT NULL
  DROP PROCEDURE zdm.objects
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateMinutes') IS NOT NULL
  DROP FUNCTION zutil.DateMinutes
GO
CREATE FUNCTION zutil.DateMinutes(@dt datetime2(0), @minutes tinyint)
RETURNS datetime2(0)
BEGIN
  SET @dt = DATEADD(second, -DATEPART(second, @dt), @dt)
  RETURN DATEADD(minute, -(DATEPART(minute, @dt) % @minutes), @dt)
END
GO


---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.MoneyListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.MoneyListToOrderedTable
GO
CREATE FUNCTION zutil.MoneyListToOrderedTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(money, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.SplitMask') IS NOT NULL
  DROP FUNCTION zutil.SplitMask
GO
CREATE FUNCTION zutil.SplitMask(@bitMask bigint)
  RETURNS TABLE
  RETURN SELECT [bit] = POWER(CONVERT(bigint, 2), n - 1) FROM zutil.Numbers(63) WHERE @bitMask & POWER(CONVERT(bigint, 2), n - 1) > 0
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateXMinutes') IS NOT NULL
  DROP FUNCTION zutil.DateXMinutes
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


GRANT EXEC ON zdm.topsql TO zzp_server
GO
GRANT EXEC ON zutil.DateMinutes TO zzp_server
GO
GRANT SELECT ON zutil.MoneyListToOrderedTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.eventTypes') AND [name] = 'obsolete')
  ALTER TABLE zsystem.eventTypes ADD obsolete bit NOT NULL DEFAULT 0
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000032)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000032, 'Insert system setting', '')
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Settings_Update') IS NOT NULL
  DROP PROCEDURE zsystem.Settings_Update
GO
CREATE PROCEDURE zsystem.Settings_Update
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

    BEGIN TRANSACTION

    IF @allowUpdate IS NULL AND @insertIfNotExists = 1
    BEGIN
      INSERT INTO zsystem.settings ([group], [key], value, [description]) VALUES (@group, @key, @value, '')

      SET @value = @group + '.' + @key + ' = ' + @value
      EXEC zsystem.Events_Insert 2000000032, NULL, @userID, @eventText = @value
    END
    ELSE
    BEGIN
      UPDATE zsystem.settings
          SET value = @value
        WHERE [group] = @group AND [key] = @key AND [value] != @value
      IF @@ROWCOUNT > 0
      BEGIN
        SET @value = @group + '.' + @key + ' = ' + @value
        EXEC zsystem.Events_Insert 2000000031, NULL, @userID, @eventText = @value
      END
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
GRANT EXEC ON zsystem.Settings_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


UPDATE zsystem.jobs SET [disabled] = 0 WHERE [disabled] IS NULL
ALTER TABLE zsystem.jobs ALTER COLUMN [disabled] bit NOT NULL
GO


EXEC zdm.DropDefaultConstraint 'zsystem.jobs', 'orderID'
UPDATE zsystem.jobs SET orderID = 0 WHERE orderID IS NULL
ALTER TABLE zsystem.jobs ALTER COLUMN orderID int NOT NULL
ALTER TABLE zsystem.jobs ADD DEFAULT 0 FOR orderID
GO


---------------------------------------------------------------------------------------------------------------------------------


UPDATE zsystem.jobs SET jobName = 'CORE - zmetric - Save stats', [sql] = 'EXEC zmetric.ColumnCounters_SaveStats' WHERE jobID = 2000000011
UPDATE zsystem.jobs SET jobName = 'CORE - zmetric - Index stats DB mail', [sql] = 'EXEC zmetric.IndexStats_Mail' WHERE jobID = 2000000012
UPDATE zsystem.jobs SET jobName = 'CORE - zsystem - Interval overflow alert' WHERE jobID = 2000000031
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.jobsEx') IS NOT NULL
  DROP VIEW zsystem.jobsEx
GO
CREATE VIEW zsystem.jobsEx
AS
  SELECT jobID, jobName, [description], [sql], [hour], [minute],
         [time] = CASE WHEN part IS NOT NULL THEN NULL
                       WHEN [week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] IS NULL THEN 'XX:X0'
                       WHEN [week] IS NULL AND [day] IS NULL AND [hour] IS NULL THEN 'XX:' + RIGHT('0' + CONVERT(varchar, [minute]), 2)
                       ELSE RIGHT('0' + CONVERT(varchar, [hour]), 2) + ':' + RIGHT('0' + CONVERT(varchar, [minute]), 2) END,
         [day], dayText = CASE [day] WHEN 1 THEN 'Sunday' WHEN 2 THEN 'Monday' WHEN 3 THEN 'Tuesday'
                                     WHEN 4 THEN 'Wednesday' WHEN 5 THEN 'Thursday' WHEN 6 THEN 'Friday'
                                     WHEN 7 THEN 'Saturday' END,
         [week], weekText = CASE [week] WHEN 1 THEN 'First (days 1-7 of month)'
                                        WHEN 2 THEN 'Second (days 8-14 of month)'
                                        WHEN 3 THEN 'Third (days 15-21 of month)'
                                        WHEN 4 THEN 'Fourth (days 22-28 of month)' END,
         [group], part, logStarted, logCompleted, orderID, [disabled]
    FROM zsystem.jobs
GO
GRANT SELECT ON zsystem.jobsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Tables_ID') IS NOT NULL
  DROP FUNCTION zsystem.Tables_ID
GO
CREATE FUNCTION zsystem.Tables_ID(@schemaName nvarchar(128), @tableName nvarchar(128))
RETURNS int
BEGIN
  DECLARE @schemaID int
  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  DECLARE @tableID int
  SELECT @tableID = tableID FROM zsystem.tables WHERE schemaID = @schemaID AND tableName = @tableName
  RETURN @tableID
END
GO
GRANT EXEC ON zsystem.Tables_ID TO zzp_server
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
         T.keyID, T.keyID2, T.keyID3, T.sequence, T.keyName, T.keyDate,
         T.textTableID, T.textKeyID, T.textTableID2, T.textKeyID2, T.textTableID3, T.textKeyID3,
         T.link, T.disableEdit, T.disableDelete, T.disabledDatasets, T.revisionOrder, T.obsolete, T.denormalized
    FROM zsystem.tables T
      LEFT JOIN zsystem.schemas S ON S.schemaID = T.schemaID
GO
GRANT SELECT ON zsystem.tablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Table_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Table_Select
GO
CREATE PROCEDURE zsystem.Table_Select
  @schemaName    nvarchar(128),
  @tableName     nvarchar(128)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    DECLARE @sql nvarchar(4000)
    SET @sql = ''
    SELECT @sql = @sql + ', ' + QUOTENAME(name)
      FROM sys.columns
     WHERE [object_id] = OBJECT_ID(@schemaName + '.' + @tableName)
     ORDER BY column_id
    SET @sql = 'SELECT ' + SUBSTRING(@sql, 3, 4000) + ' FROM ' + QUOTENAME(@schemaName) + '.' + QUOTENAME(@tableName) + ' ORDER BY 1'
    EXEC sp_executesql @sql
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.Table_Select'
    RETURN -1
  END CATCH
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

  DECLARE @maxi int, @maxb bigint, @stmt nvarchar(4000)

  DECLARE @tableID int, @tableName nvarchar(256), @keyID nvarchar(128), @keyDate nvarchar(128), @logIdentity tinyint

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT T.tableID, QUOTENAME(S.schemaName) + '.' + QUOTENAME(T.tableName), QUOTENAME(T.keyID), QUOTENAME(T.keyDate), T.logIdentity
          FROM zsystem.tables T
            INNER JOIN zsystem.schemas S ON S.schemaID = T.schemaID
         WHERE T.logIdentity IN (1, 2) AND ISNULL(T.keyID, '') != '' AND
               OBJECT_ID(S.schemaName + '.' + T.tableName) IS NOT NULL
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  WHILE @@FETCH_STATUS = 0
  BEGIN
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

    FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_Check') IS NOT NULL
  DROP PROCEDURE zsystem.Identities_Check
GO
CREATE PROCEDURE zsystem.Identities_Check
  @schemaName  nvarchar(128),
  @tableName   nvarchar(128),
  @rows        smallint = 100
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @schemaID int
  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  DECLARE @tableID int
  SELECT @tableID = tableID FROM zsystem.tables WHERE schemaID = @schemaID AND tableName = @tableName

  SELECT TOP (@rows) tableID, identityDate, identityInt, identityBigInt
    FROM zsystem.identities
   WHERE tableID = @tableID
   ORDER BY identityDate DESC
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_BigInt') IS NOT NULL
  DROP FUNCTION zsystem.Identities_BigInt
GO
CREATE FUNCTION zsystem.Identities_BigInt(@tableID int, @identityDate date, @days smallint, @seek smallint)
  RETURNS bigint
BEGIN
  IF @identityDate IS NULL SET @identityDate = GETUTCDATE()
  IF @days IS NOT NULL SET @identityDate = DATEADD(day, @days, @identityDate)

  DECLARE @identityBigInt bigint

  IF @seek < 0
  BEGIN
    SELECT TOP 1 @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate <= @identityDate
     ORDER BY identityDate DESC
  END
  ELSE IF @seek > 0
  BEGIN
    SELECT TOP 1 @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate >= @identityDate
     ORDER BY identityDate
  END
  ELSE
  BEGIN
    SELECT @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate = @identityDate
  END

  RETURN ISNULL(@identityBigInt, -1)
END
GO
GRANT EXEC ON zsystem.Identities_BigInt TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_Int') IS NOT NULL
  DROP FUNCTION zsystem.Identities_Int
GO
CREATE FUNCTION zsystem.Identities_Int(@tableID int, @identityDate date, @days smallint, @seek smallint)
  RETURNS int
BEGIN
  IF @identityDate IS NULL SET @identityDate = GETUTCDATE()
  IF @days IS NOT NULL SET @identityDate = DATEADD(day, @days, @identityDate)

  DECLARE @identityInt int

  IF @seek < 0
  BEGIN
    SELECT TOP 1 @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate <= @identityDate
     ORDER BY identityDate DESC
  END
  ELSE IF @seek > 0
  BEGIN
    SELECT TOP 1 @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate >= @identityDate
     ORDER BY identityDate
  END
  ELSE
  BEGIN
    SELECT @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate = @identityDate
  END

  RETURN ISNULL(@identityInt, -1)
END
GO
GRANT EXEC ON zsystem.Identities_Int TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'link')
  ALTER TABLE zsystem.lookupTables ADD link nvarchar(500) NULL
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'lookupTableIdentifier')
  ALTER TABLE zsystem.lookupTables ADD lookupTableIdentifier varchar(500) COLLATE Latin1_General_CI_AI NULL
GO
UPDATE zsystem.lookupTables SET lookupTableIdentifier = lookupTableID WHERE lookupTableIdentifier IS NULL
GO
ALTER TABLE zsystem.lookupTables ALTER COLUMN lookupTableIdentifier varchar(500) NOT NULL
GO
IF NOT EXISTS(SELECT * FROM sys.indexes WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'lookupTables_UQ_Identifier')
  CREATE UNIQUE NONCLUSTERED INDEX lookupTables_UQ_Identifier ON zsystem.lookupTables (lookupTableIdentifier)
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'hidden')
  ALTER TABLE zsystem.lookupTables ADD hidden bit NOT NULL DEFAULT 0
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'obsolete')
  ALTER TABLE zsystem.lookupTables ADD obsolete bit NOT NULL DEFAULT 0
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'sourceForID')
  ALTER TABLE zsystem.lookupTables ADD sourceForID varchar(20) NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000001)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableName, lookupTableIdentifier) VALUES (2000000001, 'DB Metrics - Procedure names', 'core.db.procs')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000005)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableName, lookupTableIdentifier) VALUES (2000000005, 'DB Metrics - Index names', 'core.db.indexes')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000006)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableName, lookupTableIdentifier) VALUES (2000000006, 'DB Metrics - Table names', 'core.db.tables')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000007)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableName, lookupTableIdentifier) VALUES (2000000007, 'DB Metrics - File stats', 'core.db.filegroups')
GO


---------------------------------------------------------------------------------------------------------------------------------


ALTER TABLE zsystem.lookupValues ALTER COLUMN lookupText nvarchar(1000) COLLATE Latin1_General_CI_AI NOT NULL
GO
ALTER TABLE zsystem.lookupValues ALTER COLUMN [fullText] nvarchar(1000) COLLATE Latin1_General_CI_AI NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.LookupTables_ID') IS NOT NULL
  DROP FUNCTION zsystem.LookupTables_ID
GO
CREATE FUNCTION zsystem.LookupTables_ID(@lookupTableIdentifier varchar(500))
RETURNS int
BEGIN
  DECLARE @lookupTableID int
  SELECT @lookupTableID = lookupTableID FROM zsystem.lookupTables WHERE lookupTableIdentifier = @lookupTableIdentifier
  RETURN @lookupTableID
END
GO
GRANT EXEC ON zsystem.LookupTables_ID TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupTablesEx') IS NOT NULL
  DROP VIEW zsystem.lookupTablesEx
GO
CREATE VIEW zsystem.lookupTablesEx
AS
  SELECT L.lookupTableID, L.lookupTableName, L.lookupTableIdentifier, L.[description], L.schemaID, S.schemaName, L.tableID, T.tableName,
         L.sourceForID, L.[source], L.lookupID, L.parentID, L.parentLookupTableID, parentLookupTableName = L2.lookupTableName, L.link, L.hidden, L.obsolete
    FROM zsystem.lookupTables L
      LEFT JOIN zsystem.schemas S ON S.schemaID = L.schemaID
      LEFT JOIN zsystem.tables T ON T.tableID = L.tableID
      LEFT JOIN zsystem.lookupTables L2 ON L2.lookupTableID = L.parentLookupTableID
GO
GRANT SELECT ON zsystem.lookupTablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupValuesEx') IS NOT NULL
  DROP VIEW zsystem.lookupValuesEx
GO
CREATE VIEW zsystem.lookupValuesEx
AS
  SELECT V.lookupTableID, T.lookupTableName, V.lookupID, V.lookupText, V.[fullText], V.parentID, V.[description]
    FROM zsystem.lookupValues V
      LEFT JOIN zsystem.lookupTables T ON T.lookupTableID = V.lookupTableID
GO
GRANT SELECT ON zsystem.lookupValuesEx TO zzp_server
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
  @sourceForID            varchar(20) = NULL     -- EXTERNAL/TEXT/MAX
AS
  SET NOCOUNT ON

  IF @lookupTableID IS NULL
    SELECT @lookupTableID = MAX(lookupTableID) + 1 FROM zsystem.lookupTables WHERE lookupTableID < 2000000000
  IF @lookupTableID IS NULL SET @lookupTableID = 1

  IF @lookupTableIdentifier IS NULL SET @lookupTableIdentifier = @lookupTableID

  INSERT INTO zsystem.lookupTables
              (lookupTableID, lookupTableName, [description], schemaID, tableID, [source], lookupID, parentID, parentLookupTableID,
               link, lookupTableIdentifier, sourceForID)
       VALUES (@lookupTableID, @lookupTableName, @description, @schemaID, @tableID, @source, @lookupID, @parentID, @parentLookupTableID,
               @link, @lookupTableIdentifier, @sourceForID)

  SELECT lookupTableID = @lookupTableID
GO
GRANT EXEC ON zsystem.LookupTables_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.LookupValues_Update') IS NOT NULL
  DROP PROCEDURE zsystem.LookupValues_Update
GO
CREATE PROCEDURE zsystem.LookupValues_Update
  @lookupTableID  int,
  @lookupID       int, -- If NULL then zsystem.Texts_ID is used
  @lookupText     nvarchar(1000)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @lookupID IS NULL
    BEGIN
      IF LEN(@lookupText) > 450
        RAISERROR ('@lookupText must not be over 450 characters if zsystem.Texts_ID is used', 16, 1)
      EXEC @lookupID = zsystem.Texts_ID @lookupText
    END

    IF EXISTS(SELECT * FROM zsystem.lookupValues WHERE lookupTableID = @lookupTableID AND lookupID = @lookupID)
      UPDATE zsystem.lookupValues SET lookupText = @lookupText WHERE lookupTableID = @lookupTableID AND lookupID = @lookupID AND lookupText != @lookupText
    ELSE
      INSERT INTO zsystem.lookupValues (lookupTableID, lookupID, lookupText) VALUES (@lookupTableID, @lookupID, @lookupText)

    RETURN @lookupID
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.LookupValues_Update'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.LookupValues_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF SCHEMA_ID('zmetric') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zmetric'
GO


IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000032)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000032, 'zmetric', 'CORE - Metrics', 'http://core/wiki/DB_zmetric')
GO


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'Recipients-IndexStats')
  INSERT INTO zsystem.settings ([group], [key], value, [description])
       SELECT  'zmetric', 'Recipients-IndexStats', value, 'Mail recipients for Index Stats notifications'
         FROM zsystem.settings
        WHERE [group] = 'zsys' AND [key] = 'Recipients-IndexStats'
GO
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'Recipients-IndexStats')
  INSERT INTO zsystem.settings ([group], [key], value, [description])
       VALUES ('zmetric', 'Recipients-IndexStats', '', 'Mail recipients for Index Stats notifications')
GO


---------------------------------------------------------------------------------------------------------------------------------


-- *** groupID from 30000 and up is reserved for CORE ***

IF OBJECT_ID('zmetric.groups') IS NULL
BEGIN
  CREATE TABLE zmetric.groups
  (
    groupID        smallint                                     NOT NULL,
    groupName      nvarchar(200)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]  nvarchar(max)                                NULL,
    [order]        smallint                                     NOT NULL  DEFAULT 0,
    --
    CONSTRAINT groups_PK PRIMARY KEY CLUSTERED (groupID)
  )
END
GRANT SELECT ON zmetric.groups TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- *** counterID from 30000 and up is reserved for CORE ***

IF OBJECT_ID('zmetric.counters') IS NULL
BEGIN
  CREATE TABLE zmetric.counters
  (
    counterID             smallint                                     NOT NULL,
    counterName           nvarchar(200)  COLLATE Latin1_General_CI_AI  NOT NULL,
    groupID               smallint                                     NULL,
    [description]         nvarchar(max)                                NULL,
    subjectLookupTableID  int                                          NULL, -- Lookup table for subjectID, pointing to zsystem.lookupTables/Values
    keyLookupTableID      int                                          NULL, -- Lookup table for keyID, pointing to zsystem.lookupTables/Values
    [source]              nvarchar(200)                                NULL, -- Description of data source, f.e. table name
    subjectID             nvarchar(200)                                NULL, -- Description of subjectID column
    keyID                 nvarchar(200)                                NULL, -- Description of keyID column
    absoluteValue         bit                                          NOT NULL  DEFAULT 0, -- If set counter stores absolute value
    shortName             nvarchar(50)                                 NULL,
    [order]               smallint                                     NOT NULL  DEFAULT 0,
    procedureName         nvarchar(500)                                NULL, -- Procedure called to get data for the counter
    procedureOrder        tinyint                                      NOT NULL  DEFAULT 255,
    parentCounterID       smallint                                     NULL,
    createDate            datetime2(0)                                 NOT NULL  DEFAULT GETUTCDATE(),
    baseCounterID         smallint                                     NULL,
    counterType           char(1)                                      NOT NULL  DEFAULT 'D', -- C:Column, D:Date, S:Simple, T:Time
    obsolete              bit                                          NOT NULL  DEFAULT 0,
    counterIdentifier     varchar(500)   COLLATE Latin1_General_CI_AI  NOT NULL, -- Identifier to use in code to make it readable and usable in other Metrics webs
    hidden                bit                                          NOT NULL  DEFAULT 0,
    published             bit                                          NOT NULL  DEFAULT 1,
    sourceType            varchar(20)                                  NULL, -- Used f.e. on EVE Metrics to say if counter comes from DB or DOOBJOB
    units                 varchar(20)                                  NULL, -- zmetric.columns.units overrides value set here
    --
    CONSTRAINT counters_PK PRIMARY KEY CLUSTERED (counterID)
  )

  CREATE NONCLUSTERED INDEX counters_IX_ParentCounter ON zmetric.counters (parentCounterID)

  CREATE UNIQUE NONCLUSTERED INDEX counters_UQ_Identifier ON zmetric.counters (counterIdentifier)
END
GRANT SELECT ON zmetric.counters TO zzp_server
GO


-- Data
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30004)
  INSERT INTO zmetric.counters (counterID, counterType, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30004, 'C', 'core.db.procStats', 'DB Metrics - Proc statistics', 'Proc statistics saved daily on cluster shutdown.', 2000000001)
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30007)
  INSERT INTO zmetric.counters (counterID, counterType, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30007, 'C', 'core.db.indexStats', 'DB Metrics - Index statistics', 'Index statistics saved daily by job. Note that user columns contain accumulated counts.', 2000000005)
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30008)
  INSERT INTO zmetric.counters (counterID, counterType, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30008, 'C', 'core.db.tableStats', 'DB Metrics - Table statistics', 'Table statistics saved daily by job. Note that user columns contain accumulated counts.', 2000000006)
IF NOT EXISTS(SELECT * FROM zmetric.counters WHERE counterID = 30009)
  INSERT INTO zmetric.counters (counterID, counterType, counterIdentifier, counterName, [description], keyLookupTableID)
       VALUES (30009, 'C', 'core.db.fileStats', 'DB Metrics - File statistics', 'File statistics saved daily by job. Note that most columns contain accumulated counts.', 2000000007)
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.columns') IS NULL
BEGIN
  CREATE TABLE zmetric.columns
  (
    counterID          smallint                                     NOT NULL,
    columnID           tinyint                                      NOT NULL,
    columnName         nvarchar(200)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]      nvarchar(max)                                NULL,
    [order]            smallint                                     NOT NULL  DEFAULT 0,
    units              varchar(20)                                  NULL, -- If set here it overrides value in zmetric.counters.units
    --
    CONSTRAINT columns_PK PRIMARY KEY CLUSTERED (counterID, columnID)
  )
END
GRANT SELECT ON zmetric.columns TO zzp_server
GO


-- Data
-- DB Metrics - Procedures
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004 AND columnID = 1)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30004, 1, 'calls')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004 AND columnID = 2)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30004, 2, 'rowsets')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004 AND columnID = 3)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30004, 3, 'rows')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004 AND columnID = 4)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30004, 4, 'duration')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004 AND columnID = 5)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30004, 5, 'bytesParams')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004 AND columnID = 6)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30004, 6, 'bytesData')
-- DB Metrics - Index statistics
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 1)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30007, 1, 'rows')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 2)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30007, 2, 'total_kb')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 3)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30007, 3, 'used_kb')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 4)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30007, 4, 'data_kb')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 5)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30007, 5, 'user_seeks', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 6)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30007, 6, 'user_scans', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 7)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30007, 7, 'user_lookups', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007 AND columnID = 8)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30007, 8, 'user_updates', 'Accumulated count')
-- DB Metrics - Table statistics
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 1)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30008, 1, 'rows')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 2)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30008, 2, 'total_kb')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 3)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30008, 3, 'used_kb')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 4)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30008, 4, 'data_kb')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 5)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30008, 5, 'user_seeks', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 6)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30008, 6, 'user_scans', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 7)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30008, 7, 'user_lookups', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008 AND columnID = 8)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30008, 8, 'user_updates', 'Accumulated count')
-- DB Metrics - File statistics
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 1)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30009, 1, 'reads', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 2)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30009, 2, 'reads_kb', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 3)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30009, 3, 'io_stall_read', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 4)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30009, 4, 'writes', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 5)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30009, 5, 'writes_kb', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 6)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description]) VALUES (30009, 6, 'io_stall_write', 'Accumulated count')
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009 AND columnID = 7)
  INSERT INTO zmetric.columns (counterID, columnID, columnName) VALUES (30009, 7, 'size_kb')
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.collections') IS NULL
BEGIN
  CREATE TABLE zmetric.collections
  (
    collectionID    int                                          NOT NULL  IDENTITY(1, 1),
    collectionName  nvarchar(200)  COLLATE Latin1_General_CI_AI  NOT NULL,
    groupID         smallint                                     NULL,
    [description]   nvarchar(max)                                NULL,
    [order]         smallint                                     NOT NULL  DEFAULT 0,
    createDate      datetime2(0)                                 NOT NULL  DEFAULT GETUTCDATE(),
    --
    CONSTRAINT collections_PK PRIMARY KEY CLUSTERED (collectionID)
  )
END
GRANT SELECT ON zmetric.collections TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.collectionCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.collectionCounters
  (
    collectionCounterID  int            NOT NULL  IDENTITY(1, 1),
    collectionID         int            NOT NULL,
    collectionIndex      smallint       NOT NULL,
    counterID            smallint       NOT NULL,
    subjectID            int            NOT NULL,
    keyID                int            NOT NULL,
    label                nvarchar(200)  NULL, -- Used f.e. in dashboard on EVE Metrics
    aggregateFunction    varchar(20)    NULL, -- Used f.e. in dashboard on EVE Metrics (AVG/SUM/MAX/MIN/LAST)
    severityThreshold    float          NULL, -- Used f.e. in dashboard on EVE Metrics
    goal                 float          NULL, -- Used f.e. in dashboard on EVE Metrics
    goalType             char(1)        NULL, -- Used f.e. in dashboard on EVE Metrics (P:Percentage, V:Value)
    goalDirection        char(1)        NULL, -- Used f.e. in dashboard on EVE Metrics (U:Up, D:Down)
    --
    CONSTRAINT collectionCounters_PK PRIMARY KEY CLUSTERED (collectionCounterID)
  )

  CREATE NONCLUSTERED INDEX collectionCounters_IX_CollectionIndex ON zmetric.collectionCounters (collectionID, collectionIndex)
END
GRANT SELECT ON zmetric.collectionCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.columnCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.columnCounters
  (
    counterID    smallint  NOT NULL,  -- The counter, poining to zmetric.counters
    counterDate  date      NOT NULL,  -- The date
    columnID     tinyint   NOT NULL,  -- Column if used, pointing to zmetric.columns, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting users by country, 0 if not used
    value        float     NOT NULL,  -- The value of the counter
    --
    CONSTRAINT columnCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX columnCounters_IX_CounterDate ON zmetric.columnCounters (counterID, counterDate, columnID, value)
END
GRANT SELECT ON zmetric.columnCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.dateCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.dateCounters
  (
    counterID    smallint  NOT NULL,  -- The counter, poining to zmetric.counters
    counterDate  date      NOT NULL,  -- The date
    subjectID    int       NOT NULL,  -- Subject if used, f.e. if counting for user or character, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting kills for character per solar system, 0 if not used
    value        float     NOT NULL,  -- The value of the counter
    --
    CONSTRAINT dateCounters_PK PRIMARY KEY CLUSTERED (counterID, subjectID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX dateCounters_IX_CounterDate ON zmetric.dateCounters (counterID, counterDate, value)
END
GRANT SELECT ON zmetric.dateCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.simpleCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.simpleCounters
  (
    counterID    smallint      NOT NULL,  -- The counter, poining to zmetric.counters
    counterDate  datetime2(0)  NOT NULL,  -- The datetime
    value        float         NOT NULL,  -- The value of the counter
    --
    CONSTRAINT simpleCounters_PK PRIMARY KEY CLUSTERED (counterID, counterDate)
  )
END
GRANT SELECT ON zmetric.simpleCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.timeCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.timeCounters
  (
    counterID    smallint      NOT NULL,  -- The counter, poining to zmetric.counters
    counterDate  datetime2(0)  NOT NULL,  -- The datetime
    subjectID    int           NOT NULL,  -- Subject if used, f.e. if counting for user or character, 0 if not used
    keyID        int           NOT NULL,  -- Key if used, f.e. if counting kills for character per solar system, 0 if not used
    value        float         NOT NULL,  -- The value of the counter
    --
    CONSTRAINT timeCounters_PK PRIMARY KEY CLUSTERED (counterID, subjectID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX timeCounters_IX_CounterDate ON zmetric.timeCounters (counterID, counterDate, value)
END
GRANT SELECT ON zmetric.timeCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


-- MIGRATE DATA
IF OBJECT_ID('zevent.counters') IS NOT NULL AND NOT EXISTS(SELECT * FROM zmetric.counters)
BEGIN
  INSERT INTO zmetric.counters (counterID, counterName, [description], subjectLookupTableID, keyLookupTableID, [source], subjectID, keyID, counterIdentifier)
       SELECT counterID, counterName, [description], subjectLookupTableID, keyLookupTableID, [source], subjectID, keyID, counterID FROM zevent.counters
END
GO


-- MIGRATE DATA
IF OBJECT_ID('zevent.counterColumns') IS NOT NULL AND NOT EXISTS(SELECT * FROM zmetric.columns)
BEGIN
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       SELECT counterID, subjectID, columnName, [description] FROM zevent.counterColumns
END
GO


-- MIGRATE DATA
IF OBJECT_ID('zevent.dateCounters') IS NOT NULL AND NOT EXISTS(SELECT * FROM zmetric.dateCounters)
BEGIN
  INSERT INTO zmetric.dateCounters (counterID, counterDate, subjectID, keyID, value)
       SELECT counterID, counterDate, subjectID, keyID, value FROM zevent.dateCounters
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.Counters_ID') IS NOT NULL
  DROP FUNCTION zmetric.Counters_ID
GO
CREATE FUNCTION zmetric.Counters_ID(@counterIdentifier varchar(500))
RETURNS smallint
BEGIN
  DECLARE @counterID int
  SELECT @counterID = counterID FROM zmetric.counters WHERE counterIdentifier = @counterIdentifier
  RETURN @counterID
END
GO
GRANT EXEC ON zmetric.Counters_ID TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.countersEx') IS NOT NULL
  DROP VIEW zmetric.countersEx
GO
CREATE VIEW zmetric.countersEx
AS
  SELECT C.groupID, G.groupName, C.counterID, C.counterName, C.counterType, C.counterIdentifier, C.[description],
         C.subjectLookupTableID, subjectLookupTableName = LS.lookupTableName,
         C.keyLookupTableID, keyLookupTableName = LK.lookupTableName,
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
  SELECT C.groupID, G.groupName, O.counterID, C.counterName, O.columnID, O.columnName, O.[description], O.units, O.[order]
    FROM zmetric.columns O
      LEFT JOIN zmetric.counters C ON C.counterID = O.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
GO
GRANT SELECT ON zmetric.columnsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.collectionsEx') IS NOT NULL
  DROP VIEW zmetric.collectionsEx
GO
CREATE VIEW zmetric.collectionsEx
AS
  SELECT C.groupID, G.groupName, C.collectionID, C.collectionName, C.[description], groupOrder = G.[order], C.[order]
    FROM zmetric.collections C
      LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
GO
GRANT SELECT ON zmetric.collectionsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.collectionCountersEx') IS NOT NULL
  DROP VIEW zmetric.collectionCountersEx
GO
CREATE VIEW zmetric.collectionCountersEx
AS
  SELECT CC.collectionCounterID, collectionGroupID = O.groupID, collectionGroupName = OG.groupName, CC.collectionID, O.collectionName, CC.collectionIndex,
         counterGroupID = C.groupID, counterGroupName = CG.groupName, CC.counterID, C.counterName,
         CC.subjectID, subjectText = COALESCE(L.columnName, LS.[fullText], LS.lookupText),
         CC.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText),
         CC.label, CC.aggregateFunction, CC.severityThreshold, CC.goal, CC.goalType, CC.goalDirection
    FROM zmetric.collectionCounters CC
      LEFT JOIN zmetric.collections O ON O.collectionID = CC.collectionID
        LEFT JOIN zmetric.groups OG ON OG.groupID = O.groupID
      LEFT JOIN zmetric.counters C ON C.counterID = CC.counterID
        LEFT JOIN zmetric.groups CG ON CG.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = CC.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = CC.keyID
      LEFT JOIN zmetric.columns L ON L.counterID = CC.counterID AND CONVERT(int, L.columnID) = CC.subjectID
GO
GRANT SELECT ON zmetric.collectionCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.columnCountersEx') IS NOT NULL
  DROP VIEW zmetric.columnCountersEx
GO
CREATE VIEW zmetric.columnCountersEx
AS
  SELECT C.groupID, G.groupName, CC.counterID, C.counterName, CC.counterDate, CC.columnID, O.columnName,
         CC.keyID, keyText = ISNULL(L.[fullText], L.lookupText), CC.[value]
    FROM zmetric.columnCounters CC
      LEFT JOIN zmetric.counters C ON C.counterID = CC.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = C.keyLookupTableID AND L.lookupID = CC.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = CC.counterID AND O.columnID = CC.columnID
GO
GRANT SELECT ON zmetric.columnCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.dateCountersEx') IS NOT NULL
  DROP VIEW zmetric.dateCountersEx
GO
CREATE VIEW zmetric.dateCountersEx
AS
  SELECT DC.counterID, C.counterName, DC.counterDate,
         DC.subjectID, subjectText = COALESCE(O.columnName, LS.[fullText], LS.lookupText),
         DC.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), DC.[value]
    FROM zmetric.dateCounters DC
      LEFT JOIN zmetric.counters C ON C.counterID = DC.counterID
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
  SELECT SC.counterID, C.counterName, SC.counterDate, SC.value
    FROM zmetric.simpleCounters SC
      LEFT JOIN zmetric.counters C ON C.counterID = SC.counterID
GO
GRANT SELECT ON zmetric.simpleCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.timeCountersEx') IS NOT NULL
  DROP VIEW zmetric.timeCountersEx
GO
CREATE VIEW zmetric.timeCountersEx
AS
  SELECT TC.counterID, C.counterName, TC.counterDate,
         TC.subjectID, subjectText = ISNULL(LS.[fullText], LS.lookupText),
         TC.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), TC.value
    FROM zmetric.timeCounters TC
      LEFT JOIN zmetric.counters C ON C.counterID = TC.counterID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = TC.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = TC.keyID
GO
GRANT SELECT ON zmetric.timeCountersEx TO zzp_server
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


IF OBJECT_ID('zmetric.Counters_Report') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_Report
GO
CREATE PROCEDURE zmetric.Counters_Report
  @counterID      smallint,
  @fromDate       date = NULL,
  @toDate         date = NULL,
  @rows           int = 20,
  @orderColumnID  tinyint = NULL,
  @orderDesc      bit = 1,
  @lookupText     nvarchar(1000) = NULL,
  @seekOlder      bit = 1
AS
  -- Create dynamic SQL to return report used on INFO - Metrics
  SET NOCOUNT ON

  BEGIN TRY
    IF @rows > 10000
      RAISERROR ('@rows over limit', 16, 1)

    IF @fromDate IS NULL
    BEGIN
      IF @toDate IS NOT NULL
        RAISERROR ('@toDate set when @fromDate is not set', 16, 1)
      SET @fromDate = GETUTCDATE()
    END

    DECLARE @counterType char(1), @subjectLookupTableID int, @keyLookupTableID int
    SELECT @counterType = counterType, @subjectLookupTableID = subjectLookupTableID, @keyLookupTableID = keyLookupTableID
      FROM zmetric.counters
     WHERE counterID = @counterID
    IF @counterType NOT IN ('C', 'D')
      RAISERROR ('Only counter types C and D are supported', 16, 1)

    DECLARE @dateRequested date, @dateReturned date
    IF @toDate IS NULL
    BEGIN
      SET @dateRequested = @fromDate
      IF @counterType = 'C'
      BEGIN
        IF NOT EXISTS(SELECT * FROM zmetric.columnCounters WHERE counterID = @counterID AND counterDate = @fromDate)
        BEGIN
          IF @seekOlder = 1
            SELECT TOP 1 @fromDate = counterDate FROM zmetric.columnCounters WHERE counterID = @counterID AND counterDate < @fromDate ORDER BY counterDate DESC
          ELSE
            SELECT TOP 1 @fromDate = counterDate FROM zmetric.columnCounters WHERE counterID = @counterID AND counterDate > @fromDate ORDER BY counterDate
        END
      END
      ELSE
      BEGIN
        IF NOT EXISTS(SELECT * FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate = @fromDate)
        BEGIN
          IF @seekOlder = 1
            SELECT TOP 1 @fromDate = counterDate FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate < @fromDate ORDER BY counterDate DESC
          ELSE
            SELECT TOP 1 @fromDate = counterDate FROM zmetric.dateCounters WHERE counterID = @counterID AND counterDate > @fromDate ORDER BY counterDate
        END
      END
      SET @dateReturned = @fromDate
    END

    IF @subjectLookupTableID IS NOT NULL AND @keyLookupTableID IS NULL
      RAISERROR ('Counter is not valid, subject lookup set and key lookup not set', 16, 1)

    SELECT dateRequested = @dateRequested, dateReturned = @dateReturned

    DECLARE @sql nvarchar(max)

    IF @subjectLookupTableID IS NOT NULL AND @keyLookupTableID IS NOT NULL
    BEGIN
      -- Subject + Key, Single column
      IF @counterType != 'D'
        RAISERROR ('Counter is not valid, subject and key lookup set and counter not of type D', 16, 1)
      SET @sql = 'SELECT TOP (@pRows) C.subjectID, subjectText = S.lookupText, C.keyID, keyText = K.lookupText, '
      IF @toDate IS NULL
        SET @sql = @sql + 'C.value'
      ELSE
        SET @sql = @sql + 'value = SUM(C.value)'
      SET @sql = @sql + CHAR(13) + ' FROM zmetric.dateCounters C'
      SET @sql = @sql + CHAR(13) + ' LEFT JOIN zsystem.lookupValues S ON S.lookupTableID = @pSubjectLookupTableID AND S.lookupID = C.subjectID'
      SET @sql = @sql + CHAR(13) + ' LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
      SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
      IF @toDate IS NULL
        SET @sql = @sql + 'C.counterDate = @pFromDate'
      ELSE
        SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate'
      IF @lookupText IS NOT NULL AND @lookupText != ''
        SET @sql = @sql + ' AND (S.lookupText LIKE ''%'' + @pLookupText + ''%'' OR K.lookupText LIKE ''%'' + @pLookupText + ''%'')'
      IF @toDate IS NOT NULL
        SET @sql = @sql + CHAR(13) + ' GROUP BY C.subjectID, S.lookupText, C.keyID, K.lookupText'
      SET @sql = @sql + CHAR(13) + ' ORDER BY C.value'
      IF @orderDesc = 1
        SET @sql = @sql + ' DESC'
      EXEC sp_executesql @sql, N'@pRows int, @pCounterID smallint, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)', @rows, @counterID, @fromDate, @toDate, @lookupText
    END
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.columns WHERE counterID = @counterID)
      BEGIN
        -- Multiple columns (Single value / Multiple key values)
        DECLARE @columnID tinyint, @columnName nvarchar(200), @orderBy nvarchar(200), @sql2 nvarchar(max) = '', @alias nvarchar(10)
        IF @keyLookupTableID IS NULL
          SET @sql = 'SELECT '
        ELSE
          SET @sql = 'SELECT TOP(@pRows) C.keyID, keyText = K.lookupText'
        IF @counterType = 'C'
          SET @sql2 = '  FROM zmetric.columnCounters C'
        ELSE
          SET @sql2 = '  FROM zmetric.dateCounters C'
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
          IF @sql != 'SELECT '
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
            IF @counterType = 'C'
              SET @sql2 = @sql2 + CHAR(13) + '    LEFT JOIN zmetric.columnCounters ' + @alias
              SET @sql2 = @sql2 + ' ON ' + @alias + '.counterID = C.counterID AND ' + @alias + '.columnID = ' + CONVERT(nvarchar, @columnID)
              SET @sql2 = @sql2 + ' AND ' + @alias + '.counterDate = C.counterDate AND ' + @alias + '.keyID = C.keyID'
          END
          FETCH NEXT FROM @cursor INTO @columnID, @columnName
        END
        CLOSE @cursor
        DEALLOCATE @cursor
        SET @sql = @sql + CHAR(13) + @sql2
        IF @keyLookupTableID IS NOT NULL
          SET @sql = @sql + CHAR(13) + '    LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
        SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
        IF @toDate IS NULL
          SET @sql = @sql + 'C.counterDate = @pFromDate AND'
        ELSE
          SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate AND'
        IF @counterType = 'C'
          SET @sql = @sql + ' C.columnID = ' + CONVERT(nvarchar, @orderColumnID)
        ELSE
          SET @sql = @sql + ' C.subjectID = ' + CONVERT(nvarchar, @orderColumnID)
        IF @keyLookupTableID IS NOT NULL
        BEGIN
          IF @lookupText IS NOT NULL AND @lookupText != ''
            SET @sql = @sql + ' AND K.lookupText LIKE ''%'' + @pLookupText + ''%'''
          IF @toDate IS NOT NULL
            SET @sql = @sql + CHAR(13) + ' GROUP BY C.keyID, K.lookupText'
          SET @sql = @sql + CHAR(13) + ' ORDER BY ' + @orderBy
          IF @orderDesc = 1
            SET @sql = @sql + ' DESC'
        END
        EXEC sp_executesql @sql, N'@pRows int, @pCounterID smallint, @pFromDate date, @pToDate date, @pKeyLookupTableID int, @pLookupText nvarchar(1000)', @rows, @counterID, @fromDate, @toDate, @keyLookupTableID, @lookupText
      END
      ELSE
      BEGIN
        -- Single column
        IF @keyLookupTableID IS NULL
        BEGIN
          -- Single value, Single column
          SET @sql = 'SELECT '
          IF @toDate IS NULL
            SET @sql = @sql + 'value'
          ELSE
            SET @sql = @sql + 'value = SUM(value)'
          IF @counterType = 'C'
            SET @sql = @sql + ' FROM zmetric.columnCounters'
          ELSE
            SET @sql = @sql + ' FROM zmetric.dateCounters'
          SET @sql = @sql + ' WHERE counterID = @pCounterID AND '
          IF @toDate IS NULL
            SET @sql = @sql + 'counterDate = @pFromDate'
          ELSE
            SET @sql = @sql + 'counterDate BETWEEN @pFromDate AND @pToDate'
          EXEC sp_executesql @sql, N'@pCounterID smallint, @pFromDate date, @pToDate date', @counterID, @fromDate, @toDate
        END
        ELSE
        BEGIN
          -- Multiple key values, Single column (not using WHERE subjectID = 0 as its not in the index, trusting that its always 0)
          SET @sql = 'SELECT TOP (@pRows) C.keyID, keyText = K.lookupText, '
          IF @toDate IS NULL
            SET @sql = @sql + 'C.value'
          ELSE
            SET @sql = @sql + 'value = SUM(C.value)'
          IF @counterType = 'C'
            SET @sql = @sql + CHAR(13) + '  FROM zmetric.columnCounters C'
          ELSE
            SET @sql = @sql + CHAR(13) + '  FROM zmetric.dateCounters C'
          SET @sql = @sql + CHAR(13) + '    LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
          SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
          IF @toDate IS NULL
            SET @sql = @sql + 'C.counterDate = @pFromDate'
          ELSE
            SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate'
          IF @lookupText IS NOT NULL AND @lookupText != ''
            SET @sql = @sql + ' AND K.lookupText LIKE ''%'' + @pLookupText + ''%'''
          IF @toDate IS NOT NULL
            SET @sql = @sql + CHAR(13) + ' GROUP BY C.keyID, K.lookupText'
          SET @sql = @sql + CHAR(13) + ' ORDER BY C.value'
          IF @orderDesc = 1
            SET @sql = @sql + ' DESC'
          EXEC sp_executesql @sql, N'@pRows int, @pCounterID smallint, @pFromDate date, @pToDate date, @pKeyLookupTableID int, @pLookupText nvarchar(1000)', @rows, @counterID, @fromDate, @toDate, @keyLookupTableID, @lookupText
        END
      END
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.Counters_Report'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zmetric.Counters_Report TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.ColumnCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_Insert
GO
CREATE PROCEDURE zmetric.ColumnCounters_Insert
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

  INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value)
       VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
GO
GRANT EXEC ON zmetric.ColumnCounters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.ColumnCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_Update
GO
CREATE PROCEDURE zmetric.ColumnCounters_Update
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

  UPDATE zmetric.columnCounters
      SET value = value + @value
    WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value)
          VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.columnCounters
         SET value = value + @value
       WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.ColumnCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.ColumnCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.ColumnCounters_UpdateMulti') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_UpdateMulti
GO
CREATE PROCEDURE zmetric.ColumnCounters_UpdateMulti
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
    UPDATE zmetric.columnCounters SET value = value + @value1 WHERE counterID = @counterID AND columnID = 1 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 1, @keyID, @value1)
  END

  IF ISNULL(@value2, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value2 WHERE counterID = @counterID AND columnID = 2 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 2, @keyID, @value2)
  END

  IF ISNULL(@value3, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value3 WHERE counterID = @counterID AND columnID = 3 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 3, @keyID, @value3)
  END

  IF ISNULL(@value4, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value4 WHERE counterID = @counterID AND columnID = 4 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 4, @keyID, @value4)
  END

  IF ISNULL(@value5, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value5 WHERE counterID = @counterID AND columnID = 5 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 5, @keyID, @value5)
  END

  IF ISNULL(@value6, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value6 WHERE counterID = @counterID AND columnID = 6 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 6, @keyID, @value6)
  END

  IF ISNULL(@value7, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value7 WHERE counterID = @counterID AND columnID = 7 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 7, @keyID, @value7)
  END

  IF ISNULL(@value8, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value8 WHERE counterID = @counterID AND columnID = 8 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 8, @keyID, @value8)
  END

  IF ISNULL(@value9, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value9 WHERE counterID = @counterID AND columnID = 9 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 9, @keyID, @value9)
  END

  IF ISNULL(@value10, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.columnCounters SET value = value + @value10 WHERE counterID = @counterID AND columnID = 10 AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.columnCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 10, @keyID, @value10)
  END
GO
GRANT EXEC ON zmetric.ColumnCounters_UpdateMulti TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.IndexStats_Save') IS NOT NULL
  DROP PROCEDURE zmetric.IndexStats_Save
GO
CREATE PROCEDURE zmetric.IndexStats_Save
AS
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @rows bigint, @total_kb bigint, @used_kb bigint, @data_kb bigint,
          @user_seeks bigint, @user_scans bigint, @user_lookups bigint, @user_updates bigint,
          @counterDate date, @keyText nvarchar(450), @keyID int

  SET @counterDate = GETUTCDATE()

  -- INDEX STATISTICS
  DELETE FROM zmetric.columnCounters WHERE counterID = 30007 AND counterDate = @counterDate
  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL STATIC READ_ONLY --FAST_FORWARD
    FOR SELECT S.name + '.' + T.name + '.' + ISNULL(I.name, 'HEAP'),
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
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
  WHILE @@FETCH_STATUS = 0
  BEGIN
    EXEC zmetric.ColumnCounters_UpdateMulti 30007, 'D', @counterDate, 2000000005, NULL, @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates

    FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  -- TABLE STATISTICS
  DELETE FROM zmetric.columnCounters WHERE counterID = 30008 AND counterDate = @counterDate
  SET @cursor = CURSOR LOCAL STATIC READ_ONLY --FAST_FORWARD
    FOR SELECT keyText, SUM(rows), SUM(total_kb), SUM(used_kb), SUM(data_kb), SUM(user_seeks), SUM(user_scans), SUM(user_lookups), SUM(user_updates)
          FROM (SELECT keyText = S.name + '.' + T.name, indexName = ISNULL(I.name, 'HEAP'),
                       [rows] = SUM(CASE WHEN I.index_id IN (0, 1) AND A.[type] = 1 THEN P.[rows] ELSE 0 END),  -- IN_ROW_DATA 
                       total_kb = SUM(A.total_pages * 8), used_kb = SUM(A.used_pages * 8), data_kb = SUM(A.data_pages * 8),
                       user_seeks = MAX(U.user_seeks), user_scans = MAX(U.user_scans), user_lookups = MAX(U.user_lookups), user_updates = MAX(U.user_updates)
                  FROM sys.tables T
                    INNER JOIN sys.schemas S ON S.[schema_id] = T.[schema_id]
                    INNER JOIN sys.indexes I ON I.[object_id] = T.[object_id]
                      INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
                        INNER JOIN sys.allocation_units A ON A.container_id = P.partition_id
                      LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id = DB_ID() AND U.[object_id] = I.[object_id] AND U.index_id = I.index_id
                 WHERE T.is_ms_shipped != 1
                 GROUP BY S.name, T.name, I.name
                 ) X
         GROUP BY keyText
         ORDER BY keyText
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
  WHILE @@FETCH_STATUS = 0
  BEGIN
    EXEC zmetric.ColumnCounters_UpdateMulti 30008, 'D', @counterDate, 2000000006, NULL, @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates

    FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.IndexStats_Mail') IS NOT NULL
  DROP PROCEDURE zmetric.IndexStats_Mail
GO
CREATE PROCEDURE zmetric.IndexStats_Mail
  @counterDate  date = NULL,
  @rows         smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @recipients varchar(max)
  SET @recipients = zsystem.Settings_Value('zmetric', 'Recipients-IndexStats')
  IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
  BEGIN
    IF @counterDate IS NULL SET @counterDate = GETDATE()

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
        FROM zmetric.columnCounters C1
          LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000006 AND L.lookupID = C1.keyID
          LEFT JOIN zmetric.columnCounters C2 ON C2.counterID = C1.counterID AND C2.counterDate = C1.counterDate AND C2.columnID = 2 AND C2.keyID = C1.keyID
          LEFT JOIN zmetric.columnCounters C3 ON C3.counterID = C1.counterID AND C3.counterDate = C1.counterDate AND C3.columnID = 3 AND C3.keyID = C1.keyID
          LEFT JOIN zmetric.columnCounters C4 ON C4.counterID = C1.counterID AND C4.counterDate = C1.counterDate AND C4.columnID = 4 AND C4.keyID = C1.keyID
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
        FROM zmetric.columnCounters C2
          LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000006 AND L.lookupID = C2.keyID
          LEFT JOIN zmetric.columnCounters C3 ON C3.counterID = C2.counterID AND C3.counterDate = C2.counterDate AND C3.columnID = 3 AND C3.keyID = C2.keyID
          LEFT JOIN zmetric.columnCounters C4 ON C4.counterID = C2.counterID AND C4.counterDate = C2.counterDate AND C4.columnID = 4 AND C4.keyID = C2.keyID
          LEFT JOIN zmetric.columnCounters C1 ON C1.counterID = C2.counterID AND C1.counterDate = C2.counterDate AND C1.columnID = 1 AND C1.keyID = C2.keyID
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
        FROM zmetric.columnCounters C5
          LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C5.keyID
          LEFT JOIN zmetric.columnCounters C5B ON C5B.counterID = C5.counterID AND C5B.counterDate = @subtractDate AND C5B.columnID = C5.columnID AND C5B.keyID = C5.keyID
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
        FROM zmetric.columnCounters C6
          LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C6.keyID
          LEFT JOIN zmetric.columnCounters C6B ON C6B.counterID = C6.counterID AND C6B.counterDate = @subtractDate AND C6B.columnID = C6.columnID AND C6B.keyID = C6.keyID
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
        FROM zmetric.columnCounters C7
          LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C7.keyID
          LEFT JOIN zmetric.columnCounters C7B ON C7B.counterID = C7.counterID AND C7B.counterDate = @subtractDate AND C7B.columnID = C7.columnID AND C7B.keyID = C7.keyID
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
        FROM zmetric.columnCounters C8
          LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C8.keyID
          LEFT JOIN zmetric.columnCounters C8B ON C8B.counterID = C8.counterID AND C8B.counterDate = @subtractDate AND C8B.columnID = C8.columnID AND C8B.keyID = C8.keyID
       WHERE C8.counterID = 30007 AND C8.counterDate = @counterDate AND C8.columnID = 8
       ORDER BY (C8.value - ISNULL(C8B.value, 0)) DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

    EXEC zsystem.SendMail @recipients, @subject, @body, 'HTML'
  END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.ColumnCounters_SaveStats') IS NOT NULL
  DROP PROCEDURE zmetric.ColumnCounters_SaveStats
GO
CREATE PROCEDURE zmetric.ColumnCounters_SaveStats
AS
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zmetric.IndexStats_Save

  DECLARE @counterDate date, @keyText nvarchar(450)

  SET @counterDate = GETUTCDATE()

  -- FILE STATISTICS
  DECLARE @database_name nvarchar(200), @file_type nvarchar(20), @filegroup_name nvarchar(200),
          @reads bigint, @reads_kb bigint, @io_stall_read bigint, @writes bigint, @writes_kb bigint, @io_stall_write bigint, @size_kb bigint

  DELETE FROM zmetric.columnCounters WHERE counterID = 30009 AND counterDate = @counterDate
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

    EXEC zmetric.ColumnCounters_UpdateMulti 30009, 'D', @counterDate, 2000000007, NULL, @keyText,  @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb

    FETCH NEXT FROM @cursor INTO @database_name, @file_type, @filegroup_name, @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.DateCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.DateCounters_Insert
GO
CREATE PROCEDURE zmetric.DateCounters_Insert
  @counterID    smallint,
  @subjectID    int = 0,
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

  INSERT INTO zmetric.dateCounters (counterID, counterDate, subjectID, keyID, value)
       VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
GO
GRANT EXEC ON zmetric.DateCounters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.DateCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.DateCounters_Update
GO
CREATE PROCEDURE zmetric.DateCounters_Update
  @counterID    smallint,
  @subjectID    int = 0,
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

  UPDATE zmetric.dateCounters
     SET value = value + @value
   WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.dateCounters (counterID, counterDate, subjectID, keyID, value)
         VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.dateCounters
         SET value = value + @value
       WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.DateCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.DateCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.SimpleCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.SimpleCounters_Insert
GO
CREATE PROCEDURE zmetric.SimpleCounters_Insert
  @counterID    smallint,
  @value        float,
  @interval     varchar(3) = 'M', -- M:Minute, M2:2Minutes, M3:3Minutes. M5:5Minutes, M10:10Minutes, M15:15Minutes, M30:30Minutes, H:Hour
  @counterDate  datetime2(0) = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval IS NOT NULL
  BEGIN
    SET @counterDate = CASE @interval WHEN 'H' THEN zutil.DateHour(@counterDate)
                                      WHEN 'M' THEN zutil.DateMinute(@counterDate)
                                      WHEN 'M2' THEN zutil.DateMinutes(@counterDate, 2)
                                      WHEN 'M3' THEN zutil.DateMinutes(@counterDate, 3)
                                      WHEN 'M5' THEN zutil.DateMinutes(@counterDate, 5)
                                      WHEN 'M10' THEN zutil.DateMinutes(@counterDate, 10)
                                      WHEN 'M15' THEN zutil.DateMinutes(@counterDate, 15)
                                      WHEN 'M30' THEN zutil.DateMinutes(@counterDate, 30)
                                      ELSE @counterDate END
  END

  INSERT INTO zmetric.simpleCounters (counterID, counterDate, value) VALUES (@counterID, @counterDate, @value)
GO
GRANT EXEC ON zmetric.SimpleCounters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.SimpleCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.SimpleCounters_Update
GO
CREATE PROCEDURE zmetric.SimpleCounters_Update
  @counterID    smallint,
  @value        float,
  @interval     varchar(3) = 'M', -- M:Minute, M2:2Minutes, M3:3Minutes. M5:5Minutes, M10:10Minutes, M15:15Minutes, M30:30Minutes, H:Hour
  @counterDate  datetime2(0) = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval IS NOT NULL
  BEGIN
    SET @counterDate = CASE @interval WHEN 'H' THEN zutil.DateHour(@counterDate)
                                      WHEN 'M' THEN zutil.DateMinute(@counterDate)
                                      WHEN 'M2' THEN zutil.DateMinutes(@counterDate, 2)
                                      WHEN 'M3' THEN zutil.DateMinutes(@counterDate, 3)
                                      WHEN 'M5' THEN zutil.DateMinutes(@counterDate, 5)
                                      WHEN 'M10' THEN zutil.DateMinutes(@counterDate, 10)
                                      WHEN 'M15' THEN zutil.DateMinutes(@counterDate, 15)
                                      WHEN 'M30' THEN zutil.DateMinutes(@counterDate, 30)
                                      ELSE @counterDate END
  END

  UPDATE zmetric.simpleCounters SET value = value + @value WHERE counterID = @counterID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.simpleCounters (counterID, counterDate, value) VALUES (@counterID, @counterDate, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
      UPDATE zmetric.simpleCounters SET value = value + @value WHERE counterID = @counterID AND counterDate = @counterDate
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.SimpleCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.SimpleCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.SimpleCounters_Select') IS NOT NULL
  DROP PROCEDURE zmetric.SimpleCounters_Select
GO
CREATE PROCEDURE zmetric.SimpleCounters_Select
  @counterID  smallint,
  @fromDate   datetime2(0) = NULL,
  @toDate     datetime2(0) = NULL,
  @rows       int = 1000000
AS
  SET NOCOUNT ON

  SELECT TOP (@rows) counterDate, value
    FROM zmetric.simpleCounters
   WHERE counterID = @counterID AND
         counterDate BETWEEN ISNULL(@fromDate, CONVERT(datetime2(0), '0001-01-01')) AND ISNULL(@toDate, CONVERT(datetime2(0), '9999-12-31'))
   ORDER BY counterDate
GO
GRANT EXEC ON zmetric.SimpleCounters_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.TimeCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.TimeCounters_Insert
GO
CREATE PROCEDURE zmetric.TimeCounters_Insert
  @counterID    smallint,
  @subjectID    int = 0,
  @keyID        int = 0,
  @value        float,
  @interval     varchar(3) = 'M', -- M:Minute, M2:2Minutes, M3:3Minutes. M5:5Minutes, M10:10Minutes, M15:15Minutes, M30:30Minutes, H:Hour
  @counterDate  datetime2(0) = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval IS NOT NULL
  BEGIN
    SET @counterDate = CASE @interval WHEN 'H' THEN zutil.DateHour(@counterDate)
                                      WHEN 'M' THEN zutil.DateMinute(@counterDate)
                                      WHEN 'M2' THEN zutil.DateMinutes(@counterDate, 2)
                                      WHEN 'M3' THEN zutil.DateMinutes(@counterDate, 3)
                                      WHEN 'M5' THEN zutil.DateMinutes(@counterDate, 5)
                                      WHEN 'M10' THEN zutil.DateMinutes(@counterDate, 10)
                                      WHEN 'M15' THEN zutil.DateMinutes(@counterDate, 15)
                                      WHEN 'M30' THEN zutil.DateMinutes(@counterDate, 30)
                                      ELSE @counterDate END
  END

  INSERT INTO zmetric.timeCounters (counterID, counterDate, subjectID, keyID, value)
       VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
GO
GRANT EXEC ON zmetric.TimeCounters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zmetric.TimeCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.TimeCounters_Update
GO
CREATE PROCEDURE zmetric.TimeCounters_Update
  @counterID    smallint,
  @subjectID    int = 0,
  @keyID        int = 0,
  @value        float,
  @interval     varchar(3) = 'M', -- M:Minute, M2:2Minutes, M3:3Minutes. M5:5Minutes, M10:10Minutes, M15:15Minutes, M30:30Minutes, H:Hour
  @counterDate  datetime2(0) = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval IS NOT NULL
  BEGIN
    SET @counterDate = CASE @interval WHEN 'H' THEN zutil.DateHour(@counterDate)
                                      WHEN 'M' THEN zutil.DateMinute(@counterDate)
                                      WHEN 'M2' THEN zutil.DateMinutes(@counterDate, 2)
                                      WHEN 'M3' THEN zutil.DateMinutes(@counterDate, 3)
                                      WHEN 'M5' THEN zutil.DateMinutes(@counterDate, 5)
                                      WHEN 'M10' THEN zutil.DateMinutes(@counterDate, 10)
                                      WHEN 'M15' THEN zutil.DateMinutes(@counterDate, 15)
                                      WHEN 'M30' THEN zutil.DateMinutes(@counterDate, 30)
                                      ELSE @counterDate END
  END

  UPDATE zmetric.timeCounters
     SET value = value + @value
   WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.timeCounters (counterID, counterDate, subjectID, keyID, value)
         VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.timeCounters
         SET value = value + @value
       WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.TimeCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.TimeCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.DateCounters_Update') IS NOT NULL
  DROP PROCEDURE zevent.DateCounters_Update
GO
IF OBJECT_ID('zevent.dateCountersEx') IS NOT NULL
  DROP VIEW zevent.dateCountersEx
GO
IF OBJECT_ID('zevent.counterColumnsEx') IS NOT NULL
  DROP VIEW zevent.counterColumnsEx
GO
IF OBJECT_ID('zevent.countersEx') IS NOT NULL
  DROP VIEW zevent.countersEx
GO
IF OBJECT_ID('zevent.dateCounters') IS NOT NULL
  DROP TABLE zevent.dateCounters
GO
IF OBJECT_ID('zevent.counterColumns') IS NOT NULL
  DROP TABLE zevent.counterColumns
GO
IF OBJECT_ID('zevent.counters') IS NOT NULL
  DROP TABLE zevent.counters
GO
IF SCHEMA_ID('zevent') IS NOT NULL
  EXEC sp_executesql N'DROP SCHEMA zevent'
GO

IF OBJECT_ID('zsys.ProcedureStats_DeleteDate') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_DeleteDate
GO
IF OBJECT_ID('zsys.ProcedureStats_Select') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_Select
GO
IF OBJECT_ID('zsys.ProcedureStats_Update') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_Update
GO
IF OBJECT_ID('zsys.procedureStatsEx') IS NOT NULL
  DROP VIEW zsys.procedureStatsEx
GO
IF OBJECT_ID('zsys.procedureStats') IS NOT NULL
  DROP TABLE zsys.procedureStats
GO
IF OBJECT_ID('zsys.IndexStats_Insert') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Insert
GO
IF OBJECT_ID('zsys.IndexStats_Mail') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Mail
GO
IF OBJECT_ID('zsys.IndexStats_Select') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Select
GO
IF OBJECT_ID('zsys.indexStatsEx') IS NOT NULL
  DROP VIEW zsys.indexStatsEx
GO
IF OBJECT_ID('zsys.indexStats') IS NOT NULL
  DROP TABLE zsys.indexStats
GO
IF OBJECT_ID('zsys.indexesEx') IS NOT NULL
  DROP VIEW zsys.indexesEx
GO
IF OBJECT_ID('zsys.indexes') IS NOT NULL
  DROP TABLE zsys.indexes
GO
IF OBJECT_ID('zsys.Objects_Info') IS NOT NULL
  DROP PROCEDURE zsys.Objects_Info
GO
IF OBJECT_ID('zsys.Objects_Refresh') IS NOT NULL
  DROP PROCEDURE zsys.Objects_Refresh
GO
IF OBJECT_ID('zsys.objectsEx') IS NOT NULL
  DROP VIEW zsys.objectsEx
GO
IF OBJECT_ID('zsys.objects') IS NOT NULL
  DROP TABLE zsys.objects
GO
IF OBJECT_ID('zsys.schemas') IS NOT NULL
  DROP TABLE zsys.schemas
GO
IF SCHEMA_ID('zsys') IS NOT NULL
  EXEC sp_executesql N'DROP SCHEMA zsys'
GO
delete from zsystem.settings where [group] = 'zsys' and [key] = 'Recipients-IndexStats'
GO


---------------------------------------------------------------------------------------------------



EXEC zsystem.Versions_Finish 'CORE.J', 0003, 'jorundur'
GO
