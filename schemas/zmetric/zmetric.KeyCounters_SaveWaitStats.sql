
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
