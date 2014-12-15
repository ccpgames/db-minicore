
IF OBJECT_ID('zdm.RebuildDependencies') IS NOT NULL
  DROP PROCEDURE zdm.RebuildDependencies
GO
CREATE PROCEDURE zdm.RebuildDependencies
  @listAllObjects  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @objectName nvarchar(500), @typeName nvarchar(60)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT QUOTENAME(S.name) + '.' + QUOTENAME(O.name), O.type_desc
          FROM sys.objects O
            INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
         WHERE O.is_ms_shipped = 0 AND O.[type] IN ('FN', 'IF', 'P', 'V')
         ORDER BY O.[type], S.name, O.name
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @objectName, @typeName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF @listAllObjects = 1
      PRINT @typeName + ' : ' + @objectName

    BEGIN TRY
      EXEC sp_refreshsqlmodule @objectName
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION
      IF @listAllObjects = 0
        PRINT @typeName + ' : ' + @objectName
      PRINT '  ' + ERROR_MESSAGE()
    END CATCH

    FETCH NEXT FROM @cursor INTO @objectName, @typeName
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  SET NOCOUNT OFF 
GO
