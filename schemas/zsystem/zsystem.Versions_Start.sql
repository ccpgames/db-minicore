
IF OBJECT_ID('zsystem.Versions_Start') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Start
GO
CREATE PROCEDURE zsystem.Versions_Start
  @developer  nvarchar(20),
  @version    int,
  @userName   nvarchar(100)
AS
  SET NOCOUNT ON

  DECLARE @currentVersion int
  SELECT @currentVersion = MAX([version]) FROM zsystem.versions WHERE developer = @developer
  IF @currentVersion != @version - 1
  BEGIN
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    PRINT '!!! DATABASE NOT OF CORRECT VERSION !!!'
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  END

  IF NOT EXISTS(SELECT * FROM zsystem.versions WHERE developer = @developer AND [version] = @version)
  BEGIN
    INSERT INTO zsystem.versions (developer, [version], versionDate, userName, loginName, executionCount, executingSPID)
         VALUES (@developer, @version, GETUTCDATE(), @userName, SUSER_SNAME(), 0, @@SPID)
  END
  ELSE
  BEGIN
    UPDATE zsystem.versions 
       SET lastDate = GETUTCDATE(), executingSPID = @@SPID 
     WHERE developer = @developer AND [version] = @version
  END
GO
