
IF OBJECT_ID('zsystem.LookupTables_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.LookupTables_Insert
GO
CREATE PROCEDURE zsystem.LookupTables_Insert
  @lookupTableID          int = NULL,            -- NULL means MAX-UNDER-2000000000 + 1
  @lookupTableName        nvarchar(200),
  @description            nvarchar(max) = NULL,
  @schemaID               int = NULL,            -- Link lookup table to a schema, just info
  @tableID                int = NULL,            -- Link lookup table to a table, just info
  @source                 nvarchar(200) = NULL,  -- Description of data source, f.e. table name
  @lookupID               nvarchar(200) = NULL,  -- Description of lookupID column
  @parentID               nvarchar(200) = NULL,  -- Description of parentID column
  @parentLookupTableID    int = NULL,
  @link                   nvarchar(500) = NULL,  -- If a link to a web page is needed
  @lookupTableIdentifier  varchar(500) = NULL,
  @sourceForID            varchar(20) = NULL,    -- EXTERNAL/TEXT/MAX
  @label                  nvarchar(200) = NULL   -- If a label is needed instead of lookup text
AS
  SET NOCOUNT ON

  IF @lookupTableID IS NULL
    SELECT @lookupTableID = MAX(lookupTableID) + 1 FROM zsystem.lookupTables WHERE lookupTableID < 2000000000
  IF @lookupTableID IS NULL SET @lookupTableID = 1

  IF @lookupTableIdentifier IS NULL SET @lookupTableIdentifier = @lookupTableID

  INSERT INTO zsystem.lookupTables
              (lookupTableID, lookupTableName, [description], schemaID, tableID, [source], lookupID, parentID, parentLookupTableID,
               link, lookupTableIdentifier, sourceForID, label)
       VALUES (@lookupTableID, @lookupTableName, @description, @schemaID, @tableID, @source, @lookupID, @parentID, @parentLookupTableID,
               @link, @lookupTableIdentifier, @sourceForID, @label)

  SELECT lookupTableID = @lookupTableID
GO
GRANT EXEC ON zsystem.LookupTables_Insert TO zzp_server
GO
