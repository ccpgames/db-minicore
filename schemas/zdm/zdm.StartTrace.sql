
IF OBJECT_ID('zdm.StartTrace') IS NOT NULL
  DROP PROCEDURE zdm.StartTrace
GO
CREATE PROCEDURE zdm.StartTrace
  @fileName         nvarchar(200),
  @minutes          smallint,
  @duration         bigint = NULL,
  @reads            bigint = NULL,
  @writes           bigint = NULL,
  @cpu              int = NULL,
  @rowCounts        bigint = NULL,
  @objectName       nvarchar(100) = NULL,
  @hostName         nvarchar(100) = NULL,
  @clientProcessID  nvarchar(100) = NULL,
  @databaseName     nvarchar(100) = NULL,
  @loginName        nvarchar(100) = NULL,
  @logicalOperator  int = 0,
  @maxFileSize      bigint = 4096
AS
  SET NOCOUNT ON

  -- Create trace
  DECLARE @rc int, @traceID int, @stopTime datetime2(0)
  SET @stopTime = DATEADD(minute, @minutes, GETDATE())
  EXEC @rc = sp_trace_create @traceID OUTPUT, 0, @fileName, @maxFileSize, @stopTime
  IF @rc != 0
  BEGIN
    RAISERROR ('Error in sp_trace_create (ErrorCode = %d)', 16, 1, @rc)
    RETURN -1
  END

  -- Event: RPC:Completed
  DECLARE @off bit, @on bit
  SELECT @off = 0, @on = 1
  EXEC sp_trace_setevent @traceID, 10, 14, @on  -- StartTime
  EXEC sp_trace_setevent @traceID, 10, 15, @on  -- EndTime
  EXEC sp_trace_setevent @traceID, 10, 34, @on  -- ObjectName
  EXEC sp_trace_setevent @traceID, 10,  1, @on  -- TextData
  EXEC sp_trace_setevent @traceID, 10, 13, @on  -- Duration
  EXEC sp_trace_setevent @traceID, 10, 16, @on  -- Reads
  EXEC sp_trace_setevent @traceID, 10, 17, @on  -- Writes
  EXEC sp_trace_setevent @traceID, 10, 18, @on  -- CPU
  EXEC sp_trace_setevent @traceID, 10, 48, @on  -- RowCounts
  EXEC sp_trace_setevent @traceID, 10,  8, @on  -- HostName
  EXEC sp_trace_setevent @traceID, 10,  9, @on  -- ClientProcessID
  EXEC sp_trace_setevent @traceID, 10, 12, @on  -- SPID
  EXEC sp_trace_setevent @traceID, 10, 10, @on  -- ApplicationName
  EXEC sp_trace_setevent @traceID, 10, 11, @on  -- LoginName
  EXEC sp_trace_setevent @traceID, 10, 35, @on  -- DatabaseName
  EXEC sp_trace_setevent @traceID, 10, 31, @on  -- Error

  -- Event: SQL:BatchCompleted
  IF @objectName IS NULL
  BEGIN
    EXEC sp_trace_setevent @traceID, 12, 14, @on  -- StartTime
    EXEC sp_trace_setevent @traceID, 12, 15, @on  -- EndTime
    EXEC sp_trace_setevent @traceID, 12, 34, @on  -- ObjectName
    EXEC sp_trace_setevent @traceID, 12,  1, @on  -- TextData
    EXEC sp_trace_setevent @traceID, 12, 13, @on  -- Duration
    EXEC sp_trace_setevent @traceID, 12, 16, @on  -- Reads
    EXEC sp_trace_setevent @traceID, 12, 17, @on  -- Writes
    EXEC sp_trace_setevent @traceID, 12, 18, @on  -- CPU
    EXEC sp_trace_setevent @traceID, 12, 48, @on  -- RowCounts
    EXEC sp_trace_setevent @traceID, 12,  8, @on  -- HostName
    EXEC sp_trace_setevent @traceID, 12,  9, @on  -- ClientProcessID
    EXEC sp_trace_setevent @traceID, 12, 12, @on  -- SPID
    EXEC sp_trace_setevent @traceID, 12, 10, @on  -- ApplicationName
    EXEC sp_trace_setevent @traceID, 12, 11, @on  -- LoginName
    EXEC sp_trace_setevent @traceID, 12, 35, @on  -- DatabaseName
    EXEC sp_trace_setevent @traceID, 12, 31, @on  -- Error
  END

  -- Filter: Duration
  IF @duration > 0
  BEGIN
    SET @duration = @duration * 1000
    EXEC sp_trace_setfilter @traceID, 13, @logicalOperator, 4, @duration
  END
  -- Filter: Reads
  IF @reads > 0
    EXEC sp_trace_setfilter @traceID, 16, @logicalOperator, 4, @reads
  -- Filter: Writes
  IF @writes > 0
    EXEC sp_trace_setfilter @traceID, 17, @logicalOperator, 4, @writes
  -- Filter: CPU
  IF @cpu > 0
    EXEC sp_trace_setfilter @traceID, 18, @logicalOperator, 4, @cpu
  -- Filter: RowCounts
  IF @rowCounts > 0
    EXEC sp_trace_setfilter @traceID, 48, @logicalOperator, 4, @rowCounts
  -- Filter: ObjectName
  IF @objectName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 34, @logicalOperator, 6, @objectName
  -- Filter: HostName
  IF @hostName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 8, @logicalOperator, 6, @hostName
  -- Filter: ClientProcessID
  IF @clientProcessID > 0
    EXEC sp_trace_setfilter @traceID, 9, @logicalOperator, 0, @clientProcessID
  -- Filter: DatabaseName
  IF @databaseName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 35, @logicalOperator, 6, @databaseName
  -- Filter: LoginName
  IF @loginName IS NOT NULL
    EXEC sp_trace_setfilter @traceID, 11, @logicalOperator, 6, @loginName

  -- Start trace
  EXEC sp_trace_setstatus @traceID, 1

  -- Return traceID and some extra help info
  SELECT traceID = @traceID,
         [To list active traces] = 'SELECT * FROM sys.traces',
         [To stop trace before minutes are up] = 'EXEC sp_trace_setstatus ' + CONVERT(varchar, @traceID) + ', 0;EXEC sp_trace_setstatus ' + CONVERT(varchar, @traceID) + ', 2'
GO
