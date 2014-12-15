
IF OBJECT_ID('zdm.stats') IS NOT NULL
  DROP PROCEDURE zdm.stats
GO
CREATE PROCEDURE zdm.stats
  @objectName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  IF OBJECT_ID(@objectName) IS NULL
  BEGIN
    PRINT 'Object not found!'
    RETURN
  END

  EXEC sp_autostats @objectName

  DECLARE @stmt nvarchar(4000)
  DECLARE @indexName nvarchar(128)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT name FROM sys.indexes WHERE [object_id] = OBJECT_ID(@objectName) ORDER BY index_id
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @indexName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @stmt = 'DBCC SHOW_STATISTICS (''' + @objectName + ''', ''' + @indexName + ''')'
    EXEC sp_executesql @stmt

    FETCH NEXT FROM @cursor INTO @indexName
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO
