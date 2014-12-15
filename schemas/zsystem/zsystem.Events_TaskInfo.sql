
IF OBJECT_ID('zsystem.Events_TaskInfo') IS NOT NULL
  DROP PROCEDURE zsystem.Events_TaskInfo
GO
CREATE PROCEDURE zsystem.Events_TaskInfo
  @eventID      int = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL,
  @taskID       int = NULL,
  @taskName     nvarchar(450) = NULL,
  @fixedText    nvarchar(450) = NULL,
  @eventTypeID  int = 2000001002,
  @returnRow    bit = 0
AS
  SET NOCOUNT ON

  DECLARE @textID int, @nestLevel tinyint, @parentID int

  IF @eventID IS NOT NULL AND @taskID IS NULL
    SELECT @taskID = taskID, @textID = textID, @nestLevel = nestLevel, @parentID = parentID FROM zsystem.events WHERE eventID = @eventID

  IF @taskID IS NULL AND @taskName IS NOT NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  IF @fixedText IS NOT NULL
    SET @textID = NULL

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, @eventID, @date_1, @taskID, @textID, @fixedText, @nestLevel, @parentID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_TaskInfo TO zzp_server
GO
