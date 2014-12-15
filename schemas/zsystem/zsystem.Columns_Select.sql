
IF OBJECT_ID('zsystem.Columns_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Columns_Select
GO
CREATE PROCEDURE zsystem.Columns_Select
  @schemaName  nvarchar(128),
  @tableName   nvarchar(128),
  @tableID     int = NULL
AS
  SET NOCOUNT ON

  IF @tableID IS NULL SET @tableID = zsystem.Tables_ID(@schemaName, @tableName)

  -- Using COLLATE so SQL works on Azure
  SELECT columnName = c.[name], c.system_type_id, c.max_length, c.is_nullable,
         c2.[readonly], c2.lookupTable, c2.lookupID, c2.lookupName, c2.lookupWhere, c2.html, c2.localizationGroupID
    FROM sys.columns c
      LEFT JOIN zsystem.columns c2 ON c2.tableID = @tableID AND c2.columnName COLLATE Latin1_General_BIN = c.[name] COLLATE Latin1_General_BIN
   WHERE c.[object_id] = OBJECT_ID(@schemaName + '.' + @tableName) AND ISNULL(c2.obsolete, 0) = 0
   ORDER BY c.column_id
GO
GRANT EXEC ON zsystem.Columns_Select TO zzp_server
GO
