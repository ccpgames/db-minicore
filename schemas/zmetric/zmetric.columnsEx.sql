
IF OBJECT_ID('zmetric.columnsEx') IS NOT NULL
  DROP VIEW zmetric.columnsEx
GO
CREATE VIEW zmetric.columnsEx
AS
  SELECT C.groupID, G.groupName, O.counterID, C.counterName, O.columnID, O.columnName, O.[description], O.units, O.counterTable, O.[order]
    FROM zmetric.columns O
      LEFT JOIN zmetric.counters C ON C.counterID = O.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
GO
GRANT SELECT ON zmetric.columnsEx TO zzp_server
GO
