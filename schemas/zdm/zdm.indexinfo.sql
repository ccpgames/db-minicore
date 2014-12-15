
IF OBJECT_ID('zdm.indexinfo') IS NOT NULL
  DROP PROCEDURE zdm.indexinfo
GO
CREATE PROCEDURE zdm.indexinfo
  @tableName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF @tableName IS NOT NULL AND OBJECT_ID(@tableName) IS NULL
  BEGIN
    RAISERROR ('Table not found !!!', 16, 1)
    RETURN -1
  END

  SELECT info = 'avg_fragmentation_in_percent - should be LOW'
  UNION ALL
  SELECT info = 'fragment_count - should be LOW'
  UNION ALL
  SELECT info = 'avg_fragment_size_in_pages - should be HIGH'

  SELECT table_name = t.[name], index_name = i.[name], s.*
    FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(@tableName), NULL, NULL, NULL) s
      LEFT JOIN sys.tables t ON t.[object_id] = s.[object_id]
      LEFT JOIN sys.indexes i ON i.[object_id] = s.[object_id] AND i.index_id = s.index_id
   ORDER BY s.avg_fragmentation_in_percent DESC
GO
