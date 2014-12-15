
IF OBJECT_ID('zdm.DuplicateData') IS NOT NULL
  DROP PROCEDURE zdm.DuplicateData
GO
CREATE PROCEDURE zdm.DuplicateData
  @tableName   nvarchar(256),
  @oldKeyID    bigint,
  @newKeyID    bigint = NULL OUTPUT,
  @keyColumn   nvarchar(128) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @columns nvarchar(max) = '', @identityColumn nvarchar(128)

  DECLARE @columnName nvarchar(128), @isIdentity bit

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT name, is_identity FROM sys.columns WHERE [object_id] = OBJECT_ID(@tableName) ORDER BY column_id
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @columnName, @isIdentity
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF @isIdentity = 1
      SET @identityColumn = @columnName
    ELSE
    BEGIN
      IF @keyColumn IS NULL OR @columnName != @keyColumn
      BEGIN
        IF @columns = ''
          SET @columns = @columnName
        ELSE
          SET @columns += ', ' + @columnName
      END
    END

    FETCH NEXT FROM @cursor INTO @columnName, @isIdentity
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  IF @identityColumn IS NULL
  BEGIN
    RAISERROR ('Identity column not found', 16, 1)
    RETURN -1
  END

  DECLARE @stmt nvarchar(max)
  SET @stmt = 'INSERT INTO ' + @tableName + ' ('
  IF @keyColumn IS NOT NULL
    SET @stmt += @keyColumn + ', '
  SET @stmt += @columns + ')' + CHAR(13)
            + '     SELECT '
  IF @keyColumn IS NOT NULL
    SET @stmt += CONVERT(nvarchar, @newKeyID) + ', '
  SET @stmt += @columns + CHAR(13)
            + '       FROM ' + @tableName + CHAR(13)
            + '      WHERE '
  SET @stmt += ISNULL(@keyColumn, @identityColumn)
  SET @stmt += ' = ' + CONVERT(nvarchar, @oldKeyID)
  IF @keyColumn IS NULL
    SET @stmt += ';' + CHAR(13) + 'SET @pNewKeyID = SCOPE_IDENTITY()'
  EXEC sp_executesql @stmt, N'@pNewKeyID int OUTPUT', @newKeyID OUTPUT
GO
