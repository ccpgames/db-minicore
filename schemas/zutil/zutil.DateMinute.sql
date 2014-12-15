
IF OBJECT_ID('zutil.DateMinute') IS NOT NULL
  DROP FUNCTION zutil.DateMinute
GO
CREATE FUNCTION zutil.DateMinute(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  RETURN DATEADD(second, -DATEPART(second, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateMinute TO public
GRANT EXEC ON zutil.DateMinute TO zzp_server
GO
