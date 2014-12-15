
IF OBJECT_ID('zsystem.SendMail') IS NOT NULL
  DROP PROCEDURE zsystem.SendMail
GO
CREATE PROCEDURE zsystem.SendMail
  @recipients   varchar(max),
  @subject      nvarchar(255),
  @body         nvarchar(max),
  @body_format  varchar(20) = NULL
AS
  SET NOCOUNT ON

  -- Azure does not support msdb.dbo.sp_send_dbmail
  IF CONVERT(varchar(max), SERVERPROPERTY('edition')) NOT LIKE '%Azure%'
  BEGIN
    EXEC sp_executesql N'EXEC msdb.dbo.sp_send_dbmail NULL, @p_recipients, NULL, NULL, @p_subject, @p_body, @p_body_format',
                       N'@p_recipients varchar(max), @p_subject nvarchar(255), @p_body nvarchar(max), @p_body_format  varchar(20)',
                       @p_recipients = @recipients, @p_subject = @subject, @p_body = @body, @p_body_format = @body_format
  END
GO
