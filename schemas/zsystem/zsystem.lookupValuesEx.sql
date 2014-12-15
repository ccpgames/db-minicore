
IF OBJECT_ID('zsystem.lookupValuesEx') IS NOT NULL
  DROP VIEW zsystem.lookupValuesEx
GO
CREATE VIEW zsystem.lookupValuesEx
AS
  SELECT V.lookupTableID, T.lookupTableName, V.lookupID, V.lookupText, V.[fullText], V.parentID, V.[description]
    FROM zsystem.lookupValues V
      LEFT JOIN zsystem.lookupTables T ON T.lookupTableID = V.lookupTableID
GO
GRANT SELECT ON zsystem.lookupValuesEx TO zzp_server
GO
