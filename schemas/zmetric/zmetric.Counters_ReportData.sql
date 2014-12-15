
IF OBJECT_ID('zmetric.Counters_ReportData') IS NOT NULL
  DROP PROCEDURE zmetric.Counters_ReportData
GO
CREATE PROCEDURE zmetric.Counters_ReportData
  @counterID      smallint,
  @fromDate       date = NULL,
  @toDate         date = NULL,
  @rows           int = 20,
  @orderColumnID  smallint = NULL,
  @orderDesc      bit = 1,
  @lookupText     nvarchar(1000) = NULL
AS
  -- Create dynamic SQL to return report used on INFO - Metrics
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @counterID IS NULL
      RAISERROR ('@counterID not set', 16, 1)

    IF @fromDate IS NULL
      RAISERROR ('@fromDate not set', 16, 1)

    IF @rows > 10000
      RAISERROR ('@rows over limit', 16, 1)

    IF @toDate IS NOT NULL AND @toDate = @fromDate
      SET @toDate = NULL

    DECLARE @counterTable nvarchar(256), @counterType char(1), @subjectLookupTableID int, @keyLookupTableID int
    SELECT @counterTable = counterTable, @counterType = counterType, @subjectLookupTableID = subjectLookupTableID, @keyLookupTableID = keyLookupTableID
      FROM zmetric.counters
     WHERE counterID = @counterID
    IF @counterTable IS NULL AND @counterType = 'D'
      SET @counterTable = 'zmetric.dateCounters'
    IF @counterTable IS NULL OR @counterTable NOT IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters', 'zmetric.dateCounters')
      RAISERROR ('Counter table not supported', 16, 1)
    IF @subjectLookupTableID IS NOT NULL AND @keyLookupTableID IS NULL
      RAISERROR ('Counter is not valid, subject lookup set and key lookup not set', 16, 1)
    IF @counterTable = 'zmetric.keyCounters' AND @subjectLookupTableID IS NOT NULL
      RAISERROR ('Key counter is not valid, subject lookup set', 16, 1)
    IF @counterTable = 'zmetric.subjectKeyCounters' AND (@subjectLookupTableID IS NULL OR @keyLookupTableID IS NULL)
      RAISERROR ('Subject/Key counter is not valid, subject lookup or key lookup not set', 16, 1)

    DECLARE @sql nvarchar(max)

    IF @subjectLookupTableID IS NOT NULL AND @keyLookupTableID IS NOT NULL
    BEGIN
      -- Subject + Key, Single column
      IF @counterType != 'D'
        RAISERROR ('Counter is not valid, subject and key lookup set and counter not of type D', 16, 1)
      SET @sql = 'SELECT TOP (@pRows) C.subjectID, subjectText = ISNULL(S.fullText, S.lookupText), C.keyID, keyText = ISNULL(K.fullText, K.lookupText), '
      IF @toDate IS NULL
        SET @sql = @sql + 'C.value'
      ELSE
        SET @sql = @sql + 'value = SUM(C.value)'
      SET @sql = @sql + CHAR(13) + ' FROM ' + @counterTable + ' C'
      SET @sql = @sql + CHAR(13) + ' LEFT JOIN zsystem.lookupValues S ON S.lookupTableID = @pSubjectLookupTableID AND S.lookupID = C.subjectID'
      SET @sql = @sql + CHAR(13) + ' LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
      SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
      IF @toDate IS NULL
        SET @sql = @sql + 'C.counterDate = @pFromDate'
      ELSE
        SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate'

      -- *** *** *** temporarily hard coding columnID = 0 *** *** ***
      IF @counterTable = 'zmetric.subjectKeyCounters'
        SET @sql = @sql + ' AND C.columnID = 0'

      IF @lookupText IS NOT NULL AND @lookupText != ''
        SET @sql = @sql + ' AND (ISNULL(S.fullText, S.lookupText) LIKE ''%'' + @pLookupText + ''%'' OR ISNULL(K.fullText, K.lookupText) LIKE ''%'' + @pLookupText + ''%'')'
      IF @toDate IS NOT NULL
        SET @sql = @sql + CHAR(13) + ' GROUP BY C.subjectID, ISNULL(S.fullText, S.lookupText), C.keyID, ISNULL(K.fullText, K.lookupText)'
      SET @sql = @sql + CHAR(13) + ' ORDER BY 5'
      IF @orderDesc = 1
        SET @sql = @sql + ' DESC'
      EXEC sp_executesql @sql,
                         N'@pRows int, @pCounterID smallint, @pSubjectLookupTableID int, @pKeyLookupTableID int, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)',
                         @rows, @counterID, @subjectLookupTableID, @keyLookupTableID, @fromDate, @toDate, @lookupText
    END
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.columns WHERE counterID = @counterID)
      BEGIN
        -- Multiple columns (Single value / Multiple key values)
        DECLARE @columnID tinyint, @columnName nvarchar(200), @orderBy nvarchar(200), @sql2 nvarchar(max) = '', @alias nvarchar(10)
        IF @keyLookupTableID IS NULL
          SET @sql = 'SELECT TOP 1 '
        ELSE
          SET @sql = 'SELECT TOP (@pRows) C.keyID, keyText = ISNULL(K.fullText, K.lookupText)'
         SET @sql2 = ' FROM ' + @counterTable + ' C'
        IF @keyLookupTableID IS NOT NULL
          SET @sql2 = @sql2 + CHAR(13) + '    LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
        DECLARE @cursor CURSOR
        SET @cursor = CURSOR LOCAL FAST_FORWARD
          FOR SELECT columnID, columnName FROM zmetric.columns WHERE counterID = @counterID ORDER BY [order], columnID
        OPEN @cursor
        FETCH NEXT FROM @cursor INTO @columnID, @columnName
        WHILE @@FETCH_STATUS = 0
        BEGIN
          IF @orderColumnID IS NULL SET @orderColumnID = @columnID
          IF @columnID = @orderColumnID SET @orderBy = @columnName
          SET @alias = 'C'
          IF @columnID != @orderColumnID
            SET @alias = @alias + CONVERT(nvarchar, @columnID)
          IF @sql != 'SELECT TOP 1 '
            SET @sql = @sql + ',' + CHAR(13) + '       '
          SET @sql = @sql + '[' + @columnName + '] = '
          IF @toDate IS NULL
            SET @sql = @sql + 'ISNULL(' + @alias + '.value, 0)'
          ELSE
            SET @sql = @sql + 'SUM(ISNULL(' + @alias + '.value, 0))'
          IF @columnID = @orderColumnID
            SET @orderBy = '[' + @columnName + ']'
          ELSE
          BEGIN
            SET @sql2 = @sql2 + CHAR(13) + '    LEFT JOIN ' + @counterTable + ' ' + @alias + ' ON ' + @alias + '.counterID = C.counterID'

            IF @counterTable IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters')
              SET @sql2 = @sql2 + ' AND ' + @alias + '.columnID = ' + CONVERT(nvarchar, @columnID)

            IF @counterTable IN ('zmetric.subjectKeyCounters', 'zmetric.dateCounters')
              SET @sql2 = @sql2 + ' AND ' + @alias + '.subjectID = ' + CONVERT(nvarchar, @columnID)

            SET @sql2 = @sql2 + ' AND ' + @alias + '.counterDate = C.counterDate AND ' + @alias + '.keyID = C.keyID'
          END
          FETCH NEXT FROM @cursor INTO @columnID, @columnName
        END
        CLOSE @cursor
        DEALLOCATE @cursor
        SET @sql = @sql + CHAR(13) + @sql2
        SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
        IF @toDate IS NULL
          SET @sql = @sql + 'C.counterDate = @pFromDate AND'
        ELSE
          SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate AND'

        IF @counterTable IN ('zmetric.keyCounters', 'zmetric.subjectKeyCounters')
          SET @sql = @sql + ' C.columnID = ' + CONVERT(nvarchar, @orderColumnID)

        IF @counterTable IN ('zmetric.subjectKeyCounters', 'zmetric.dateCounters')
          SET @sql = @sql + ' C.subjectID = ' + CONVERT(nvarchar, @orderColumnID)

        IF @keyLookupTableID IS NOT NULL
        BEGIN
          IF @lookupText IS NOT NULL AND @lookupText != ''
            SET @sql = @sql + ' AND ISNULL(K.fullText, K.lookupText) LIKE ''%'' + @pLookupText + ''%'''
          IF @toDate IS NOT NULL
            SET @sql = @sql + CHAR(13) + ' GROUP BY C.keyID, ISNULL(K.fullText, K.lookupText)'
          SET @sql = @sql + CHAR(13) + ' ORDER BY ' + @orderBy
          IF @orderDesc = 1
            SET @sql = @sql + ' DESC'
        END
        SET @sql = @sql + CHAR(13) + 'OPTION (FORCE ORDER)'
        EXEC sp_executesql @sql,
                           N'@pRows int, @pCounterID smallint, @pKeyLookupTableID int, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)',
                           @rows, @counterID, @keyLookupTableID, @fromDate, @toDate, @lookupText
      END
      ELSE
      BEGIN
        -- Single column
        IF @keyLookupTableID IS NULL
        BEGIN
          -- Single value, Single column
          SET @sql = 'SELECT TOP 1 '
          IF @toDate IS NULL
            SET @sql = @sql + 'value'
          ELSE
            SET @sql = @sql + 'value = SUM(value)'
          SET @sql = @sql + ' FROM ' + @counterTable + ' WHERE counterID = @pCounterID AND '
          IF @toDate IS NULL
            SET @sql = @sql + 'counterDate = @pFromDate'
          ELSE
            SET @sql = @sql + 'counterDate BETWEEN @pFromDate AND @pToDate'
          EXEC sp_executesql @sql, N'@pCounterID smallint, @pFromDate date, @pToDate date', @counterID, @fromDate, @toDate
        END
        ELSE
        BEGIN
          -- Multiple key values, Single column (not using WHERE subjectID = 0 as its not in the index, trusting that its always 0)
          SET @sql = 'SELECT TOP (@pRows) C.keyID, keyText = ISNULL(K.fullText, K.lookupText), '
          IF @toDate IS NULL
            SET @sql = @sql + 'C.value'
          ELSE
            SET @sql = @sql + 'value = SUM(C.value)'
          SET @sql = @sql + CHAR(13) + '  FROM ' + @counterTable + ' C'
          SET @sql = @sql + CHAR(13) + '    LEFT JOIN zsystem.lookupValues K ON K.lookupTableID = @pKeyLookupTableID AND K.lookupID = C.keyID'
          SET @sql = @sql + CHAR(13) + ' WHERE C.counterID = @pCounterID AND '
          IF @toDate IS NULL
            SET @sql = @sql + 'C.counterDate = @pFromDate'
          ELSE
            SET @sql = @sql + 'C.counterDate BETWEEN @pFromDate AND @pToDate'
          IF @lookupText IS NOT NULL AND @lookupText != ''
            SET @sql = @sql + ' AND ISNULL(K.fullText, K.lookupText) LIKE ''%'' + @pLookupText + ''%'''
          IF @toDate IS NOT NULL
            SET @sql = @sql + CHAR(13) + ' GROUP BY C.keyID, ISNULL(K.fullText, K.lookupText)'
          SET @sql = @sql + CHAR(13) + ' ORDER BY 3'
          IF @orderDesc = 1
            SET @sql = @sql + ' DESC'
          EXEC sp_executesql @sql,
                             N'@pRows int, @pCounterID smallint, @pKeyLookupTableID int, @pFromDate date, @pToDate date, @pLookupText nvarchar(1000)',
                             @rows, @counterID, @keyLookupTableID, @fromDate, @toDate, @lookupText
        END
      END
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.Counters_ReportData'
    RETURN -1
  END CATCH
GO
GRANT EXEC ON zmetric.Counters_ReportData TO zzp_server
GO
