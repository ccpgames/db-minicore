


---------------------------------------------------------------------------------------------------


IF NOT EXISTS (SELECT * FROM sys.schemas WHERE [name] = 'zsystem')
  EXEC sp_executesql N'CREATE SCHEMA zsystem'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.settings') IS NULL
BEGIN
  CREATE TABLE zsystem.settings
  (
    [group]        varchar(200)   NOT NULL,
    [key]          varchar(200)   NOT NULL,
    [value]        nvarchar(max)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    defaultValue   nvarchar(max)  NULL,
    critical       bit            NOT NULL  DEFAULT 0,
    allowUpdate    bit            NOT NULL  DEFAULT 0,
    orderID        int            NULL,
    --
    CONSTRAINT settings_PK PRIMARY KEY CLUSTERED ([group], [key])
  )
END
GO


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' and [key] = 'Product')
  INSERT INTO zsystem.settings ([group], [key], [value], [description], critical)
       VALUES ('zsystem', 'Product', '', 'The product being developed (EVE, WOD, DUST, ...)', 1)
GO
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' AND [key] = 'Recipients-Updates')
  INSERT INTO zsystem.settings ([group], [key], [value], [description])
       VALUES ('zsystem', 'Recipients-Updates', '', 'Mail recipients for DB update notifications')
GO
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' AND [key] = 'Recipients-Operations')
  INSERT INTO zsystem.settings ([group], [key], [value], [description])
       VALUES ('zsystem', 'Recipients-Operations', '', 'Mail recipients for notifications to operations')
GO
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' and [key] = 'Recipients-Operations-Software')
  INSERT INTO zsystem.settings ([group], [key], value, [description])
       VALUES ('zsystem', 'Recipients-Operations-Software', '', 'A recipient list for DB events that should go to both Software and Ops members.')
GO
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zsystem' AND [key] = 'Database')
  INSERT INTO zsystem.settings ([group], [key], [value], [description])
       VALUES ('zsystem', 'Database', '', 'The database being used.  Often useful to know when working on a restored database with a different name.)')
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.versions') IS NULL
BEGIN
  CREATE TABLE zsystem.versions
  (
    developer       varchar(20)    NOT NULL,
    [version]       int            NOT NULL,
    versionDate     datetime       NOT NULL,
    userName        nvarchar(100)  NOT NULL,
    loginName       nvarchar(256)  NOT NULL,
    executionCount  int            NOT NULL,
    lastDate        datetime       NULL,
    lastLoginName   nvarchar(256)  NULL,
    coreVersion     int            NULL,
    firstDuration   int            NULL,
    lastDuration    int            NULL,
    executingSPID   int            NULL
    --
    CONSTRAINT versions_PK PRIMARY KEY CLUSTERED (developer, [version])
  )
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Settings_Value') IS NOT NULL
  DROP FUNCTION zsystem.Settings_Value
GO
CREATE FUNCTION zsystem.Settings_Value(@group varchar(200), @key varchar(200))
RETURNS nvarchar(max)
BEGIN
  DECLARE @value nvarchar(max)
  SELECT @value = LTRIM(RTRIM([value])) FROM zsystem.settings WHERE [group] = @group AND [key] = @key
  RETURN ISNULL(@value, '')
END
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


EXEC zsystem.Versions_Start 'CORE.J', 0001, 'jorundur'
GO


---------------------------------------------------------------------------------------------------


IF SCHEMA_ID('zutil') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zutil'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MailServerInfo') IS NOT NULL
  DROP FUNCTION zutil.MailServerInfo
GO
CREATE FUNCTION zutil.MailServerInfo()
RETURNS nvarchar(4000)
BEGIN
  RETURN NCHAR(13) + NCHAR(13) + NCHAR(13)
         + '   Database: ' + DB_NAME() + NCHAR(13)
         + '       Host: ' + HOST_NAME() + NCHAR(13)
         + '      Login: ' + SUSER_SNAME() + NCHAR(13)
         + 'Application: ' + APP_NAME()
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.TimeString') IS NOT NULL
  DROP FUNCTION zutil.TimeString
GO
CREATE FUNCTION zutil.TimeString(@seconds int)
RETURNS varchar(20)
BEGIN
  DECLARE @s varchar(20)

  DECLARE @x int

  -- Seconds
  SET @x = @seconds % 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2)
  SET @seconds = @seconds - @x

  -- Minutes
  SET @x = (@seconds % (60 * 60)) / 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2) + ':' + @s
  SET @seconds = @seconds - (@x * 60)

  -- Hours
  SET @x = @seconds / (60 * 60)
  SET @s = CONVERT(varchar, @x) + ':' + @s
  IF LEN(@s) < 8 SET @s = '0' + @s

  RETURN @s
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateDiffString') IS NOT NULL
  DROP FUNCTION zutil.DateDiffString
GO
CREATE FUNCTION zutil.DateDiffString(@dt1 datetime, @dt2 datetime)
RETURNS varchar(20)
BEGIN
  DECLARE @s varchar(20)

  DECLARE @seconds int, @x int
  SET @seconds = ABS(DATEDIFF(second, @dt1, @dt2))

  -- Seconds
  SET @x = @seconds % 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2)
  SET @seconds = @seconds - @x

  -- Minutes
  SET @x = (@seconds % (60 * 60)) / 60
  SET @s = RIGHT('00' + CONVERT(varchar, @x), 2) + ':' + @s
  SET @seconds = @seconds - (@x * 60)

  -- Hours
  SET @x = @seconds / (60 * 60)
  SET @s = CONVERT(varchar, @x) + ':' + @s
  IF LEN(@s) < 8 SET @s = '0' + @s

  RETURN @s
END
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


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
                + zutil.MailServerInfo()
    EXEC zsystem.SendMail @recipients, @subject, @body
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_FirstExecution') IS NOT NULL
  DROP FUNCTION zsystem.Versions_FirstExecution
GO
CREATE FUNCTION zsystem.Versions_FirstExecution()
RETURNS BIT
BEGIN
  IF EXISTS(SELECT * FROM zsystem.versions WHERE executingSPID = @@SPID AND firstDuration IS NULL)
    RETURN 1
  RETURN 0
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_Check') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Check
GO
CREATE PROCEDURE zsystem.Versions_Check
  @developer  varchar(20) = 'CORE'
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @firstVersion int
  SELECT @firstVersion = MIN([version]) - 1 FROM zsystem.versions WHERE developer = @developer

  DECLARE @version int;
  WITH CTE (rowID, versionID, [version]) AS
  (
    SELECT ROW_NUMBER() OVER(ORDER BY [version]),
           [version] - @firstVersion, [version]
      FROM zsystem.versions
      WHERE developer = @developer
  )
  SELECT @version = MAX([version]) FROM CTE WHERE rowID = versionID

  SELECT info = CASE WHEN [version] = @version THEN 'LAST CONTINUOUS VERSION' ELSE 'MISSING PRIOR VERSIONS' END,
         [version], versionDate, userName, executionCount, lastDate, coreVersion
    FROM zsystem.versions
   WHERE developer = @developer AND [version] >= @version
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.CatchError') IS NOT NULL
  DROP PROCEDURE zsystem.CatchError
GO
CREATE PROCEDURE zsystem.CatchError
  @objectName  nvarchar(256) = NULL,
  @rollback    bit = 1
AS
  SET NOCOUNT ON

  IF @rollback = 1
  BEGIN
    IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION
  END

  DECLARE @message nvarchar(4000)
  DECLARE @number int
  DECLARE @severity int
  DECLARE @state int
  DECLARE @line int
  DECLARE @procedure nvarchar(200)
  SELECT @number = ERROR_NUMBER(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE(),
         @line = ERROR_LINE(), @procedure = ISNULL(ERROR_PROCEDURE(), '?'), @message = ERROR_MESSAGE()

  IF @number IS NULL
    RETURN

  IF @procedure = 'CatchError'
    SET @message = ISNULL(@objectName, '??') + ' >> ' + @message
  ELSE
    SET @message = ISNULL(@objectName, @procedure) + ' (line ' + CONVERT(nvarchar, @line) + ') >> ' + @message

  RAISERROR (@message, @severity, @state, @number, @severity, @state, @procedure, @line)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.PrintFlush') IS NOT NULL
  DROP PROCEDURE zsystem.PrintFlush
GO
CREATE PROCEDURE zsystem.PrintFlush
AS
  SET NOCOUNT ON

  BEGIN TRY
    RAISERROR ('', 11, 1) WITH NOWAIT;
  END TRY
  BEGIN CATCH
  END CATCH
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.PrintNow') IS NOT NULL
  DROP PROCEDURE zsystem.PrintNow
GO
CREATE PROCEDURE zsystem.PrintNow
  @str        nvarchar(4000),
  @printTime  bit = 0
AS
  SET NOCOUNT ON

  IF @printTime = 1
    SET @str = CONVERT(nvarchar, GETUTCDATE(), 120) + ': ' + @str

  RAISERROR (@str, 0, 1) WITH NOWAIT;
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF SCHEMA_ID('zdm') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zdm'
GO


---------------------------------------------------------------------------------------------------


if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'Recipients-LongRunning')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'Recipients-LongRunning', '', 'Mail recipients for long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL1')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL1', 'sqlbackup', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL2')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL2', 'BACKUP DATABASE%', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL3')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL3', '%DBCC INDEXDEFRAG%', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL4')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL4', '', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL5')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL5', '', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL6')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL6', '', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL7')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL7', '', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL8')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL8', '', 'Ignore SQL in long running SQL notifications')
go
if not exists(select * from zsystem.settings where [group] = 'zdm' and [key] = 'LongRunning-IgnoreSQL9')
  insert into zsystem.settings ([group], [key], [value], [description])
       values ('zdm', 'LongRunning-IgnoreSQL9', '', 'Ignore SQL in long running SQL notifications')
go


---------------------------------------------------------------------------------------------------


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

  DECLARE @ignoreSQL1 nvarchar(max)
  DECLARE @ignoreSQL2 nvarchar(max)
  DECLARE @ignoreSQL3 nvarchar(max)
  DECLARE @ignoreSQL4 nvarchar(max)
  DECLARE @ignoreSQL5 nvarchar(max)
  DECLARE @ignoreSQL6 nvarchar(max)
  DECLARE @ignoreSQL7 nvarchar(max)
  DECLARE @ignoreSQL8 nvarchar(max)
  DECLARE @ignoreSQL9 nvarchar(max)
  SET @ignoreSQL1 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL1')
  SET @ignoreSQL2 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL2')
  SET @ignoreSQL3 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL3')
  SET @ignoreSQL4 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL4')
  SET @ignoreSQL5 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL5')
  SET @ignoreSQL6 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL6')
  SET @ignoreSQL7 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL7')
  SET @ignoreSQL8 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL8')
  SET @ignoreSQL9 = zsystem.Settings_Value('zdm', 'LongRunning-IgnoreSQL9')

  DECLARE @session_id int
  DECLARE @start_time datetime
  DECLARE @text nvarchar(max)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT TOP (@rows) R.session_id, R.start_time, S.[text]
          FROM sys.dm_exec_requests R
            CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) S
         WHERE R.session_id != @@SPID AND R.start_time < DATEADD(minute, -@minutes, GETDATE())
               AND (@ignoreSQL1 = '' OR S.[text] NOT LIKE @ignoreSQL1)
               AND (@ignoreSQL2 = '' OR S.[text] NOT LIKE @ignoreSQL2)
               AND (@ignoreSQL3 = '' OR S.[text] NOT LIKE @ignoreSQL3)
               AND (@ignoreSQL4 = '' OR S.[text] NOT LIKE @ignoreSQL4)
               AND (@ignoreSQL5 = '' OR S.[text] NOT LIKE @ignoreSQL5)
               AND (@ignoreSQL6 = '' OR S.[text] NOT LIKE @ignoreSQL6)
               AND (@ignoreSQL7 = '' OR S.[text] NOT LIKE @ignoreSQL7)
               AND (@ignoreSQL8 = '' OR S.[text] NOT LIKE @ignoreSQL8)
               AND (@ignoreSQL9 = '' OR S.[text] NOT LIKE @ignoreSQL9)
         ORDER BY R.start_time
  OPEN @cursor
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


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.DropDefaultConstraint') IS NOT NULL
  DROP PROCEDURE zdm.DropDefaultConstraint
GO
CREATE PROCEDURE zdm.DropDefaultConstraint
  @tableName   nvarchar(256),
  @columnName  nvarchar(128)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @sql nvarchar(4000)
  SELECT @sql = 'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + OBJECT_NAME(default_object_id)
    FROM sys.columns
   WHERE [object_id] = OBJECT_ID(@tableName) AND [name] = @columnName AND default_object_id != 0
  EXEC (@sql)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.StartTrace') IS NOT NULL
  DROP PROCEDURE zdm.StartTrace
GO
CREATE PROCEDURE zdm.StartTrace
  @fileName         nvarchar(200),
  @minutes          smallint,
  @duration         bigint = NULL,
  @reads            bigint = NULL,
  @writes           bigint = NULL,
  @cpu              int = NULL,
  @rowCounts        bigint = NULL,
  @objectName       nvarchar(100) = NULL,
  @hostName         nvarchar(100) = NULL,
  @clientProcessID  nvarchar(100) = NULL,
  @databaseName     nvarchar(100) = NULL,
  @loginName        nvarchar(100) = NULL,
  @logicalOperator  int = 0,
  @maxFileSize      bigint = 4096
AS
  SET NOCOUNT ON

  -- Create trace
  DECLARE @rc int
  DECLARE @traceID int
  DECLARE @stopTime datetime
  SET @stopTime = DATEADD(minute, @minutes, GETDATE())
  EXEC @rc = sp_trace_create @traceID OUTPUT, 0, @fileName, @maxFileSize, @stopTime
  IF @rc != 0
  BEGIN
    RAISERROR ('Error in sp_trace_create (ErrorCode = %d)', 16, 1, @rc)
    RETURN -1
  END

  -- Event: RPC:Completed
  DECLARE @off bit
  DECLARE @on bit
  SET @off = 0
  SET @on = 1
  EXEC sp_trace_setevent @traceID, 10, 14, @on  -- StartTime
  EXEC sp_trace_setevent @traceID, 10, 15, @on  -- EndTime
  EXEC sp_trace_setevent @traceID, 10, 34, @on  -- ObjectName
  EXEC sp_trace_setevent @traceID, 10,  1, @on  -- TextData
  EXEC sp_trace_setevent @traceID, 10, 13, @on  -- Duration
  EXEC sp_trace_setevent @traceID, 10, 16, @on  -- Reads
  EXEC sp_trace_setevent @traceID, 10, 17, @on  -- Writes
  EXEC sp_trace_setevent @traceID, 10, 18, @on  -- CPU
  EXEC sp_trace_setevent @traceID, 10, 48, @on  -- RowCounts
  EXEC sp_trace_setevent @traceID, 10,  8, @on  -- HostName
  EXEC sp_trace_setevent @traceID, 10,  9, @on  -- ClientProcessID
  EXEC sp_trace_setevent @traceID, 10, 12, @on  -- SPID
  EXEC sp_trace_setevent @traceID, 10, 10, @on  -- ApplicationName
  EXEC sp_trace_setevent @traceID, 10, 11, @on  -- LoginName
  EXEC sp_trace_setevent @traceID, 10, 35, @on  -- DatabaseName
  EXEC sp_trace_setevent @traceID, 10, 31, @on  -- Error

  -- Event: SQL:BatchCompleted
  EXEC sp_trace_setevent @traceID, 12, 14, @on  -- StartTime
  EXEC sp_trace_setevent @traceID, 12, 15, @on  -- EndTime
  EXEC sp_trace_setevent @traceID, 12, 34, @on  -- ObjectName
  EXEC sp_trace_setevent @traceID, 12,  1, @on  -- TextData
  EXEC sp_trace_setevent @traceID, 12, 13, @on  -- Duration
  EXEC sp_trace_setevent @traceID, 12, 16, @on  -- Reads
  EXEC sp_trace_setevent @traceID, 12, 17, @on  -- Writes
  EXEC sp_trace_setevent @traceID, 12, 18, @on  -- CPU
  EXEC sp_trace_setevent @traceID, 12, 48, @on  -- RowCounts
  EXEC sp_trace_setevent @traceID, 12,  8, @on  -- HostName
  EXEC sp_trace_setevent @traceID, 12,  9, @on  -- ClientProcessID
  EXEC sp_trace_setevent @traceID, 12, 12, @on  -- SPID
  EXEC sp_trace_setevent @traceID, 12, 10, @on  -- ApplicationName
  EXEC sp_trace_setevent @traceID, 12, 11, @on  -- LoginName
  EXEC sp_trace_setevent @traceID, 12, 35, @on  -- DatabaseName
  EXEC sp_trace_setevent @traceID, 12, 31, @on  -- Error

  -- Filter: Duration
  IF @duration > 0
  BEGIN
    SET @duration = @duration * 1000
    EXEC sp_trace_setfilter @traceID, 13, @logicalOperator, 4, @duration
  END
  -- Filter: Reads
  IF @reads > 0
    EXEC sp_trace_setfilter @traceID, 16, @logicalOperator, 4, @reads
  -- Filter: Writes
  IF @writes > 0
    EXEC sp_trace_setfilter @traceID, 17, @logicalOperator, 4, @writes
  -- Filter: CPU
  IF @cpu > 0
    EXEC sp_trace_setfilter @traceID, 18, @logicalOperator, 4, @cpu
  -- Filter: RowCounts
  IF @rowCounts > 0
    EXEC sp_trace_setfilter @traceID, 48, @logicalOperator, 4, @rowCounts
  -- Filter: ObjectName
  IF @objectName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 34, @logicalOperator, 6, @objectName
  -- Filter: HostName
  IF @hostName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 8, @logicalOperator, 6, @hostName
  -- Filter: ClientProcessID
  IF @clientProcessID > 0
    EXEC sp_trace_setfilter @traceID, 9, @logicalOperator, 0, @clientProcessID
  -- Filter: DatabaseName
  IF @databaseName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 35, @logicalOperator, 6, @databaseName
  -- Filter: LoginName
  IF @loginName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 11, @logicalOperator, 6, @loginName

  -- Start trace
  EXEC sp_trace_setstatus @traceID, 1

  -- Return traceID and some extra help info
  SELECT traceID = @traceID,
         [To list active traces] = 'SELECT * FROM sys.traces',
         [To stop trace before minutes are up] = 'EXEC sp_trace_setstatus ' + CONVERT(varchar, @traceID) + ', 0;EXEC sp_trace_setstatus ' + CONVERT(varchar, @traceID) + ', 2'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.applocks') IS NOT NULL
  DROP PROCEDURE zdm.applocks
GO
CREATE PROCEDURE zdm.applocks
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT resource_database_id, resource_database_name = DB_NAME(resource_database_id), resource_description,
         request_mode, request_type, request_status, request_reference_count, request_session_id, request_owner_type
    FROM sys.dm_tran_locks
   WHERE resource_type = 'APPLICATION'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.blockers') IS NOT NULL
  DROP PROCEDURE zdm.blockers
GO
CREATE PROCEDURE zdm.blockers
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @blockingSessionID int

  SELECT TOP 1 @blockingSessionID = blocking_session_id 
    FROM sys.dm_exec_requests 
   WHERE blocking_session_id != 0
   GROUP BY blocking_session_id 
   ORDER BY COUNT(*) DESC

  IF @blockingSessionID > 0
  BEGIN
    SELECT * FROM sys.dm_exec_requests WHERE session_id = @blockingSessionID

    SELECT TOP (@rows) blocking_session_id, blocking_count = COUNT(*)
      FROM sys.dm_exec_requests
     WHERE blocking_session_id != 0
     GROUP BY blocking_session_id
     ORDER BY COUNT(*) DESC
  END
  ELSE
    PRINT 'No blockers found :-)'
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.counters') IS NOT NULL
  DROP PROCEDURE zdm.counters
GO
CREATE PROCEDURE zdm.counters
  @time_to_execute  char(8)= '00:00:03'
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime, @seconds int, @dbName nvarchar(128),
          @pageLookups bigint, @pageReads bigint, @pageWrites bigint, @pageSplits bigint,
          @transactions bigint, @writeTransactions bigint, @batchRequests bigint,
          @logins bigint, @logouts bigint, @tempTables bigint,
          @indexSearches bigint, @fullScans bigint, @probeScans bigint, @rangeScans bigint

  SELECT @now = GETUTCDATE(), @dbName = DB_NAME()

  SELECT @pageLookups = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page lookups/sec'

  SELECT @pageReads = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page reads/sec'

  SELECT @pageWrites = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page writes/sec'

  SELECT @pageSplits = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Page Splits/sec'

  SELECT @transactions = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Transactions/sec' AND instance_name = @dbName

  SELECT @writeTransactions = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Write Transactions/sec' AND instance_name = @dbName

  SELECT @batchRequests = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:SQL Statistics' AND counter_name = 'Batch Requests/sec'

  SELECT @logins = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logins/sec'

  SELECT @logouts = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logouts/sec'

  SELECT @tempTables = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Temp Tables Creation Rate'

  SELECT @indexSearches = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Index Searches/sec'

  SELECT @fullScans = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Full Scans/sec'

  SELECT @probeScans = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Probe Scans/sec'

  SELECT @rangeScans = cntr_value
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Range Scans/sec'

  WAITFOR DELAY @time_to_execute

  SET @seconds = DATEDIFF(second, @now, GETUTCDATE())

  SELECT [object_name] = RTRIM([object_name]), counter_name = RTRIM(counter_name), cntr_value = (cntr_value - @pageLookups) / @seconds, info = '', instance_name = RTRIM(instance_name), [description] = 'Number of requests per second to find a page in the buffer pool.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page lookups/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @pageReads) / @seconds, '', RTRIM(instance_name), 'Number of physical database page reads that are issued per second. This statistic displays the total number of physical page reads across all databases. Because physical I/O is expensive, you may be able to minimize the cost, either by using a larger data cache, intelligent indexes, and more efficient queries, or by changing the database design.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page reads/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @pageWrites) / @seconds, '', RTRIM(instance_name), 'Number of physical database page writes issued per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Buffer Manager' AND counter_name = 'Page writes/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @pageSplits) / @seconds, '', RTRIM(instance_name), 'Number of page splits per second that occur as the result of overflowing index pages.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Page Splits/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), cntr_value, '', RTRIM(instance_name), 'Counts the number of users currently connected to SQL Server.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'User Connections'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), cntr_value, '', RTRIM(instance_name), 'The number of currently active transactions of all types.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Transactions' AND counter_name = 'Transactions'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @transactions) / @seconds, '', RTRIM(instance_name), 'Number of transactions started for the database per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Transactions/sec' AND instance_name = @dbName
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @writeTransactions) / @seconds, '', RTRIM(instance_name), 'Number of transactions that wrote to the database and committed, in the last second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Write Transactions/sec' AND instance_name = @dbName
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), cntr_value, '', RTRIM(instance_name), 'Number of active transactions for the database.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Databases' AND counter_name = 'Active Transactions' AND instance_name = @dbName
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @batchRequests) / @seconds, '', RTRIM(instance_name), 'Number of Transact-SQL command batches received per second. This statistic is affected by all constraints (such as I/O, number of users, cache size, complexity of requests, and so on). High batch requests mean good throughput.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:SQL Statistics' AND counter_name = 'Batch Requests/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @logins) / @seconds, '', RTRIM(instance_name), 'Total number of logins started per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logins/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @logouts) / @seconds, '', RTRIM(instance_name), 'Total number of logout operations started per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Logouts/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @tempTables) / @seconds, '', RTRIM(instance_name), 'Number of temporary tables/table variables created per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:General Statistics' AND counter_name = 'Temp Tables Creation Rate'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @indexSearches) / @seconds, '', RTRIM(instance_name), 'Number of index searches per second. These are used to start a range scan, reposition a range scan, revalidate a scan point, fetch a single index record, and search down the index to locate where to insert a new row.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Index Searches/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @fullScans) / @seconds, '', RTRIM(instance_name), 'Number of unrestricted full scans per second. These can be either base-table or full-index scans.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Full Scans/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @probeScans) / @seconds, '', RTRIM(instance_name), 'Number of probe scans per second that are used to find at most one single qualified row in an index or base table directly.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Probe Scans/sec'
  UNION ALL
  SELECT RTRIM([object_name]), RTRIM(counter_name), (cntr_value - @rangeScans) / @seconds, '', RTRIM(instance_name), 'Number of qualified range scans through indexes per second.'
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Access Methods' AND counter_name = 'Range Scans/sec'
  ORDER BY 5, 1, 2
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.describe') IS NOT NULL
  DROP PROCEDURE zdm.describe
GO
CREATE PROCEDURE zdm.describe
  @objectName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @schemaID int, @schemaName nvarchar(128), @objectID int,
          @type char(2), @typeDesc nvarchar(60),
          @createDate datetime, @modifyDate datetime, @isMsShipped bit,
          @i int, @text varchar(max), @parentID int

  SET @i = CHARINDEX('.', @objectName)
  IF @i > 0
  BEGIN
    SET @schemaName = SUBSTRING(@objectName, 1, @i - 1)
    SET @objectName = SUBSTRING(@objectName, @i + 1, 256)
    IF CHARINDEX('.', @objectName) > 0
    BEGIN
      RAISERROR ('Object name invalid', 16, 1)
      RETURN -1
    END

    SELECT @schemaID = [schema_id] FROM sys.schemas WHERE LOWER(name) = LOWER(@schemaName)
    IF @schemaID IS NULL
    BEGIN
      RAISERROR ('Schema not found', 16, 1)
      RETURN -1
    END
  END

  IF @schemaID IS NULL
  BEGIN
    SELECT TOP 2 @objectID = [object_id], @type = [type], @typeDesc = type_desc,
                 @createDate = create_date, @modifyDate = modify_date, @isMsShipped = is_ms_shipped
      FROM sys.objects
     WHERE LOWER(name) = LOWER(@objectName)
  END
  ELSE
  BEGIN
    SELECT TOP 2 @objectID = [object_id], @type = [type], @typeDesc = type_desc,
                 @createDate = create_date, @modifyDate = modify_date, @isMsShipped = is_ms_shipped
      FROM sys.objects
     WHERE [schema_id] = @schemaID AND LOWER(name) = LOWER(@objectName)
  END
  IF @@ROWCOUNT = 1
  BEGIN
    IF @schemaID IS NULL
      SELECT @schemaID = [schema_id] FROM sys.objects WHERE [object_id] = @objectID
    IF @schemaName IS NULL
      SELECT @schemaName = name FROM sys.schemas WHERE [schema_id] = @schemaID

    IF @type IN ('V', 'P', 'FN', 'IF') -- View, Procedure, Scalar Function, Table Function
    BEGIN
      PRINT ''
      SELECT @text = OBJECT_DEFINITION(OBJECT_ID(@schemaName + '.' + @objectName))
      PRINT @text
    END
    ELSE IF @type = 'C' -- Check Constraint
    BEGIN
      PRINT ''
      SELECT @text = [definition], @parentID = parent_object_id
        FROM sys.check_constraints
       WHERE [object_id] = @objectID
      PRINT @text
    END
    ELSE IF @type = 'D' -- Default Constraint
    BEGIN
      PRINT ''
      SELECT @text = C.name + ' = ' + DC.[definition], @parentID = DC.parent_object_id
        FROM sys.default_constraints DC
          INNER JOIN sys.columns C ON C.[object_id] = DC.parent_object_id AND C.column_id = DC.parent_column_id
       WHERE DC.[object_id] = @objectID
      PRINT @text
    END
    ELSE IF @type IN ('U', 'IT', 'S', 'PK') -- User Table, Internal Table, System Table, Primary Key
    BEGIN
      DECLARE @tableID int, @rows int
      IF @type = 'PK' -- Primary Key
      BEGIN
        SELECT [object_id], [object_name] = @schemaName + '.' + @objectName, [type], type_desc, create_date, modify_date, is_ms_shipped, parent_object_id
          FROM sys.objects
         WHERE [object_id] = @objectID

        SELECT @parentID = parent_object_id FROM sys.objects  WHERE [object_id] = @objectID
        SET @tableID = @parentID
      END
      ELSE
        SET @tableID = @objectID

      SELECT @rows = SUM(P.[rows])
        FROM sys.indexes I
          INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
       WHERE I.[object_id] = @tableID AND I.index_id IN (0, 1)

      SELECT [object_id], [object_name] = @schemaName + '.' + @objectName, [type], type_desc, [rows] = @rows, create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [object_id] = @tableID
      SELECT column_id, column_name = name, [type_name] = TYPE_NAME(system_type_id), max_length, [precision], scale, collation_name, is_nullable, is_identity
        FROM sys.columns
       WHERE [object_id] = @tableID
       ORDER BY column_id
      SELECT index_id, index_name = name, [type], type_desc, is_unique, is_primary_key, is_unique_constraint, fill_factor
        FROM sys.indexes
       WHERE [object_id] = @tableID
      ORDER BY index_id
      SELECT index_name = I.name, IC.index_column_id, column_name = C.name, IC.is_included_column
        FROM sys.indexes I
          INNER JOIN sys.index_columns IC ON IC.[object_id] = I.[object_id] AND IC.index_id = I.index_id
            INNER JOIN sys.columns C ON C.[object_id] = IC.[object_id] AND C.column_id = IC.column_id
       WHERE I.[object_id] = @tableID
      ORDER BY I.index_id, IC.index_column_id
    END
    ELSE
    BEGIN
      PRINT ''
      PRINT 'EXTRA INFORMATION NOT AVAILABLE FOR THIS TYPE OF OBJECT!'
    END

    IF @type NOT IN ('U', 'IT', 'S', 'PK')
    BEGIN
      PRINT REPLICATE('_', 100)
      IF @isMsShipped = 1
        PRINT 'THIS IS A MICROSOFT OBJECT'

      IF @parentID IS NOT NULL
        PRINT '  PARENT: ' + OBJECT_SCHEMA_NAME(@parentID) + '.' + OBJECT_NAME(@parentID)

      PRINT '    Name: ' + @schemaName + '.' + @objectName
      PRINT '    Type: ' + @typeDesc
      PRINT ' Created: ' + CONVERT(varchar, @createDate, 120)
      PRINT 'Modified: ' + CONVERT(varchar, @modifyDate, 120)
    END
  END
  ELSE
  BEGIN
    IF @schemaID IS NULL
    BEGIN
      SELECT O.[object_id], [object_name] = S.name + '.' + O.name, O.[type], O.type_desc, O.parent_object_id,
             O.create_date, O.modify_date, O.is_ms_shipped
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE LOWER(O.name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY O.[type], LOWER(S.name), LOWER(O.name)
    END
    ELSE
    BEGIN
      SELECT [object_id], [object_name] = @schemaName + '.' + name, [type], type_desc, parent_object_id,
             create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [schema_id] = @schemaID AND LOWER(name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY [type], LOWER(name)
    END
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.indexinfo') IS NOT NULL
  DROP PROCEDURE zdm.indexinfo
GO
CREATE PROCEDURE zdm.indexinfo
  @tableName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @tableName IS NOT NULL AND OBJECT_ID(@tableName) IS NULL
  BEGIN
    RAISERROR ('Table not found !!!', 16, 1)
    RETURN -1
  END

  SELECT info = 'avg_fragmentation_in_percent - should be LOW'
  UNION ALL
  SELECT info = 'fragment_count - should be LOW'
  UNION ALL
  SELECT info = 'avg_fragment_size_in_pages - should be HIGH'

  SELECT table_name = t.[name], index_name = i.[name], s.*
    FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(@tableName), NULL, NULL, NULL) s
      LEFT JOIN sys.tables t ON t.[object_id] = s.[object_id]
      LEFT JOIN sys.indexes i ON i.[object_id] = s.[object_id] AND i.index_id = s.index_id
   ORDER BY s.avg_fragmentation_in_percent DESC
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.memory') IS NOT NULL
  DROP PROCEDURE zdm.memory
GO
CREATE PROCEDURE zdm.memory
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [object_name], counter_name,
         cntr_value = CASE WHEN counter_name LIKE '%(KB)%' THEN CASE WHEN cntr_value > 1048576 THEN CONVERT(varchar, CONVERT(money, cntr_value / 1048576.0)) + ' GB'
                                                                     WHEN cntr_value > 1024 THEN CONVERT(varchar, CONVERT(money, cntr_value / 1024.0)) + ' MB'
                                                                     ELSE CONVERT(varchar, cntr_value) + ' KB' END
                           ELSE CONVERT(varchar, cntr_value) END
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Memory Manager'
   ORDER BY instance_name, [object_name], counter_name
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.panic') IS NOT NULL
  DROP PROCEDURE zdm.panic
GO
CREATE PROCEDURE zdm.panic
AS
  SET NOCOUNT ON

  PRINT ''
  PRINT '#######################'
  PRINT '# DBA Panic Checklist #'
  PRINT '#######################'
  PRINT ''
  PRINT 'Web page: http://core/wiki/DB_DBA_Panic_Checklist'
  PRINT ''
  PRINT '------------------------------------------------'
  PRINT 'STORED PROCEDURES TO USE IN A PANIC SITUATION...'
  PRINT '------------------------------------------------'
  PRINT '  zdm.topsql        /  zdm.topsqlp'
  PRINT '  zdm.counters'
  PRINT '  zdm.sessioninfo   /  zdm.processinfo'
  PRINT '  zdm.transactions'
  PRINT '  zdm.applocks'
  PRINT '  zdm.memory'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.plans') IS NOT NULL
  DROP PROCEDURE zdm.plans
GO
CREATE PROCEDURE zdm.plans
  @filter      nvarchar(256),
  @objectType  nvarchar(20) = 'Proc',
  @rows        smallint = 50
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT TOP (@rows) C.objtype, C.cacheobjtype, C.refcounts, C.usecounts, C.size_in_bytes,
         P.query_plan, T.[text]
    FROM sys.dm_exec_cached_plans C
      CROSS APPLY sys.dm_exec_sql_text (C.plan_handle) T
      CROSS APPLY sys.dm_exec_query_plan(C.plan_handle) P
   WHERE C.objtype = @objectType AND T.[text] like N'%' + @filter + N'%'
   ORDER BY C.usecounts DESC
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.plantext') IS NOT NULL
  DROP PROCEDURE zdm.plantext
GO
CREATE PROCEDURE zdm.plantext
  @plan_handle  varbinary(64)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM sys.dm_exec_query_plan(@plan_handle)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.processinfo') IS NOT NULL
  DROP PROCEDURE zdm.processinfo
GO
CREATE PROCEDURE zdm.processinfo
  @hostName     varchar(100) = '',
  @programName  varchar(100) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [db_name] = DB_NAME([dbid]), [program_name], hostname = RTRIM(hostname), hostprocess,
         loginame = RTRIM(loginame), session_count = COUNT(*)
    FROM master..sysprocesses
   WHERE [dbid] != 0 AND hostname LIKE @hostName + '%' AND program_name LIKE @programName + '%'
   GROUP BY DB_NAME([dbid]), [program_name], hostname, hostprocess, loginame
   ORDER BY [db_name], [program_name], loginame, COUNT(*) DESC, hostname
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.procstats') IS NOT NULL
  DROP PROCEDURE zdm.procstats
GO
CREATE PROCEDURE zdm.procstats
  @rows  smallint = 5
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @count float, @CPU float, @reads float, @writes float
  SELECT @count = SUM(execution_count), @CPU = SUM(total_worker_time),
         @reads = SUM(total_logical_reads), @writes = SUM(total_logical_writes)
    FROM sys.dm_exec_procedure_stats

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         PERCENT_EXECUTION_COUNT = ROUND((execution_count / @count) * 100, 2),
         percent_worker_time = ROUND((total_worker_time / @CPU) * 100, 2),
         percent_logical_reads = ROUND((total_logical_reads / @reads) * 100, 2),
         percent_logical_writes = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY execution_count DESC

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         percent_execution_count = ROUND((execution_count / @count) * 100, 2),
         PERCENT_WORKER_TIME = ROUND((total_worker_time / @CPU) * 100, 2),
         percent_logical_reads = ROUND((total_logical_reads / @reads) * 100, 2),
         percent_logical_writes = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY total_worker_time DESC

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         percent_execution_count = ROUND((execution_count / @count) * 100, 2),
         percent_worker_time = ROUND((total_worker_time / @CPU) * 100, 2),
         PERCENT_LOGICAL_READS = ROUND((total_logical_reads / @reads) * 100, 2),
         percent_logical_writes = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY total_logical_reads DESC

  SELECT TOP (@rows) database_name = DB_NAME(database_id), [object_id],
         [object_name] = OBJECT_SCHEMA_NAME([object_id], database_id) + '.' + OBJECT_NAME([object_id], database_id),
         execution_count,
         percent_execution_count = ROUND((execution_count / @count) * 100, 2),
         percent_worker_time = ROUND((total_worker_time / @CPU) * 100, 2),
         percent_logical_reads = ROUND((total_logical_reads / @reads) * 100, 2),
         PERCENT_LOGICAL_WRITES = ROUND((total_logical_writes / @writes) * 100, 2),
         last_execution_time = CONVERT(varchar, last_execution_time, 120)
    FROM sys.dm_exec_procedure_stats
   ORDER BY total_logical_writes DESC
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.sessioninfo') IS NOT NULL
  DROP PROCEDURE zdm.sessioninfo
GO
CREATE PROCEDURE zdm.sessioninfo
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [db_name] = DB_NAME([dbid]), [program_name], loginame = RTRIM(loginame),
         host_count = COUNT(DISTINCT hostname),
         process_count = COUNT(DISTINCT CONVERT(nvarchar(128), hostname) + CONVERT(nvarchar, hostprocess)),
         session_count = COUNT(*)
    FROM master..sysprocesses
   WHERE [dbid] != 0
   GROUP BY DB_NAME([dbid]), [program_name], loginame
   ORDER BY COUNT(*) DESC
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.sqltext') IS NOT NULL
  DROP PROCEDURE zdm.sqltext
GO
CREATE PROCEDURE zdm.sqltext
  @sql_handle  varbinary(64)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM sys.dm_exec_sql_text(@sql_handle)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.stats') IS NOT NULL
  DROP PROCEDURE zdm.stats
GO
CREATE PROCEDURE zdm.stats
  @objectName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF OBJECT_ID(@objectName) IS NULL
  BEGIN
    PRINT 'Object not found!'
    RETURN
  END

  EXEC sp_autostats @objectName

  DECLARE @stmt nvarchar(4000)
  DECLARE @indexName nvarchar(128)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL STATIC READ_ONLY --FAST_FORWARD
    FOR SELECT name FROM sys.indexes WHERE [object_id] = OBJECT_ID(@objectName) ORDER BY index_id
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @indexName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @stmt = 'DBCC SHOW_STATISTICS (''' + @objectName + ''', ''' + @indexName + ''')'
    EXEC sp_executesql @stmt

    FETCH NEXT FROM @cursor INTO @indexName
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.tableusage') IS NOT NULL
  DROP PROCEDURE zdm.tableusage
GO
CREATE PROCEDURE zdm.tableusage
  @tableName  nvarchar(256) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT t.[name], i.[name], s.*
    FROM sys.dm_db_index_usage_stats s
      LEFT JOIN sys.tables t ON t.[object_id] = s.[object_id]
      LEFT JOIN sys.indexes i ON i.[object_id] = s.[object_id] AND i.index_id = s.index_id
   WHERE s.database_id = DB_ID() AND s.[object_id] = OBJECT_ID(@tableName)
   ORDER BY t.name, s.index_id
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.topsql') IS NOT NULL
  DROP PROCEDURE zdm.topsql
GO
CREATE PROCEDURE zdm.topsql
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime
  SET @now = GETDATE()

  SELECT TOP (@rows) R.session_id, R.database_id, database_name = DB_NAME(R.database_id), [object_id] = T.objectid,
         [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
         T.[text], R.command, R.[status], start_time = CONVERT(datetime2(0), R.start_time),
         run_time = zutil.DateDiffString(R.start_time, @now),
         estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
         wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type,
         cpu_time = zutil.TimeString(R.cpu_time / 1000),
         total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000),
         R.reads, R.writes, R.logical_reads, R.blocking_session_id, R.open_transaction_count, R.open_resultset_count,
         R.percent_complete, R.[sql_handle], R.plan_handle
    FROM sys.dm_exec_requests R
      CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
   ORDER BY R.start_time
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.topsqlp') IS NOT NULL
  DROP PROCEDURE zdm.topsqlp
GO
CREATE PROCEDURE zdm.topsqlp
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @now datetime
  SET @now = GETDATE()

  SELECT TOP (@rows) R.session_id, R.database_id, database_name = DB_NAME(R.database_id), [object_id] = T.objectid,
         [object_name] = OBJECT_SCHEMA_NAME(T.objectid, R.database_id) + '.' + OBJECT_NAME(T.objectid, R.database_id),
         T.[text], P.query_plan, R.command, R.[status], start_time = CONVERT(datetime2(0), R.start_time),
         run_time = zutil.DateDiffString(R.start_time, @now),
         estimated_completion_time = zutil.TimeString(R.estimated_completion_time / 1000),
         wait_time = zutil.TimeString(R.wait_time / 1000), R.last_wait_type,
         cpu_time = zutil.TimeString(R.cpu_time / 1000),
         total_elapsed_time = zutil.TimeString(R.total_elapsed_time / 1000),
         R.reads, R.writes, R.logical_reads, R.blocking_session_id, R.open_transaction_count, R.open_resultset_count,
         R.percent_complete, R.[sql_handle], R.plan_handle
    FROM sys.dm_exec_requests R
      CROSS APPLY sys.dm_exec_sql_text(R.[sql_handle]) T
      CROSS APPLY sys.dm_exec_query_plan(R.plan_handle) P
   ORDER BY R.start_time
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.transactions') IS NOT NULL
  DROP PROCEDURE zdm.transactions
GO
CREATE PROCEDURE zdm.transactions
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [description] = 'All active transactions that have done something...'
  SELECT tat.*, tdt.*
    FROM sys.dm_tran_database_transactions tdt
      LEFT JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = tdt.transaction_id
   WHERE tdt.database_id = DB_ID()
   ORDER BY tdt.database_transaction_begin_time

  SELECT [description] = 'Active transactions that have done nothing...'
  SELECT *
    FROM sys.dm_tran_active_transactions tat
      LEFT JOIN sys.dm_tran_database_transactions tdt ON tdt.transaction_id = tat.transaction_id
   WHERE tdt.transaction_id IS NULL
   ORDER BY tat.transaction_begin_time
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.objects') IS NOT NULL
  DROP PROCEDURE zdm.objects
GO
CREATE PROCEDURE zdm.objects
  @filter  nvarchar(256) = NULL,
  @type    char(2) = NULL
AS
  -- @type...
  --   C   CHECK_CONSTRAINT 49
  --   D   DEFAULT_CONSTRAINT 1028
  --   FN  SQL_SCALAR_FUNCTION 76
  --   P   SQL_STORED_PROCEDURE 2471
  --   PK  PRIMARY_KEY_CONSTRAINT 663
  --   TF  SQL_TABLE_VALUED_FUNCTION 5
  --   U   USER_TABLE 671
  --   UQ  UNIQUE_CONSTRAINT 6
  --   V   VIEW 302
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @filter IS NULL
  BEGIN
    IF @type IS NULL
    BEGIN
      SELECT [object_id], [object_name] = S.name + '.' + O.name, O.[type], O.type_desc, O.create_date, O.modify_date
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE O.is_ms_shipped = 0
       ORDER BY O.[type], S.name + '.' + O.name
    END
    ELSE
    BEGIN
      SELECT [object_id], [object_name] = S.name + '.' + O.name, O.create_date, O.modify_date
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE O.is_ms_shipped = 0 AND O.[type] = @type
       ORDER BY S.name + '.' + O.name
    END
  END
  ELSE
  BEGIN
    SET @filter = '%' + UPPER(@filter) + '%'

    IF @type IS NULL
    BEGIN
      SELECT [object_id], [object_name] = S.name + '.' + O.name, O.[type], O.type_desc, O.create_date, O.modify_date
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE O.is_ms_shipped = 0 AND UPPER(S.name + '.' + O.name) LIKE @filter
       ORDER BY O.[type], S.name + '.' + O.name
    END
    ELSE
    BEGIN
      SELECT [object_id], [object_name] = S.name + '.' + O.name, O.create_date, O.modify_date
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE O.is_ms_shipped = 0 AND O.[type] = @type AND UPPER(S.name + '.' + O.name) LIKE @filter
       ORDER BY S.name + '.' + O.name
    END
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.tables') IS NOT NULL
  DROP PROCEDURE zdm.tables
GO
CREATE PROCEDURE zdm.tables
  @filter  nvarchar(256) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.objects @filter, 'U'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.views') IS NOT NULL
  DROP PROCEDURE zdm.views
GO
CREATE PROCEDURE zdm.views
  @filter  nvarchar(256) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.objects @filter, 'V'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.functions') IS NOT NULL
  DROP PROCEDURE zdm.functions
GO
CREATE PROCEDURE zdm.functions
  @filter  nvarchar(256) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.objects @filter, 'FN'
  EXEC zdm.objects @filter, 'TF'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zdm.procs') IS NOT NULL
  DROP PROCEDURE zdm.procs
GO
CREATE PROCEDURE zdm.procs
  @filter  nvarchar(256) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.objects @filter, 'P'
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


-- Code from Itzik Ben-Gan, a very fast inline table function that will return a table of numbers

IF OBJECT_ID('zutil.Numbers') IS NOT NULL
  DROP FUNCTION zutil.Numbers
GO
CREATE FUNCTION zutil.Numbers(@n int)
  RETURNS TABLE
  RETURN WITH L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
              L1   AS(SELECT 1 AS c FROM L0 AS A, L0 AS B),
              L2   AS(SELECT 1 AS c FROM L1 AS A, L1 AS B),
              L3   AS(SELECT 1 AS c FROM L2 AS A, L2 AS B),
              L4   AS(SELECT 1 AS c FROM L3 AS A, L3 AS B),
              L5   AS(SELECT 1 AS c FROM L4 AS A, L4 AS B),
              Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY c) AS n FROM L5)
         SELECT n FROM Nums WHERE n <= @n;
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.Age') IS NOT NULL
  DROP FUNCTION zutil.Age
GO
CREATE FUNCTION zutil.Age(@dob smalldatetime, @today smalldatetime)
RETURNS int
BEGIN
  DECLARE @age int
  SET @age = YEAR(@today) - YEAR(@dob)
  IF MONTH(@today) < MONTH(@dob) SET @age = @age -1
  IF MONTH(@today) = MONTH(@dob) AND DAY(@today) < DAY(@dob) SET @age = @age - 1
  RETURN @age
END
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.BigintListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.BigintListToOrderedTable
GO
CREATE FUNCTION zutil.BigintListToOrderedTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(bigint, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.BigintListToTable') IS NOT NULL
  DROP FUNCTION zutil.BigintListToTable
GO
CREATE FUNCTION zutil.BigintListToTable (@list varchar(max))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(bigint, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.BigintToNvarchar') IS NOT NULL
  DROP FUNCTION zutil.BigintToNvarchar
GO
CREATE FUNCTION zutil.BigintToNvarchar(@bi bigint, @style tinyint)
RETURNS nvarchar(30)
BEGIN
  IF @style = 1
    RETURN PARSENAME(CONVERT(nvarchar, CONVERT(money, @bi), 1), 2)
  RETURN CONVERT(nvarchar, @bi)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.ContainsUnicode') IS NOT NULL
  DROP FUNCTION zutil.ContainsUnicode
GO
CREATE FUNCTION zutil.ContainsUnicode(@s nvarchar(4000))
RETURNS bit
BEGIN
  DECLARE @r bit, @i int, @l int

  SET @r = 0

  IF @s IS NOT NULL
  BEGIN
    SELECT @l = LEN(@s), @i = 1

    WHILE @i <= @l
    BEGIN
      IF UNICODE(SUBSTRING(@s, @i, 1)) > 255
      BEGIN
        SET @r = 1
        BREAK
      END
      SET @i = @i + 1
    END
  END
  
  RETURN @r
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateDay') IS NOT NULL
  DROP FUNCTION zutil.DateDay
GO
CREATE FUNCTION zutil.DateDay(@dt smalldatetime)
RETURNS smalldatetime
BEGIN
  RETURN CONVERT(int, @dt - 0.50000004)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateHour') IS NOT NULL
  DROP FUNCTION zutil.DateHour
GO
CREATE FUNCTION zutil.DateHour(@dt smalldatetime)
RETURNS smalldatetime
BEGIN
  RETURN DATEADD(minute, -DATEPART(minute, @dt), @dt)
END
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.DateListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.DateListToOrderedTable
GO
CREATE FUNCTION zutil.DateListToOrderedTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                dateValue = CONVERT(datetime2(0), SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.DateListToTable') IS NOT NULL
  DROP FUNCTION zutil.DateListToTable
GO
CREATE FUNCTION zutil.DateListToTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT dateValue = CONVERT(datetime2(0), SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateLocal') IS NOT NULL
  DROP FUNCTION zutil.DateLocal
GO
CREATE FUNCTION zutil.DateLocal(@dt smalldatetime)
RETURNS smalldatetime
BEGIN
  RETURN DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()), @dt)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateMonth') IS NOT NULL
  DROP FUNCTION zutil.DateMonth
GO
CREATE FUNCTION zutil.DateMonth(@dt smalldatetime)
RETURNS smalldatetime
BEGIN
  SET @dt = CONVERT(int, @dt - 0.50000004)
  RETURN DATEADD(day, 1 - DATEPART(day, @dt), @dt)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DateWeek') IS NOT NULL
  DROP FUNCTION zutil.DateWeek
GO
CREATE FUNCTION zutil.DateWeek(@dt smalldatetime)
RETURNS smalldatetime
BEGIN
  SET @dt = CONVERT(int, @dt - 0.50000004)
  RETURN DATEADD(day, 1 - DATEPART(weekday, @dt), @dt)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DiffFloat') IS NOT NULL
  DROP FUNCTION zutil.DiffFloat
GO
CREATE FUNCTION zutil.DiffFloat(@A float, @B float)
RETURNS bit
BEGIN
  DECLARE @R bit
  IF @A IS NULL AND @B IS NULL
    SET @R = 0
  ELSE
  BEGIN
    IF @A IS NULL OR @B IS NULL
      SET @R = 1
    ELSE IF @A = @B
      SET @R = 0
    ELSE
      SET @R = 1
  END
  RETURN @R
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.DiffInt') IS NOT NULL
  DROP FUNCTION zutil.DiffInt
GO
CREATE FUNCTION zutil.DiffInt(@A int, @B int)
RETURNS bit
BEGIN
  DECLARE @R bit
  IF @A IS NULL AND @B IS NULL
    SET @R = 0
  ELSE
  BEGIN
    IF @A IS NULL OR @B IS NULL
      SET @R = 1
    ELSE IF @A = @B
      SET @R = 0
    ELSE
      SET @R = 1
  END
  RETURN @R
END
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.FloatListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.FloatListToOrderedTable
GO
CREATE FUNCTION zutil.FloatListToOrderedTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(float, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.FloatListToTable') IS NOT NULL
  DROP FUNCTION zutil.FloatListToTable
GO
CREATE FUNCTION zutil.FloatListToTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(float, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.IntListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.IntListToOrderedTable
GO
CREATE FUNCTION zutil.IntListToOrderedTable (@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(int, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.IntListToTable') IS NOT NULL
  DROP FUNCTION zutil.IntListToTable
GO
CREATE FUNCTION zutil.IntListToTable (@list varchar(max))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(int, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IntToNvarchar') IS NOT NULL
  DROP FUNCTION zutil.IntToNvarchar
GO
CREATE FUNCTION zutil.IntToNvarchar(@i int, @style tinyint)
RETURNS nvarchar(20)
BEGIN
  IF @style = 1
    RETURN PARSENAME(CONVERT(nvarchar, CONVERT(money, @i), 1), 2)
  RETURN CONVERT(nvarchar, @i)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.IntToRoman') IS NOT NULL
  DROP FUNCTION zutil.IntToRoman
GO
CREATE FUNCTION zutil.IntToRoman(@intvalue int)
RETURNS varchar(20)
BEGIN
  DECLARE @str varchar(20)
  SET @str = CASE @intvalue
               WHEN 1 THEN 'I'
               WHEN 2 THEN 'II'
               WHEN 3 THEN 'III'
               WHEN 4 THEN 'IV'
               WHEN 5 THEN 'V'
               WHEN 6 THEN 'VI'
               WHEN 7 THEN 'VII'
               WHEN 8 THEN 'VIII'
               WHEN 9 THEN 'IX'
               WHEN 10 THEN 'X'
               WHEN 11 THEN 'XI'
               WHEN 12 THEN 'XII'
               WHEN 13 THEN 'XIII'
               WHEN 14 THEN 'XIV'
               WHEN 15 THEN 'XV'
               WHEN 16 THEN 'XVI'
               WHEN 17 THEN 'XVII'
               WHEN 18 THEN 'XVIII'
               WHEN 19 THEN 'XIX'
               WHEN 20 THEN 'XX'
               WHEN 21 THEN 'XXI'
               WHEN 22 THEN 'XXII'
               WHEN 23 THEN 'XXIII'
               WHEN 24 THEN 'XXIV'
               WHEN 25 THEN 'XXV'
               WHEN 26 THEN 'XXVI'
               WHEN 27 THEN 'XXVII'
               WHEN 28 THEN 'XXVIII'
               WHEN 29 THEN 'XXIX'
               WHEN 30 THEN 'XXX'
               WHEN 31 THEN 'XXXI'
               WHEN 32 THEN 'XXXII'
               WHEN 33 THEN 'XXXIII'
               WHEN 34 THEN 'XXXIV'
               WHEN 35 THEN 'XXXV'
               WHEN 36 THEN 'XXXVI'
               WHEN 37 THEN 'XXXVII'
               WHEN 38 THEN 'XXXVIII'
               WHEN 39 THEN 'XXXIX'
               WHEN 40 THEN 'XL'
               WHEN 41 THEN 'XLI'
               WHEN 42 THEN 'XLII'
               WHEN 43 THEN 'XLIII'
               WHEN 44 THEN 'XLIV'
               WHEN 45 THEN 'XLV'
               WHEN 46 THEN 'XLVI'
               WHEN 47 THEN 'XLVII'
               WHEN 48 THEN 'XLVIII'
               WHEN 49 THEN 'XLIX'
               WHEN 50 THEN 'L'
               WHEN 51 THEN 'LI'
               WHEN 52 THEN 'LII'
               WHEN 53 THEN 'LIII'
               WHEN 54 THEN 'LIV'
               WHEN 55 THEN 'LV'
               WHEN 56 THEN 'LVI'
               WHEN 57 THEN 'LVII'
               WHEN 58 THEN 'LVIII'
               WHEN 59 THEN 'LIX'
               WHEN 60 THEN 'LX'
               ELSE '???'
             END
  RETURN @str
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MaxFloat') IS NOT NULL
  DROP FUNCTION zutil.MaxFloat
GO
CREATE FUNCTION zutil.MaxFloat(@value1 float, @value2 float)
RETURNS float
BEGIN
  DECLARE @f float
  IF @value1 > @value2
    SET @f = @value1
  ELSE
    SET @f = @value2
  RETURN @f
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MaxInt') IS NOT NULL
  DROP FUNCTION zutil.MaxInt
GO
CREATE FUNCTION zutil.MaxInt(@value1 int, @value2 int)
RETURNS int
BEGIN
  DECLARE @i int
  IF @value1 > @value2
    SET @i = @value1
  ELSE
    SET @i = @value2
  RETURN @i
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.MoneyToNvarchar') IS NOT NULL
  DROP FUNCTION zutil.MoneyToNvarchar
GO
CREATE FUNCTION zutil.MoneyToNvarchar(@m money, @style tinyint)
RETURNS nvarchar(30)
BEGIN
  IF @style = 1
    RETURN PARSENAME(CONVERT(nvarchar, @m, 1), 2)
  RETURN CONVERT(nvarchar, @m)
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.NoBrackets') IS NOT NULL
  DROP FUNCTION zutil.NoBrackets
GO
CREATE FUNCTION zutil.NoBrackets(@s nvarchar(max))
RETURNS nvarchar(max)
BEGIN
  RETURN REPLACE(REPLACE(@s, '[', ''), ']', '')
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.RandomChar') IS NOT NULL
  DROP FUNCTION zutil.RandomChar
GO
CREATE FUNCTION zutil.RandomChar(@charFrom char(1), @charTo char(1), @rand float)
RETURNS char(1)
BEGIN
  DECLARE @cf smallint
  DECLARE @ct smallint
  SET @cf = ASCII(@charFrom)
  SET @ct = ASCII(@charTo)

  DECLARE @c smallint
  SET @c = (@ct - @cf) + 1
  SET @c = @cf + (@c * @rand)
  IF @c > @ct
    SET @c = @ct

  RETURN CHAR(@c)
END
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.StringListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.StringListToOrderedTable
GO
CREATE FUNCTION zutil.StringListToOrderedTable (@list nvarchar(MAX), @trim smallint=1)
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                string = CASE WHEN @trim = 1 THEN LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
                                             ELSE SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n) END
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.StringListToTable') IS NOT NULL
  DROP FUNCTION zutil.StringListToTable
GO
CREATE FUNCTION zutil.StringListToTable (@list nvarchar(max), @trim smallint = 1)
  RETURNS TABLE
  RETURN SELECT string = CASE WHEN @trim = 1 THEN LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
                                             ELSE SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n) END
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.TrimDatetime') IS NOT NULL
  DROP FUNCTION zutil.TrimDatetime
GO
CREATE FUNCTION zutil.TrimDatetime(@value datetime2(0), @minDateTime datetime2(0), @maxDateTime datetime2(0))
RETURNS datetime2(0)
BEGIN
  IF @value < @minDateTime
    RETURN @minDateTime
  IF @value > @maxDateTime
    RETURN @maxDateTime
  RETURN @value
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.UnicodeValueString') IS NOT NULL
  DROP FUNCTION zutil.UnicodeValueString
GO
CREATE FUNCTION zutil.UnicodeValueString(@s nvarchar(200))
RETURNS varchar(2000)
BEGIN
  DECLARE @vs varchar(2000)
  SET @vs = ''
  DECLARE @i int
  DECLARE @len int
  SET @i = 1
  SET @len = LEN(@s)
  WHILE @i <= @len
  BEGIN
    IF @vs != ''
      SET @vs = @vs + '+'
    SET @vs = @vs + 'NCHAR(' + CONVERT(varchar, UNICODE(SUBSTRING(@s, @i, 1))) + ')'
    SET @i = @i + 1
  END
  RETURN @vs
END
GO



---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zutil.ValidIntList') IS NOT NULL
  DROP FUNCTION zutil.ValidIntList
GO
CREATE FUNCTION zutil.ValidIntList(@list varchar(1000))
RETURNS smallint
BEGIN
  DECLARE @len smallint
  DECLARE @pos smallint
  DECLARE @c char(1)
  SET @pos = 1
  SET @len = LEN(@list)
  WHILE @pos <= @len
  BEGIN
    SET @c = SUBSTRING(@list, @pos, 1)
    SET @pos = @pos + 1
    IF ASCII(@c) IN (32, 44) OR ASCII(@c) BETWEEN 48 AND 57
      CONTINUE
    RETURN -1
  END
  RETURN 1
END
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF NOT EXISTS (select * from sys.database_principals where [name] = 'zzp_server')
  CREATE ROLE zzp_server
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


GRANT EXEC ON zutil.Age TO zzp_server
GO
GRANT SELECT ON zutil.BigintListToOrderedTable TO zzp_server
GO
GRANT SELECT ON zutil.BigintListToTable TO zzp_server
GO
GRANT EXEC ON zutil.BigintToNvarchar TO zzp_server
GO
GRANT EXEC ON zutil.DateDay TO zzp_server
GO
GRANT EXEC ON zutil.DateDiffString TO zzp_server
GO
GRANT EXEC ON zutil.DateHour TO zzp_server
GO
GRANT SELECT ON zutil.DateListToOrderedTable TO zzp_server
GO
GRANT SELECT ON zutil.DateListToTable TO zzp_server
GO
GRANT EXEC ON zutil.DateLocal TO zzp_server
GO
GRANT EXEC ON zutil.DateMonth TO zzp_server
GO
GRANT EXEC ON zutil.DateWeek TO zzp_server
GO
GRANT SELECT ON zutil.FloatListToOrderedTable TO zzp_server
GO
GRANT SELECT ON zutil.FloatListToTable TO zzp_server
GO
GRANT SELECT ON zutil.IntListToOrderedTable TO zzp_server
GO
GRANT SELECT ON zutil.IntListToTable TO zzp_server
GO
GRANT EXEC ON zutil.IntToNvarchar TO zzp_server
GO
GRANT EXEC ON zutil.MoneyToNvarchar TO zzp_server
GO
GRANT SELECT ON zutil.Numbers TO zzp_server
GO
GRANT SELECT ON zutil.StringListToOrderedTable TO zzp_server
GO
GRANT SELECT ON zutil.StringListToTable TO zzp_server
GO
GRANT EXEC ON zutil.TimeString TO zzp_server
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


GRANT SELECT ON zsystem.settings TO zzp_server
GO

GRANT SELECT ON zsystem.versions TO zzp_server
GO


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.eventTypes') IS NULL
BEGIN
  CREATE TABLE zsystem.eventTypes
  (
    eventTypeID    int            NOT NULL,
    eventTypeName  nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    --
    CONSTRAINT eventTypes_PK PRIMARY KEY CLUSTERED (eventTypeID)
  )
END
GRANT SELECT ON zsystem.eventTypes TO zzp_server
GO


---------------------------------------------------------------------------------------------------


if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000001)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000001, 'Execute procedure', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000011)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000011, 'Insert', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000012)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000012, 'Update', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000013)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000013, 'Delete', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000014)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000014, 'Copy', '')
go

if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000031)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000031, 'Update system setting', '')
go


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.EventTypes_Select') IS NOT NULL
  DROP PROCEDURE zsystem.EventTypes_Select
GO
CREATE PROCEDURE zsystem.EventTypes_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT eventTypeID, eventTypeName FROM zsystem.eventTypes ORDER BY eventTypeID
GO
GRANT EXEC ON zsystem.EventTypes_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.events') IS NULL
BEGIN
  CREATE TABLE zsystem.events
  (
    eventID      int            NOT NULL IDENTITY(1, 1),
    eventDate    datetime2(0)   NOT NULL DEFAULT GETUTCDATE(),
    eventTypeID  int            NOT NULL,
    duration     int            NULL,
    int_1        int            NULL,
    int_2        int            NULL,
    int_3        int            NULL,
    int_4        int            NULL,
    int_5        int            NULL,
    int_6        int            NULL,
    int_7        int            NULL,
    int_8        int            NULL,
    int_9        int            NULL,
    eventText    nvarchar(max)  NULL,
    --
    CONSTRAINT events_PK PRIMARY KEY CLUSTERED (eventID)
  )
END
GRANT SELECT ON zsystem.events TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.Events_Insert
GO
CREATE PROCEDURE zsystem.Events_Insert
  @eventTypeID  int,
  @duration     int,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @eventText    nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText)
       VALUES (@eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText)
GO
GRANT EXEC ON zsystem.Events_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Settings_Update') IS NOT NULL
  DROP PROCEDURE zsystem.Settings_Update
GO
CREATE PROCEDURE zsystem.Settings_Update
  @group   varchar(200), 
  @key     varchar(200), 
  @value   nvarchar(max),
  @userID  int = NULL
AS
  SET NOCOUNT ON

  BEGIN TRY
    DECLARE @allowUpdate bit
    SELECT @allowUpdate = allowUpdate FROM zsystem.settings WHERE [group] = @group AND [key] = @key
    IF @allowUpdate IS NULL
      RAISERROR ('Setting not found', 16, 1)
    IF @allowUpdate = 0
      RAISERROR ('Update not allowed', 16, 1)

    BEGIN TRANSACTION

    UPDATE zsystem.settings
       SET value = @value
     WHERE [group] = @group AND [key] = @key AND allowUpdate = 1 AND [value] != @value

    IF @@ROWCOUNT > 0
    BEGIN
      SET @value = @group + '.' + @key + ' = ' + @value
      EXEC zsystem.Events_Insert 2000000031, NULL, @userID, @eventText = @value
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


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Settings_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Settings_Select
GO
CREATE PROCEDURE zsystem.Settings_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [group], [key], [value], critical, allowUpdate, defaultValue, [description], orderID FROM zsystem.settings
  UNION ALL
  SELECT 'zsystem', 'DB_NAME', DB_NAME(), 0, 0, NULL, '', NULL
  ORDER BY 1, 8, 2
GO
GRANT EXEC ON zsystem.Settings_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Versions_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Select
GO
CREATE PROCEDURE zsystem.Versions_Select
  @developer  varchar(20) = 'CORE'
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT TOP 1 [version], versionDate, userName, coreVersion
    FROM zsystem.versions
   WHERE developer = @developer
   ORDER BY [version] DESC
GO
GRANT EXEC ON zsystem.Versions_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.texts') IS NULL
BEGIN
  CREATE TABLE zsystem.texts
  (
    textID  int                                          NOT NULL  IDENTITY(1, 1),
    [text]  nvarchar(450)  COLLATE Latin1_General_CI_AI  NOT NULL,
    --
    CONSTRAINT texts_PK PRIMARY KEY CLUSTERED (textID)
  )

  CREATE UNIQUE NONCLUSTERED INDEX texts_IX_Text ON zsystem.texts ([text])
END
GRANT SELECT ON zsystem.texts TO zzp_server
GO


---------------------------------------------------------------------------------------------------


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


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.dateCounters') IS NULL
BEGIN
  CREATE TABLE zsystem.dateCounters
  (
    eventTypeID  int   NOT NULL,
    counterDate  date  NOT NULL,
    [counter]    int   NOT NULL,
    --
    CONSTRAINT dateCounters_PK PRIMARY KEY CLUSTERED (eventTypeID, counterDate)
  )
END
GRANT SELECT ON zsystem.dateCounters TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.dateCountersEx') IS NOT NULL
  DROP VIEW zsystem.dateCountersEx
GO
CREATE VIEW zsystem.dateCountersEx
AS
  SELECT DC.eventTypeID, ET.eventTypeName, DC.counterDate, DC.[counter]
    FROM zsystem.dateCounters DC
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = DC.eventTypeID
GO
GRANT SELECT ON zsystem.dateCountersEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.DateCounters_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.DateCounters_Insert
GO
CREATE PROCEDURE zsystem.DateCounters_Insert
  @eventTypeID  int,
  @counter      int
AS
  SET NOCOUNT ON

  INSERT INTO zsystem.dateCounters (eventTypeID, counterDate, [counter])
       VALUES (@eventTypeID, GETUTCDATE(), @counter)
GO
GRANT EXEC ON zsystem.DateCounters_Insert TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.DateCounters_Update') IS NOT NULL
  DROP PROCEDURE zsystem.DateCounters_Update
GO
CREATE PROCEDURE zsystem.DateCounters_Update
  @eventTypeID  int,
  @counter      int
AS
  SET NOCOUNT ON

  UPDATE zsystem.dateCounters
     SET [counter] = [counter] + @counter
   WHERE eventTypeID = @eventTypeID AND counterDate = GETUTCDATE()
  IF @@ROWCOUNT = 0
  BEGIN
    INSERT INTO zsystem.dateCounters (eventTypeID, counterDate, [counter])
         VALUES (@eventTypeID, GETUTCDATE(), @counter)
  END
GO
GRANT EXEC ON zsystem.DateCounters_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF SCHEMA_ID('zsys') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zsys'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.schemas') IS NULL
BEGIN
  CREATE TABLE zsys.schemas
  (
    [schema_id]    int            NOT NULL,
    [schema_name]  nvarchar(128)  NOT NULL,
    --
    insert_date    datetime2(0)   NOT NULL,
    update_date    datetime2(0)   NULL,
    last_name      nvarchar(128)  NULL,
    --
    CONSTRAINT schemas_PK PRIMARY KEY CLUSTERED ([schema_id])
  )
END
GRANT SELECT ON zsys.schemas TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.objects') IS NULL
BEGIN
  CREATE TABLE zsys.objects
  (
    [schema_id]    int            NOT NULL,
    [object_id]    int            NOT NULL,
    [object_name]  nvarchar(128)  NOT NULL,
    object_type    char(2)        NOT NULL,
    create_date    datetime2(0)   NOT NULL,
    update_date    datetime2(0)   NULL,
    last_name      nvarchar(128)  NULL,
    --
    CONSTRAINT objects_PK PRIMARY KEY CLUSTERED ([object_id])
  )
END
GRANT SELECT ON zsys.objects TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.indexes') IS NULL
BEGIN
  CREATE TABLE zsys.indexes
  (
    [object_id]  int            NOT NULL,
    index_id     int            NOT NULL,
    index_name   nvarchar(128)  NOT NULL,
    index_type   tinyint        NOT NULL,
    --
    insert_date  datetime2(0)   NOT NULL,
    update_date  datetime2(0)   NULL,
    last_name    nvarchar(128)  NULL,
    --
    CONSTRAINT indexes_PK PRIMARY KEY CLUSTERED ([object_id], index_id)
  )
END
GRANT SELECT ON zsys.indexes TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.indexStats') IS NULL
BEGIN
  CREATE TABLE zsys.indexStats
  (
    [object_id]   int     NOT NULL,
    index_id      int     NOT NULL,
    [stats_date]  date    NOT NULL,
    --
    [rows]        bigint  NULL,
    --
    total_pages   bigint  NULL,
    used_pages    bigint  NULL,
    data_pages    bigint  NULL,
    --
    user_seeks    bigint  NULL,
    user_scans    bigint  NULL,
    user_lookups  bigint  NULL,
    user_updates  bigint  NULL,
    --
    CONSTRAINT indexStats_PK PRIMARY KEY CLUSTERED ([object_id], index_id, [stats_date])
  )

  CREATE NONCLUSTERED INDEX indexStats_IX_Date ON zsys.indexStats ([stats_date])
END
GRANT SELECT ON zsys.indexStats TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.procedureStats') IS NULL
BEGIN
  CREATE TABLE zsys.procedureStats
  (
    [object_id]   int     NOT NULL,
    [stats_date]  date    NOT NULL,
    --
    calls         int     NULL,
    rowsets       int     NULL,
    [rows]        bigint  NULL,
    duration      bigint  NULL,
    bytes_params  bigint  NULL,
    bytes_data    bigint  NULL,
    --
    CONSTRAINT procedureStats_PK PRIMARY KEY CLUSTERED ([object_id], [stats_date])
  )

  CREATE NONCLUSTERED INDEX procedureStats_IX_Date ON zsys.procedureStats ([stats_date])
END
GRANT SELECT ON zsys.procedureStats TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.objectsEx') IS NOT NULL
  DROP VIEW zsys.objectsEx
GO
CREATE VIEW zsys.objectsEx
AS
  SELECT O.[schema_id], S.[schema_name], O.[object_id], O.[object_name], O.object_type,
         O.create_date, O.update_date, O.last_name
    FROM zsys.objects O
      LEFT JOIN zsys.schemas S ON S.[schema_id] = O.[schema_id]
GO
GRANT SELECT ON zsys.objectsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.indexesEx') IS NOT NULL
  DROP VIEW zsys.indexesEx
GO
CREATE VIEW zsys.indexesEx
AS
  SELECT O.[schema_id], S.[schema_name], O.[object_id], [object_name], I.index_id, I.index_name, I.index_type,
         I.insert_date, I.update_date, I.last_name
    FROM zsys.indexes I
      LEFT JOIN zsys.objects O ON O.[object_id] = I.[object_id]
        LEFT JOIN zsys.schemas S ON S.[schema_id] = O.[schema_id]
GO
GRANT SELECT ON zsys.indexesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.indexStatsEx') IS NOT NULL
  DROP VIEW zsys.indexStatsEx
GO
CREATE VIEW zsys.indexStatsEx
AS
  SELECT O.[schema_id], S.[schema_name], X.[object_id], O.[object_name], X.index_id, I.index_name, X.[stats_date],
         X.[rows],
         X.total_pages, X.used_pages, X.data_pages,
         total_MB = CONVERT(float, (X.total_pages * 8) / 1024.0),
         used_MB = CONVERT(float, (X.used_pages * 8) / 1024.0),
         data_MB = CONVERT(float, (X.data_pages * 8) / 1024.0),
         user_data = CASE WHEN X2.user_seeks IS NULL OR X2.user_seeks > X.user_seeks THEN 'absolute' ELSE 'delta' END,
         user_seeks = CASE WHEN X2.user_seeks > X.user_seeks THEN X.user_seeks ELSE X.user_seeks - ISNULL(X2.user_seeks, 0) END,
         user_scans = CASE WHEN X2.user_scans > X.user_scans THEN X.user_scans ELSE X.user_scans - ISNULL(X2.user_scans, 0) END,
         user_lookups = CASE WHEN X2.user_lookups > X.user_lookups THEN X.user_lookups ELSE X.user_lookups - ISNULL(X2.user_lookups, 0) END,
         user_updates = CASE WHEN X2.user_updates > X.user_updates THEN X.user_updates ELSE X.user_updates - ISNULL(X2.user_updates, 0) END
    FROM zsys.indexStats X
      LEFT JOIN zsys.objects O ON O.[object_id] = X.[object_id]
        LEFT JOIN zsys.schemas S ON S.[schema_id] = O.[schema_id]
      LEFT JOIN zsys.indexes I ON I.[object_id] = X.[object_id] AND I.index_id = X.index_id
      LEFT JOIN zsys.indexStats X2 ON X2.[object_id] = X.[object_id] AND X2.index_id = X.index_id AND X2.[stats_date] = DATEADD(day, -1, X.[stats_date])
GO
GRANT SELECT ON zsys.indexStatsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.procedureStatsEx') IS NOT NULL
  DROP VIEW zsys.procedureStatsEx
GO
CREATE VIEW zsys.procedureStatsEx
AS
  SELECT O.[schema_id], S.[schema_name], X.[object_id], O.[object_name], X.[stats_date],
         X.calls, X.rowsets, X.[rows], X.duration, X.bytes_params, X.bytes_data
    FROM zsys.procedureStats X
      LEFT JOIN zsys.objects O ON O.[object_id] = X.[object_id]
        LEFT JOIN zsys.schemas S ON S.[schema_id] = O.[schema_id]
GO
GRANT SELECT ON zsys.procedureStatsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.Objects_Refresh') IS NOT NULL
  DROP PROCEDURE zsys.Objects_Refresh
GO
CREATE PROCEDURE zsys.Objects_Refresh
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  -- zsys.schemas
  UPDATE Z
     SET Z.last_name = Z.[schema_name], Z.[schema_name] = S.[name], Z.update_date = GETDATE()
    FROM zsys.schemas Z
      INNER JOIN sys.schemas S ON S.[schema_id] = Z.[schema_id]
   WHERE Z.[schema_name] != S.[name]

  INSERT INTO zsys.schemas ([schema_id], [schema_name], insert_date)
       SELECT S.[schema_id], S.[name], GETDATE()
         FROM sys.schemas S
           LEFT JOIN zsys.schemas Z ON Z.[schema_id] = S.[schema_id]
        WHERE S.principal_id = 1 AND Z.[schema_id] IS NULL
        ORDER BY S.[schema_id]

  -- zsys.objects
  UPDATE Z
     SET Z.last_name = Z.[object_name], Z.[object_name] = O.[name], Z.update_date = GETDATE()
    FROM zsys.objects Z
      INNER JOIN sys.objects O ON O.[object_id] = Z.[object_id]
   WHERE Z.[object_name] != O.[name]

  INSERT INTO zsys.objects ([schema_id], [object_id], [object_name], object_type, create_date)
       SELECT O.[schema_id], O.[object_id], O.[name], O.[type], O.create_date
         FROM sys.objects O
           LEFT JOIN zsys.objects Z ON Z.[object_id] = O.[object_id]
        WHERE O.is_ms_shipped != 1 AND O.[type] IN ('FN', 'P', 'TF', 'U', 'V') AND Z.[object_id] IS NULL
        ORDER BY O.[object_id]

  -- zsys.indexes
  UPDATE Z
     SET Z.last_name = Z.index_name, Z.index_name = ISNULL(I.[name], ''), Z.update_date = GETDATE()
    FROM zsys.indexes Z
      INNER JOIN sys.indexes I ON I.[object_id] = Z.[object_id] AND I.index_id = Z.index_id
   WHERE Z.index_name != ISNULL(I.[name], '')

  INSERT INTO zsys.indexes ([object_id], index_id, index_name, index_type, insert_date)
       SELECT O.[object_id], I.index_id, ISNULL(I.[name], ''), I.[type], GETDATE()
         FROM sys.indexes I
           INNER JOIN sys.objects O ON O.[object_id] = I.[object_id]
           LEFT JOIN zsys.indexes Z ON Z.[object_id] = I.[object_id] AND Z.index_id = I.index_id
        WHERE O.is_ms_shipped != 1 AND Z.[object_id] IS NULL
        ORDER BY I.[object_id], I.index_id
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.Objects_Info') IS NOT NULL
  DROP PROCEDURE zsys.Objects_Info
GO
CREATE PROCEDURE zsys.Objects_Info
  @objectName  nvarchar(256),
  @objectID    int = NULL,
  @rows        smallint = 10
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @objectID IS NULL
  BEGIN
    DECLARE @objectType char(2)
    SELECT @objectID = [object_id]
      FROM zsys.objectsEx
     WHERE [schema_name] + '.' + [object_name] = @objectName
    IF @@ROWCOUNT > 1
    BEGIN
      SELECT [schema_id], [schema_name], [object_id], [object_name], object_type, create_date,
             [statement] = 'EXEC zsys.Objects_Info NULL, ' + CONVERT(nvarchar, [object_id])
        FROM zsys.objectsEx
       WHERE [schema_name] + '.' + [object_name] = @objectName
       ORDER BY [object_id]
       RETURN
    END
  END

  IF @objectID IS NOT NULL
  BEGIN
    SELECT [schema_id], [schema_name], [object_id], [object_name], object_type, create_date, update_date, last_name
      FROM zsys.objectsEx
     WHERE [object_id] = @objectID

    SELECT @objectType = object_type FROM zsys.objects WHERE [object_id] = @objectID

    IF @objectType = 'U'
    BEGIN
      SELECT index_id, index_name, insert_date, update_date, last_name
        FROM zsys.indexes
       WHERE [object_id] = @objectID
       ORDER BY index_id

      SELECT TOP (@rows) [stats_date], [rows], total_pages, used_pages, data_pages
        FROM zsys.indexStats
       WHERE [object_id] = @objectID AND index_id = 1
       ORDER BY [stats_date] desc
    END
  END
  ELSE
    SELECT [message] = 'Object not found!'
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.IndexStats_Insert') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Insert
GO
CREATE PROCEDURE zsys.IndexStats_Insert
AS
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @statsDate date
  SET @statsDate = GETDATE()

  IF NOT EXISTS(SELECT * FROM zsys.indexStats WHERE [stats_date] = @statsDate)
  BEGIN
    INSERT INTO zsys.indexStats
                ([object_id], index_id, [stats_date], [rows], total_pages, used_pages, data_pages,
                 user_seeks, user_scans, user_lookups, user_updates)
         SELECT T.[object_id], I.index_id, @statsDate,
                SUM(CASE WHEN A.[type] = 1 THEN P.[rows] ELSE 0 END),  -- IN_ROW_DATA 
                SUM(A.total_pages), SUM(A.used_pages), SUM(A.data_pages),
                MAX(S.user_seeks), MAX(S.user_scans), MAX(S.user_lookups), MAX(S.user_updates)
           FROM sys.tables T
             INNER JOIN sys.indexes I ON I.[object_id] = T.[object_id]
               INNER JOIN sys.partitions P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
                 INNER JOIN sys.allocation_units A ON A.container_id = P.partition_id
               LEFT JOIN sys.dm_db_index_usage_stats S ON S.database_id = DB_ID() AND S.[object_id] = I.[object_id] AND S.index_id = I.index_id
          WHERE T.is_ms_shipped != 1
          GROUP BY T.[object_id], I.index_id
          ORDER BY T.[object_id], I.index_id

    EXEC zsystem.DateCounters_Insert 2000000304, 0
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.IndexStats_Mail') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Mail
GO
CREATE PROCEDURE zsys.IndexStats_Mail
  @statsDate  date = NULL,
  @rows       smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @recipients varchar(max)
  SET @recipients = zsystem.Settings_Value('zsys', 'Recipients-IndexStats')
  IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
  BEGIN
    IF @statsDate IS NULL SET @statsDate = GETDATE()

    -- SEND MAIL...
    DECLARE @subject nvarchar(255)
    SET @subject = HOST_NAME() + '.' + DB_NAME() + ': Index Statistics'

    DECLARE @body nvarchar(MAX)
    SET @body = 
      -- rows
        N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' rows</font></h3>'
      + N'<table border="1">'
      + N'<tr>'
      + N'<th align="left">table</th><th>rows</th><th>total_MB</th><th>used_MB</th><th>data_MB</th>'
      + N'</tr>'
      + ISNULL(CAST((
      SELECT TOP (@rows) td = [schema_name] + '.' + [object_name], '',
             [td/@align] = 'right', td = zutil.BigintToNvarchar(MAX([rows]), 1), '',
             [td/@align] = 'right', td = zutil.IntToNvarchar(SUM(total_MB), 1), '',
             [td/@align] = 'right', td = zutil.IntToNvarchar(SUM(used_MB), 1), '',
             [td/@align] = 'right', td = zutil.IntToNvarchar(SUM(data_MB), 1), ''
        FROM zsys.indexStatsEx
       WHERE [stats_date] = @statsDate
       GROUP BY [schema_name] + '.' + [object_name]
       ORDER BY MAX([rows]) DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

      -- total_MB
      + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' total_MB</font></h3>'
      + N'<table border="1">'
      + N'<tr>'
      + N'<th align="left">table</th><th>total_MB</th><th>used_MB</th><th>data_MB</th><th>rows</th>'
      + N'</tr>'
      + ISNULL(CAST((
      SELECT TOP (@rows) td = [schema_name] + '.' + [object_name], '',
             [td/@align] = 'right', td = zutil.IntToNvarchar(SUM(total_MB), 1), '',
             [td/@align] = 'right', td = zutil.IntToNvarchar(SUM(used_MB), 1), '',
             [td/@align] = 'right', td = zutil.IntToNvarchar(SUM(data_MB), 1), '',
             [td/@align] = 'right', td = zutil.BigintToNvarchar(MAX([rows]), 1), ''
        FROM zsys.indexStatsEx
       WHERE [stats_date] = @statsDate
       GROUP BY [schema_name] + '.' + [object_name]
       ORDER BY SUM(total_MB) DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

      -- user_seeks
      + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_seeks</font></h3>'
      + N'<table border="1">'
      + N'<tr>'
      + N'<th align="left">table</th><th align="left">index</th><th>count</th>'
      + N'</tr>'
      + ISNULL(CAST((
      SELECT TOP (@rows) td = [schema_name] + '.' + [object_name], '', td = index_name, '',
             [td/@align] = 'right', td = zutil.BigintToNvarchar(user_seeks, 1), ''
        FROM zsys.indexStatsEx
       WHERE [stats_date] = @statsDate
       ORDER BY user_seeks DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

      -- user_scans
      + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_scans</font></h3>'
      + N'<table border="1">'
      + N'<tr>'
      + N'<th align="left">table</th><th align="left">index</th><th>count</th>'
      + N'</tr>'
      + ISNULL(CAST((
      SELECT TOP (@rows) td = [schema_name] + '.' + [object_name], '', td = index_name, '',
             [td/@align] = 'right', td = zutil.BigintToNvarchar(user_scans, 1), ''
        FROM zsys.indexStatsEx
       WHERE [stats_date] = @statsDate
       ORDER BY user_scans DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

      -- user_lookups
      + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_lookups</font></h3>'
      + N'<table border="1">'
      + N'<tr>'
      + N'<th align="left">table</th><th align="left">index</th><th>count</th>'
      + N'</tr>'
      + ISNULL(CAST((
      SELECT TOP (@rows) td = [schema_name] + '.' + [object_name], '', td = index_name, '',
             [td/@align] = 'right', td = zutil.BigintToNvarchar(user_lookups, 1), ''
        FROM zsys.indexStatsEx
       WHERE [stats_date] = @statsDate
       ORDER BY user_lookups DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

      -- user_updates
      + N'<h3><font color=blue>Top ' + CONVERT(nvarchar, @rows) + ' user_updates</font></h3>'
      + N'<table border="1">'
      + N'<tr>'
      + N'<th align="left">table</th><th align="left">index</th><th>count</th>'
      + N'</tr>'
      + ISNULL(CAST((
      SELECT TOP (@rows) td = [schema_name] + '.' + [object_name], '', td = index_name, '',
             [td/@align] = 'right', td = zutil.BigintToNvarchar(user_updates, 1), ''
        FROM zsys.indexStatsEx
       WHERE [stats_date] = @statsDate
       ORDER BY user_updates DESC
             FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
      + N'</table>'

    EXEC zsystem.SendMail @recipients, @subject, @body, 'HTML'
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.IndexStats_Select') IS NOT NULL
  DROP PROCEDURE zsys.IndexStats_Select
GO
CREATE PROCEDURE zsys.IndexStats_Select
  @statsDate   date = NULL,
  @allIndexes  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @statsDate IS NULL
    SELECT TOP 1 @statsDate = [stats_date] FROM zsys.indexStats ORDER BY [stats_date] DESC

  DECLARE @previousDate date
  SELECT TOP 1 @previousDate = [stats_date]
    FROM zsys.indexStats
   WHERE [stats_date] < @statsDate
   ORDER BY [stats_date] DESC

  DECLARE @nextDate date
  SELECT TOP 1 @nextDate = [stats_date]
    FROM zsys.indexStats
   WHERE [stats_date] > @statsDate
   ORDER BY [stats_date]

  IF @allIndexes = 1
  BEGIN
    SELECT [schema_id], [schema_name], [object_id], [object_name], index_id, index_name,
           [rows], total_pages, used_pages, data_pages, total_MB, used_MB, data_MB,
           user_seeks = ISNULL(user_seeks, 0), user_scans = ISNULL(user_scans, 0),
           user_lookups = ISNULL(user_lookups, 0), user_updates = ISNULL(user_updates, 0)
      FROM zsys.indexStatsEx S
     WHERE [stats_date] = @statsDate
     ORDER BY total_MB DESC
  END
  ELSE
  BEGIN
    SELECT [schema_id], [schema_name], [object_id], [object_name], [rows] = MAX([rows]),
           total_pages = SUM(total_pages), used_pages = SUM(used_pages), data_pages = SUM(data_pages),
           total_MB = SUM(total_MB), used_MB = SUM(used_MB), data_MB = SUM(data_MB),
           user_seeks = SUM(ISNULL(user_seeks, 0)), user_scans = SUM(ISNULL(user_scans, 0)),
           user_lookups = SUM(ISNULL(user_lookups, 0)), user_updates = SUM(ISNULL(user_updates, 0))
      FROM zsys.indexStatsEx S
     WHERE [stats_date] = @statsDate
     GROUP BY [schema_id], [schema_name], [object_id], [object_name]
     ORDER BY total_MB DESC         
  END

  SELECT previous_date = @previousDate, [stats_date] = @statsDate, next_date = @nextDate
GO
GRANT EXEC ON zsys.IndexStats_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.ProcedureStats_DeleteDate') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_DeleteDate
GO
CREATE PROCEDURE zsys.ProcedureStats_DeleteDate
AS
  SET NOCOUNT ON

  DECLARE @stats_date date
  SET @stats_date = GETDATE()

  DELETE FROM zsys.procedureStats WHERE [stats_date] = @stats_date
  DELETE FROM zsystem.dateCounters WHERE eventTypeID = 2000000302 AND counterDate = @stats_date
GO
GRANT EXEC ON zsys.ProcedureStats_DeleteDate TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.ProcedureStats_Update') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_Update
GO
CREATE PROCEDURE zsys.ProcedureStats_Update
  @procedure_name  nvarchar(256),
  @calls           int,
  @rowsets         int,
  @rows            bigint,
  @duration        bigint,
  @bytes_params    bigint,
  @bytes_data      bigint
AS
  SET NOCOUNT ON

  DECLARE @stats_date date
  SET @stats_date = GETDATE()

  DECLARE @object_id int
  SET @object_id = OBJECT_ID(@procedure_name)
  IF @object_id IS NULL SET @object_id = -1

  UPDATE zsys.procedureStats
     SET calls = calls + ISNULL(@calls, 0), rowsets = rowsets + ISNULL(@rowsets, 0),
         [rows] = [rows] + ISNULL(@rows, 0), duration = duration + ISNULL(@duration, 0),
         bytes_params = bytes_params + ISNULL(@bytes_params, 0),
         bytes_data = bytes_data + ISNULL(@bytes_data, 0)
   WHERE [object_id] = @object_id AND [stats_date] = @stats_date
  IF @@ROWCOUNT = 0
  BEGIN
    INSERT INTO zsys.procedureStats
                ([object_id], [stats_date], calls, rowsets, [rows], duration, bytes_params, bytes_data)
         VALUES (@object_id, @stats_date, ISNULL(@calls, 0), ISNULL(@rowsets, 0), ISNULL(@rows, 0),
                 ISNULL(@duration, 0), ISNULL(@bytes_params, 0), ISNULL(@bytes_data, 0))
  END
GO
GRANT EXEC ON zsys.ProcedureStats_Update TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsys.ProcedureStats_Select') IS NOT NULL
  DROP PROCEDURE zsys.ProcedureStats_Select
GO
CREATE PROCEDURE zsys.ProcedureStats_Select
  @statsDate  date = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @statsDate IS NULL
    SELECT TOP 1 @statsDate = [stats_date] FROM zsys.procedureStats ORDER BY [stats_date] DESC

  DECLARE @previousDate date
  SELECT TOP 1 @previousDate = [stats_date]
    FROM zsys.procedureStats
   WHERE [stats_date] < @statsDate
   ORDER BY [stats_date] DESC

  DECLARE @nextDate date
  SELECT TOP 1 @nextDate = [stats_date]
    FROM zsys.procedureStats
   WHERE [stats_date] > @statsDate
   ORDER BY [stats_date]

  SELECT [schema_id], [schema_name], [object_id], [object_name],
         calls, rowsets, [rows], duration, bytes_params, bytes_data
    FROM zsys.procedureStatsEx
   WHERE [stats_date] = @statsDate
   ORDER BY calls DESC

  SELECT previous_date = @previousDate, [stats_date] = @statsDate, next_date = @nextDate
GO
GRANT EXEC ON zsys.ProcedureStats_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.schemas') IS NULL
BEGIN
  CREATE TABLE zsystem.schemas
  (
    schemaID       int            NOT NULL,
    schemaName     nvarchar(128)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    webPage        varchar(200)   NULL,
    --
    CONSTRAINT schemas_PK PRIMARY KEY CLUSTERED (schemaID)
  )

  CREATE UNIQUE NONCLUSTERED INDEX schemas_UQ_Name ON zsystem.schemas (schemaName)
END
GRANT SELECT ON zsystem.schemas TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.tables') IS NULL
BEGIN
  CREATE TABLE zsystem.tables
  (
    schemaID          int            NOT NULL,
    tableID           int            NOT NULL,
    tableName         nvarchar(128)  NOT NULL,
    [description]     nvarchar(max)  NOT NULL,
    --
    tableType         varchar(20)    NULL,
    logIdentity       tinyint        NULL,  -- 1:Int, 2:Bigint
    copyStatic        tinyint        NULL,  -- 1:BSD, 2:Regular
    --
    keyID             nvarchar(128)  NULL,
    keyID2            nvarchar(128)  NULL,
    keyID3            nvarchar(128)  NULL,
    sequence          int            NULL,
    keyName           nvarchar(128)  NULL,
    disableEdit       bit            NULL,
    disableDelete     bit            NULL,
    textTableID       int            NULL,
    textKeyID         nvarchar(128)  NULL,
    textTableID2      int            NULL,
    textKeyID2        nvarchar(128)  NULL,
    textTableID3      int            NULL,
    textKeyID3        nvarchar(128)  NULL,
    obsolete          bit            NULL,
    link              nvarchar(256)  NULL,
    keyDate           nvarchar(128)  NULL,
    disabledDatasets  bit            NULL,
    --
    CONSTRAINT tables_PK PRIMARY KEY CLUSTERED (tableID)
  )

  CREATE NONCLUSTERED INDEX tables_IX_Schema ON zsystem.tables (schemaID)
  CREATE UNIQUE NONCLUSTERED INDEX tables_UQ_Name ON zsystem.tables (schemaID, tableName)
END
GRANT SELECT ON zsystem.tables TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.columns') IS NULL
BEGIN
  CREATE TABLE zsystem.columns
  (
    tableID      int            NOT NULL,
    columnName   nvarchar(128)  NOT NULL,
    --
    [readonly]   bit            NULL,
    --
    lookupTable  nvarchar(128)  NULL,
    lookupID     nvarchar(128)  NULL,
    lookupName   nvarchar(128)  NULL,
    lookupWhere  nvarchar(128)  NULL,
    --
    html         bit            NULL,
    --
    CONSTRAINT columns_PK PRIMARY KEY CLUSTERED (tableID, columnName)
  )
END
GRANT SELECT ON zsystem.columns TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.procedures') IS NULL
BEGIN
  CREATE TABLE zsystem.procedures
  (
    schemaID       int            NOT NULL,
    procedureID    int            NOT NULL,
    procedureName  nvarchar(128)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    obsolete       bit            NULL,
    --
    CONSTRAINT procedures_PK PRIMARY KEY CLUSTERED (procedureID)
  )

  CREATE NONCLUSTERED INDEX procedures_IX_Schema ON zsystem.procedures (schemaID)
  CREATE UNIQUE NONCLUSTERED INDEX procedures_UQ_Name ON zsystem.procedures (schemaID, procedureName)
END
GRANT SELECT ON zsystem.procedures TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.tablesEx') IS NOT NULL
  DROP VIEW zsystem.tablesEx
GO
CREATE VIEW zsystem.tablesEx
AS
  SELECT fullName = S.schemaName + '.' + T.tableName,
         T.schemaID, S.schemaName, T.tableID, T.tableName, T.[description],
         T.tableType, T.logIdentity, T.copyStatic,
         T.keyID, T.keyID2, T.keyID3, T.sequence, T.keyName, T.keyDate,
         T.textTableID, T.textKeyID, T.textTableID2, T.textKeyID2, T.textTableID3, T.textKeyID3,
         T.link, T.disableEdit, T.disableDelete, T.disabledDatasets, T.obsolete
    FROM zsystem.tables T
      LEFT JOIN zsystem.schemas S ON S.schemaID = T.schemaID
GO
GRANT SELECT ON zsystem.tablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.columnsEx') IS NOT NULL
  DROP VIEW zsystem.columnsEx
GO
CREATE VIEW zsystem.columnsEx
AS
  SELECT T.schemaID, S.schemaName, C.tableID, T.tableName,
         C.columnName, C.[readonly], C.lookupTable, C.lookupID, C.lookupName, C.lookupWhere, C.html
    FROM zsystem.columns C
      LEFT JOIN zsystem.tables T ON T.tableID = C.tableID
        LEFT JOIN zsystem.schemas S ON S.schemaID = T.schemaID
GO
GRANT SELECT ON zsystem.columnsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.proceduresEx') IS NOT NULL
  DROP VIEW zsystem.proceduresEx
GO
CREATE VIEW zsystem.proceduresEx
AS
  SELECT fullName = S.schemaName + '.' + P.procedureName,
         P.schemaID, S.schemaName, P.procedureID, P.procedureName, P.[description], P.obsolete
    FROM zsystem.procedures P
      LEFT JOIN zsystem.schemas S ON S.schemaID = P.schemaID
GO
GRANT SELECT ON zsystem.proceduresEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Schemas_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Schemas_Select
GO
CREATE PROCEDURE zsystem.Schemas_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM zsystem.schemas
GO
GRANT EXEC ON zsystem.Schemas_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Schemas_Name') IS NOT NULL
  DROP FUNCTION zsystem.Schemas_Name
GO
CREATE FUNCTION zsystem.Schemas_Name(@schemaID int)
RETURNS nvarchar(128)
BEGIN
  DECLARE @schemaName nvarchar(128)
  SELECT @schemaName = schemaName FROM zsystem.schemas WHERE schemaID = @schemaID
  RETURN @schemaName
END
GO
GRANT EXEC ON zsystem.Schemas_Name TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Tables_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Tables_Select
GO
CREATE PROCEDURE zsystem.Tables_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM zsystem.tables
GO
GRANT EXEC ON zsystem.Tables_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Tables_ID') IS NOT NULL
  DROP FUNCTION zsystem.Tables_ID
GO
CREATE FUNCTION zsystem.Tables_ID(@schemaName nvarchar(128), @tableName nvarchar(128))
RETURNS int
BEGIN
  DECLARE @schemaID int
  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  DECLARE @tableID int
  SELECT @tableID = tableID FROM zsystem.tables WHERE schemaID = @schemaID AND tableName = @tableName
  RETURN @tableID
END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Tables_Name') IS NOT NULL
  DROP FUNCTION zsystem.Tables_Name
GO
CREATE FUNCTION zsystem.Tables_Name(@tableID int)
RETURNS nvarchar(257)
BEGIN
  DECLARE @fullName nvarchar(257)
  SELECT @fullName = S.schemaName + '.' + T.tableName
    FROM zsystem.tables T
      INNER JOIN zsystem.schemas S ON S.schemaID = T.schemaID
   WHERE T.tableID = @tableID
  RETURN @fullName
END
GO
GRANT EXEC ON zsystem.Tables_Name TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Columns_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Columns_Select
GO
CREATE PROCEDURE zsystem.Columns_Select
  @schemaName  nvarchar(128),
  @tableName   nvarchar(128),
  @tableID     int = NULL
AS
  SET NOCOUNT ON

  IF @tableID IS NULL SET @tableID = zsystem.Tables_ID(@schemaName, @tableName)

  SELECT columnName = c.[name], c.system_type_id, c.max_length, c.is_nullable,
         c2.[readonly], c2.lookupTable, c2.lookupID, c2.lookupName, c2.lookupWhere, c2.html
    FROM sys.columns c
      LEFT JOIN zsystem.columns c2 ON c2.tableID = @tableID AND c2.columnName = c.[name]
   WHERE c.[object_id] = OBJECT_ID(@schemaName + '.' + @tableName)
   ORDER BY c.column_id
GO
GRANT EXEC ON zsystem.Columns_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Procedures_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Procedures_Select
GO
CREATE PROCEDURE zsystem.Procedures_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM zsystem.procedures
GO
GRANT EXEC ON zsystem.Procedures_Select TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000001)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000001, 'zsystem', 'CORE - Zhared system objects, supporting f.e. database version control, meta data about objects, settings, identities, events, jobs and so on.', 'http://core/wiki/DB_zsystem')
GO
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000005)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000005, 'zsys', 'CORE - Objects using MSSQL system views, supporting f.e. index statistics (stored using MSSQL id''s).', 'http://core/wiki/DB_zsys')
GO
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000007)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000007, 'zutil', 'CORE - Utility functions', 'http://core/wiki/DB_zutil')
GO
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000008)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000008, 'zdm', 'CORE - Dynamic Management, procedures to help with SQL Server management (mostly for DBA''s).', 'http://core/wiki/DB_zdm')
GO


IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100001)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100001, 'settings', 'Core - Zhared settings stored in DB')
GO
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100002)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100002, 'versions', 'Core - List of DB updates (versions) applied on the DB')
GO
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100003)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100003, 'schemas', 'Core - List of database schemas', 2)
GO
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100004)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100004, 'tables', 'Core - List of database tables', 2)
GO
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100005)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100005, 'columns', 'Core - List of database columns that need special handling', 2)
GO
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100006)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100006, 'procedures', 'Core - List of database procedures that need special handling', 2)
GO

IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100013)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100013, 'eventTypes', 'Core - Events types', 2)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.identities') IS NULL
BEGIN
  CREATE TABLE zsystem.identities
  (
    tableID           int     NOT NULL,
    identityDate      date    NOT NULL,
    identityInt       int     NULL,
    identityBigInt    bigint  NULL,
    --
    CONSTRAINT identities_PK PRIMARY KEY CLUSTERED (tableID, identityDate)
  )
END
GRANT SELECT ON zsystem.identities TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.identitiesEx') IS NOT NULL
  DROP VIEW zsystem.identitiesEx
GO
CREATE VIEW zsystem.identitiesEx
AS
  SELECT s.schemaName, t.tableName, i.tableID, i.identityDate, i.identityInt, i.identityBigInt
    FROM zsystem.identities i
      LEFT JOIN zsystem.tables t ON t.tableID = i.tableID
        LEFT JOIN zsystem.schemas s ON s.schemaID = t.schemaID
GO
GRANT SELECT ON zsystem.identitiesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_Int') IS NOT NULL
  DROP FUNCTION zsystem.Identities_Int
GO
CREATE FUNCTION zsystem.Identities_Int(@tableID int, @identityDate date, @days smallint, @seek smallint)
  RETURNS int
BEGIN
  IF @identityDate IS NULL SET @identityDate = GETUTCDATE()
  IF @days IS NOT NULL SET @identityDate = DATEADD(day, @days, @identityDate)

  DECLARE @identityInt int
  SET @identityInt = -1

  IF @seek < 0
  BEGIN
    SELECT TOP 1 @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate <= @identityDate
     ORDER BY identityDate DESC
  END
  ELSE IF @seek > 0
  BEGIN
    SELECT TOP 1 @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate >= @identityDate
     ORDER BY identityDate
  END
  ELSE
  BEGIN
    SELECT @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate = @identityDate
  END

  RETURN @identityInt
END
GO
GRANT EXEC ON zsystem.Identities_Int TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_BigInt') IS NOT NULL
  DROP FUNCTION zsystem.Identities_BigInt
GO
CREATE FUNCTION zsystem.Identities_BigInt(@tableID int, @identityDate date, @days smallint, @seek smallint)
  RETURNS bigint
BEGIN
  IF @identityDate IS NULL SET @identityDate = GETUTCDATE()
  IF @days IS NOT NULL SET @identityDate = DATEADD(day, @days, @identityDate)

  DECLARE @identityBigInt bigint
  SET @identityBigInt = -1

  IF @seek < 0
  BEGIN
    SELECT TOP 1 @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate <= @identityDate
     ORDER BY identityDate DESC
  END
  ELSE IF @seek > 0
  BEGIN
    SELECT TOP 1 @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate >= @identityDate
     ORDER BY identityDate
  END
  ELSE
  BEGIN
    SELECT @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate = @identityDate
  END

  RETURN @identityBigInt
END
GO
GRANT EXEC ON zsystem.Identities_BigInt TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Identities_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.Identities_Insert
GO
CREATE PROCEDURE zsystem.Identities_Insert
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @identityDate date
  SET @identityDate = GETUTCDATE() + (5.0 / 1440.0)

  DECLARE @maxi int
  DECLARE @maxb bigint

  DECLARE @tableID int
  DECLARE @tableName nvarchar(256)
  DECLARE @keyID nvarchar(128)
  DECLARE @keyDate nvarchar(128)
  DECLARE @logIdentity tinyint
  DECLARE @stmt nvarchar(4000)
  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT T.tableID, S.schemaName + '.' + T.tableName, T.keyID, T.keyDate, T.logIdentity
          FROM zsystem.tables T
            INNER JOIN zsystem.schemas S ON S.schemaID = T.schemaID
         WHERE T.logIdentity IN (1, 2) AND ISNULL(T.keyID, '') != '' AND ISNULL(T.obsolete, 0) = 0
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF OBJECT_ID(@tableName) IS NOT NULL
    BEGIN
      IF @logIdentity = 1
      BEGIN
        SET @maxi = NULL
        SET @stmt = 'SELECT TOP 1 @p_maxi = ' + @keyID + ' FROM ' + @tableName
        IF @keyDate IS NOT NULL
          SET @stmt = @stmt + ' WHERE ' + @keyDate + ' < @p_date'
        SET @stmt = @stmt + ' ORDER BY ' + @keyID + ' DESC'
        EXEC sp_executesql @stmt, N'@p_maxi int OUTPUT, @p_date datetime2(0)', @maxi OUTPUT, @identityDate
        IF @maxi IS NOT NULL
        BEGIN
          IF @keyDate IS NOT NULL
            SET @maxi = @maxi + 1
          INSERT INTO zsystem.identities (tableID, identityDate, identityInt)
               VALUES (@tableID, @identityDate, @maxi)
        END
      END
      ELSE
      BEGIN
        SET @maxb = NULL
        SET @stmt = 'SELECT TOP 1 @p_maxb = ' + @keyID + ' FROM ' + @tableName
        IF @keyDate IS NOT NULL
          SET @stmt = @stmt + ' WHERE ' + @keyDate + ' < @p_date'
        SET @stmt = @stmt + ' ORDER BY ' + @keyID + ' DESC'
        EXEC sp_executesql @stmt, N'@p_maxb bigint OUTPUT, @p_date datetime2(0)', @maxb OUTPUT, @identityDate
        IF @maxb IS NOT NULL
        BEGIN
          IF @keyDate IS NOT NULL
            SET @maxb = @maxb + 1
          INSERT INTO zsystem.identities (tableID, identityDate, identityBigInt)
               VALUES (@tableID, @identityDate, @maxb)
        END
      END
    END

    FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------


IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100011)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100011, 'identities', 'Core - Identity statistics (used to support searching without the need for datetime indexes)')
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.jobs') IS NULL
BEGIN
  CREATE TABLE zsystem.jobs
  (
    jobID          int            NOT NULL,
    jobName        nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    [sql]          nvarchar(max)  NOT NULL,
    --
    [hour]         tinyint        NULL,  -- 0, 1, 2, ..., 22, 23
    [minute]       tinyint        NULL,  -- 0, 10, 20, 30, 40, 50
    [day]          tinyint        NULL,  -- 1-7 (day of week, where 1 is sunday and 6 is saturday)
    [week]         tinyint        NULL,  -- 1-4 (week of month)
    --
    [group]        nvarchar(100)  NULL,  -- Typically SCHEDULE or DOWNTIME
    part           smallint       NULL,  -- NULL for SCHEDULE, set for DOWNTIME
    --
    orderID        smallint       NULL,
    --
    [disabled]     bit            NULL,
    --
    logStarted     bit            NOT NULL  DEFAULT 1,
    logCompleted   bit            NOT NULL  DEFAULT 1,
    --
    CONSTRAINT jobs_PK PRIMARY KEY CLUSTERED (jobID),
    --
    CONSTRAINT jobs_CK_Hour CHECK ([hour] >= 0 AND [hour] <= 23),
    CONSTRAINT jobs_CK_Minute CHECK ([minute] >= 0 AND [minute] <= 50 AND [minute] % 10 = 0),
    CONSTRAINT jobs_CK_Day CHECK ([day] >= 1 AND [day] <= 7),
    CONSTRAINT jobs_CK_Week CHECK ([week] >= 1 AND [week] <= 4),
  )
END
GRANT SELECT ON zsystem.jobs TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.jobsEx') IS NOT NULL
  DROP VIEW zsystem.jobsEx
GO
CREATE VIEW zsystem.jobsEx
AS
  SELECT jobID, jobName, [description], [sql], [hour], [minute],
         [time] = CASE WHEN part IS NOT NULL THEN NULL
                       WHEN [week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] IS NULL THEN 'XX:X0'
                       WHEN [week] IS NULL AND [day] IS NULL AND [hour] IS NULL THEN 'XX:' + RIGHT('0' + CONVERT(varchar, [minute]), 2)
                       ELSE RIGHT('0' + CONVERT(varchar, [hour]), 2) + ':' + RIGHT('0' + CONVERT(varchar, [minute]), 2) END,
         [day], dayText = CASE [day] WHEN 1 THEN 'Sunday' WHEN 2 THEN 'Monday' WHEN 3 THEN 'Tuesday'
                                     WHEN 4 THEN 'Wednesday' WHEN 5 THEN 'Thursday' WHEN 6 THEN 'Friday'
                                     WHEN 7 THEN 'Saturday' END,
         [week], weekText = CASE [week] WHEN 1 THEN 'First (days 1-7 of month)'
                                        WHEN 2 THEN 'Second (days 8-14 of month)'
                                        WHEN 3 THEN 'Third (days 15-21 of month)'
                                        WHEN 4 THEN 'Fourth (days 22-28 of month)' END,
         [group], part, logStarted, logCompleted, orderID, [disabled]
    FROM zsystem.jobs
GO
GRANT SELECT ON zsystem.jobsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Jobs_Exec') IS NOT NULL
  DROP PROCEDURE zsystem.Jobs_Exec
GO
CREATE PROCEDURE zsystem.Jobs_Exec
  @group  nvarchar(100) = 'SCHEDULE',
  @part   smallint = NULL
AS
  -- This proc must be called every 10 minutes in a SQL Agent job, no more and no less
  -- @part...
  --   NULL: Use hour:minute (typically used for group SCHEDULE)
  --      0: Execute all parts (typically used for group DOWNTIME)
  --     >0: Execute only that part (typically used for group DOWNTIME)
  -- When @part is NULL...
  --   If week/day/hour/minute is NULL job executes every time the proc is called (every 10 minutes)
  --   If week/day/hour is NULL job executes every hour on the minutes set
  SET NOCOUNT ON

  DECLARE @now datetime, @day tinyint
  SELECT @now = GETUTCDATE(), @day = DATEPART(weekday, @now)

  DECLARE @week tinyint, @r real
  SET @r = DAY(@now) / 7.0
  IF @r <= 1.0 SET @week = 1
  ELSE IF @r <= 2.0 SET @week = 2
  ELSE IF @r <= 3.0 SET @week = 3
  ELSE IF @r <= 4.0 SET @week = 4

  DECLARE @cursor CURSOR

  IF @part IS NULL
  BEGIN
    DECLARE @hour tinyint, @minute tinyint
    SELECT @hour = DATEPART(hour, @now), @minute = (DATEPART(minute, @now) / 10) * 10

    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND ISNULL([disabled], 0) = 0 AND
                 (([week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] IS NULL)
                  OR
                  ([week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] = @minute)
                  OR
                  ([hour] = @hour AND [minute] = @minute AND ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)))
           ORDER BY orderID
  END
  ELSE IF @part = 0
  BEGIN
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND ISNULL([disabled], 0) = 0 AND
                 ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)
           ORDER BY part, orderID
  END
  ELSE
  BEGIN
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND part = @part AND ISNULL([disabled], 0) = 0 AND
                 ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)
           ORDER BY part, orderID
  END

  DECLARE @jobID int, @jobName nvarchar(200), @sql nvarchar(max), @logStarted bit, @logCompleted bit
  DECLARE @duration int, @startTime datetime

  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  WHILE @@FETCH_STATUS = 0
  BEGIN
    -- Job started event
    SET @startTime = GETUTCDATE()
    IF @logStarted = 1
      INSERT INTO zsystem.events (eventTypeID, int_1) VALUES (2000000021, @jobID)

    -- Job execute 
    BEGIN TRY
      EXEC sp_executesql @sql
    END TRY
    BEGIN CATCH
      -- Job ERROR event
      SET @duration = DATEDIFF(second, @startTime, GETUTCDATE())
      INSERT INTO zsystem.events (eventTypeID, duration, int_1, eventText) VALUES (2000000024, @duration, @jobID, ERROR_MESSAGE())

      DECLARE @objectName nvarchar(256)
      SET @objectName = 'zsystem.Jobs_Exec: ' + @jobName
      EXEC zsystem.CatchError @objectName
    END CATCH

    -- Job completed event
    SET @duration = DATEDIFF(second, @startTime, GETUTCDATE())
    IF @logCompleted = 1
      INSERT INTO zsystem.events (eventTypeID, duration, int_1) VALUES (2000000023, @duration, @jobID)

    FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO


---------------------------------------------------------------------------------------------------


if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000021)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000021, 'Job started', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000022)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000022, 'Job info', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000023)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000023, 'Job completed', '')
go
if not exists(select * from zsystem.eventTypes where eventTypeID = 2000000024)
  insert into zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       values (2000000024, 'Job ERROR', '')
go


---------------------------------------------------------------------------------------------------


if not exists(select * from zsystem.jobs where jobID = 2000000001)
  insert into zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], orderID)
       values (2000000001, 'CORE - zsystem - Insert identity statistics', '', 'EXEC zsystem.Identities_Insert', 'SCHEDULE', 0, 0, -10)
go
if not exists(select * from zsystem.jobs where jobID = 2000000011)
  insert into zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], orderID)
       values (2000000011, 'CORE - zsys - Refresh objects and insert index stats', '', 'EXEC zsys.Objects_Refresh;EXEC zsys.IndexStats_Insert', 'SCHEDULE', 0, 0, -9)
go
if not exists(select * from zsystem.jobs where jobID = 2000000012)
  insert into zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], orderID, [disabled])
       values (2000000012, 'CORE - zsys - Index stats DB mail', '', 'EXEC zsys.IndexStats_Mail', 'SCHEDULE', 0, 0, -8, 1)
go
if not exists(select * from zsystem.jobs where jobID = 2000000031)
  insert into zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], [day], orderID, [disabled])
       values (2000000031, 'CORE - zsystem - interval overflow alert', '', 'EXEC zsystem.Intervals_OverflowAlert', 'SCHEDULE', 7, 0, 4, -10, 1)
go


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.eventsEx') IS NOT NULL
  DROP VIEW zsystem.eventsEx
GO
CREATE VIEW zsystem.eventsEx
AS
  SELECT E.eventID, E.eventDate, E.eventTypeID, ET.eventTypeName, E.duration,
         E.int_1, E.int_2, E.int_3, E.int_4, E.int_5, E.int_6, E.int_7, E.int_8, E.int_9, E.eventText,
         procedureName = CASE WHEN E.eventTypeID = 2000000001 THEN S.schemaName + '.' + P.procedureName ELSE NULL END,
         jobName = CASE WHEN E.eventTypeID IN (2000000021, 2000000022, 2000000023, 2000000024) THEN J.jobName ELSE NULL END
    FROM zsystem.events E
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = E.eventTypeID
      LEFT JOIN zsystem.procedures P ON P.procedureID = E.int_1
        LEFT JOIN zsystem.schemas S ON S.schemaID = P.schemaID
      LEFT JOIN zsystem.jobs J ON J.jobID = E.int_1
GO
GRANT SELECT ON zsystem.eventsEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ExecProc') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ExecProc
GO
CREATE PROCEDURE zsystem.Events_ExecProc
  @schemaName     nvarchar(128),
  @procedureName  nvarchar(128),
  @duration       int,
  @int_2          int = NULL,
  @int_3          int = NULL,
  @int_4          int = NULL,
  @int_5          int = NULL,
  @int_6          int = NULL,
  @int_7          int = NULL,
  @int_8          int = NULL,
  @int_9          int = NULL,
  @eventText      nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  DECLARE @schemaID int
  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  DECLARE @procedureID int
  SELECT @procedureID = procedureID
    FROM zsystem.procedures
   WHERE schemaID = @schemaID AND procedureName = @procedureName
  IF @procedureID IS NULL
  BEGIN
    RAISERROR ('Procedure not found', 16, 1)
    RETURN -1
  END

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText)
       VALUES (2000000001, @duration, @procedureID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Events_ExecJob') IS NOT NULL
  DROP PROCEDURE zsystem.Events_ExecJob
GO
CREATE PROCEDURE zsystem.Events_ExecJob
  @jobID      int,
  @int_2      int = NULL,
  @int_3      int = NULL,
  @int_4      int = NULL,
  @int_5      int = NULL,
  @int_6      int = NULL,
  @int_7      int = NULL,
  @int_8      int = NULL,
  @int_9      int = NULL,
  @eventText  nvarchar(max) = NULL
AS
  SET NOCOUNT ON

  INSERT INTO zsystem.events
              (eventTypeID, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText)
       VALUES (2000000022, @jobID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText)
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.intervals') IS NULL
BEGIN
  CREATE TABLE zsystem.intervals
  (
    intervalID     int            NOT NULL,
    intervalName   nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    minID          bigint         NOT NULL,
    maxID          bigint         NOT NULL,
    currentID      bigint         NOT NULL,
    tableID        int            NULL,
    --
    CONSTRAINT intervals_PK PRIMARY KEY CLUSTERED (intervalID)
  )
END
GRANT SELECT ON zsystem.intervals TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Intervals_NextID') IS NOT NULL
  DROP PROCEDURE zsystem.Intervals_NextID
GO
CREATE PROCEDURE zsystem.Intervals_NextID
  @intervalID  int,
  @nextID      bigint OUTPUT
AS
  SET NOCOUNT ON

  UPDATE zsystem.intervals SET @nextID = currentID = currentID + 1 WHERE intervalID = @intervalID
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.Intervals_OverflowAlert') IS NOT NULL
  DROP PROCEDURE zsystem.Intervals_OverflowAlert
GO
CREATE PROCEDURE zsystem.Intervals_OverflowAlert
  @alertLevel  real = 0.05 -- default alert level (we alert when less than 5% of the ids are left)
AS
  SET NOCOUNT ON

  IF EXISTS (SELECT * FROM zsystem.intervals WHERE (maxID - currentID) / CONVERT(real, (maxID - minID)) <= @alertLevel)
  BEGIN
    DECLARE @recipients varchar(max)
    SET @recipients = zsystem.Settings_Value('zsystem', 'Recipients-Operations-Software')

    IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
    BEGIN
      DECLARE @intervalID int
      DECLARE @intervalName nvarchar(400)
      DECLARE @maxID int
      DECLARE @currentID int
      DECLARE @body nvarchar(max)

      DECLARE @cursor CURSOR
      SET @cursor = CURSOR LOCAL STATIC READ_ONLY
      FOR SELECT intervalID, intervalName, maxID, currentID
            FROM zsystem.intervals
           WHERE (maxID - currentID) / CONVERT(real, (maxID - minID)) <= @alertLevel
      OPEN @cursor
      FETCH NEXT FROM @cursor INTO @intervalID, @intervalName, @maxID, @currentID
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @body = N'ID''s for the interval: <b>' + @intervalName  + N' (intervalID: '
                  + CONVERT(nvarchar, @intervalID) + N')</b> is getting low.<br>'
                  + N'The current counter is now at ' + CONVERT(nvarchar, @currentID) + N' and the maximum it can '
                  + N'get up to is ' + CONVERT(nvarchar, @maxID) + N', so we will run out after '
                  + CONVERT(nvarchar, (@maxID-@currentID)) + N' ID''s.<br><br>'
                  + N'We need to find another range for it very soon, so please don''t just ignore this mail!<br><br>'
                  + N'That was all <br>  Your friendly automatic e-mail sender'

        EXEC zsystem.SendMail @recipients, 'INTERVAL OVERFLOW ALERT!', @body, 'HTML'
        FETCH NEXT FROM @cursor INTO @intervalID, @intervalName, @maxID, @currentID
      END
      CLOSE @cursor
      DEALLOCATE @cursor
    END
  END
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupTables') IS NULL
BEGIN
  CREATE TABLE zsystem.lookupTables
  (
    lookupTableID    int            NOT NULL,
    lookupTableName  nvarchar(200)  NOT NULL,
    [description]    nvarchar(max)  NULL,
    --
    schemaID         int            NULL,  -- link lookup table to a schema, just info
    tableID          int            NULL,  -- link lookup table to a table, just info
    --
    CONSTRAINT lookupTables_PK PRIMARY KEY CLUSTERED (lookupTableID)
  )
END
GRANT SELECT ON zsystem.lookupTables TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupValues') IS NULL
BEGIN
  CREATE TABLE zsystem.lookupValues
  (
    lookupTableID  int            NOT NULL,
    lookupID       tinyint        NOT NULL,
    lookupText     nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NULL,
    --
    CONSTRAINT lookupValues_PK PRIMARY KEY CLUSTERED (lookupTableID, lookupID)
  )
END
GRANT SELECT ON zsystem.lookupValues TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupTablesEx') IS NOT NULL
  DROP VIEW zsystem.lookupTablesEx
GO
CREATE VIEW zsystem.lookupTablesEx
AS
  SELECT LT.lookupTableID, LT.lookupTableName, LT.[description],
         LT.schemaID, S.schemaName, LT.tableID, T.tableName
    FROM zsystem.lookupTables LT
      LEFT JOIN zsystem.schemas S ON S.schemaID = LT.schemaID
      LEFT JOIN zsystem.tables T ON T.tableID = LT.tableID
GO
GRANT SELECT ON zsystem.lookupTablesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.lookupValuesEx') IS NOT NULL
  DROP VIEW zsystem.lookupValuesEx
GO
CREATE VIEW zsystem.lookupValuesEx
AS
  SELECT V.lookupTableID, T.lookupTableName, V.lookupID, V.lookupText, V.[description]
    FROM zsystem.lookupValues V
      LEFT JOIN zsystem.lookupTables T ON T.lookupTableID = V.lookupTableID
GO
GRANT SELECT ON zsystem.lookupValuesEx TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.LookupValues_SelectTable') IS NOT NULL
  DROP PROCEDURE zsystem.LookupValues_SelectTable
GO
CREATE PROCEDURE zsystem.LookupValues_SelectTable
  @lookupTableID  int
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT lookupID, lookupText
    FROM zsystem.lookupValues
   WHERE lookupTableID = @lookupTableID
   ORDER BY lookupID
GO
GRANT EXEC ON zsystem.LookupValues_SelectTable TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.SQL') IS NOT NULL
  DROP PROCEDURE zsystem.SQL
GO
CREATE PROCEDURE zsystem.SQL
  @sql  nvarchar(max)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC sp_executesql @sql
GO
GRANT EXEC ON zsystem.SQL TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.SQLInt') IS NOT NULL
  DROP PROCEDURE zsystem.SQLInt
GO
CREATE PROCEDURE zsystem.SQLInt
  @sqlSelect        nvarchar(500),
  @sqlFrom          nvarchar(500),
  @sqlWhere         nvarchar(500) = NULL,
  @sqlOrder         nvarchar(500) = NULL,
  @parameterName    nvarchar(100),
  @parameterValue   int,
  @comparison       nchar(1) = '='
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @stmt nvarchar(max)
  SET @stmt = 'SELECT ' + @sqlSelect + ' FROM ' + @sqlFrom + ' WHERE '
  IF NOT (@sqlWhere IS NULL OR @sqlWhere = '')
    SET @stmt = @stmt + @sqlWhere + ' AND '
  SET @stmt = @stmt + @parameterName + ' ' + @comparison + ' @pParameterValue'
  IF NOT (@sqlOrder IS NULL OR @sqlOrder = '')
    SET @stmt = @stmt + ' ORDER BY ' + @sqlOrder
  EXEC sp_executesql @stmt, N'@pParameterValue int', @pParameterValue = @parameterValue
GO
GRANT EXEC ON zsystem.SQLInt TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.SQLBigInt') IS NOT NULL
  DROP PROCEDURE zsystem.SQLBigInt
GO
CREATE PROCEDURE zsystem.SQLBigInt
  @sqlSelect        nvarchar(500),
  @sqlFrom          nvarchar(500),
  @sqlWhere         nvarchar(500) = NULL,
  @sqlOrder         nvarchar(500) = NULL,
  @parameterName    nvarchar(100),
  @parameterValue   bigint,
  @comparison       nchar(1) = '='
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @stmt nvarchar(max)
  SET @stmt = 'SELECT ' + @sqlSelect + ' FROM ' + @sqlFrom + ' WHERE '
  IF NOT (@sqlWhere IS NULL OR @sqlWhere = '')
    SET @stmt = @stmt + @sqlWhere + ' AND '
  SET @stmt = @stmt + @parameterName + ' ' + @comparison + ' @pParameterValue'
  IF NOT (@sqlOrder IS NULL OR @sqlOrder = '')
    SET @stmt = @stmt + ' ORDER BY ' + @sqlOrder
  EXEC sp_executesql @stmt, N'@pParameterValue bigint', @pParameterValue = @parameterValue
GO
GRANT EXEC ON zsystem.SQLBigInt TO zzp_server
GO


---------------------------------------------------------------------------------------------------


IF OBJECT_ID('zsystem.SQLSELECT') IS NOT NULL
  DROP PROCEDURE zsystem.SQLSELECT
GO
CREATE PROCEDURE zsystem.SQLSELECT
  @sql  nvarchar(max)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SET ROWCOUNT 1000

  BEGIN TRY
    IF CHARINDEX(';', @sql) > 0
      RAISERROR ('Semicolon in SQL', 13, 1)

    DECLARE @usql nvarchar(4000)
    SET @usql = UPPER(@sql)

    IF NOT @usql LIKE 'SELECT %'
      RAISERROR ('SQL must start with SELECT ', 13, 1)

    IF CHARINDEX('INSERT', @usql) > 0
      RAISERROR ('INSERT in SQL', 13, 1)

    IF CHARINDEX('INTO', @usql) > 0
      RAISERROR ('INTO in SQL', 13, 1)

    IF CHARINDEX('UPDATE', @usql) > 0
      RAISERROR ('UPDATE in SQL', 13, 1)

    IF CHARINDEX('DELETE', @usql) > 0
      RAISERROR ('DELETE in SQL', 13, 1)

    IF CHARINDEX('TRUNCATE', @usql) > 0
      RAISERROR ('TRUNCATE in SQL', 13, 1)

    IF CHARINDEX('CREATE', @usql) > 0
      RAISERROR ('CREATE in SQL', 13, 1)

    IF CHARINDEX('ALTER', @usql) > 0
      RAISERROR ('ALTER in SQL', 13, 1)

    IF CHARINDEX('DROP', @usql) > 0
      RAISERROR ('DROP in SQL', 13, 1)

    IF CHARINDEX('EXEC', @usql) > 0
      RAISERROR ('EXEC in SQL', 13, 1)

    EXEC sp_executesql @sql
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.SQLSELECT'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.SQLSELECT TO zzp_server
GO


---------------------------------------------------------------------------------------------------



EXEC zsystem.Versions_Finish 'CORE.J', 0001, 'jorundur'
GO
