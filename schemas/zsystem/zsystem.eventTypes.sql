
-- *** eventTypeID from 2000000000 and up is reserved for CORE ***

IF OBJECT_ID('zsystem.eventTypes') IS NULL
BEGIN
  CREATE TABLE zsystem.eventTypes
  (
    eventTypeID    int            NOT NULL,
    eventTypeName  nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    obsolete       bit            NOT NULL  DEFAULT 0,
    --
    CONSTRAINT eventTypes_PK PRIMARY KEY CLUSTERED (eventTypeID)
  )
END
GRANT SELECT ON zsystem.eventTypes TO zzp_server
GO



-- Data
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000001)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000001, 'Procedure started', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000002)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000002, 'Procedure info', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000003)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000003, 'Procedure completed', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000004)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000004, 'Procedure ERROR', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000011)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000011, 'Insert', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000012)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000012, 'Update', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000013)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000013, 'Delete', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000014)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000014, 'Copy', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000021)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000021, 'Job started', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000022)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000022, 'Job info', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000023)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000023, 'Job completed', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000024)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000024, 'Job ERROR', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000031)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000031, 'Update system setting', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000032)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000032, 'Insert system setting', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000041)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000041, 'ProcessClusterShutdown started', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000042)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000042, 'ProcessClusterShutdown info', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000043)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000043, 'ProcessClusterShutdown completed', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000044)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000000044, 'ProcessClusterShutdown ERROR', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000201)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description], obsolete)
       VALUES (2000000201, 'Server page refresh', '', 1)
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000301)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description], obsolete)
       VALUES (2000000301, 'ProcessClusterShutdown - DB Statistics - Begin', '', 1)
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000302)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description], obsolete)
       VALUES (2000000302, 'DB Statistics', '', 1)
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000303)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description], obsolete)
       VALUES (2000000303, 'ProcessClusterShutdown - DB Statistics - End', '', 1)
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000000304)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description], obsolete)
       VALUES (2000000304, 'Index Statistics', '', 1)
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001001)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001001, 'Task started', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001002)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001002, 'Task info', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001003)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001003, 'Task completed', '')
IF NOT EXISTS(SELECT * FROM zsystem.eventTypes WHERE eventTypeID = 2000001004)
  INSERT INTO zsystem.eventTypes (eventTypeID, eventTypeName, [description])
       VALUES (2000001004, 'Task ERROR', '')
GO
