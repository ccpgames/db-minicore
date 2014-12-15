
--
-- SCHEMA
--

IF SCHEMA_ID('zdm') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zdm'
GO


--
-- DATA
--

-- Schema
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000008)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000008, 'zdm', 'CORE - Dynamic Management, procedures to help with SQL Server management (mostly for DBA''s).', 'http://core/wiki/DB_zdm')
GO

-- Settings
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zdm' AND [key] = 'Recipients-LongRunning')
  INSERT INTO zsystem.settings ([group], [key], [value], [description])
       VALUES ('zdm', 'Recipients-LongRunning', '', 'Mail recipients for long running SQL notifications')
IF NOT EXISTS(SELECT * FROM zsystem.settings WHERE [group] = 'zdm' AND [key] = 'LongRunning-IgnoreSQL')
  INSERT INTO zsystem.settings ([group], [key], [value], [description])
       VALUES ('zdm', 'LongRunning-IgnoreSQL', '%--DBA%', 'Ignore SQL in long running SQL notifications.  Comma delimited list things to use in NOT LIKE.')
GO
