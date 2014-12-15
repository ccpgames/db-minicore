
IF OBJECT_ID('zsystem.Table_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Table_Select
GO
CREATE PROCEDURE zsystem.Table_Select
  @schemaName    nvarchar(128),
  @tableName     nvarchar(128)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    DECLARE @sql nvarchar(4000)
    SET @sql = ''
    SELECT @sql = @sql + ', ' + QUOTENAME(name)
      FROM sys.columns
     WHERE [object_id] = OBJECT_ID(@schemaName + '.' + @tableName)
     ORDER BY column_id
    SET @sql = 'SELECT ' + SUBSTRING(@sql, 3, 4000) + ' FROM ' + QUOTENAME(@schemaName) + '.' + QUOTENAME(@tableName) + ' ORDER BY 1'
    EXEC sp_executesql @sql
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.Table_Select'
    RETURN -1
  END CATCH
GO
