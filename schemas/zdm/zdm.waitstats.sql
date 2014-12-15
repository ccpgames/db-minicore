
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
