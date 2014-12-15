
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
