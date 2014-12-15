
IF OBJECT_ID('zutil.UnicodeValueString') IS NOT NULL
  DROP FUNCTION zutil.UnicodeValueString
GO
CREATE FUNCTION zutil.UnicodeValueString(@s nvarchar(1000))
RETURNS varchar(8000)
BEGIN
  DECLARE @vs varchar(8000)
  SET @vs = ''
  DECLARE @i int
  DECLARE @len int
  SET @i = 1
  SET @len = LEN(@s)
  WHILE @i <= @len
  BEGIN
    IF @vs != ''
      SET @vs = @vs + '+'
    SET @vs = @vs + 'NCHAR(' + CONVERT(varchar, UNICODE(SUBSTRING(@s, @i, 1))) + ')'
    SET @i = @i + 1
  END
  RETURN @vs
END
GO
