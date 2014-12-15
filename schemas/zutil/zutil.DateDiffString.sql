
IF OBJECT_ID('zutil.DateDiffString') IS NOT NULL
  DROP FUNCTION zutil.DateDiffString
GO
CREATE FUNCTION zutil.DateDiffString(@dt1 datetime2(0), @dt2 datetime2(0))
RETURNS varchar(20)
BEGIN
  DECLARE @s varchar(20)

  DECLARE @seconds int, @x int
  SET @seconds = ABS(DATEDIFF(second, @dt1, @dt2))

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
GRANT EXEC ON zutil.DateDiffString TO public
GRANT EXEC ON zutil.DateDiffString TO zzp_server
GO
