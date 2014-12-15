
IF OBJECT_ID('zmetric.simpleCountersEx') IS NOT NULL
  DROP VIEW zmetric.simpleCountersEx
GO
CREATE VIEW zmetric.simpleCountersEx
AS
  SELECT C.groupID, G.groupName, SC.counterID, C.counterName, SC.counterDate, SC.value
    FROM zmetric.simpleCounters SC
      LEFT JOIN zmetric.counters C ON C.counterID = SC.counterID
        LEFT JOIN zmetric.groups G ON G.groupID = C.groupID
GO
GRANT SELECT ON zmetric.simpleCountersEx TO zzp_server
GO
