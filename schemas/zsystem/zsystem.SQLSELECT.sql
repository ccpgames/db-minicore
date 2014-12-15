
IF OBJECT_ID('zsystem.SQLSELECT') IS NOT NULL
  DROP PROCEDURE zsystem.SQLSELECT
GO
CREATE PROCEDURE zsystem.SQLSELECT
  @sql  nvarchar(max)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SET ROWCOUNT 1000

  BEGIN TRY
    IF CHARINDEX(';', @sql) > 0
      RAISERROR ('Semicolon in SQL', 13, 1)

    DECLARE @usql nvarchar(4000)
    SET @usql = UPPER(@sql)

    IF NOT @usql LIKE 'SELECT %'
      RAISERROR ('SQL must start with SELECT ', 13, 1)

    IF CHARINDEX('INSERT', @usql) > 0
      RAISERROR ('INSERT in SQL', 13, 1)

    IF CHARINDEX('INTO', @usql) > 0
      RAISERROR ('INTO in SQL', 13, 1)

    IF CHARINDEX('UPDATE', @usql) > 0
      RAISERROR ('UPDATE in SQL', 13, 1)

    IF CHARINDEX('DELETE', @usql) > 0
      RAISERROR ('DELETE in SQL', 13, 1)

    IF CHARINDEX('TRUNCATE', @usql) > 0
      RAISERROR ('TRUNCATE in SQL', 13, 1)

    IF CHARINDEX('CREATE', @usql) > 0
      RAISERROR ('CREATE in SQL', 13, 1)

    IF CHARINDEX('ALTER', @usql) > 0
      RAISERROR ('ALTER in SQL', 13, 1)

    IF CHARINDEX('DROP', @usql) > 0
      RAISERROR ('DROP in SQL', 13, 1)

    IF CHARINDEX('EXEC', @usql) > 0
      RAISERROR ('EXEC in SQL', 13, 1)

    EXEC sp_executesql @sql
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zsystem.SQLSELECT'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zsystem.SQLSELECT TO zzp_server
GO
