
-- This table is intended for time detail of data stored in zmetric.keyCounters
--
-- The only difference between this table and zmetric.keyCounters is that counterDate is datetime2(0) and there is only a primary key and no extra index

IF OBJECT_ID('zmetric.keyTimeCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.keyTimeCounters
  (
    counterID    smallint      NOT NULL,  -- Counter, poining to zmetric.counters
    counterDate  datetime2(0)  NOT NULL,  -- Date/Time
    columnID     tinyint       NOT NULL,  -- Column if used, pointing to zmetric.columns, 0 if not used
    keyID        int           NOT NULL,  -- Key if used, f.e. if counting by country, 0 if not used
    value        float         NOT NULL,  -- Value
    --
    CONSTRAINT keyTimeCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, keyID, counterDate)
  )
END
GRANT SELECT ON zmetric.keyTimeCounters TO zzp_server
GO
