
IF OBJECT_ID('zutil.BigintToNvarchar') IS NOT NULL
  DROP FUNCTION zutil.BigintToNvarchar
GO
CREATE FUNCTION zutil.BigintToNvarchar(@bi bigint, @style tinyint)
RETURNS nvarchar(30)
BEGIN
  IF @style = 1
    RETURN PARSENAME(CONVERT(nvarchar, CONVERT(money, @bi), 1), 2)
  RETURN CONVERT(nvarchar, @bi)
END
GO
GRANT EXEC ON zutil.BigintToNvarchar TO zzp_server
GO
