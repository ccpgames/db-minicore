
IF OBJECT_ID('zdm.procstats') IS NOT NULL
  DROP PROCEDURE zdm.procstats
GO
CREATE PROCEDURE zdm.procstats
  @rows  smallint = 5
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @count float, @CPU float, @reads float, @writes float
  SELECT @count = SUM(execution_count), @CPU = SUM(total_worker_time),
         @reads = SUM(total_logical_reads), @writes = SUM(total_logical_writes)
    FROM sys.dm_exec_procedure_stats

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         PERCENT_EXECUTION_COUNT = ROUND((execution_count / @count) * 100, 2),
         percent_worker_time = ROUND((total_worker_time / @CPU) * 100, 2),
         percent_logical_reads = ROUND((total_logical_reads / @reads) * 100, 2),
         percent_logical_writes = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY execution_count DESC

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         percent_execution_count = ROUND((execution_count / @count) * 100, 2),
         PERCENT_WORKER_TIME = ROUND((total_worker_time / @CPU) * 100, 2),
         percent_logical_reads = ROUND((total_logical_reads / @reads) * 100, 2),
         percent_logical_writes = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY total_worker_time DESC

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         percent_execution_count = ROUND((execution_count / @count) * 100, 2),
         percent_worker_time = ROUND((total_worker_time / @CPU) * 100, 2),
         PERCENT_LOGICAL_READS = ROUND((total_logical_reads / @reads) * 100, 2),
         percent_logical_writes = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY total_logical_reads DESC

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         percent_execution_count = ROUND((execution_count / @count) * 100, 2),
         percent_worker_time = ROUND((total_worker_time / @CPU) * 100, 2),
         percent_logical_reads = ROUND((total_logical_reads / @reads) * 100, 2),
         PERCENT_LOGICAL_WRITES = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY total_logical_writes DESC
GO
