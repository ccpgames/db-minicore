
IF OBJECT_ID('zsystem.Texts_ID') IS NOT NULL
  DROP PROCEDURE zsystem.Texts_ID
GO
CREATE PROCEDURE zsystem.Texts_ID
  @text  nvarchar(450)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @text IS NULL
    RETURN 0

  DECLARE @textID int
  SELECT @textID = textID FROM zsystem.texts WHERE [text] = @text
  IF @textID IS NULL
  BEGIN
    INSERT INTO zsystem.texts ([text]) VALUES (@text)
    SET @textID = SCOPE_IDENTITY()
  END
  RETURN @textID
GO
GRANT EXEC ON zsystem.Texts_ID TO zzp_server
GO
