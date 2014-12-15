
IF OBJECT_ID('zsystem.Identities_Insert') IS NOT NULL
  DROP PROCEDURE zsystem.Identities_Insert
GO
CREATE PROCEDURE zsystem.Identities_Insert
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @identityDate date
  SET @identityDate = DATEADD(minute, 5, GETUTCDATE())

  DECLARE @maxi int, @maxb bigint, @stmt nvarchar(4000), @objectID int

  DECLARE @tableID int, @tableName nvarchar(256), @keyID nvarchar(128), @keyDate nvarchar(128), @logIdentity tinyint

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT T.tableID, QUOTENAME(S.schemaName) + '.' + QUOTENAME(T.tableName), QUOTENAME(T.keyID), T.keyDate, T.logIdentity
          FROM zsystem.tables T
            INNER JOIN zsystem.schemas S ON S.schemaID = T.schemaID
         WHERE T.logIdentity IN (1, 2) AND ISNULL(T.keyID, '') != ''
         ORDER BY tableID
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @objectID = OBJECT_ID(@tableName)
    IF @objectID IS NOT NULL
    BEGIN
      IF @keyDate IS NOT NULL
      BEGIN
        IF EXISTS(SELECT * FROM sys.columns WHERE [object_id] = @objectID AND name = @keyDate)
          SET @keyDate = QUOTENAME(@keyDate)
        ELSE
          SET @keyDate = NULL
      END

      IF @logIdentity = 1
      BEGIN
        SET @maxi = NULL
        SET @stmt = 'SELECT TOP 1 @p_maxi = ' + @keyID + ' FROM ' + @tableName
        IF @keyDate IS NOT NULL
          SET @stmt = @stmt + ' WHERE ' + @keyDate + ' < @p_date'
        SET @stmt = @stmt + ' ORDER BY ' + @keyID + ' DESC'
        EXEC sp_executesql @stmt, N'@p_maxi int OUTPUT, @p_date datetime2(0)', @maxi OUTPUT, @identityDate
        IF @maxi IS NOT NULL
        BEGIN
          SET @maxi = @maxi + 1
          INSERT INTO zsystem.identities (tableID, identityDate, identityInt)
               VALUES (@tableID, @identityDate, @maxi)
        END
      END
      ELSE
      BEGIN
        SET @maxb = NULL
        SET @stmt = 'SELECT TOP 1 @p_maxb = ' + @keyID + ' FROM ' + @tableName
        IF @keyDate IS NOT NULL
          SET @stmt = @stmt + ' WHERE ' + @keyDate + ' < @p_date'
        SET @stmt = @stmt + ' ORDER BY ' + @keyID + ' DESC'
        EXEC sp_executesql @stmt, N'@p_maxb bigint OUTPUT, @p_date datetime2(0)', @maxb OUTPUT, @identityDate
        IF @maxb IS NOT NULL
        BEGIN
          SET @maxb = @maxb + 1
          INSERT INTO zsystem.identities (tableID, identityDate, identityBigInt)
               VALUES (@tableID, @identityDate, @maxb)
        END
      END
    END

    FETCH NEXT FROM @cursor INTO @tableID, @tableName, @keyID, @keyDate, @logIdentity
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO
