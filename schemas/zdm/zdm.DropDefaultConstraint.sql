
IF OBJECT_ID('zdm.DropDefaultConstraint') IS NOT NULL
  DROP PROCEDURE zdm.DropDefaultConstraint
GO
CREATE PROCEDURE zdm.DropDefaultConstraint
  @tableName   nvarchar(256),
  @columnName  nvarchar(128)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @sql nvarchar(4000)
  SELECT @sql = 'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + OBJECT_NAME(default_object_id)
    FROM sys.columns
   WHERE [object_id] = OBJECT_ID(@tableName) AND [name] = @columnName AND default_object_id != 0
  EXEC (@sql)
GO
