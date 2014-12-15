
IF OBJECT_ID('zutil.DateWeek') IS NOT NULL
  DROP FUNCTION zutil.DateWeek
GO
CREATE FUNCTION zutil.DateWeek(@dt datetime2(0))
RETURNS date
BEGIN
  -- SQL Server says sunday is the first day of the week but the CCP week starts on monday
  SET @dt = CONVERT(date, @dt)
  DECLARE @weekday int = DATEPART(weekday, @dt)
  IF @weekday = 1
    SET @dt = DATEADD(day, -6, @dt)
  ELSE IF @weekday > 2
    SET @dt = DATEADD(day, -(@weekday - 2), @dt)
  RETURN @dt
END
GO
GRANT EXEC ON zutil.DateWeek TO public
GRANT EXEC ON zutil.DateWeek TO zzp_server
GO
