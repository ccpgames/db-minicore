
IF OBJECT_ID('zmetric.subjectKeyCountersEx') IS NOT NULL
  DROP VIEW zmetric.subjectKeyCountersEx
GO
CREATE VIEW zmetric.subjectKeyCountersEx
AS
  SELECT C.groupID, G.groupName, SK.counterID, C.counterName, SK.counterDate, SK.columnID, O.columnName,
         SK.subjectID, subjectText = ISNULL(LS.[fullText], LS.lookupText), SK.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), SK.[value]
    FROM zmetric.subjectKeyCounters SK
      LEFT JOIN zmetric.counters C ON C.counterID = SK.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = SK.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = SK.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = SK.counterID AND O.columnID = SK.columnID
GO
GRANT SELECT ON zmetric.subjectKeyCountersEx TO zzp_server
GO
