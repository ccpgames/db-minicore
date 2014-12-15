
IF OBJECT_ID('zsystem.Events_SelectByEvent') IS NOT NULL
  DROP PROCEDURE zsystem.Events_SelectByEvent
GO
CREATE PROCEDURE zsystem.Events_SelectByEvent
  @eventID  int
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    DECLARE @eventDate datetime2(0), @parentID int
    SELECT @eventDate = eventDate, @parentID = parentID FROM zsystem.events WHERE eventID = @eventID
    IF @eventDate IS NULL
      RAISERROR ('Event not found', 16, 1)

    -- Setting from/to interval to 3 days, 1 day before and 1 day after
    DECLARE @fromID int, @toID int
    SET @fromID = zsystem.Identities_Int(2000100014, @eventDate, -1, 0)
    IF @fromID < 0
      RAISERROR ('Identity not found', 16, 1)
    SET @toID = zsystem.Identities_Int(2000100014, @eventDate, 2, 0) - 1
    IF @toID < 0 SET @toID = 2147483647

    -- Table for events returned
    DECLARE @events TABLE (eventID int NOT NULL PRIMARY KEY, eventLevel int NULL)

    -- Find top level parent event
    IF @parentID IS NOT NULL
    BEGIN
      DECLARE @nextParentID int = 0, @c tinyint = 0, @masterID int
      WHILE 1 = 1
      BEGIN
        SET @nextParentID = NULL
        SELECT @nextParentID = parentID FROM zsystem.events WHERE eventID = @parentID
        IF @nextParentID IS NULL
        BEGIN
          SET @masterID = @parentID
          BREAK
        END
        SET @parentID = @nextParentID
        SET @c += 1
        IF @c > 30
        BEGIN
          RAISERROR ('Recursion > 30 in search for master eventID', 16, 1)
          RETURN -1
        END
      END
      SET @eventID = @masterID
    END

    -- Initialize @events table with top level event(s)
    DECLARE @eventTypeID int, @referenceID int, @duration int
    DECLARE @startedEventID int, @completedEventID int
    SELECT @eventTypeID = eventTypeID, @referenceID = referenceID, @duration = duration FROM zsystem.events WHERE eventID = @eventID
    IF @eventTypeID IS NULL
      RAISERROR ('Event not found', 16, 1)
    IF @eventTypeID NOT BETWEEN 2000001001 AND 2000001004 -- Task started/info/completed/ERROR
    BEGIN
      -- Not a task event, simple initialize
      INSERT INTO @events (eventID, eventLevel) VALUES (@eventID, 1)
      SET @startedEventID = @eventID
      SET @completedEventID = @toID
    END
    ELSE
    BEGIN
      -- Find started and completed events
      IF @eventTypeID = 2000001001 -- Task started
      BEGIN
        SET @startedEventID = @eventID
        SET @referenceID = @eventID
      END
      ELSE
      BEGIN
        IF ISNULL(@referenceID, 0) > 0
          SET @startedEventID = @referenceID
        ELSE
        BEGIN
          SET @startedEventID = @eventID
          SET @referenceID = @eventID
        END
      END
      IF @eventTypeID = 2000001003 OR (@eventTypeID = 2000001004 AND @duration IS NOT NULL) -- Task completed / Task ERROR with duration set
        SET @completedEventID = @eventID
      ELSE
      BEGIN
        -- Find the completed event
        SELECT TOP 1 @completedEventID = eventID
          FROM zsystem.events
          WHERE eventID BETWEEN @eventID AND @toID
            AND (eventTypeID = 2000001003 OR (eventTypeID = 2000001004 AND duration IS NOT NULL)) AND referenceID = @referenceID
          ORDER BY eventID

        IF @completedEventID IS NULL
          SET @completedEventID = @toID
      END
      INSERT INTO @events (eventID, eventLevel)
           SELECT eventID, 1
             FROM zsystem.events
            WHERE eventID BETWEEN @startedEventID AND @completedEventID AND (eventID = @referenceID OR referenceID = @referenceID)
    END

    -- Recursively add child events
    DECLARE @eventLevel int = 1
    WHILE @eventLevel < 20
    BEGIN
      INSERT INTO @events (eventID, eventLevel)
           SELECT eventID, @eventLevel + 1
             FROM zsystem.events
            WHERE eventID BETWEEN @startedEventID AND @completedEventID AND parentID IN (SELECT eventID FROM @events WHERE eventLevel = @eventLevel)
      IF @@ROWCOUNT = 0
        BREAK
      SET @eventLevel += 1
    END

    -- Return all top level and child events
    SELECT X.eventLevel, E.*
      FROM @events X
        INNER JOIN zsystem.eventsEx E ON E.eventID = X.eventID
     ORDER BY E.eventID DESC
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.Events_SelectByEvent'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.Events_SelectByEvent TO zzp_server
GO
