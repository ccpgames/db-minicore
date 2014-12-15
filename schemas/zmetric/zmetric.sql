
--
-- SCHEMA
--

IF SCHEMA_ID('zmetric') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zmetric'
GO


--
-- DATA
--

-- Schema
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000032)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000032, 'zmetric', 'CORE - Metrics', 'http://core/wiki/DB_zmetric')
GO

-- Settings
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'Recipients-IndexStats')
  INSERT INTO zsystem.settings ([group], [key], value, [description])
       VALUES ('zmetric', 'Recipients-IndexStats', '', 'Mail recipients for Index Stats notifications')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveIndexStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveIndexStats', '0', '0', 'Save index stats daily to zmetric.keyCounters (set to "1" to activate).')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveFileStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveFileStats', '0', '0', 'Save file stats daily to zmetric.keyCounters (set to "1" to activate).  Note that file stats are saved for server so only one database needs to save file stats.')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveWaitStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveWaitStats', '0', '0', 'Save wait stats daily to zmetric.keyCounters (set to "1" to activate).  Note that waits stats are saved for server so only one database needs to save wait stats.')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SaveProcStats')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SaveProcStats', '0', '0', 'Save proc stats daily to zmetric.keyCounters (set to "1" to activate).')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SavePerfCountersTotal')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SavePerfCountersTotal', '0', '0', 'Save total performance counters daily to zmetric.keyCounters (set to "1" to activate).')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'SavePerfCountersInstance')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'SavePerfCountersInstance', '0', '0', 'Save instance performance counters daily to zmetric.keyCounters (set to "1" to activate).')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zmetric' AND [key] = 'AutoDeleteMaxRows')
  INSERT INTO zsystem.settings ([group], [key], value, defaultValue, [description])
       VALUES ('zmetric', 'AutoDeleteMaxRows', '50000', '50000', 'Max rows to delete when zmetric.counters.autoDeleteMaxDays (set to "0" to disable).  See proc zmetric.Counters_SaveStats.')
GO

-- Jobs
IF NOT EXISTS(SELECT * FROM zsystem.jobs WHERE jobID = 2000000011)
  INSERT INTO zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], orderID, [disabled])
       VALUES (2000000011, 'CORE - zmetric - Save stats', '', 'EXEC zmetric.Counters_SaveStats', 'SCHEDULE', 0, 0, -9, 1)
GO

-- Lookup tables
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000001)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000001, 'core.db.procs', 'DB - Procs')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000002)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000002, 'core.cache.tableCaches', 'Cache - TableCaches')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000003)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000003, 'core.cache.recordCaches', 'Cache - RecordCaches')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000004)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000004, 'core.machoNet.functions', 'machoNet - Functions')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000005)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000005, 'core.db.indexes', 'DB - Indexes')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000006)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000006, 'core.db.tables', 'DB - Tables')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000007)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000007, 'core.db.filegroups', 'DB - Filegroups')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000008)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000008, 'core.db.waitTypes', 'DB - Wait types')
IF NOT EXISTS(SELECT * FROM zsystem.lookupTables WHERE lookupTableID = 2000000009)
  INSERT INTO zsystem.lookupTables (lookupTableID, lookupTableIdentifier, lookupTableName)
       VALUES (2000000009, 'core.db.perfCounters', 'DB - Performance counters')
GO
