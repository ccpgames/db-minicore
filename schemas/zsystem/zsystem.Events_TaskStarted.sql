
IF OBJECT_ID('zsystem.Events_TaskStarted') IS NOT NULL
  DROP PROCEDURE zsystem.Events_TaskStarted
GO
CREATE PROCEDURE zsystem.Events_TaskStarted
  @taskName     nvarchar(450) = NULL,
  @fixedText    nvarchar(450) = NULL,
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
  @eventTypeID  int = 2000001001,
  @returnRow    bit = 0,
  @parentID     int = NULL
AS
  SET NOCOUNT ON

  IF @taskID IS NULL AND @taskName IS NOT NULL
    EXEC @taskID = zsystem.Tasks_DynamicID @taskName

  DECLARE @nestLevel int
  SET @nestLevel = @@NESTLEVEL - 1
  IF @nestLevel < 1 SET @nestLevel = NULL
  IF @nestLevel > 255 SET @nestLevel = 255

  DECLARE @eventID int

  EXEC @eventID = zsystem.Events_Insert @eventTypeID, NULL, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @returnRow, NULL, @date_1, @taskID, NULL, @fixedText, @nestLevel, @parentID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_TaskStarted TO zzp_server
GO
