
IF OBJECT_ID('zutil.DateDay') IS NOT NULL
  DROP FUNCTION zutil.DateDay
GO
CREATE FUNCTION zutil.DateDay(@dt datetime2(0))
RETURNS date
BEGIN
  RETURN CONVERT(date, @dt)
END
GO
GRANT EXEC ON zutil.DateDay TO public
GRANT EXEC ON zutil.DateDay TO zzp_server
GO
