
IF OBJECT_ID('zsystem.lookupTablesEx') IS NOT NULL
  DROP VIEW zsystem.lookupTablesEx
GO
CREATE VIEW zsystem.lookupTablesEx
AS
  SELECT L.lookupTableID, L.lookupTableName, L.lookupTableIdentifier, L.[description], L.schemaID, S.schemaName, L.tableID, T.tableName,
         L.sourceForID, L.[source], L.lookupID, L.parentID, L.parentLookupTableID, parentLookupTableName = L2.lookupTableName,
         L.link, L.label, L.hidden, L.obsolete
    FROM zsystem.lookupTables L
      LEFT JOIN zsystem.schemas S ON S.schemaID = L.schemaID
      LEFT JOIN zsystem.tables T ON T.tableID = L.tableID
      LEFT JOIN zsystem.lookupTables L2 ON L2.lookupTableID = L.parentLookupTableID
GO
GRANT SELECT ON zsystem.lookupTablesEx TO zzp_server
GO
