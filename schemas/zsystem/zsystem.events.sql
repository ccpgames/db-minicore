
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
    referenceID  int            NULL,  -- General referenceID, could f.e. be used for first eventID if there are grouped events
    date_1       date           NULL,
    taskID       int            NULL,  -- Task in zsystem.tasks
    textID       int            NULL,  -- Fixed text in zsystem.texts, displayed as fixedText in zsystem.eventsEx
    nestLevel    tinyint        NULL,  -- @@NESTLEVEL-1 saved by the zsystem.Events_Task* procs, capped at 255
    parentID     int            NULL,  -- General parentID, f.e. to be used for first eventID of the calling proc when nested proc calls
    --
    CONSTRAINT events_PK PRIMARY KEY CLUSTERED (eventID)
  )
END
GRANT SELECT ON zsystem.events TO zzp_server
GO
