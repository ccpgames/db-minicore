
IF OBJECT_ID('zutil.DiffInt') IS NOT NULL
  DROP FUNCTION zutil.DiffInt
GO
CREATE FUNCTION zutil.DiffInt(@A int, @B int)
RETURNS bit
BEGIN
  DECLARE @R bit
  IF @A IS NULL AND @B IS NULL
    SET @R = 0
  ELSE
  BEGIN
    IF @A IS NULL OR @B IS NULL
      SET @R = 1
    ELSE IF @A = @B
      SET @R = 0
    ELSE
      SET @R = 1
  END
  RETURN @R
END
GO
