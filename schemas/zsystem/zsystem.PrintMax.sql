
-- Based on code from Ben Dill

IF OBJECT_ID('zsystem.PrintMax') IS NOT NULL
  DROP PROCEDURE zsystem.PrintMax
GO
CREATE PROCEDURE zsystem.PrintMax
  @str  nvarchar(max)
AS
  SET NOCOUNT ON

  IF @str IS NULL
    RETURN

  DECLARE @reversed nvarchar(max), @break int

  WHILE (LEN(@str) > 4000)
  BEGIN
    SET @reversed = REVERSE(LEFT(@str, 4000))

    SET @break = CHARINDEX(CHAR(10) + CHAR(13), @reversed)

    IF @break = 0
    BEGIN
      PRINT LEFT(@str, 4000)
      SET @str = RIGHT(@str, LEN(@str) - 4000)
    END
    ELSE
    BEGIN
      PRINT LEFT(@str, 4000 - @break + 1)
      SET @str = RIGHT(@str, LEN(@str) - 4000 + @break - 1)
    END
  END

  IF LEN(@str) > 0
    PRINT @str
GO
