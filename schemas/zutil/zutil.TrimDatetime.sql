
IF OBJECT_ID('zutil.TrimDatetime') IS NOT NULL
  DROP FUNCTION zutil.TrimDatetime
GO
CREATE FUNCTION zutil.TrimDatetime(@value datetime2(0), @minDateTime datetime2(0), @maxDateTime datetime2(0))
RETURNS datetime2(0)
BEGIN
  IF @value < @minDateTime
    RETURN @minDateTime
  IF @value > @maxDateTime
    RETURN @maxDateTime
  RETURN @value
END
GO
