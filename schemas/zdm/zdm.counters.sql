
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
