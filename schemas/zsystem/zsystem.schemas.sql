
-- *** schemaID from 2000000000 and up is reserved for CORE ***
-- *** schemaName starting with "z" is reserved for CORE    ***

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



-- Data
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000001)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000001, 'zsystem', 'CORE - Zhared system objects, supporting f.e. database version control, meta data about objects, settings, identities, events, jobs and so on.', 'http://core/wiki/DB_zsystem')
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000034)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description])
       VALUES (2000000034, 'Operations', 'Special schema record, not actually a schema but rather pointing to the Operations database, allowing ops to register procs.')
GO
