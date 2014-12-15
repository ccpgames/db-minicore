
EXEC zsystem.Versions_Start 'CORE.J', 0006, 'jorundur'
GO



---------------------------------------------------------------------------------------------------------------------------------


-- Based on code from Ben Dill

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

    IF @break = 0
    BEGIN
      PRINT LEFT(@str, 4000)
      SET @str = RIGHT(@str, LEN(@str) - 4000)
    END
    ELSE
    BEGIN
      PRINT LEFT(@str, 4000 - @break + 1)
      SET @str = RIGHT(@str, LEN(@str) - 4000 + @break - 1)
    END
  END

  IF LEN(@str) > 0
    PRINT @str
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.counters') IS NOT NULL
  DROP PROCEDURE zdm.counters
GO
CREATE PROCEDURE zdm.counters
  @time_to_pass  char(8)= '00:00:03'
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0), @seconds int, @dbName nvarchar(128),
          @pageLookups bigint, @pageReads bigint, @pageWrites bigint, @pageSplits bigint,
          @transactions bigint, @writeTransactions bigint, @batchRequests bigint,
          @logins bigint, @logouts bigint, @tempTables bigint,
          @indexSearches bigint, @fullScans bigint, @probeScans bigint, @rangeScans bigint

  SELECT @now = GETUTCDATE(), @dbName = DB_NAME()

  SELECT @pageLookups = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page lookups/sec'

  SELECT @pageReads = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page reads/sec'

  SELECT @pageWrites = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page writes/sec'

  SELECT @pageSplits = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Page Splits/sec'

  SELECT @transactions = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Transactions/sec' AND instance_name = @dbName

  SELECT @writeTransactions = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Write Transactions/sec' AND instance_name = @dbName

  SELECT @batchRequests = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:SQL Statistics' AND counter_name = 'Batch Requests/sec'

  SELECT @logins = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logins/sec'

  SELECT @logouts = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logouts/sec'

  SELECT @tempTables = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Temp Tables Creation Rate'

  SELECT @indexSearches = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Index Searches/sec'

  SELECT @fullScans = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Full Scans/sec'

  SELECT @probeScans = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Probe Scans/sec'

  SELECT @rangeScans = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Range Scans/sec'

  WAITFOR DELAY @time_to_pass

  SET @seconds = DATEDIFF(second, @now, GETUTCDATE())

  SELECT [object_name] = RTRIM([object_name]), counter_name = RTRIM(counter_name), cntr_value = (cntr_value - @pageLookups) / @seconds, info = '', instance_name = RTRIM(instance_name), [description] = 'Number of requests per second to find a page in the buffer pool.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page lookups/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @pageReads) / @seconds, '', RTRIM(instance_name), 'Number of physical database page reads that are issued per second. This statistic displays the total number of physical page reads across all databases. Because physical I/O is expensive, you may be able to minimize the cost, either by using a larger data cache, intelligent indexes, and more efficient queries, or by changing the database design.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page reads/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @pageWrites) / @seconds, '', RTRIM(instance_name), 'Number of physical database page writes issued per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page writes/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @pageSplits) / @seconds, '', RTRIM(instance_name), 'Number of page splits per second that occur as the result of overflowing index pages.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Page Splits/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), cntr_value, '', RTRIM(instance_name), 'Counts the number of users currently connected to SQL Server.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'User Connections'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), cntr_value, '', RTRIM(instance_name), 'The number of currently active transactions of all types.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Transactions' AND counter_name = 'Transactions'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @transactions) / @seconds, '', RTRIM(instance_name), 'Number of transactions started for the database per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Transactions/sec' AND instance_name = @dbName
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @writeTransactions) / @seconds, '', RTRIM(instance_name), 'Number of transactions that wrote to the database and committed, in the last second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Write Transactions/sec' AND instance_name = @dbName
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), cntr_value, '', RTRIM(instance_name), 'Number of active transactions for the database.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Active Transactions' AND instance_name = @dbName
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @batchRequests) / @seconds, '', RTRIM(instance_name), 'Number of Transact-SQL command batches received per second. This statistic is affected by all constraints (such as I/O, number of users, cache size, complexity of requests, and so on). High batch requests mean good throughput.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:SQL Statistics' AND counter_name = 'Batch Requests/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @logins) / @seconds, '', RTRIM(instance_name), 'Total number of logins started per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logins/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @logouts) / @seconds, '', RTRIM(instance_name), 'Total number of logout operations started per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logouts/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @tempTables) / @seconds, '', RTRIM(instance_name), 'Number of temporary tables/table variables created per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Temp Tables Creation Rate'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @indexSearches) / @seconds, '', RTRIM(instance_name), 'Number of index searches per second. These are used to start a range scan, reposition a range scan, revalidate a scan point, fetch a single index record, and search down the index to locate where to insert a new row.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Index Searches/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @fullScans) / @seconds, '', RTRIM(instance_name), 'Number of unrestricted full scans per second. These can be either base-table or full-index scans.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Full Scans/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @probeScans) / @seconds, '', RTRIM(instance_name), 'Number of probe scans per second that are used to find at most one single qualified row in an index or base table directly.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Probe Scans/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @rangeScans) / @seconds, '', RTRIM(instance_name), 'Number of qualified range scans through indexes per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Range Scans/sec'
  ORDER BY 5, 1, 2
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.DuplicateData') IS NOT NULL
  DROP PROCEDURE zdm.DuplicateData
GO
CREATE PROCEDURE zdm.DuplicateData
  @tableName   nvarchar(256),
  @oldKeyID    bigint,
  @newKeyID    bigint = NULL OUTPUT,
  @keyColumn   nvarchar(128) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @columns nvarchar(max) = '', @identityColumn nvarchar(128)

  DECLARE @columnName nvarchar(128), @isIdentity bit

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT name, is_identity FROM sys.columns WHERE [object_id] = OBJECT_ID(@tableName) ORDER BY column_id
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @columnName, @isIdentity
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF @isIdentity = 1
      SET @identityColumn = @columnName
    ELSE
    BEGIN
      IF @keyColumn IS NULL OR @columnName != @keyColumn
      BEGIN
        IF @columns = ''
          SET @columns = @columnName
        ELSE
          SET @columns += ', ' + @columnName
      END
    END

    FETCH NEXT FROM @cursor INTO @columnName, @isIdentity
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  IF @identityColumn IS NULL
  BEGIN
    RAISERROR ('Identity column not found', 16, 1)
    RETURN -1
  END

  DECLARE @stmt nvarchar(max)
  SET @stmt = 'INSERT INTO ' + @tableName + ' ('
  IF @keyColumn IS NOT NULL
    SET @stmt += @keyColumn + ', '
  SET @stmt += @columns + ')' + CHAR(13)
            + '     SELECT '
  IF @keyColumn IS NOT NULL
    SET @stmt += CONVERT(nvarchar, @newKeyID) + ', '
  SET @stmt += @columns + CHAR(13)
            + '       FROM ' + @tableName + CHAR(13)
            + '      WHERE '
  SET @stmt += ISNULL(@keyColumn, @identityColumn)
  SET @stmt += ' = ' + CONVERT(nvarchar, @oldKeyID)
  IF @keyColumn IS NULL
    SET @stmt += ';' + CHAR(13) + 'SET @pNewKeyID = SCOPE_IDENTITY()'
  EXEC sp_executesql @stmt, N'@pNewKeyID int OUTPUT', @newKeyID OUTPUT
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.findusage') IS NOT NULL
  DROP PROCEDURE zdm.findusage
GO
CREATE PROCEDURE zdm.findusage
  @usageText  nvarchar(256),
  @describe   bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @objectID int, @objectName nvarchar(256), @text nvarchar(max), @somethingFound bit = 0

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT O.[object_id], S.name + '.' + O.name
          FROM sys.objects O
            INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
         WHERE O.is_ms_shipped = 0 AND O.type IN ('V', 'P', 'FN', 'IF') -- View, Procedure, Scalar Function, Table Function
         ORDER BY O.type_desc, S.name, O.name
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @objectID, @objectName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @text = OBJECT_DEFINITION(@objectID)
    IF CHARINDEX(@usageText, @text) > 0
    BEGIN
      SET @somethingFound = 1

      IF @describe = 0
        PRINT @objectName
      ELSE
      BEGIN
        EXEC zdm.describe @objectName
        PRINT ''
        PRINT REPLICATE('#', 100)
      END
    END

    FETCH NEXT FROM @cursor INTO @objectID, @objectName
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  IF @somethingFound = 0
    PRINT 'No usage found!'
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF TYPE_ID('zutil.BigintTable') IS NULL
  CREATE TYPE zutil.BigintTable AS TABLE (number bigint NOT NULL)
GO
GRANT EXECUTE ON TYPE::zutil.BigintTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF TYPE_ID('zutil.IntTable') IS NULL
  CREATE TYPE zutil.IntTable AS TABLE (number int NOT NULL)
GO
GRANT EXECUTE ON TYPE::zutil.IntTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER FUNCTION zutil.DateWeek(@dt datetime2(0))
RETURNS date
BEGIN
  -- SQL Server says sunday is the first day of the week but the CCP week starts on monday
  SET @dt = CONVERT(date, @dt)
  DECLARE @weekday int = DATEPART(weekday, @dt)
  IF @weekday = 1
    SET @dt = DATEADD(day, -6, @dt)
  ELSE IF @weekday > 2
    SET @dt = DATEADD(day, -(@weekday - 2), @dt)
  RETURN @dt
END
GO


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.events') AND [name] = 'nestLevel')
  ALTER TABLE zsystem.events ADD nestLevel tinyint NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.events') AND [name] = 'parentID')
  ALTER TABLE zsystem.events ADD parentID int NULL
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.eventsEx') IS NOT NULL
  DROP VIEW zsystem.eventsEx
GO
CREATE VIEW zsystem.eventsEx
AS
  SELECT E.eventID, E.eventDate, E.eventTypeID, ET.eventTypeName, E.taskID, T.taskName, fixedText = X.[text], E.eventText,
         E.duration, E.referenceID, E.parentID, E.nestLevel,
         E.date_1, E.int_1, E.int_2, E.int_3, E.int_4, E.int_5, E.int_6, E.int_7, E.int_8, E.int_9
    FROM zsystem.events E
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = E.eventTypeID
      LEFT JOIN zsystem.tasks T ON T.taskID = E.taskID
      LEFT JOIN zsystem.texts X ON X.textID = E.textID
GO
GRANT SELECT ON zsystem.eventsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Events_Insert
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
  @fixedText    nvarchar(450) = NULL,
  @nestLevel    tinyint = NULL,
  @parentID     int = NULL
AS
  SET NOCOUNT ON

  DECLARE @eventID int

  IF @textID IS NULL AND @fixedText IS NOT NULL
    EXEC @textID = zsystem.Texts_ID @fixedText

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText, referenceID, date_1, taskID, textID, nestLevel, parentID)
       VALUES (@eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @referenceID, @date_1, @taskID, @textID, @nestLevel, @parentID)

  SET @eventID = SCOPE_IDENTITY()

  IF @returnRow = 1
    SELECT eventID = @eventID

  RETURN @eventID
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Events_TaskStarted
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
  @returnRow    bit = 0,
  @parentID     int = NULL
AS
  SET NOCOUNT ON

  IF @taskID IS NULL AND @taskName IS NOT NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  DECLARE @nestLevel int
  SET @nestLevel = @@NESTLEVEL - 1
  IF @nestLevel < 1 SET @nestLevel = NULL
  IF @nestLevel > 255 SET @nestLevel = 255

  DECLARE @eventID int

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, NULL, @date_1, @taskID, NULL, @fixedText, @nestLevel, @parentID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_TaskStarted TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Events_TaskInfo
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

  DECLARE @textID int, @nestLevel tinyint, @parentID int

  IF @eventID IS NOT NULL AND @taskID IS NULL
    SELECT @taskID = taskID, @textID = textID, @nestLevel = nestLevel, @parentID = parentID FROM zsystem.events WHERE eventID = @eventID

  IF @taskID IS NULL AND @taskName IS NOT NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText, @nestLevel, @parentID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_TaskInfo TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Events_TaskError
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
  @eventTypeID  int = 2000001004,
  @returnRow    bit = 0,
  @taskEnded    bit = 1
AS
  SET NOCOUNT ON

  DECLARE @textID int, @nestLevel tinyint, @parentID int

  IF @eventID IS NOT NULL AND @taskID IS NULL AND @duration IS NULL
  BEGIN
    DECLARE @eventDate datetime2(0)
    SELECT @taskID = taskID, @textID = textID, @eventDate = eventDate, @nestLevel = nestLevel, @parentID = parentID FROM zsystem.events WHERE eventID = @eventID
    IF @eventDate IS NOT NULL AND @taskEnded = 1
    BEGIN
      SET @duration = DATEDIFF(second, @eventDate, GETUTCDATE())
      IF @duration < 0 SET @duration = 0
    END
  END

  IF @taskID IS NULL AND @taskName IS NOT NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText, @nestLevel, @parentID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_TaskError TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


GO
ALTER PROCEDURE zsystem.Events_TaskCompleted
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

  DECLARE @textID int, @nestLevel tinyint, @parentID int

  IF @eventID IS NOT NULL AND @taskID IS NULL AND @duration IS NULL
  BEGIN
    DECLARE @eventDate datetime2(0)
    SELECT @taskID = taskID, @textID = textID, @eventDate = eventDate, @nestLevel = nestLevel, @parentID = parentID FROM zsystem.events WHERE eventID = @eventID
    IF @eventDate IS NOT NULL
    BEGIN
      SET @duration = DATEDIFF(second, @eventDate, GETUTCDATE())
      IF @duration < 0 SET @duration = 0
    END
  END

  IF @taskID IS NULL AND @taskName IS NOT NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText, @nestLevel, @parentID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_TaskCompleted TO zzp_server
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
         groupOrder = G.[order], C.[order], C.procedureName, C.procedureOrder, C.parentCounterID, C.createDate, C.modifyDate, C.userName,
         C.baseCounterID, C.hidden, C.published, C.units, C.obsolete
    FROM zmetric.counters C
      LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
      LEFT JOIN zsystem.lookupTables LS ON LS.lookupTableID = C.subjectLookupTableID
      LEFT JOIN zsystem.lookupTables LK ON LK.lookupTableID = C.keyLookupTableID
GO
GRANT SELECT ON zmetric.countersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IpLocations_IpInt') IS NOT NULL
  DROP FUNCTION zutil.IpLocations_IpInt
GO
CREATE FUNCTION zutil.IpLocations_IpInt(@ip varchar(15))
RETURNS bigint
BEGIN
  -- Code based on ip2location.dbo.Dot2LongIP
  DECLARE @ipA bigint, @ipB int, @ipC int, @ipD Int
  SELECT @ipA = LEFT(@ip, PATINDEX('%.%', @ip) - 1)
  SELECT @ip = RIGHT(@ip, LEN(@ip) - LEN(@ipA) - 1)
  SELECT @ipB = LEFT(@ip, PATINDEX('%.%', @ip) - 1)
  SELECT @ip = RIGHT(@ip, LEN(@ip) - LEN(@ipB) - 1)
  SELECT @ipC = LEFT(@ip, PATINDEX('%.%', @ip) - 1)
  SELECT @ip = RIGHT(@ip, LEN(@ip) - LEN(@ipC) - 1)
  SELECT @ipD = @ip
  RETURN (@ipA * 256 * 256 * 256) + (@ipB * 256*256) + (@ipC * 256) + @ipD
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.ipLocations') IS NULL
BEGIN
  CREATE TABLE zutil.ipLocations
  (
    ipFrom        bigint                                      NOT NULL,
    ipTo          bigint                                      NOT NULL,
    countryID     smallint                                    NULL,
    countryCode   char(2)       COLLATE Latin1_General_CI_AI  NULL,
    countryName   varchar(100)  COLLATE Latin1_General_CI_AI  NULL,
    region        varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    city          varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    latitude      real                                        NULL,
    longitude     real                                        NULL,
    zipCode       varchar(50)   COLLATE Latin1_General_CI_AI  NULL,
    timeZone      varchar(50)   COLLATE Latin1_General_CI_AI  NULL,
    ispName       varchar(300)  COLLATE Latin1_General_CI_AI  NULL,
    domainName    varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    --
    CONSTRAINT ipLocations_PK PRIMARY KEY CLUSTERED (ipFrom, ipTo)
  )
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.ipLocations_SWITCH') IS NULL
BEGIN
  CREATE TABLE zutil.ipLocations_SWITCH
  (
    ipFrom        bigint                                      NOT NULL,
    ipTo          bigint                                      NOT NULL,
    countryID     smallint                                    NULL,
    countryCode   char(2)       COLLATE Latin1_General_CI_AI  NULL,
    countryName   varchar(100)  COLLATE Latin1_General_CI_AI  NULL,
    region        varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    city          varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    latitude      real                                        NULL,
    longitude     real                                        NULL,
    zipCode       varchar(50)   COLLATE Latin1_General_CI_AI  NULL,
    timeZone      varchar(50)   COLLATE Latin1_General_CI_AI  NULL,
    ispName       varchar(300)  COLLATE Latin1_General_CI_AI  NULL,
    domainName    varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    --
    CONSTRAINT ipLocations_SWITCH_PK PRIMARY KEY CLUSTERED (ipFrom, ipTo)
  )
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IpLocations_ID') IS NOT NULL
  DROP FUNCTION zutil.IpLocations_ID
GO
CREATE FUNCTION zutil.IpLocations_ID(@ip varchar(15))
RETURNS smallint
BEGIN
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  DECLARE @ipInt bigint = zutil.IpLocations_IpInt(@ip)
  DECLARE @countryID smallint
  SELECT TOP 1 @countryID = countryID FROM zutil.ipLocations WHERE ipFrom <= @ipInt ORDER BY ipFrom DESC
  RETURN @countryID
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IpLocations_Code') IS NOT NULL
  DROP FUNCTION zutil.IpLocations_Code
GO
CREATE FUNCTION zutil.IpLocations_Code(@ip varchar(15))
RETURNS char(2)
BEGIN
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  DECLARE @ipInt bigint = zutil.IpLocations_IpInt(@ip)
  DECLARE @countryCode char(2)
  SELECT TOP 1 @countryCode = countryCode FROM zutil.ipLocations WHERE ipFrom <= @ipInt ORDER BY ipFrom DESC
  RETURN @countryCode
END
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IpLocations_Select') IS NOT NULL
  DROP PROCEDURE zutil.IpLocations_Select
GO
CREATE PROCEDURE zutil.IpLocations_Select
  @ip  varchar(15)
AS
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  SET NOCOUNT ON

  DECLARE @ipInt bigint = zutil.IpLocations_IpInt(@ip)
  SELECT TOP 1 countryID, countryCode, countryName, region, city, latitude, longitude, zipCode, timeZone, ispName, domainName
    FROM zutil.ipLocations
   WHERE ipFrom <= @ipInt
   ORDER BY ipFrom DESC
GO
GRANT EXEC ON zutil.IpLocations_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IpLocations_SelectList') IS NOT NULL
  DROP PROCEDURE zutil.IpLocations_SelectList
GO
CREATE PROCEDURE zutil.IpLocations_SelectList
  @ips  varchar(max)
AS
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  SET NOCOUNT ON

  DECLARE @table TABLE
  (
    ipInt        bigint       PRIMARY KEY,
    ip           varchar(15),
    countryID    smallint,
    countryCode  char(2),
    countryName  varchar(100),
    region       varchar(200),
    city         varchar(200),
    latitude     real,
    longitude    real,
    zipCode      varchar(50),
    timeZone     varchar(50),
    ispName      varchar(300),
    domainName   varchar(200)
  )

  INSERT INTO @table (ipInt, ip)
       SELECT zutil.IpLocations_IpInt(string), string FROM zutil.CharListToTable(@ips)

  DECLARE @ipInt bigint,
          @countryID smallint, @countryCode char(2), @countryName varchar(100), @region varchar(200), @city varchar(200),
          @latitude real, @longitude real, @zipCode varchar(50), @timeZone varchar(50), @ispName varchar(300), @domainName varchar(200)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT ipInt FROM @table
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @ipInt
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SELECT @countryID = NULL, @countryCode = NULL, @countryName = NULL, @region = NULL, @city = NULL,
           @latitude = NULL, @longitude = NULL, @zipCode = NULL, @timeZone = NULL, @ispName = NULL, @domainName = NULL

    SELECT TOP 1 @countryID = countryID, @countryCode = countryCode, @countryName = countryName, @region = region, @city = city,
           @latitude = latitude, @longitude = longitude, @zipCode = zipCode, @timeZone = timeZone, @ispName = ispName, @domainName = domainName
      FROM zutil.ipLocations
     WHERE ipFrom <= @ipInt
     ORDER BY ipFrom DESC

    UPDATE @table
       SET countryID = @countryID, countryCode = @countryCode, countryName = @countryName, region = @region, city = @city,
           latitude = @latitude, longitude = @longitude, zipCode = @zipCode, timeZone = @timeZone, ispName = @ispName, domainName = @domainName
     WHERE ipInt = @ipInt

    FETCH NEXT FROM @cursor INTO @ipInt
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  SELECT ip, countryID, countryCode, countryName, region, city, latitude, longitude, zipCode, timeZone, ispName, domainName
    FROM @table
GO
GRANT EXEC ON zutil.IpLocations_SelectList TO zzp_server
GO


---------------------------------------------------------------------------------------------------------------------------------



EXEC zsystem.Versions_Finish 'CORE.J', 0006, 'jorundur'
GO
