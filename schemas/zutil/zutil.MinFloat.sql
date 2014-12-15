
IF OBJECT_ID('zutil.MinFloat') IS NOT NULL
  DROP FUNCTION zutil.MinFloat
GO
CREATE FUNCTION zutil.MinFloat(@value1 float, @value2 float)
RETURNS float
BEGIN
  DECLARE @f float
  IF @value1 < @value2
    SET @f = @value1
  ELSE
    SET @f = @value2
  RETURN @f
END
GO
