
IF OBJECT_ID('zutil.MinInt') IS NOT NULL
  DROP FUNCTION zutil.MinInt
GO
CREATE FUNCTION zutil.MinInt(@value1 int, @value2 int)
RETURNS int
BEGIN
  DECLARE @i int
  IF @value1 < @value2
    SET @i = @value1
  ELSE
    SET @i = @value2
  RETURN @i
END
GO