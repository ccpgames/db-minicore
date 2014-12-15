
-- This table is intended for normal key counters
--
-- Normal key counters are key counters where you need to get top x records ordered by value (f.e. leaderboards)

IF OBJECT_ID('zmetric.keyCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.keyCounters
  (
    counterID    smallint  NOT NULL,  -- Counter, poining to zmetric.counters
    counterDate  date      NOT NULL,  -- Date
    columnID     tinyint   NOT NULL,  -- Column if used, pointing to zmetric.columns, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting by country, 0 if not used
    value        float     NOT NULL,  -- Value
    --
    CONSTRAINT keyCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX keyCounters_IX_CounterDate ON zmetric.keyCounters (counterID, counterDate, columnID, value)
END
GRANT SELECT ON zmetric.keyCounters TO zzp_server
GO
