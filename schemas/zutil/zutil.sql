
--
-- SCHEMA
--

IF SCHEMA_ID('zutil') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zutil'
GO


--
-- DATA
--

-- Schema
IF NOT EXISTS(SELECT * FROM zsystem.schemas WHERE schemaID = 2000000007)
  INSERT INTO zsystem.schemas (schemaID, schemaName, [description], webPage)
       VALUES (2000000007, 'zutil', 'CORE - Utility functions', 'http://core/wiki/DB_zutil')
GO
