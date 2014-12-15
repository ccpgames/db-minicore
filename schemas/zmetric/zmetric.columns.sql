
IF OBJECT_ID('zmetric.columns') IS NULL
BEGIN
  CREATE TABLE zmetric.columns
  (
    counterID          smallint                                     NOT NULL,
    columnID           tinyint                                      NOT NULL,
    columnName         nvarchar(200)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]      nvarchar(max)                                NULL,
    [order]            smallint                                     NOT NULL  DEFAULT 0,
    units              varchar(20)                                  NULL, -- If set here it overrides value in zmetric.counters.units
    counterTable       nvarchar(256)                                NULL, -- If set here it overrides value in zmetric.counters.counterTable
    --
    CONSTRAINT columns_PK PRIMARY KEY CLUSTERED (counterID, columnID)
  )
END
GRANT SELECT ON zmetric.columns TO zzp_server
GO


-- Data
-- core.dbsvc.procStats
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30004)
  INSERT INTO zmetric.columns (counterID, columnID, columnName)
       VALUES (30004, 1, 'calls'),  (30004, 2, 'rowsets'), (30004, 3, 'rows'), (30004, 4, 'duration'), (30004, 5, 'bytesParams'), (30004, 6, 'bytesData')
-- core.cache.tableCache
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30005)
  INSERT INTO zmetric.columns (counterID, columnID, columnName)
       VALUES (30005, 1, 'usage')
-- core.cache.recordCache
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30006)
  INSERT INTO zmetric.columns (counterID, columnID, columnName)
       VALUES (30006, 1, 'cacheHits'), (30006, 2, 'procCalls'), (30006, 3, 'deletes')
-- core.db.indexStats
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30007)
BEGIN
  INSERT INTO zmetric.columns (counterID, columnID, columnName)
       VALUES (30007, 1, 'rows'), (30007, 2, 'total_kb'), (30007, 3, 'used_kb'), (30007, 4, 'data_kb')
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30007, 5, 'user_seeks', 'Accumulated count'), (30007, 6, 'user_scans', 'Accumulated count'), (30007, 7, 'user_lookups', 'Accumulated count'), (30007, 8, 'user_updates', 'Accumulated count')
END
-- core.db.tableStats
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30008)
BEGIN
  INSERT INTO zmetric.columns (counterID, columnID, columnName)
       VALUES (30008, 1, 'rows'), (30008, 2, 'total_kb'), (30008, 3, 'used_kb'), (30008, 4, 'data_kb')
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30008, 5, 'user_seeks', 'Accumulated count'), (30008, 6, 'user_scans', 'Accumulated count'), (30008, 7, 'user_lookups', 'Accumulated count'), (30008, 8, 'user_updates', 'Accumulated count')
END
-- core.db.fileStats
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30009)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30009, 1, 'reads', 'Accumulated count'), (30009, 2, 'reads_kb', 'Accumulated count'), (30009, 3, 'io_stall_read', 'Accumulated count'), (30009, 4, 'writes', 'Accumulated count'),
              (30009, 5, 'writes_kb', 'Accumulated count'), (30009, 6, 'io_stall_write', 'Accumulated count'), (30009, 7, 'size_kb', NULL)
-- core.db.waitStats
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30025)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30025, 1, 'waiting_tasks_count', 'Accumulated count'), (30025, 2, 'wait_time_ms', 'Accumulated count'), (30025, 3, 'signal_wait_time_ms', 'Accumulated count')
-- core.db.procStats
IF NOT EXISTS(SELECT * FROM zmetric.columns WHERE counterID = 30026)
  INSERT INTO zmetric.columns (counterID, columnID, columnName, [description])
       VALUES (30026, 1, 'execution_count', 'Accumulated count'), (30026, 2, 'total_logical_reads', 'Accumulated count'), (30026, 3, 'total_logical_writes', 'Accumulated count'),
              (30026, 4, 'total_worker_time', 'Accumulated count'), (30026, 5, 'total_elapsed_time', 'Accumulated count')
GO
