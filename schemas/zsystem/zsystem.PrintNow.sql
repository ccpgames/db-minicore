
IF OBJECT_ID('zsystem.PrintNow') IS NOT NULL
  DROP PROCEDURE zsystem.PrintNow
GO
CREATE PROCEDURE zsystem.PrintNow
  @str        nvarchar(4000),
  @printTime  bit = 0
AS
  SET NOCOUNT ON

  IF @printTime = 1
    SET @str = CONVERT(nvarchar, GETUTCDATE(), 120) + ' : ' + @str

  RAISERROR (@str, 0, 1) WITH NOWAIT;
GO
