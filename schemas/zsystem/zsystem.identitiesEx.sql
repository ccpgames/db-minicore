
IF OBJECT_ID('zsystem.identitiesEx') IS NOT NULL
  DROP VIEW zsystem.identitiesEx
GO
CREATE VIEW zsystem.identitiesEx
AS
  SELECT s.schemaName, t.tableName, i.tableID, i.identityDate, i.identityInt, i.identityBigInt
    FROM zsystem.identities i
      LEFT JOIN zsystem.tables t ON t.tableID = i.tableID
        LEFT JOIN zsystem.schemas s ON s.schemaID = t.schemaID
GO
GRANT SELECT ON zsystem.identitiesEx TO zzp_server
GO
