
IF OBJECT_ID('zmetric.dateCountersEx') IS NOT NULL
  DROP VIEW zmetric.dateCountersEx
GO
CREATE VIEW zmetric.dateCountersEx
AS
  SELECT C.groupID, G.groupName, DC.counterID, C.counterName, DC.counterDate,
         DC.subjectID, subjectText = COALESCE(O.columnName, LS.[fullText], LS.lookupText),
         DC.keyID, keyText = ISNULL(LK.[fullText], LK.lookupText), DC.[value]
    FROM zmetric.dateCounters DC
      LEFT JOIN zmetric.counters C ON C.counterID = DC.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues LS ON LS.lookupTableID = C.subjectLookupTableID AND LS.lookupID = DC.subjectID
        LEFT JOIN zsystem.lookupValues LK ON LK.lookupTableID = C.keyLookupTableID AND LK.lookupID = DC.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = DC.counterID AND CONVERT(int, O.columnID) = DC.subjectID
GO
GRANT SELECT ON zmetric.dateCountersEx TO zzp_server
GO
