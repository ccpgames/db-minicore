
IF OBJECT_ID('zsystem.LookupValues_SelectTable') IS NOT NULL
  DROP PROCEDURE zsystem.LookupValues_SelectTable
GO
CREATE PROCEDURE zsystem.LookupValues_SelectTable
  @lookupTableID  int
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT lookupID, lookupText, parentID
    FROM zsystem.lookupValues
   WHERE lookupTableID = @lookupTableID
   ORDER BY lookupID
GO
GRANT EXEC ON zsystem.LookupValues_SelectTable TO zzp_server
GO
