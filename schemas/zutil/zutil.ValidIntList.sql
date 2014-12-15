
IF OBJECT_ID('zutil.ValidIntList') IS NOT NULL
  DROP FUNCTION zutil.ValidIntList
GO
CREATE FUNCTION zutil.ValidIntList(@list varchar(8000))
RETURNS smallint
BEGIN
  DECLARE @len smallint
  DECLARE @pos smallint
  DECLARE @c char(1)
  SET @pos = 1
  SET @len = LEN(@list)
  WHILE @pos <= @len
  BEGIN
    SET @c = SUBSTRING(@list, @pos, 1)
    SET @pos = @pos + 1
    IF ASCII(@c) IN (32, 44) OR ASCII(@c) BETWEEN 48 AND 57
      CONTINUE
    RETURN -1
  END
  RETURN 1
END
GO
