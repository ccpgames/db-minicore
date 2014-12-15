
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
