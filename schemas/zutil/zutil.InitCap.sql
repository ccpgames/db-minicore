
IF OBJECT_ID('zutil.InitCap') IS NOT NULL
  DROP FUNCTION zutil.InitCap
GO
CREATE FUNCTION zutil.InitCap(@s nvarchar(4000)) 
RETURNS nvarchar(4000)
AS
BEGIN
  DECLARE @i int, @char nchar(1), @prevChar nchar(1), @output nvarchar(4000)

  SELECT @output = LOWER(@s), @i = 1

  WHILE @i <= LEN(@s)
  BEGIN
    SELECT @char = SUBSTRING(@s, @i, 1),
           @prevChar = CASE WHEN @i = 1 THEN ' ' ELSE SUBSTRING(@s, @i - 1, 1) END

    IF @prevChar IN (' ', ';', ':', '!', '?', ',', '.', '_', '-', '/', '&', '''', '(')
    BEGIN
      IF @prevChar != '''' OR UPPER(@char) != 'S'
        SET @output = STUFF(@output, @i, 1, UPPER(@char))
    END

    SET @i = @i + 1
  END

  RETURN @output
END
GO
GRANT EXEC ON zutil.InitCap TO zzp_server
GO
