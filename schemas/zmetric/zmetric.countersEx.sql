
IF OBJECT_ID('zmetric.countersEx') IS NOT NULL
  DROP VIEW zmetric.countersEx
GO
CREATE VIEW zmetric.countersEx
AS
  SELECT C.groupID, G.groupName, C.counterID, C.counterName, C.counterType, C.counterTable, C.counterIdentifier, C.[description],
         C.subjectLookupTableID, subjectLookupTableIdentifier = LS.lookupTableIdentifier, subjectLookupTableName = LS.lookupTableName,
         C.keyLookupTableID, keyLookupTableIdentifier = LK.lookupTableIdentifier, keyLookupTableName = LK.lookupTableName,
         C.sourceType, C.[source], C.subjectID, C.keyID, C.absoluteValue, C.shortName,
         groupOrder = G.[order], C.[order], C.procedureName, C.procedureOrder, C.parentCounterID, C.createDate, C.modifyDate, C.userName,
         C.baseCounterID, C.hidden, C.published, C.units, C.obsolete
    FROM zmetric.counters C
      LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
      LEFT JOIN zsystem.lookupTables LS ON LS.lookupTableID = C.subjectLookupTableID
      LEFT JOIN zsystem.lookupTables LK ON LK.lookupTableID = C.keyLookupTableID
GO
GRANT SELECT ON zmetric.countersEx TO zzp_server
GO
