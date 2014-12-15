
IF OBJECT_ID('zmetric.KeyCounters_SavePerfCountersInstance') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SavePerfCountersInstance
GO
CREATE PROCEDURE zmetric.KeyCounters_SavePerfCountersInstance
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SavePerfCountersInstance') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30028 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30028 AND counterDate = @counterDate)
        RAISERROR ('Performance counters instance data exists', 16, 1)
    END

    -- PERFORMANCE COUNTERS INSTANCE
    DECLARE @object_name nvarchar(200), @counter_name nvarchar(200), @cntr_value bigint, @keyID int, @keyText nvarchar(450)

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT REPLACE(RTRIM([object_name]), 'SQLServer:', ''), RTRIM(counter_name), cntr_value
            FROM sys.dm_os_performance_counters
           WHERE cntr_type = 272696576 AND cntr_value != 0 AND instance_name = DB_NAME()
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @keyText = @object_name + ' :: ' + @counter_name

      EXEC @keyID = zsystem.LookupValues_Update 2000000009, NULL, @keyText

      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (30028, @counterDate, 0, @keyID, @cntr_value)

      FETCH NEXT FROM @cursor INTO @object_name, @counter_name, @cntr_value
    END
    CLOSE @cursor
    DEALLOCATE @cursor
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SavePerfCountersInstance'
    RETURN -1
  END CATCH
GO
