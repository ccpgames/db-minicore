
IF OBJECT_ID('zdm.findusage') IS NOT NULL
  DROP PROCEDURE zdm.findusage
GO
CREATE PROCEDURE zdm.findusage
  @usageText  nvarchar(256),
  @describe   bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @objectID int, @objectName nvarchar(256), @text nvarchar(max), @somethingFound bit = 0

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT O.[object_id], S.name + '.' + O.name
          FROM sys.objects O
            INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
         WHERE O.is_ms_shipped = 0 AND O.type IN ('V', 'P', 'FN', 'IF') -- View, Procedure, Scalar Function, Table Function
         ORDER BY O.type_desc, S.name, O.name
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @objectID, @objectName
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @text = OBJECT_DEFINITION(@objectID)
    IF CHARINDEX(@usageText, @text) > 0
    BEGIN
      SET @somethingFound = 1

      IF @describe = 0
        PRINT @objectName
      ELSE
      BEGIN
        EXEC zdm.describe @objectName
        PRINT ''
        PRINT REPLICATE('#', 100)
      END
    END

    FETCH NEXT FROM @cursor INTO @objectID, @objectName
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  IF @somethingFound = 0
    PRINT 'No usage found!'
GO
