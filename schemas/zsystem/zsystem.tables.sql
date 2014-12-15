
-- tableID from 2000000000 and up is reserved for CORE

IF OBJECT_ID('zsystem.tables') IS NULL
BEGIN
  CREATE TABLE zsystem.tables
  (
    schemaID             int            NOT NULL,
    tableID              int            NOT NULL,
    tableName            nvarchar(128)  NOT NULL,
    [description]        nvarchar(max)  NOT NULL,
    tableType            varchar(20)    NULL,
    logIdentity          tinyint        NULL,  -- 1:Int, 2:Bigint
    copyStatic           tinyint        NULL,  -- 1:BSD, 2:Regular
    keyID                nvarchar(128)  NULL,
    keyID2               nvarchar(128)  NULL,
    keyID3               nvarchar(128)  NULL,
    sequence             int            NULL,
    keyName              nvarchar(128)  NULL,
    disableEdit          bit            NOT NULL  DEFAULT 0,
    disableDelete        bit            NOT NULL  DEFAULT 0,
    textTableID          int            NULL,
    textKeyID            nvarchar(128)  NULL,
    textTableID2         int            NULL,
    textKeyID2           nvarchar(128)  NULL,
    textTableID3         int            NULL,
    textKeyID3           nvarchar(128)  NULL,
    obsolete             bit            NOT NULL  DEFAULT 0,
    link                 nvarchar(256)  NULL,
    keyDate              nvarchar(128)  NULL,  -- Points to the date column to use for identities (keyID and keyDate used)
    disabledDatasets     bit            NULL,
    revisionOrder        int            NOT NULL  DEFAULT 0,
    denormalized         bit            NOT NULL  DEFAULT 0,  -- Points to a *Dx table and a *Dx_Refresh proc, only one key supported
    keyDateUTC           bit            NOT NULL  DEFAULT 1,  -- States wether the keyDate column is storing UTC or local time (GETUTCDATE or GETDATE)
    --
    CONSTRAINT tables_PK PRIMARY KEY CLUSTERED (tableID)
  )

  CREATE UNIQUE NONCLUSTERED INDEX tables_UQ_Name ON zsystem.tables (schemaID, tableName)
END
GRANT SELECT ON zsystem.tables TO zzp_server
GO



-- Data
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100001)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100001, 'settings', 'Core - System - Shared settings stored in DB')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100002)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100002, 'versions', 'Core - System - List of DB updates (versions) applied on the DB')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100003)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100003, 'schemas', 'Core - System - List of database schemas')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100004)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100004, 'tables', 'Core - System - List of database tables')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100005)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100005, 'columns', 'Core - System - List of database columns that need special handling')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100006)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100006, 'procedures', 'Core - System - List of database procedures that need special handling', 2)
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100011)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description])
       VALUES (2000000001, 2000100011, 'identities', 'Core - System - Identity statistics (used to support searching without the need for datetime indexes)')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100012)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], logIdentity, keyID, keyDate)
       VALUES (2000000001, 2000100012, 'columnEvents', 'Core - System - Column events', 1, 'eventID', 'eventDate')
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100013)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], copyStatic)
       VALUES (2000000001, 2000100013, 'eventTypes', 'Core - System - Events types', 2)
IF NOT EXISTS(SELECT * FROM zsystem.tables WHERE tableID = 2000100014)
  INSERT INTO zsystem.tables (schemaID, tableID, tableName, [description], logIdentity, keyID, keyDate)
       VALUES (2000000001, 2000100014, 'events', 'Core - System - Events', 1, 'eventID', 'eventDate')
GO
