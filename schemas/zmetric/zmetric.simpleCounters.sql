
-- This table is intended for simple (no column and no key) time counters

IF OBJECT_ID('zmetric.simpleCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.simpleCounters
  (
    counterID    smallint      NOT NULL,  -- Counter, poining to zmetric.counters
    counterDate  datetime2(0)  NOT NULL,  -- Date/Time
    value        float         NOT NULL,  -- Value
    --
    CONSTRAINT simpleCounters_PK PRIMARY KEY CLUSTERED (counterID, counterDate)
  )
END
GRANT SELECT ON zmetric.simpleCounters TO zzp_server
GO
