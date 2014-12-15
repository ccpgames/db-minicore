
-- *** lookupTableID from 2000000000 and up is reserved for CORE ***

IF OBJECT_ID('zsystem.lookupTables') IS NULL
BEGIN
  CREATE TABLE zsystem.lookupTables
  (
    lookupTableID             int                                          NOT NULL,
    lookupTableName           nvarchar(200)                                NOT NULL,
    [description]             nvarchar(max)                                NULL,
    --
    schemaID                  int                                          NULL, -- Link lookup table to a schema, just info
    tableID                   int                                          NULL, -- Link lookup table to a table, just info
    [source]                  nvarchar(200)                                NULL, -- Description of data source, f.e. table name
    lookupID                  nvarchar(200)                                NULL, -- Description of lookupID column
    parentID                  nvarchar(200)                                NULL, -- Description of parentID column
    parentLookupTableID       int                                          NULL,
    link                      nvarchar(500)                                NULL, -- If a link to a web page is needed
    lookupTableIdentifier     varchar(500)   COLLATE Latin1_General_CI_AI  NOT NULL, -- Identifier to use in code to make it readable and usable in other Metrics webs
    hidden                    bit                                          NOT NULL  DEFAULT 0,
    obsolete                  bit                                          NOT NULL  DEFAULT 0,
    sourceForID               varchar(20)                                  NULL, -- EXTERNAL/TEXT/MAX
    label                     nvarchar(200)                                NULL, -- If a label is needed instead of lookup text
    --
    CONSTRAINT lookupTables_PK PRIMARY KEY CLUSTERED (lookupTableID)
  )

  CREATE UNIQUE NONCLUSTERED INDEX lookupTables_UQ_Identifier ON zsystem.lookupTables (lookupTableIdentifier)
END
GRANT SELECT ON zsystem.lookupTables TO zzp_server
GO
