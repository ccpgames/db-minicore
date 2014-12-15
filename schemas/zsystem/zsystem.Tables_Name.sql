
IF OBJECT_ID('zsystem.Tables_Name') IS NOT NULL
  DROP FUNCTION zsystem.Tables_Name
GO
CREATE FUNCTION zsystem.Tables_Name(@tableID int)
RETURNS nvarchar(257)
BEGIN
  DECLARE @fullName nvarchar(257)
  SELECT @fullName = S.schemaName + '.' + T.tableName
    FROM zsystem.tables T
      INNER JOIN zsystem.schemas S ON S.schemaID = T.schemaID
   WHERE T.tableID = @tableID
  RETURN @fullName
END
GO
GRANT EXEC ON zsystem.Tables_Name TO zzp_server
GO
