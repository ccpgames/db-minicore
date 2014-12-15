
IF OBJECT_ID('zutil.DateMonth') IS NOT NULL
  DROP FUNCTION zutil.DateMonth
GO
CREATE FUNCTION zutil.DateMonth(@dt datetime2(0))
RETURNS date
BEGIN
  SET @dt = CONVERT(date, @dt)
  RETURN DATEADD(day, 1 - DATEPART(day, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateMonth TO public
GRANT EXEC ON zutil.DateMonth TO zzp_server
GO
