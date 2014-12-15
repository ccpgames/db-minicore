
IF OBJECT_ID('zutil.NoBrackets') IS NOT NULL
  DROP FUNCTION zutil.NoBrackets
GO
CREATE FUNCTION zutil.NoBrackets(@s nvarchar(max))
RETURNS nvarchar(max)
BEGIN
  RETURN REPLACE(REPLACE(@s, '[', ''), ']', '')
END
GO
