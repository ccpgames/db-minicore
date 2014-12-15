
IF OBJECT_ID('zsystem.Tables_ID') IS NOT NULL
  DROP FUNCTION zsystem.Tables_ID
GO
CREATE FUNCTION zsystem.Tables_ID(@schemaName nvarchar(128), @tableName nvarchar(128))
RETURNS int
BEGIN
  DECLARE @schemaID int
  SELECT @schemaID = schemaID FROM zsystem.schemas WHERE schemaName = @schemaName

  DECLARE @tableID int
  SELECT @tableID = tableID FROM zsystem.tables WHERE schemaID = @schemaID AND tableName = @tableName
  RETURN @tableID
END
GO
GRANT EXEC ON zsystem.Tables_ID TO zzp_server
GO
