
IF OBJECT_ID('zmetric.Counters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_Insert
GO
CREATE PROCEDURE zmetric.Counters_Insert
  @counterType           char(1) = 'D',         -- C:Column, D:Date, S:Simple, T:Time
  @counterID             smallint = NULL,       -- NULL means MAX-UNDER-30000 + 1
  @counterName           nvarchar(200),
  @groupID               smallint = NULL,
  @description           nvarchar(max) = NULL,
  @subjectLookupTableID  int = NULL,            -- Lookup table for subjectID, pointing to zsystem.lookupTables/Values
  @keyLookupTableID      int = NULL,            -- Lookup table for keyID, pointing to zsystem.lookupTables/Values
  @source                nvarchar(200) = NULL,  -- Description of data source, f.e. table name
  @subjectID             nvarchar(200) = NULL,  -- Description of subjectID column
  @keyID                 nvarchar(200) = NULL,  -- Description of keyID column
  @absoluteValue         bit = 0,               -- If set counter stores absolute value
  @shortName             nvarchar(50) = NULL,
  @order                 smallint = 0,
  @procedureName         nvarchar(500) = NULL,  -- Procedure called to get data for the counter
  @procedureOrder        tinyint = 255,
  @parentCounterID       smallint = NULL,
  @baseCounterID         smallint = NULL,
  @counterIdentifier     varchar(500) = NULL,
  @published             bit = 1,
  @sourceType            varchar(20) = NULL,    -- Used f.e. on EVE Metrics to say if counter comes from DB or DOOBJOB
  @units                 varchar(20) = NULL,
  @counterTable          nvarchar(256) = NULL,
  @userName              varchar(200) = NULL
AS
  SET NOCOUNT ON

  IF @counterID IS NULL
    SELECT @counterID = MAX(counterID) + 1 FROM zmetric.counters WHERE counterID < 30000
  IF @counterID IS NULL SET @counterID = 1

  IF @counterIdentifier IS NULL SET @counterIdentifier = @counterID

  INSERT INTO zmetric.counters
              (counterID, counterName, groupID, [description], subjectLookupTableID, keyLookupTableID, [source], subjectID, keyID,
               absoluteValue, shortName, [order], procedureName, procedureOrder, parentCounterID, baseCounterID, counterType,
               counterIdentifier, published, sourceType, units, counterTable, userName)
       VALUES (@counterID, @counterName, @groupID, @description, @subjectLookupTableID, @keyLookupTableID, @source, @subjectID, @keyID,
               @absoluteValue, @shortName, @order, @procedureName, @procedureOrder, @parentCounterID, @baseCounterID, @counterType,
               @counterIdentifier, @published, @sourceType, @units, @counterTable, @userName)

  SELECT counterID = @counterID
GO
GRANT EXEC ON zmetric.Counters_Insert TO zzp_server
GO
