
IF OBJECT_ID('zutil.MaxFloat') IS NOT NULL
  DROP FUNCTION zutil.MaxFloat
GO
CREATE FUNCTION zutil.MaxFloat(@value1 float, @value2 float)
RETURNS float
BEGIN
  DECLARE @f float
  IF @value1 > @value2
    SET @f = @value1
  ELSE
    SET @f = @value2
  RETURN @f
END
GO
