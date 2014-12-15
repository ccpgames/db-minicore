
IF OBJECT_ID('zutil.Age') IS NOT NULL
  DROP FUNCTION zutil.Age
GO
CREATE FUNCTION zutil.Age(@dob datetime2(0), @today datetime2(0))
RETURNS int
BEGIN
  DECLARE @age int
  SET @age = YEAR(@today) - YEAR(@dob)
  IF MONTH(@today) < MONTH(@dob) SET @age = @age -1
  IF MONTH(@today) = MONTH(@dob) AND DAY(@today) < DAY(@dob) SET @age = @age - 1
  RETURN @age
END
GO
GRANT EXEC ON zutil.Age TO zzp_server
GO
