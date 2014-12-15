
IF OBJECT_ID('zsystem.LookupValues_Update') IS NOT NULL
  DROP PROCEDURE zsystem.LookupValues_Update
GO
CREATE PROCEDURE zsystem.LookupValues_Update
  @lookupTableID  int,
  @lookupID       int, -- If NULL then zsystem.Texts_ID is used
  @lookupText     nvarchar(1000)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @lookupID IS NULL
    BEGIN
      IF LEN(@lookupText) > 450
        RAISERROR ('@lookupText must not be over 450 characters if zsystem.Texts_ID is used', 16, 1)
      EXEC @lookupID = zsystem.Texts_ID @lookupText
    END

    IF EXISTS(SELECT * FROM zsystem.lookupValues WHERE lookupTableID = @lookupTableID AND lookupID = @lookupID)
      UPDATE zsystem.lookupValues SET lookupText = @lookupText WHERE lookupTableID = @lookupTableID AND lookupID = @lookupID AND lookupText != @lookupText
    ELSE
      INSERT INTO zsystem.lookupValues (lookupTableID, lookupID, lookupText) VALUES (@lookupTableID, @lookupID, @lookupText)

    RETURN @lookupID
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.LookupValues_Update'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.LookupValues_Update TO zzp_server
GO
