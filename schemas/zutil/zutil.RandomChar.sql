
IF OBJECT_ID('zutil.RandomChar') IS NOT NULL
  DROP FUNCTION zutil.RandomChar
GO
CREATE FUNCTION zutil.RandomChar(@charFrom char(1), @charTo char(1), @rand float)
RETURNS char(1)
BEGIN
  DECLARE @cf smallint
  DECLARE @ct smallint
  SET @cf = ASCII(@charFrom)
  SET @ct = ASCII(@charTo)

  DECLARE @c smallint
  SET @c = (@ct - @cf) + 1
  SET @c = @cf + (@c * @rand)
  IF @c > @ct
    SET @c = @ct

  RETURN CHAR(@c)
END
GO
