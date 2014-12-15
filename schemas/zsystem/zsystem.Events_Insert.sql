
IF OBJECT_ID('zsystem.Events_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.Events_Insert
GO
CREATE PROCEDURE zsystem.Events_Insert
  @eventTypeID  int,
  @duration     int = NULL,
  @int_1        int = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @eventText    nvarchar(max) = NULL,
  @returnRow    bit = 0,
  @referenceID  int = NULL,
  @date_1       date = NULL,
  @taskID       int = NULL,
  @textID       int = NULL,
  @fixedText    nvarchar(450) = NULL,
  @nestLevel    tinyint = NULL,
  @parentID     int = NULL
AS
  SET NOCOUNT ON

  DECLARE @eventID int

  IF @textID IS NULL AND @fixedText IS NOT NULL
    EXEC @textID = zsystem.Texts_ID @fixedText

  INSERT INTO zsystem.events
              (eventTypeID, duration, int_1, int_2, int_3, int_4, int_5, int_6, int_7, int_8, int_9, eventText, referenceID, date_1, taskID, textID, nestLevel, parentID)
       VALUES (@eventTypeID, @duration, @int_1, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @eventText, @referenceID, @date_1, @taskID, @textID, @nestLevel, @parentID)

  SET @eventID = SCOPE_IDENTITY()

  IF @returnRow = 1
    SELECT eventID = @eventID

  RETURN @eventID
GO
GRANT EXEC ON zsystem.Events_Insert TO zzp_server
GO
