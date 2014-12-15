
IF OBJECT_ID('zsystem.Settings_Update') IS NOT NULL
  DROP PROCEDURE zsystem.Settings_Update
GO
CREATE PROCEDURE zsystem.Settings_Update
  @group              varchar(200), 
  @key                varchar(200), 
  @value              nvarchar(max),
  @userID             int = NULL,
  @insertIfNotExists  bit = 0
AS
  SET NOCOUNT ON

  BEGIN TRY
    DECLARE @allowUpdate bit
    SELECT @allowUpdate = allowUpdate FROM zsystem.settings WHERE [group] = @group AND [key] = @key
    IF @allowUpdate IS NULL AND @insertIfNotExists = 0
      RAISERROR ('Setting not found', 16, 1)
    IF @allowUpdate = 0 AND @insertIfNotExists = 0
      RAISERROR ('Update not allowed', 16, 1)

    DECLARE @fixedText nvarchar(450) = @group + '.' + @key

    BEGIN TRANSACTION

    IF @allowUpdate IS NULL AND @insertIfNotExists = 1
    BEGIN
      INSERT INTO zsystem.settings ([group], [key], value, [description]) VALUES (@group, @key, @value, '')

      EXEC zsystem.Events_Insert 2000000032, NULL, @userID, @fixedText=@fixedText, @eventText=@value
    END
    ELSE
    BEGIN
      UPDATE zsystem.settings
          SET value = @value
        WHERE [group] = @group AND [key] = @key AND [value] != @value
      IF @@ROWCOUNT > 0
        EXEC zsystem.Events_Insert 2000000031, NULL, @userID, @fixedText=@fixedText, @eventText=@value
    END

    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION
    EXEC zsystem.CatchError 'zsystem.Settings_Update'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.Settings_Update TO zzp_server
GO
