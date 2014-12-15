
IF OBJECT_ID('zdm.tableusage') IS NOT NULL
  DROP PROCEDURE zdm.tableusage
GO
CREATE PROCEDURE zdm.tableusage
  @tableName  nvarchar(256) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT t.[name], i.[name], s.*
    FROM sys.dm_db_index_usage_stats s
      LEFT JOIN sys.tables t ON t.[object_id] = s.[object_id]
      LEFT JOIN sys.indexes i ON i.[object_id] = s.[object_id] AND i.index_id = s.index_id
   WHERE s.database_id = DB_ID() AND s.[object_id] = OBJECT_ID(@tableName)
   ORDER BY t.name, s.index_id
GO
