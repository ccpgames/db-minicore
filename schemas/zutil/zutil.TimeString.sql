
IF OBJECT_ID('zutil.TimeString') IS NOT NULL
  DROP FUNCTION zutil.TimeString
GO
CREATE FUNCTION zutil.TimeString(@seconds int)
RETURNS varchar(20)
BEGIN
  DECLARE @s varchar(20)

  DECLARE @x int

  -- Seconds
  SET @x = @seconds % 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2)
  SET @seconds = @seconds - @x

  -- Minutes
  SET @x = (@seconds % (60 * 60)) / 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2) + ':' + @s
  SET @seconds = @seconds - (@x * 60)

  -- Hours
  SET @x = @seconds / (60 * 60)
  SET @s = CONVERT(varchar, @x) + ':' + @s
  IF LEN(@s) < 8 SET @s = '0' + @s

  RETURN @s
END
GO
GRANT EXEC ON zutil.TimeString TO zzp_server
GO
