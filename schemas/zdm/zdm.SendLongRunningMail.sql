
IF OBJECT_ID('zdm.SendLongRunningMail') IS NOT NULL
  DROP PROCEDURE zdm.SendLongRunningMail
GO
CREATE PROCEDURE zdm.SendLongRunningMail
  @minutes  smallint = 10,
  @rows     tinyint = 10
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @recipients varchar(max)
  SET @recipients = zsystem.Settings_Value('zdm', 'Recipients-LongRunning')
  IF @recipients = '' RETURN

  DECLARE @ignoreSQL nvarchar(max)
  SET @ignoreSQL = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL')

  DECLARE @session_id int, @start_time datetime2(0), @text nvarchar(max)

  DECLARE @stmt nvarchar(max), @cursor CURSOR
  SET @stmt = '
SET @p_cursor = CURSOR LOCAL FAST_FORWARD
  FOR SELECT TOP (@p_rows) R.session_id, R.start_time, S.[text]
        FROM sys.dm_exec_requests R
          CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) S
       WHERE R.session_id != @@SPID AND R.start_time < DATEADD(minute, -@p_minutes, GETDATE())'
  IF @ignoreSQL != ''
    SELECT @stmt = @stmt + ' AND S.[text] NOT LIKE ''' + string + '''' FROM zutil.CharListToTable(@ignoreSQL)
  SET @stmt = @stmt + '
         ORDER BY R.start_time
OPEN @p_cursor'

  EXEC sp_executesql @stmt, N'@p_cursor CURSOR OUTPUT, @p_rows tinyint, @p_minutes smallint', @cursor OUTPUT, @rows, @minutes
  FETCH NEXT FROM @cursor INTO @session_id, @start_time, @text
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @text = CHAR(13) + '   getdate: ' + CONVERT(nvarchar, GETDATE(), 120)
              + CHAR(13) + 'start_time: ' + CONVERT(nvarchar, @start_time, 120)
              + CHAR(13) + 'session_id: ' + CONVERT(nvarchar, @session_id)
              + CHAR(13) + CHAR(13) + @text
    EXEC zsystem.SendMail @recipients, 'LONG RUNNING SQL', @text

    FETCH NEXT FROM @cursor INTO @session_id, @start_time, @text
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO
