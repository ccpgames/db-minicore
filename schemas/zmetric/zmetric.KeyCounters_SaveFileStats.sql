
IF OBJECT_ID('zmetric.KeyCounters_SaveFileStats') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_SaveFileStats
GO
CREATE PROCEDURE zmetric.KeyCounters_SaveFileStats
  @checkSetting   bit = 1,
  @deleteOldData  bit = 0
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  BEGIN TRY
    IF @checkSetting = 1 AND zsystem.Settings_Value('zmetric', 'SaveFileStats') != '1'
      RETURN

    DECLARE @counterDate date = GETDATE()

    IF @deleteOldData = 1
      DELETE FROM zmetric.keyCounters WHERE counterID = 30009 AND counterDate = @counterDate
    ELSE
    BEGIN
      IF EXISTS(SELECT * FROM zmetric.keyCounters WHERE counterID = 30009 AND counterDate = @counterDate)
        RAISERROR ('File stats data exists', 16, 1)
    END

    -- FILE STATISTICS
    DECLARE @database_name nvarchar(200), @file_type nvarchar(20), @filegroup_name nvarchar(200),
            @reads bigint, @reads_kb bigint, @io_stall_read bigint, @writes bigint, @writes_kb bigint, @io_stall_write bigint, @size_kb bigint,
            @keyText nvarchar(450)

    DECLARE @cursor CURSOR
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT database_name = D.name,
                 file_type = CASE WHEN M.type_desc = 'ROWS' THEN 'DATA' ELSE M.type_desc END,
                 [filegroup_name] = F.name,
                 SUM(S.num_of_reads), SUM(S.num_of_bytes_read) / 1024, SUM(S.io_stall_read_ms),
                 SUM(S.num_of_writes), SUM(S.num_of_bytes_written) / 1024, SUM(S.io_stall_write_ms),
                 SUM(S.size_on_disk_bytes) / 1024
            FROM sys.dm_io_virtual_file_stats(NULL, NULL) S
              LEFT JOIN sys.databases D ON D.database_id = S.database_id
              LEFT JOIN sys.master_files M ON M.database_id = S.database_id AND M.[file_id] = S.[file_id]
                LEFT JOIN sys.filegroups F ON S.database_id = DB_ID() AND F.data_space_id = M.data_space_id
           GROUP BY D.name, M.type_desc, F.name
           ORDER BY database_name, M.type_desc DESC
    OPEN @cursor
    FETCH NEXT FROM @cursor INTO @database_name, @file_type, @filegroup_name, @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @keyText = @database_name + ' :: ' + ISNULL(@filegroup_name, @file_type)

      EXEC zmetric.KeyCounters_InsertMulti 30009, 'D', @counterDate, 2000000007, NULL, @keyText,  @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb

      FETCH NEXT FROM @cursor INTO @database_name, @file_type, @filegroup_name, @reads, @reads_kb, @io_stall_read, @writes, @writes_kb, @io_stall_write, @size_kb
    END
    CLOSE @cursor
    DEALLOCATE @cursor
  END TRY
  BEGIN CATCH
    EXEC zsystem.CatchError 'zmetric.KeyCounters_SaveFileStats'
    RETURN -1
  END CATCH
GO
