
IF OBJECT_ID('zutil.DateTimeDay') IS NOT NULL
  DROP FUNCTION zutil.DateTimeDay
GO
CREATE FUNCTION zutil.DateTimeDay(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  RETURN CONVERT(date, @dt)
END
GO
GRANT EXEC ON zutil.DateTimeDay TO public
GRANT EXEC ON zutil.DateTimeDay TO zzp_server
GO
