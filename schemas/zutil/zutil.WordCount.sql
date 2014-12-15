
IF OBJECT_ID('zutil.WordCount') IS NOT NULL
  DROP FUNCTION zutil.WordCount
GO
CREATE FUNCTION zutil.WordCount(@s nvarchar(max))
RETURNS int
BEGIN
  -- Returns the word count of a string
  -- Note that the function does not return 100% correct value if the string has over 10 whitespaces in a row
  SET @s = REPLACE(@s, CHAR(10), ' ')
  SET @s = REPLACE(@s, CHAR(13), ' ')
  SET @s = REPLACE(@s, CHAR(9), ' ')
  SET @s = REPLACE(@s, '    ', ' ')
  SET @s = REPLACE(@s, '   ', ' ')
  SET @s = REPLACE(@s, '  ', ' ')
  SET @s = LTRIM(@s)
  IF @s = ''
    RETURN 0
  RETURN LEN(@s) - LEN(REPLACE(@s, ' ', '')) + 1
END
GO
GRANT EXEC ON zutil.WordCount TO zzp_server
GO
