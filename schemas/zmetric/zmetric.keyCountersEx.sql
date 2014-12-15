
IF OBJECT_ID('zmetric.keyCountersEx') IS NOT NULL
  DROP VIEW zmetric.keyCountersEx
GO
CREATE VIEW zmetric.keyCountersEx
AS
  SELECT C.groupID, G.groupName, K.counterID, C.counterName, K.counterDate, K.columnID, O.columnName,
         K.keyID, keyText = ISNULL(L.[fullText], L.lookupText), K.[value]
    FROM zmetric.keyCounters K
      LEFT JOIN zmetric.counters C ON C.counterID = K.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
        LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = C.keyLookupTableID AND L.lookupID = K.keyID
      LEFT JOIN zmetric.columns O ON O.counterID = K.counterID AND O.columnID = K.columnID
GO
GRANT SELECT ON zmetric.keyCountersEx TO zzp_server
GO
