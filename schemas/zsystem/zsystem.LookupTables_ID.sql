
IF OBJECT_ID('zsystem.LookupTables_ID') IS NOT NULL
  DROP FUNCTION zsystem.LookupTables_ID
GO
CREATE FUNCTION zsystem.LookupTables_ID(@lookupTableIdentifier varchar(500))
RETURNS int
BEGIN
  DECLARE @lookupTableID int
  SELECT @lookupTableID = lookupTableID FROM zsystem.lookupTables WHERE lookupTableIdentifier = @lookupTableIdentifier
  RETURN @lookupTableID
END
GO
GRANT EXEC ON zsystem.LookupTables_ID TO zzp_server
GO
