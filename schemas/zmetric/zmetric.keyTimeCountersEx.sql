
IF OBJECT_ID('zmetric.keyTimeCountersEx') IS NOT NULL
  DROP VIEW zmetric.keyTimeCountersEx
GO
CREATE VIEW zmetric.keyTimeCountersEx
AS
  SELECT C.groupID, G.groupName, T.counterID, C.counterName, T.counterDate, T.columnID, O.columnName,
         T.keyID, keyText = ISNULL(L.[fullText], L.lookupText), T.[value]
    FROM zmetric.keyTimeCounters T
      LEFT JOIN zmetric.counters C ON C.counterID = T.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = C.keyLookupTableID AND L.lookupID = T.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = T.counterID AND O.columnID = T.columnID
GO
GRANT SELECT ON zmetric.keyTimeCountersEx TO zzp_server
GO
