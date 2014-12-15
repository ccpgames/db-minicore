
IF OBJECT_ID('zmetric.KeyCounters_SavePerfCountersTotal') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SavePerfCountersTotal
GO
CREATE PROCEDURE zmetric.KeyCounters_SavePerfCountersTotal
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SavePerfCountersTotal') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30027 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30027 AND counterDate = @counterDate)
        RAISERROR ('Performance counters total data exists', 16, 1)
    END

    -- PERFORMANCE COUNTERS TOTAL
    DECLARE @object_name nvarchar(200), @counter_name nvarchar(200), @cntr_value bigint, @keyID int, @keyText nvarchar(450)

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT REPLACE(RTRIM([object_name]), 'SQLServer:', ''),
                 CASE WHEN [object_name] = 'SQLServer:SQL Errors' THEN RTRIM(instance_name) ELSE RTRIM(counter_name) END,
                 cntr_value
            FROM sys.dm_os_performance_counters
           WHERE cntr_type = 272696576
             AND cntr_value != 0
             AND (    ([object_name] = 'SQLServer:Access Methods' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Buffer Manager' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:General Statistics' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Latches' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Access Methods' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:SQL Statistics' AND instance_name = '')
                   OR ([object_name] = 'SQLServer:Databases' AND instance_name = '_Total')
                   OR ([object_name] = 'SQLServer:Locks' AND instance_name = '_Total')
                   OR ([object_name] = 'SQLServer:SQL Errors' AND instance_name != '_Total')
                 )
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @keyText = @object_name + ' :: ' + @counter_name

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, @keyText

      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @cntr_value)

      FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    END
    CLOSE @cursor
    DEALLOCATE @cursor

    -- ADDING A FEW SYSTEM FUNCTIONS TO THE MIX
    -- Azure does not support @@PACK_RECEIVED, @@PACK_SENT, @@PACKET_ERRORS, @@TOTAL_READ, @@TOTAL_WRITE and @@TOTAL_ERRORS
    IF CONVERT(varchar(max), SERVERPROPERTY('edition')) NOT LIKE '%Azure%'
    BEGIN
      DECLARE @pack_received int, @pack_sent int, @packet_errors int, @total_read int, @total_write int, @total_errors int

      EXEC sp_executesql N'
        SELECT @pack_received = @@PACK_RECEIVED, @pack_sent = @@PACK_SENT, @packet_errors = @@PACKET_ERRORS,
               @total_read = @@TOTAL_READ, @total_write = @@TOTAL_WRITE, @total_errors = @@TOTAL_ERRORS',
        N'@pack_received int OUTPUT, @pack_sent int OUTPUT, @packet_errors int OUTPUT, @total_read int OUTPUT, @total_write int OUTPUT, @total_errors int OUTPUT',
        @pack_received OUTPUT, @pack_sent OUTPUT, @packet_errors OUTPUT, @total_read OUTPUT, @total_write OUTPUT, @total_errors OUTPUT

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@PACK_RECEIVED'
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @pack_received)

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@PACK_SENT'
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @pack_sent)

      IF @packet_errors != 0
      BEGIN
        EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@PACKET_ERRORS'
        INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @packet_errors)
      END

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@TOTAL_READ'
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @total_read)

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@TOTAL_WRITE'
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @total_write)

      IF @total_errors != 0
      BEGIN
        EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, '@@TOTAL_ERRORS'
        INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30027, @counterDate, 0, @keyID, @total_errors)
      END
    END
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SavePerfCountersTotal'
    RETURN -1
  END CATCH
GO
