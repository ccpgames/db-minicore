
IF OBJECT_ID('zsystem.columnsEx') IS NOT NULL
  DROP VIEW zsystem.columnsEx
GO
CREATE VIEW zsystem.columnsEx
AS
  SELECT T.schemaID, S.schemaName, C.tableID, T.tableName,
         C.columnName, C.[readonly], C.lookupTable, C.lookupID, C.lookupName,
         C.lookupWhere, C.html, C.localizationGroupID, C.obsolete
    FROM zsystem.columns C
      LEFT JOIN zsystem.tables T ON T.tableID = C.tableID
        LEFT JOIN zsystem.schemas S ON S.schemaID = T.schemaID
GO
GRANT SELECT ON zsystem.columnsEx TO zzp_server
GO
