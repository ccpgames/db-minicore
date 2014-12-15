
IF OBJECT_ID('zutil.ContainsUnicode') IS NOT NULL
  DROP FUNCTION zutil.ContainsUnicode
GO
CREATE FUNCTION zutil.ContainsUnicode(@s nvarchar(4000))
RETURNS bit
BEGIN
  DECLARE @r bit, @i int, @l int

  SET @r = 0

  IF @s IS NOT NULL
  BEGIN
    SELECT @l = LEN(@s), @i = 1

    WHILE @i <= @l
    BEGIN
      IF UNICODE(SUBSTRING(@s, @i, 1)) > 255
      BEGIN
        SET @r = 1
        BREAK
      END
      SET @i = @i + 1
    END
  END
  
  RETURN @r
END
GO
