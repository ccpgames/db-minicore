
-- Add style 2 and 3, 2 = "1,000.00", 3 = "1000" ?

IF OBJECT_ID('zutil.MoneyToNvarchar') IS NOT NULL
  DROP FUNCTION zutil.MoneyToNvarchar
GO
CREATE FUNCTION zutil.MoneyToNvarchar(@m money, @style tinyint)
RETURNS nvarchar(30)
BEGIN
  IF @style = 1
    RETURN PARSENAME(CONVERT(nvarchar, @m, 1), 2)
  RETURN CONVERT(nvarchar, @m)
END
GO
GRANT EXEC ON zutil.MoneyToNvarchar TO zzp_server
GO
