
IF OBJECT_ID('zutil.IntToNvarchar') IS NOT NULL
  DROP FUNCTION zutil.IntToNvarchar
GO
CREATE FUNCTION zutil.IntToNvarchar(@i int, @style tinyint)
RETURNS nvarchar(20)
BEGIN
  IF @style = 1
    RETURN PARSENAME(CONVERT(nvarchar, CONVERT(money, @i), 1), 2)
  RETURN CONVERT(nvarchar, @i)
END
GO
GRANT EXEC ON zutil.IntToNvarchar TO zzp_server
GO
