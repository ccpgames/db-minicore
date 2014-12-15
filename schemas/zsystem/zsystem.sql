
--
-- ROLES
--

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'zzp_server')
  CREATE ROLE zzp_server
GO


--
-- SCHEMA
--

IF SCHEMA_ID('zsystem') IS NULL
  EXEC sp_executesql N'CREATE SCHEMA zsystem'
GO
