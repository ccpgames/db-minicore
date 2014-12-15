
IF OBJECT_ID('zutil.DateLocal') IS NOT NULL
  DROP FUNCTION zutil.DateLocal
GO
CREATE FUNCTION zutil.DateLocal(@dt datetime2(0))
RETURNS datetime2(0)
BEGIN
  RETURN DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()), @dt)
END
GO
GRANT EXEC ON zutil.DateLocal TO public
GRANT EXEC ON zutil.DateLocal TO zzp_server
GO
