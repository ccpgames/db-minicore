
IF OBJECT_ID('zsystem.Versions_Finish') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Finish
GO
CREATE PROCEDURE zsystem.Versions_Finish
  @developer  varchar(20),
  @version    int,
  @userName   nvarchar(100)
AS
  SET NOCOUNT ON

  IF EXISTS(SELECT *
              FROM zsystem.versions
             WHERE developer = @developer AND [version] = @version AND userName = @userName AND firstDuration IS NOT NULL)
  BEGIN
    PRINT ''
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    PRINT '!!! DATABASE UPDATE HAS BEEN EXECUTED BEFORE !!!'
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    UPDATE zsystem.versions
       SET executionCount = executionCount + 1, lastDate = GETUTCDATE(),
           lastLoginName = SUSER_SNAME(), lastDuration = DATEDIFF(second, lastDate, GETUTCDATE()), executingSPID = NULL
     WHERE developer = @developer AND [version] = @version
  END
  ELSE
  BEGIN
    DECLARE @coreVersion int
    IF @developer != 'CORE'
      SELECT @coreVersion = MAX([version]) FROM zsystem.versions WHERE developer = 'CORE'

    UPDATE zsystem.versions 
       SET executionCount = executionCount + 1, coreVersion = @coreVersion,
           firstDuration = DATEDIFF(second, versionDate, GETUTCDATE()), executingSPID = NULL
     WHERE developer = @developer AND [version] = @version
  END

  PRINT ''
  PRINT '[EXEC zsystem.Versions_Finish ''' + @developer + ''', ' + CONVERT(varchar, @version) + ', ''' + @userName + '''] has completed'
  PRINT ''

  DECLARE @recipients varchar(max)
  SET @recipients = zsystem.Settings_Value('zsystem', 'Recipients-Updates')
  IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
  BEGIN
    DECLARE @subject nvarchar(255), @body nvarchar(max)
    SET @subject = 'Database update ' + @developer + '-' + CONVERT(varchar, @version) + ' applied on ' + DB_NAME()
    SET @body = NCHAR(13) + @subject + NCHAR(13)
                + NCHAR(13) + '  Developer: ' + @developer
                + NCHAR(13) + '    Version: ' + CONVERT(varchar, @version)
                + NCHAR(13) + '       User: ' + @userName
                + NCHAR(13) + NCHAR(13)
                + NCHAR(13) + '   Database: ' + DB_NAME()
                + NCHAR(13) + '       Host: ' + HOST_NAME()
                + NCHAR(13) + '      Login: ' + SUSER_SNAME()
                + NCHAR(13) + 'Application: ' + APP_NAME()
    EXEC zsystem.SendMail @recipients, @subject, @body
  END
GO
