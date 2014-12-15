
IF OBJECT_ID('zdm.checkmail') IS NOT NULL
  DROP PROCEDURE zdm.checkmail
GO
CREATE PROCEDURE zdm.checkmail
  @rows  smallint = 10
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC msdb.dbo.sysmail_help_status_sp

  EXEC msdb.dbo.sysmail_help_queue_sp @queue_type = 'mail'

  SELECT TOP (@rows) * FROM msdb.dbo.sysmail_sentitems ORDER BY mailitem_id DESC
GO
