
IF OBJECT_ID('zmetric.SimpleCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.SimpleCounters_Insert
GO
CREATE PROCEDURE zmetric.SimpleCounters_Insert
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

  INSERT INTO zmetric.simpleCounters (counterID, counterDate, value) VALUES (@counterID, @counterDate, @value)
GO
GRANT EXEC ON zmetric.SimpleCounters_Insert TO zzp_server
GO
