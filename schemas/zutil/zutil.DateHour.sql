
IF OBJECT_ID('zutil.DateHour') IS NOT NULL
  DROP FUNCTION zutil.DateHour
GO
CREATE FUNCTION zutil.DateHour(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  SET @dt = DATEADD(second, -DATEPART(second, @dt), @dt)
  RETURN DATEADD(minute, -DATEPART(minute, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateHour TO public
GRANT EXEC ON zutil.DateHour TO zzp_server
GO
