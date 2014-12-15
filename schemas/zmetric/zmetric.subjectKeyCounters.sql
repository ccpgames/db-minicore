
-- This table is intended for subject/key counters
--
-- This is basically a two-key version of zmetric.keyCounters where it was decided to use subjectID/keyID instead of keyID/keyID2

IF OBJECT_ID('zmetric.subjectKeyCounters') IS NULL
BEGIN
  CREATE TABLE zmetric.subjectKeyCounters
  (
    counterID    smallint  NOT NULL,  -- Counter, poining to zmetric.counters
    counterDate  date      NOT NULL,  -- Date
    columnID     tinyint   NOT NULL,  -- Column if used, pointing to zmetric.columns, 0 if not used
    subjectID    int       NOT NULL,  -- Subject if used, f.e. if counting for user or character, 0 if not used
    keyID        int       NOT NULL,  -- Key if used, f.e. if counting kills for character per solar system, 0 if not used
    value        float     NOT NULL,  -- Value
    --
    CONSTRAINT subjectKeyCounters_PK PRIMARY KEY CLUSTERED (counterID, columnID, subjectID, keyID, counterDate)
  )

  CREATE NONCLUSTERED INDEX subjectKeyCounters_IX_CounterDate ON zmetric.subjectKeyCounters (counterID, counterDate, columnID, value)
END
GRANT SELECT ON zmetric.subjectKeyCounters TO zzp_server
GO
