
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
