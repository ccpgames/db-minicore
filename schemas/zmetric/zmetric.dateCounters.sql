
-- This table is deprecated, it will be dropped once EVE Metrics has been changed to use zmetric.keyCounters and zmetric.subjectKeyCounters

IF OBJECT_ID('zmetric.dateCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.dateCounters
  (
    counterID    smallint  NOT NULL,  -- Counter, poining to zmetric.counters
    counterDate  date      NOT NULL,  -- Date
    subjectID    int       NOT NULL,  -- Subject if used, f.e. if counting for user or character, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting kills for character per solar system, 0 if not used
    value        float     NOT NULL,  -- Value
    --
    CONSTRAINT dateCounters_PK PRIMARY KEY CLUSTERED (counterID, subjectID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX dateCounters_IX_CounterDate ON zmetric.dateCounters (counterID, counterDate, value)
END
GRANT SELECT ON zmetric.dateCounters TO zzp_server
GO
