
IF OBJECT_ID('zsystem.Identities_Check') IS NOT NULL
  DROP PROCEDURE zsystem.Identities_Check
GO
CREATE PROCEDURE zsystem.Identities_Check
  @schemaName  nvarchar(128),
  @tableName   nvarchar(128),
  @rows        smallint = 100
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @schemaID int
  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  DECLARE @tableID int
  SELECT @tableID = tableID FROM zsystem.tables WHERE schemaID = @schemaID AND tableName = @tableName

  SELECT TOP (@rows) tableID, identityDate, identityInt, identityBigInt
    FROM zsystem.identities
   WHERE tableID = @tableID
   ORDER BY identityDate DESC
GO
