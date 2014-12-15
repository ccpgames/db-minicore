
IF OBJECT_ID('zsystem.Schemas_Name') IS NOT NULL
  DROP FUNCTION zsystem.Schemas_Name
GO
CREATE FUNCTION zsystem.Schemas_Name(@schemaID int)
RETURNS nvarchar(128)
BEGIN
  DECLARE @schemaName nvarchar(128)
  SELECT @schemaName = schemaName FROM zsystem.schemas WHERE schemaID = @schemaID
  RETURN @schemaName
END
GO
GRANT EXEC ON zsystem.Schemas_Name TO zzp_server
GO
