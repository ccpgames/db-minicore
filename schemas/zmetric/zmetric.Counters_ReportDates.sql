
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
