
IF OBJECT_ID('zutil.DateMinutes') IS NOT NULL
  DROP FUNCTION zutil.DateMinutes
GO
CREATE FUNCTION zutil.DateMinutes(@dt datetime2(0), @minutes tinyint)
RETURNS datetime2(0)
BEGIN
  SET @dt = DATEADD(second, -DATEPART(second, @dt), @dt)
  RETURN DATEADD(minute, -(DATEPART(minute, @dt) % @minutes), @dt)
END
GO
GRANT EXEC ON zutil.DateMinutes TO public
GRANT EXEC ON zutil.DateMinutes TO zzp_server
GO
