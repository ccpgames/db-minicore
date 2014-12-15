
EXEC zsystem.Versions_Start 'CORE.J', 0002, 'jorundur'
GO



---------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' and [key] = 'Product' AND [value] = '')
  UPDATE zsystem.settings SET [value] = 'CORE' WHERE [group] = 'zsystem' and [key] = 'Product'
GO

IF EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' and [key] = 'Product' AND defaultValue IS NULL)
  UPDATE zsystem.settings
     SET defaultValue = 'CORE', [description] = 'The product being developed (CORE, EVE, WOD, ...)' 
   WHERE [group] = 'zsystem' and [key] = 'Product'
GO


---------------------------------------------------------------------------------------------------


ALTER TABLE zsystem.versions ALTER COLUMN versionDate datetime2(2) NOT NULL
ALTER TABLE zsystem.versions ALTER COLUMN lastDate datetime2(2) NULL
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_Check') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Check
GO
CREATE PROCEDURE zsystem.Versions_Check
  @developer  varchar(20) = 'CORE'
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @firstVersion int
  SELECT @firstVersion = MIN([version]) - 1 FROM zsystem.versions WHERE developer = @developer

  DECLARE @version int;
  WITH CTE (rowID, versionID, [version]) AS
  (
    SELECT ROW_NUMBER() OVER(ORDER BY [version]),
           [version] - @firstVersion, [version]
      FROM zsystem.versions
      WHERE developer = @developer
  )
  SELECT @version = MAX([version]) FROM CTE WHERE rowID = versionID

  SELECT info = CASE WHEN [version] = @version THEN 'LAST CONTINUOUS VERSION' ELSE 'MISSING PRIOR VERSIONS' END,
         [version], versionDate, userName, executionCount, lastDate, coreVersion,
         firstDuration = zutil.TimeString(firstDuration), lastDuration = zutil.TimeString(lastDuration)
    FROM zsystem.versions
   WHERE developer = @developer AND [version] >= @version
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.CatchError') IS NOT NULL
  DROP PROCEDURE zsystem.CatchError
GO
CREATE PROCEDURE zsystem.CatchError
  @objectName  nvarchar(256) = NULL,
  @rollback    bit = 1
AS
  SET NOCOUNT ON

  DECLARE @message nvarchar(4000), @number int, @severity int, @state int, @line int, @procedure nvarchar(200)
  SELECT @number = ERROR_NUMBER(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE(),
         @line = ERROR_LINE(), @procedure = ISNULL(ERROR_PROCEDURE(), '?'), @message = ISNULL(ERROR_MESSAGE(), '?')

  IF @rollback = 1
  BEGIN
    IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION
  END

  IF @procedure = 'CatchError'
    SET @message = ISNULL(@objectName, '?') + ' >> ' + @message
  ELSE
  BEGIN
    IF @number = 50000
      SET @message = ISNULL(@objectName, @procedure) + ' (line ' + ISNULL(CONVERT(nvarchar, @line), '?') + ') >> ' + @message
    ELSE
    BEGIN
      SET @message = ISNULL(@objectName, @procedure) + ' (line ' + ISNULL(CONVERT(nvarchar, @line), '?')
                   + ', error ' + ISNULL(CONVERT(nvarchar, @number), '?') + ') >> ' + @message
    END
  END

  RAISERROR (@message, @severity, @state)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.PrintNow') IS NOT NULL
  DROP PROCEDURE zsystem.PrintNow
GO
CREATE PROCEDURE zsystem.PrintNow
  @str        nvarchar(4000),
  @printTime  bit = 0
AS
  SET NOCOUNT ON

  IF @printTime = 1
    SET @str = CONVERT(nvarchar, GETUTCDATE(), 120) + ' : ' + @str

  RAISERROR (@str, 0, 1) WITH NOWAIT;
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zdm' AND [key] = 'LongRunning-IgnoreSQL')
begin
  declare @value nvarchar(max), @list nvarchar(max) = ''
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL1')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL2')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL3')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL4')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL5')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL6')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL7')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL8')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL9')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL10')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL11')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL12')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL13')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL14')
  if @value != '' set @list = @list + ',' + @value
  set @value = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL15')
  if @value != '' set @list = @list + ',' + @value
  if @list = ''
  begin
    INSERT INTO zsystem.settings ([group], [key], [value], [description])
         VALUES ('zdm', 'LongRunning-IgnoreSQL', '%--DBA%', 'Ignore SQL in long running SQL notifications.  Comma delimited list things to use in NOT LIKE.')
  end
  else
  begin
    INSERT INTO zsystem.settings ([group], [key], [value], [description])
         VALUES ('zdm', 'LongRunning-IgnoreSQL', substring(@list, 2, 4000), 'Ignore SQL in long running SQL notifications.  Comma delimited list things to use in NOT LIKE.')
  end

  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL1'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL2'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL3'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL4'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL5'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL6'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL7'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL8'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL9'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL10'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL11'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL12'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL13'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL14'
  delete from zsystem.settings where [group] = 'zdm' and  [key] = 'LongRunning-IgnoreSQL15'
end
go


---------------------------------------------------------------------------------------------------


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
    SELECT @stmt = @stmt + ' AND S.[text] NOT LIKE ''' + string + '''' FROM zutil.StringListToTable(@ignoreSQL, 0)
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


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.RebuildDependencies') IS NOT NULL
  DROP PROCEDURE zdm.RebuildDependencies
GO
CREATE PROCEDURE zdm.RebuildDependencies
  @listAllObjects  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @objectName nvarchar(500), @typeName nvarchar(60)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT QUOTENAME(S.name) + '.' + QUOTENAME(O.name), O.type_desc
          FROM sys.objects O
            INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
         WHERE O.is_ms_shipped = 0 AND O.[type] IN ('FN', 'IF', 'P', 'V')
         ORDER BY O.[type], S.name, O.name
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @objectName, @typeName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF @listAllObjects = 1
      PRINT @typeName + ' : ' + @objectName

    BEGIN TRY
      EXEC sp_refreshsqlmodule @objectName
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION
      IF @listAllObjects = 0
        PRINT @typeName + ' : ' + @objectName
      PRINT '  ' + ERROR_MESSAGE()
    END CATCH

    FETCH NEXT FROM @cursor INTO @objectName, @typeName
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  SET NOCOUNT OFF 
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.counters') IS NOT NULL
  DROP PROCEDURE zdm.counters
GO
CREATE PROCEDURE zdm.counters
  @time_to_execute  char(8)= '00:00:03'
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

  WAITFOR DELAY @time_to_execute

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


---------------------------------------------------------------------------------------------------


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
      PRINT @text
    END
    ELSE IF @type = 'C' -- Check Constraint
    BEGIN
      PRINT ''
      SELECT @text = [definition], @parentID = parent_object_id
        FROM sys.check_constraints
       WHERE [object_id] = @objectID
      PRINT @text
    END
    ELSE IF @type = 'D' -- Default Constraint
    BEGIN
      PRINT ''
      SELECT @text = C.name + ' = ' + DC.[definition], @parentID = DC.parent_object_id
        FROM sys.default_constraints DC
          INNER JOIN sys.columns C ON C.[object_id] = DC.parent_object_id AND C.column_id = DC.parent_column_id
       WHERE DC.[object_id] = @objectID
      PRINT @text
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

      SELECT index_id, index_name = name, [type], type_desc, is_unique, is_primary_key, is_unique_constraint, fill_factor
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
       ORDER BY O.[type], LOWER(S.name), LOWER(O.name)
    END
    ELSE
    BEGIN
      SELECT [object_id], [object_name] = @schemaName + '.' + name, [type], type_desc, parent_object_id,
             create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [schema_id] = @schemaID AND LOWER(name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY [type], LOWER(name)
    END
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.findusage') IS NOT NULL
  DROP PROCEDURE zdm.findusage
GO
CREATE PROCEDURE zdm.findusage
  @usageText  nvarchar(256),
  @describe   bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @objectID int, @objectName nvarchar(256), @text nvarchar(max)

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
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.processinfo') IS NOT NULL
  DROP PROCEDURE zdm.processinfo
GO
CREATE PROCEDURE zdm.processinfo
  @hostName     nvarchar(100) = '',
  @programName  nvarchar(100) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [db_name] = DB_NAME(P.[dbid]), S.[program_name], S.[host_name], S.host_process_id, S.login_name, session_count = COUNT(*)
    FROM sys.dm_exec_sessions S
      LEFT JOIN sys.sysprocesses P ON P.spid = S.session_id
   WHERE P.[dbid] != 0 AND S.[host_name] LIKE @hostName + '%' AND S.[program_name] LIKE @programName + '%'
   GROUP BY DB_NAME(P.[dbid]), S.[program_name], S.[host_name], S.host_process_id, S.login_name
   ORDER BY [db_name], S.[program_name], S.login_name, COUNT(*) DESC, S.[host_name]
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.sessioninfo') IS NOT NULL
  DROP PROCEDURE zdm.sessioninfo
GO
CREATE PROCEDURE zdm.sessioninfo
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [db_name] = DB_NAME(P.[dbid]), S.[program_name], S.login_name,
         host_count = COUNT(DISTINCT S.[host_name]),
         process_count = COUNT(DISTINCT S.[host_name] + CONVERT(nvarchar, S.host_process_id)),
         session_count = COUNT(*)
    FROM sys.dm_exec_sessions S
      LEFT JOIN sys.sysprocesses P ON P.spid = S.session_id
   WHERE P.[dbid] != 0
   GROUP BY DB_NAME(P.[dbid]), S.[program_name], S.login_name
   ORDER BY COUNT(*) DESC
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.stats') IS NOT NULL
  DROP PROCEDURE zdm.stats
GO
CREATE PROCEDURE zdm.stats
  @objectName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF OBJECT_ID(@objectName) IS NULL
  BEGIN
    PRINT 'Object not found!'
    RETURN
  END

  EXEC sp_autostats @objectName

  DECLARE @stmt nvarchar(4000)
  DECLARE @indexName nvarchar(128)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT name FROM sys.indexes WHERE [object_id] = OBJECT_ID(@objectName) ORDER BY index_id
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @indexName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @stmt = 'DBCC SHOW_STATISTICS (''' + @objectName + ''', ''' + @indexName + ''')'
    EXEC sp_executesql @stmt

    FETCH NEXT FROM @cursor INTO @indexName
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.topsql') IS NOT NULL
  DROP PROCEDURE zdm.topsql
GO
CREATE PROCEDURE zdm.topsql
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0) = GETDATE()

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
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.topsqlp') IS NOT NULL
  DROP PROCEDURE zdm.topsqlp
GO
CREATE PROCEDURE zdm.topsqlp
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime2(0) = GETDATE()

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
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.Age') IS NOT NULL
  DROP FUNCTION zutil.Age
GO
CREATE FUNCTION zutil.Age(@dob datetime2(0), @today datetime2(0))
RETURNS int
BEGIN
  DECLARE @age int
  SET @age = YEAR(@today) - YEAR(@dob)
  IF MONTH(@today) < MONTH(@dob) SET @age = @age -1
  IF MONTH(@today) = MONTH(@dob) AND DAY(@today) < DAY(@dob) SET @age = @age - 1
  RETURN @age
END
GO
GRANT EXEC ON zutil.Age TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateDay') IS NOT NULL
  DROP FUNCTION zutil.DateDay
GO
CREATE FUNCTION zutil.DateDay(@dt datetime2(0))
RETURNS date
BEGIN
  RETURN CONVERT(date, @dt)
END
GO
GRANT EXEC ON zutil.DateDay TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateDiffString') IS NOT NULL
  DROP FUNCTION zutil.DateDiffString
GO
CREATE FUNCTION zutil.DateDiffString(@dt1 datetime2(0), @dt2 datetime2(0))
RETURNS varchar(20)
BEGIN
  DECLARE @s varchar(20)

  DECLARE @seconds int, @x int
  SET @seconds = ABS(DATEDIFF(second, @dt1, @dt2))

  -- Seconds
  SET @x = @seconds % 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2)
  SET @seconds = @seconds - @x

  -- Minutes
  SET @x = (@seconds % (60 * 60)) / 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2) + ':' + @s
  SET @seconds = @seconds - (@x * 60)

  -- Hours
  SET @x = @seconds / (60 * 60)
  SET @s = CONVERT(varchar, @x) + ':' + @s
  IF LEN(@s) < 8 SET @s = '0' + @s

  RETURN @s
END
GO
GRANT EXEC ON zutil.DateDiffString TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateHour') IS NOT NULL
  DROP FUNCTION zutil.DateHour
GO
CREATE FUNCTION zutil.DateHour(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  SET @dt = DATEADD(second, -DATEPART(second, @dt), @dt)
  RETURN DATEADD(minute, -DATEPART(minute, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateHour TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateLocal') IS NOT NULL
  DROP FUNCTION zutil.DateLocal
GO
CREATE FUNCTION zutil.DateLocal(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  RETURN DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()), @dt)
END
GO
GRANT EXEC ON zutil.DateLocal TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateMinute') IS NOT NULL
  DROP FUNCTION zutil.DateMinute
GO
CREATE FUNCTION zutil.DateMinute(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  RETURN DATEADD(second, -DATEPART(second, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateMinute TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateMonth') IS NOT NULL
  DROP FUNCTION zutil.DateMonth
GO
CREATE FUNCTION zutil.DateMonth(@dt datetime2(0))
RETURNS date
BEGIN
  SET @dt = CONVERT(date, @dt)
  RETURN DATEADD(day, 1 - DATEPART(day, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateMonth TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateTimeDay') IS NOT NULL
  DROP FUNCTION zutil.DateTimeDay
GO
CREATE FUNCTION zutil.DateTimeDay(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  RETURN CONVERT(date, @dt)
END
GO
GRANT EXEC ON zutil.DateTimeDay TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateWeek') IS NOT NULL
  DROP FUNCTION zutil.DateWeek
GO
CREATE FUNCTION zutil.DateWeek(@dt datetime2(0))
RETURNS date
BEGIN
  SET @dt = CONVERT(date, @dt)
  RETURN DATEADD(day, 1 - DATEPART(weekday, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateWeek TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateXMinutes') IS NOT NULL
  DROP FUNCTION zutil.DateXMinutes
GO
CREATE FUNCTION zutil.DateXMinutes(@dt datetime2(0), @minutes tinyint)
RETURNS datetime2(0)
BEGIN
  SET @dt = DATEADD(second, -DATEPART(second, @dt), @dt)
  RETURN DATEADD(minute, -(DATEPART(minute, @dt) % @minutes), @dt)
END
GO
GRANT EXEC ON zutil.DateXMinutes TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateYear') IS NOT NULL
  DROP FUNCTION zutil.DateYear
GO
CREATE FUNCTION zutil.DateYear(@dt datetime2(0))
RETURNS date
BEGIN
  SET @dt = CONVERT(date, @dt)
  RETURN DATEADD(day, 1 - DATEPART(dayofyear, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateYear TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.InitCap') IS NOT NULL
  DROP FUNCTION zutil.InitCap
GO
CREATE FUNCTION zutil.InitCap(@s nvarchar(4000)) 
RETURNS nvarchar(4000)
AS
BEGIN
  DECLARE @i int, @char nchar(1), @prevChar nchar(1), @output nvarchar(4000)

  SELECT @output = LOWER(@s), @i = 1

  WHILE @i <= LEN(@s)
  BEGIN
    SELECT @char = SUBSTRING(@s, @i, 1),
           @prevChar = CASE WHEN @i = 1 THEN ' ' ELSE SUBSTRING(@s, @i - 1, 1) END

    IF @prevChar IN (' ', ';', ':', '!', '?', ',', '.', '_', '-', '/', '&', '''', '(')
    BEGIN
      IF @prevChar != '''' OR UPPER(@char) != 'S'
        SET @output = STUFF(@output, @i, 1, UPPER(@char))
    END

    SET @i = @i + 1
  END

  RETURN @output
END
GO
GRANT EXEC ON zutil.InitCap TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.WordCount') IS NOT NULL
  DROP FUNCTION zutil.WordCount
GO
CREATE FUNCTION zutil.WordCount(@s nvarchar(max))
RETURNS int
BEGIN
  -- Returns the word count of a string
  -- Note that the function does not return 100% correct value if the string has over 10 whitespaces in a row
  SET @s = REPLACE(@s, CHAR(10), ' ')
  SET @s = REPLACE(@s, CHAR(13), ' ')
  SET @s = REPLACE(@s, CHAR(9), ' ')
  SET @s = REPLACE(@s, '    ', ' ')
  SET @s = REPLACE(@s, '   ', ' ')
  SET @s = REPLACE(@s, '  ', ' ')
  SET @s = LTRIM(@s)
  IF @s = ''
    RETURN 0
  RETURN LEN(@s) - LEN(REPLACE(@s, ' ', '')) + 1
END
GO
GRANT EXEC ON zutil.WordCount TO zzp_server
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


GRANT EXEC ON zsystem.Versions_Check TO zzp_server
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000001 AND eventTypeName = 'Execute procedure')
BEGIN
  UPDATE zsystem.events SET eventTypeID = 2000000003 WHERE eventTypeID = 2000000001
  UPDATE zsystem.eventTypes SET eventTypeName = 'Procedure started' WHERE eventTypeID = 2000000001
END
GO


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000002)
  INSERT INTO  zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000002, 'Procedure info', '')
GO
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000003)
  INSERT INTO  zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000003, 'Procedure completed', '')
GO
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000004)
  INSERT INTO  zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000004, 'Procedure ERROR', '')
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.eventsEx') IS NOT NULL
  DROP VIEW zsystem.eventsEx
GO
CREATE VIEW zsystem.eventsEx
AS
  SELECT E.eventID, E.eventDate, E.eventTypeID, ET.eventTypeName, E.duration,
         E.int_1, E.int_2, E.int_3, E.int_4, E.int_5, E.int_6, E.int_7, E.int_8, E.int_9, E.eventText,
         procedureName = CASE WHEN E.eventTypeID IN (2000000001, 2000000002, 2000000003, 2000000004) THEN S.schemaName + '.' + P.procedureName ELSE NULL END,
         jobName = CASE WHEN E.eventTypeID IN (2000000021, 2000000022, 2000000023, 2000000024) THEN J.jobName ELSE NULL END
    FROM zsystem.events E
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = E.eventTypeID
      LEFT JOIN zsystem.procedures P ON P.procedureID = E.int_1
        LEFT JOIN zsystem.schemas S ON S.schemaID = P.schemaID
      LEFT JOIN zsystem.jobs J ON J.jobID = E.int_1
GO
GRANT SELECT ON zsystem.eventsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


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
  @eventText    nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText)
       VALUES (@eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText)
GO
GRANT EXEC ON zsystem.Events_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------


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
  @eventText      nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  DECLARE @schemaID int, @procedureID int

  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  SELECT @procedureID = procedureID FROM zsystem.procedures WHERE schemaID = @schemaID AND procedureName = @procedureName
  IF @procedureID IS NULL
  BEGIN
    RAISERROR ('Procedure not found', 16, 1)
    RETURN -1
  END

  EXEC zsystem.Events_Insert 2000000003, @duration, @procedureID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText
GO


---------------------------------------------------------------------------------------------------


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
  @eventText      nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  DECLARE @schemaID int, @procedureID int

  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  SELECT @procedureID = procedureID FROM zsystem.procedures WHERE schemaID = @schemaID AND procedureName = @procedureName
  IF @procedureID IS NULL
  BEGIN
    RAISERROR ('Procedure not found', 16, 1)
    RETURN -1
  END

  EXEC zsystem.Events_Insert 2000000004, NULL, @procedureID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText
GO


---------------------------------------------------------------------------------------------------


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
  @eventText      nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  DECLARE @schemaID int, @procedureID int

  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  SELECT @procedureID = procedureID FROM zsystem.procedures WHERE schemaID = @schemaID AND procedureName = @procedureName
  IF @procedureID IS NULL
  BEGIN
    RAISERROR ('Procedure not found', 16, 1)
    RETURN -1
  END

  EXEC zsystem.Events_Insert 2000000002, NULL, @procedureID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText
GO


---------------------------------------------------------------------------------------------------


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
  @eventText      nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  DECLARE @schemaID int, @procedureID int

  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  SELECT @procedureID = procedureID FROM zsystem.procedures WHERE schemaID = @schemaID AND procedureName = @procedureName
  IF @procedureID IS NULL
  BEGIN
    RAISERROR ('Procedure not found', 16, 1)
    RETURN -1
  END

  EXEC zsystem.Events_Insert 2000000001, NULL, @procedureID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText
GO


---------------------------------------------------------------------------------------------------


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
    FOR SELECT T.tableID, '[' + S.schemaName + '].[' + T.tableName + ']', T.keyID, T.keyDate, T.logIdentity
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
        IF @keyDate IS NOT NULL
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
        IF @keyDate IS NOT NULL
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


---------------------------------------------------------------------------------------------------


EXEC zdm.DropDefaultConstraint 'zsystem.jobs', 'disabled'
UPDATE zsystem.jobs SET [disabled] = 0 WHERE [disabled] IS NULL
ALTER TABLE zsystem.jobs ADD DEFAULT 0 FOR [disabled]
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.tables') AND [name] = 'revisionOrder')
  ALTER TABLE zsystem.tables ADD revisionOrder int NOT NULL DEFAULT 0
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('zsystem.tables') AND [name] = 'denormalized')
  ALTER TABLE zsystem.tables ADD denormalized bit NOT NULL DEFAULT 0
GO


---------------------------------------------------------------------------------------------------


EXEC zdm.DropDefaultConstraint 'zsystem.tables', 'disableEdit'
UPDATE zsystem.tables SET disableEdit = 0 WHERE disableEdit IS NULL
ALTER TABLE zsystem.tables ADD DEFAULT 0 FOR disableEdit
GO

EXEC zdm.DropDefaultConstraint 'zsystem.tables', 'disableDelete'
UPDATE zsystem.tables SET disableDelete = 0 WHERE disableDelete IS NULL
ALTER TABLE zsystem.tables ADD DEFAULT 0 FOR disableDelete
GO

EXEC zdm.DropDefaultConstraint 'zsystem.tables', 'obsolete'
UPDATE zsystem.tables SET obsolete = 0 WHERE obsolete IS NULL
ALTER TABLE zsystem.tables ADD DEFAULT 0 FOR obsolete
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


UPDATE zsystem.tables SET [description] = 'Core - System - Shared settings stored in DB' WHERE tableID = 2000100001
GO
UPDATE zsystem.tables SET [description] = 'Core - System - List of DB updates (versions) applied on the DB' WHERE tableID = 2000100002
GO
UPDATE zsystem.tables SET [description] = 'Core - System - List of database schemas' WHERE tableID = 2000100003
GO
UPDATE zsystem.tables SET [description] = 'Core - System - List of database tables' WHERE tableID = 2000100004
GO
UPDATE zsystem.tables SET [description] = 'Core - System - List of database columns that need special handling' WHERE tableID = 2000100005
GO
UPDATE zsystem.tables SET [description] = 'Core - System - List of database procedures that need special handling' WHERE tableID = 2000100006
GO
UPDATE zsystem.tables SET [description] = 'Core - System - Identity statistics (used to support searching without the need for datetime indexes)' WHERE tableID = 2000100011
GO
UPDATE zsystem.tables SET [description] = 'Core - System - Column events' WHERE tableID = 2000100012
GO
UPDATE zsystem.tables SET [description] = 'Core - System - Events types' WHERE tableID = 2000100013
GO


---------------------------------------------------------------------------------------------------


update zsystem.tables set copyStatic = null where tableID = 2000100003 and tableName = 'schemas' and copyStatic is not null
update zsystem.tables set copyStatic = null where tableID = 2000100004 and tableName = 'tables' and copyStatic is not null
update zsystem.tables set copyStatic = null where tableID = 2000100005 and tableName = 'columns' and copyStatic is not null
go


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.columns') AND [name] = 'localizationGroupID')
  ALTER TABLE zsystem.columns ADD localizationGroupID int NULL
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.columns') AND [name] = 'obsolete')
  ALTER TABLE zsystem.columns ADD obsolete int NULL
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.columnsEx') IS NOT NULL
  DROP VIEW zsystem.columnsEx
GO
CREATE VIEW zsystem.columnsEx
AS
  SELECT T.schemaID, S.schemaName, C.tableID, T.tableName,
         C.columnName, C.[readonly], C.lookupTable, C.lookupID, C.lookupName,
         C.lookupWhere, C.html, C.localizationGroupID, C.obsolete
    FROM zsystem.columns C
      LEFT JOIN zsystem.tables T ON T.tableID = C.tableID
        LEFT JOIN zsystem.schemas S ON S.schemaID = T.schemaID
GO
GRANT SELECT ON zsystem.columnsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


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

  SELECT columnName = c.[name], c.system_type_id, c.max_length, c.is_nullable,
         c2.[readonly], c2.lookupTable, c2.lookupID, c2.lookupName, c2.lookupWhere, c2.html, c2.localizationGroupID
    FROM sys.columns c
      LEFT JOIN zsystem.columns c2 ON c2.tableID = @tableID AND c2.columnName = c.[name]
   WHERE c.[object_id] = OBJECT_ID(@schemaName + '.' + @tableName) AND ISNULL(c2.obsolete, 0) = 0
   ORDER BY c.column_id
GO
GRANT EXEC ON zsystem.Columns_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM sys.indexes WHERE [object_id] = OBJECT_ID('zsystem.tables') AND [name] = 'tables_IX_Schema')
  DROP INDEX tables_IX_Schema ON zsystem.tables
GO


---------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM sys.indexes WHERE [object_id] = OBJECT_ID('zsystem.procedures') AND [name] = 'procedures_IX_Schema')
  DROP INDEX procedures_IX_Schema ON zsystem.procedures
GO


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'source')
  ALTER TABLE zsystem.lookupTables ADD [source] nvarchar(200) NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'lookupID')
  ALTER TABLE zsystem.lookupTables ADD lookupID nvarchar(200) NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'parentID')
  ALTER TABLE zsystem.lookupTables ADD parentID nvarchar(200) NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupTables') AND [name] = 'parentLookupTableID')
  ALTER TABLE zsystem.lookupTables ADD parentLookupTableID int NULL
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupTablesEx') IS NOT NULL
  DROP VIEW zsystem.lookupTablesEx
GO
CREATE VIEW zsystem.lookupTablesEx
AS
  SELECT L.lookupTableID, L.lookupTableName, L.[description], L.schemaID, S.schemaName, L.tableID, T.tableName,
         L.[source], L.lookupID, L.parentID, L.parentLookupTableID, parentLookupTableName = L2.lookupTableName
    FROM zsystem.lookupTables L
      LEFT JOIN zsystem.schemas S ON S.schemaID = L.schemaID
      LEFT JOIN zsystem.tables T ON T.tableID = L.tableID
      LEFT JOIN zsystem.lookupTables L2 ON L2.lookupTableID = L.parentLookupTableID
GO
GRANT SELECT ON zsystem.lookupTablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupValues') AND [name] = 'lookupID' AND TYPE_NAME(system_type_id) = 'tinyint')
BEGIN
  ALTER TABLE zsystem.lookupValues DROP CONSTRAINT lookupValues_PK
  ALTER TABLE zsystem.lookupValues ALTER COLUMN lookupID int NOT NULL
  ALTER TABLE zsystem.lookupValues ADD CONSTRAINT lookupValues_PK PRIMARY KEY CLUSTERED (lookupTableID, lookupID)
END
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupValues') AND [name] = 'parentID')
  ALTER TABLE zsystem.lookupValues ADD parentID int NULL
GO
ALTER TABLE zsystem.lookupValues ALTER COLUMN lookupText nvarchar(1000) NOT NULL
GO
IF NOT EXISTS(SELECT * FROM sys.columns WHERE [object_id] = OBJECT_ID('zsystem.lookupValues') AND [name] = 'fullText')
  ALTER TABLE zsystem.lookupValues ADD [fullText] nvarchar(1000) NULL
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.LookupValues_SelectTable') IS NOT NULL
  DROP PROCEDURE zsystem.LookupValues_SelectTable
GO
CREATE PROCEDURE zsystem.LookupValues_SelectTable
  @lookupTableID  int
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT lookupID, lookupText, parentID
    FROM zsystem.lookupValues
   WHERE lookupTableID = @lookupTableID
   ORDER BY lookupID
GO
GRANT EXEC ON zsystem.LookupValues_SelectTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF SCHEMA_ID('zevent') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zevent'
GO


IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000015)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000015, 'zevent', 'CORE - General event system objects.', 'http://core/wiki/DB_zevent')
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.counters') IS NULL
BEGIN
  CREATE TABLE zevent.counters
  (
    counterID             smallint       NOT NULL,
    counterName           nvarchar(200)  NOT NULL,
    [description]         nvarchar(max)  NULL,
    --
    subjectLookupTableID  int            NULL,     -- Lookup table for subjectID, pointing to zsystem.lookupTables/Values
    keyLookupTableID      int            NULL,     -- Lookup table for keyID, pointing to zsystem.lookupTables/Values
    [source]              nvarchar(200)  NULL,     -- Description of data source, f.e. table name
    subjectID             nvarchar(200)  NULL,     -- Description of subjectID column
    keyID                 nvarchar(200)  NULL,     -- Description of keyID column
    --
    CONSTRAINT counters_PK PRIMARY KEY CLUSTERED (counterID)
  )
END
GRANT SELECT ON zevent.counters TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.counterColumns') IS NULL
BEGIN
  CREATE TABLE zevent.counterColumns
  (
    counterID      smallint       NOT NULL,
    subjectID      int            NOT NULL,
    columnName     nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NULL,
    --
    CONSTRAINT counterColumns_PK PRIMARY KEY CLUSTERED (counterID, subjectID)
  )
END
GRANT SELECT ON zevent.counterColumns TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.dateCounters') IS NULL
BEGIN
  CREATE TABLE zevent.dateCounters
  (
    counterID    smallint  NOT NULL,  -- The counter, poining to zevent.counters
    counterDate  date      NOT NULL,  -- The date
    subjectID    int       NOT NULL,  -- Subject if used, f.e. if counting for user or character, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting kills for character per solar system, 0 if not used
    [value]      bigint    NOT NULL,  -- The value of the counter
    --
    CONSTRAINT dateCounters_PK PRIMARY KEY CLUSTERED (counterID, subjectID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX dateCounters_IX_CounterDate ON zevent.dateCounters (counterID, counterDate)
END
GRANT SELECT ON zevent.dateCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.countersEx') IS NOT NULL
  DROP VIEW zevent.countersEx
GO
CREATE VIEW zevent.countersEx
AS
  SELECT C.counterID, C.counterName, C.[description],
         C.subjectLookupTableID, subjectLookupTableName = LS.lookupTableName,
         C.keyLookupTableID, keyLookupTableName = LK.lookupTableName,
         C.[source], C.subjectID, C.keyID
    FROM zevent.counters C
      LEFT JOIN zsystem.lookupTables LS ON LS.lookupTableID = C.subjectLookupTableID
      LEFT JOIN zsystem.lookupTables LK ON LK.lookupTableID = C.keyLookupTableID
GO
GRANT SELECT ON zevent.countersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.counterColumnsEx') IS NOT NULL
  DROP VIEW zevent.counterColumnsEx
GO
CREATE VIEW zevent.counterColumnsEx
AS
  SELECT CC.counterID, C.counterName, CC.subjectID, CC.columnName, CC.[description]
    FROM zevent.counterColumns CC
      LEFT JOIN zevent.counters C ON C.counterID = CC.counterID
GO
GRANT SELECT ON zevent.counterColumnsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------



IF OBJECT_ID('zevent.dateCountersEx') IS NOT NULL
  DROP VIEW zevent.dateCountersEx
GO
CREATE VIEW zevent.dateCountersEx
AS
  SELECT DC.counterID, C.counterName, DC.counterDate,
         DC.subjectID, subjectText = ISNULL(LS.[fullText], LS.lookupText),
         DC.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), DC.[value]
    FROM zevent.dateCounters DC
      LEFT JOIN zevent.counters C ON C.counterID = DC.counterID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = DC.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = DC.keyID
GO
GRANT SELECT ON zevent.dateCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zevent.DateCounters_Update') IS NOT NULL
  DROP PROCEDURE zevent.DateCounters_Update
GO
CREATE PROCEDURE zevent.DateCounters_Update
  @counterID    smallint,
  @subjectID    int = 0,
  @keyID        int = 0,
  @value        bigint,
  @interval     char = 'D', -- D:Day, W:Week, M:Month, Y:Year
  @counterDate  date = NULL,
  @onlyInsert   bit = 0
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL
  BEGIN
    IF @interval = 'D' SET @counterDate = GETUTCDATE()
    ELSE IF @interval = 'W' SET @counterDate = zutil.DateWeek(GETUTCDATE())
    ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(GETUTCDATE())
    ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(GETUTCDATE())
    ELSE SET @counterDate = GETUTCDATE()
  END
  ELSE
  BEGIN
    IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
    ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
    ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)
  END

  IF @onlyInsert = 0
  BEGIN
    UPDATE zevent.dateCounters
       SET [value] = [value] + @value
     WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
    IF @@ROWCOUNT = 0
    BEGIN
      INSERT INTO zevent.dateCounters (counterID, counterDate, subjectID, keyID, [value])
           VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
    END
  END
  ELSE
  BEGIN
    INSERT INTO zevent.dateCounters (counterID, counterDate, subjectID, keyID, [value])
         VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
  END
GO
GRANT EXEC ON zevent.DateCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.IndexStats_Insert') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Insert
GO
CREATE PROCEDURE zsys.IndexStats_Insert
AS
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @statsDate date
  SET @statsDate = GETDATE()

  IF NOT EXISTS(SELECT * FROM zsys.indexStats WHERE [stats_date] = @statsDate)
  BEGIN
    INSERT INTO zsys.indexStats
                ([object_id], index_id, [stats_date], [rows], total_pages, used_pages, data_pages,
                 user_seeks, user_scans, user_lookups, user_updates)
         SELECT T.[object_id], I.index_id, @statsDate,
                SUM(CASE WHEN A.[type] = 1 THEN P.[rows] ELSE 0 END),  -- IN_ROW_DATA 
                SUM(A.total_pages), SUM(A.used_pages), SUM(A.data_pages),
                MAX(S.user_seeks), MAX(S.user_scans), MAX(S.user_lookups), MAX(S.user_updates)
           FROM sys.tables T
             INNER JOIN sys.indexes I ON I.[object_id] = T.[object_id]
               INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
                 INNER JOIN sys.allocation_units A ON A.container_id = P.partition_id
               LEFT JOIN sys.dm_db_index_usage_stats S ON S.database_id = DB_ID() AND S.[object_id] = I.[object_id] AND S.index_id = I.index_id
          WHERE T.is_ms_shipped != 1
          GROUP BY T.[object_id], I.index_id
          ORDER BY T.[object_id], I.index_id

    EXEC zevent.DateCounters_Update 30002, 0, 0, 0, 'D', NULL, 1
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.ProcedureStats_DeleteDate') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_DeleteDate
GO
CREATE PROCEDURE zsys.ProcedureStats_DeleteDate
AS
  SET NOCOUNT ON

  DECLARE @stats_date date
  SET @stats_date = GETDATE()

  DELETE FROM zsys.procedureStats WHERE [stats_date] = @stats_date
  DELETE FROM zevent.dateCounters WHERE counterID = 30001 AND subjectID = 0 AND keyID = 0 AND counterDate = @stats_date
GO
GRANT EXEC ON zsys.ProcedureStats_DeleteDate TO zzp_server
GO


---------------------------------------------------------------------------------------------------
-- DROPPING OBSOLETE OBJECTS!


-- 2011.01.08
IF OBJECT_ID('zsystem.Events_ExecProc') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ExecProc
GO
-- 2011.04.02
IF OBJECT_ID('zsystem.DateCounters_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.DateCounters_Insert
GO
-- 2012.01.04 *** DROPPED SOONER IN MINI-CORE ***
IF OBJECT_ID('zsystem.DateCounters_Update') IS NOT NULL
  DROP PROCEDURE zsystem.DateCounters_Update
GO
IF OBJECT_ID('zsystem.dateCountersEx') IS NOT NULL
  DROP VIEW zsystem.dateCountersEx
GO
IF OBJECT_ID('zsystem.dateCounters') IS NOT NULL
BEGIN
  IF EXISTS(SELECT * FROM zsystem.dateCounters)
  BEGIN
    -- if table has been used, save the data on the side
    -- note that if the table zsystem.dateCounters_OBSOLETE_UPDATE_1, it will not be dropped again in a mini-core update
    SELECT *
      INTO zsystem.dateCounters_OBSOLETE_UPDATE_1
      FROM zsystem.dateCounters
  END

  DROP TABLE zsystem.dateCounters
END
GO


---------------------------------------------------------------------------------------------------



EXEC zsystem.Versions_Finish 'CORE.J', 0002, 'jorundur'
GO
