
IF OBJECT_ID('zmetric.KeyCounters_SaveIndexStats') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SaveIndexStats
GO
CREATE PROCEDURE zmetric.KeyCounters_SaveIndexStats
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SaveIndexStats') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
    BEGIN
      DELETE FROM zmetric.keyCounters WHERE counterID = 30007 AND counterDate = @counterDate
      DELETE FROM zmetric.keyCounters WHERE counterID = 30008 AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30007 AND counterDate = @counterDate)
        RAISERROR ('Index stats data exists', 16, 1)
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30008 AND counterDate = @counterDate)
        RAISERROR ('Table stats data exists', 16, 1)
    END

    DECLARE @indexStats TABLE
    (
      tableName    nvarchar(450)  NOT NULL,
      indexName    nvarchar(450)  NOT NULL,
      [rows]       bigint         NOT NULL,
      total_kb     bigint         NOT NULL,
      used_kb      bigint         NOT NULL,
      data_kb      bigint         NOT NULL,
      user_seeks   bigint         NULL,
      user_scans   bigint         NULL,
      user_lookups bigint         NULL,
      user_updates bigint         NULL
    )
    INSERT INTO @indexStats (tableName, indexName, [rows], total_kb, used_kb, data_kb, user_seeks, user_scans, user_lookups, user_updates)
         SELECT S.name + '.' + T.name, ISNULL(I.name, 'HEAP'),
                SUM(P.row_count),
                SUM(P.reserved_page_count * 8), SUM(P.used_page_count * 8), SUM(P.in_row_data_page_count * 8),
                MAX(U.user_seeks), MAX(U.user_scans), MAX(U.user_lookups), MAX(U.user_updates)
           FROM sys.tables T
             INNER JOIN sys.schemas S ON S.[schema_id] = T.[schema_id]
             INNER JOIN sys.indexes I ON I.[object_id] = T.[object_id]
               INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
               LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id = DB_ID() AND U.[object_id] = I.[object_id] AND U.index_id = I.index_id
          WHERE T.is_ms_shipped != 1
          GROUP BY S.name, T.name, I.name
          ORDER BY S.name, T.name, I.name

    DECLARE @rows bigint, @total_kb bigint, @used_kb bigint, @data_kb bigint,
            @user_seeks bigint, @user_scans bigint, @user_lookups bigint, @user_updates bigint,
            @keyText nvarchar(450), @keyID int

    -- INDEX STATISTICS
    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT tableName + '.' + indexName, [rows], total_kb, used_kb, data_kb, user_seeks, user_scans, user_lookups, user_updates
            FROM @indexStats
           ORDER BY tableName, indexName
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC zmetric.KeyCounters_InsertMulti 30007, 'D', @counterDate, 2000000005, NULL, @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates

      FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    END
    CLOSE @cursor
    DEALLOCATE @cursor

    -- TABLE STATISTICS
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT tableName, MAX([rows]), SUM(total_kb), SUM(used_kb), SUM(data_kb), MAX(user_seeks), MAX(user_scans), MAX(user_lookups), MAX(user_updates)
            FROM @indexStats
           GROUP BY tableName
           ORDER BY tableName
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC zmetric.KeyCounters_InsertMulti 30008, 'D', @counterDate, 2000000006, NULL, @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates

      FETCH NEXT FROM @cursor INTO @keyText, @rows, @total_kb, @used_kb, @data_kb, @user_seeks, @user_scans, @user_lookups, @user_updates
    END
    CLOSE @cursor
    DEALLOCATE @cursor

    -- MAIL
    DECLARE @recipients varchar(max)
    SET @recipients = zsystem.Settings_Value('zmetric', 'Recipients-IndexStats')
    IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
    BEGIN
      DECLARE @subtractDate date
      SET @subtractDate = DATEADD(day, -1, @counterDate)

      -- SEND MAIL...
      DECLARE @subject nvarchar(255)
      SET @subject = HOST_NAME() + '.' + DB_NAME() + ': Index Statistics'

      DECLARE @body nvarchar(MAX)
      SET @body = 
        -- rows
          N'<h3><font color=blue>Top 30 rows</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">table</th><th>rows</th><th>total_MB</th><th>used_MB</th><th>data_MB</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C1.value, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C2.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C3.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C4.value / 1024, 1), ''
          FROM zmetric.keyCounters C1
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000006 AND L.lookupID = C1.keyID
            LEFT JOIN zmetric.keyCounters C2 ON C2.counterID = C1.counterID AND C2.counterDate = C1.counterDate AND C2.columnID = 2 AND C2.keyID = C1.keyID
            LEFT JOIN zmetric.keyCounters C3 ON C3.counterID = C1.counterID AND C3.counterDate = C1.counterDate AND C3.columnID = 3 AND C3.keyID = C1.keyID
            LEFT JOIN zmetric.keyCounters C4 ON C4.counterID = C1.counterID AND C4.counterDate = C1.counterDate AND C4.columnID = 4 AND C4.keyID = C1.keyID
         WHERE C1.counterID = 30008 AND C1.counterDate = @counterDate AND C1.columnID = 1
         ORDER BY C1.value DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- total_MB
        + N'<h3><font color=blue>Top 30 total_MB</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">table</th><th>total_MB</th><th>used_MB</th><th>data_MB</th><th>rows</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C2.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C3.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.IntToNvarchar(C4.value / 1024, 1), '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C1.value, 1), ''
          FROM zmetric.keyCounters C2
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000006 AND L.lookupID = C2.keyID
            LEFT JOIN zmetric.keyCounters C3 ON C3.counterID = C2.counterID AND C3.counterDate = C2.counterDate AND C3.columnID = 3 AND C3.keyID = C2.keyID
            LEFT JOIN zmetric.keyCounters C4 ON C4.counterID = C2.counterID AND C4.counterDate = C2.counterDate AND C4.columnID = 4 AND C4.keyID = C2.keyID
            LEFT JOIN zmetric.keyCounters C1 ON C1.counterID = C2.counterID AND C1.counterDate = C2.counterDate AND C1.columnID = 1 AND C1.keyID = C2.keyID
         WHERE C2.counterID = 30008 AND C2.counterDate = @counterDate AND C2.columnID = 2
         ORDER BY C2.value DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_seeks (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_seeks</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C5.value - ISNULL(C5B.value, 0), 1), ''
          FROM zmetric.keyCounters C5
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C5.keyID
            LEFT JOIN zmetric.keyCounters C5B ON C5B.counterID = C5.counterID AND C5B.counterDate = @subtractDate AND C5B.columnID = C5.columnID AND C5B.keyID = C5.keyID
         WHERE C5.counterID = 30007 AND C5.counterDate = @counterDate AND C5.columnID = 5
         ORDER BY (C5.value - ISNULL(C5B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_scans (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_scans</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C6.value - ISNULL(C6B.value, 0), 1), ''
          FROM zmetric.keyCounters C6
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C6.keyID
            LEFT JOIN zmetric.keyCounters C6B ON C6B.counterID = C6.counterID AND C6B.counterDate = @subtractDate AND C6B.columnID = C6.columnID AND C6B.keyID = C6.keyID
         WHERE C6.counterID = 30007 AND C6.counterDate = @counterDate AND C6.columnID = 6
         ORDER BY (C6.value - ISNULL(C6B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_lookups (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_lookups</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C7.value - ISNULL(C7B.value, 0), 1), ''
          FROM zmetric.keyCounters C7
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C7.keyID
            LEFT JOIN zmetric.keyCounters C7B ON C7B.counterID = C7.counterID AND C7B.counterDate = @subtractDate AND C7B.columnID = C7.columnID AND C7B.keyID = C7.keyID
         WHERE C7.counterID = 30007 AND C7.counterDate = @counterDate AND C7.columnID = 7
         ORDER BY (C7.value - ISNULL(C7B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

        -- user_updates (accumulative count, subtracting the value from the day before)
        + N'<h3><font color=blue>Top 30 user_updates</font></h3>'
        + N'<table border="1">'
        + N'<tr>'
        + N'<th align="left">index</th><th>count</th>'
        + N'</tr>'
        + ISNULL(CAST((
        SELECT TOP 30 td = L.lookupText, '',
               [td/@align] = 'right', td = zutil.BigintToNvarchar(C8.value - ISNULL(C8B.value, 0), 1), ''
          FROM zmetric.keyCounters C8
            LEFT JOIN zsystem.lookupValues L ON L.lookupTableID = 2000000005 AND L.lookupID = C8.keyID
            LEFT JOIN zmetric.keyCounters C8B ON C8B.counterID = C8.counterID AND C8B.counterDate = @subtractDate AND C8B.columnID = C8.columnID AND C8B.keyID = C8.keyID
         WHERE C8.counterID = 30007 AND C8.counterDate = @counterDate AND C8.columnID = 8
         ORDER BY (C8.value - ISNULL(C8B.value, 0)) DESC
               FOR XML PATH('tr'), TYPE) AS nvarchar(MAX)), '<tr></tr>')
        + N'</table>'

      EXEC zsystem.SendMail @recipients, @subject, @body, 'HTML'
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SaveIndexStats'
    RETURN -1
  END CATCH
GO
