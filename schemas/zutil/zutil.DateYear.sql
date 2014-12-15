
IF OBJECT_ID('zutil.DateYear') IS NOT NULL
  DROP FUNCTION zutil.DateYear
GO
CREATE FUNCTION zutil.DateYear(@dt datetime2(0))
RETURNS date
BEGIN
  SET @dt = CONVERT(date, @dt)
  RETURN DATEADD(day, 1 - DATEPART(dayofyear, @dt), @dt)
END
GO
GRANT EXEC ON zutil.DateYear TO public
GRANT EXEC ON zutil.DateYear TO zzp_server
GO
