
IF OBJECT_ID('zsystem.Events_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Events_Select
GO
CREATE PROCEDURE zsystem.Events_Select
  @filter   varchar(50) = '',
  @rows     smallint = 1000,
  @eventID  int = NULL,
  @text     nvarchar(450) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @eventID IS NULL SET @eventID = 2147483647

  DECLARE @stmt nvarchar(max)

  SET @stmt = 'SELECT TOP (@pRows) * FROM zsystem.eventsEx WHERE eventID < @pEventID'


  -- Application Hook!
  IF @filter != '' AND OBJECT_ID('system.Events_AppFilter') IS NOT NULL
  BEGIN
    DECLARE @where nvarchar(max)
    EXEC sp_executesql N'SELECT @p_where = system.Events_AppFilter(@p_filter)', N'@p_where nvarchar(max) OUTPUT, @p_filter varchar(50)', @where OUTPUT, @filter
    SET @stmt += @where
  END

  IF @text IS NOT NULL
  BEGIN
    SET @text = '%' + LOWER(@text) + '%'
    SET @stmt += ' AND (LOWER(eventTypeName) LIKE @pText OR taskName LIKE @pText OR fixedText LIKE @pText OR LOWER(eventText) LIKE @pText)'
  END

  SET @stmt += ' ORDER BY eventID DESC'

  EXEC sp_executesql @stmt, N'@pRows smallint, @pEventID int, @pText nvarchar(450)', @pRows = @rows, @pEventID = @eventID, @pText = @text
GO
GRANT EXEC ON zsystem.Events_Select TO zzp_server
GO
