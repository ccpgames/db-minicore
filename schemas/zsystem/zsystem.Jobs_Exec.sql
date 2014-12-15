
IF OBJECT_ID('zsystem.Jobs_Exec') IS NOT NULL
  DROP PROCEDURE zsystem.Jobs_Exec
GO
CREATE PROCEDURE zsystem.Jobs_Exec
  @group  nvarchar(100) = 'SCHEDULE',
  @part   smallint = NULL
AS
  -- This proc must be called every 10 minutes in a SQL Agent job, no more and no less
  -- @part...
  --   NULL: Use hour:minute (typically used for group SCHEDULE)
  --      0: Execute all parts (typically used for group DOWNTIME)
  --     >0: Execute only that part (typically used for group DOWNTIME)
  -- When @part is NULL...
  --   If week/day/hour/minute is NULL job executes every time the proc is called (every 10 minutes)
  --   If week/day/hour is NULL job executes every hour on the minutes set
  SET NOCOUNT ON

  DECLARE @now datetime2(0), @day tinyint
  SELECT @now = GETUTCDATE(), @day = DATEPART(weekday, @now)

  DECLARE @week tinyint, @r real
  SET @r = DAY(@now) / 7.0
  IF @r <= 1.0 SET @week = 1
  ELSE IF @r <= 2.0 SET @week = 2
  ELSE IF @r <= 3.0 SET @week = 3
  ELSE IF @r <= 4.0 SET @week = 4

  DECLARE @jobID int, @jobName nvarchar(200), @sql nvarchar(max), @logStarted bit, @logCompleted bit, @eventID int, @eventText nvarchar(max)

  DECLARE @cursor CURSOR

  IF @part IS NULL
  BEGIN
    DECLARE @hour tinyint, @minute tinyint
    SELECT @hour = DATEPART(hour, @now), @minute = (DATEPART(minute, @now) / 10) * 10

    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND [disabled] = 0 AND
                 (([week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] IS NULL)
                  OR
                  ([week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] = @minute)
                  OR
                  ([hour] = @hour AND [minute] = @minute AND ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)))
           ORDER BY orderID
  END
  ELSE IF @part = 0
  BEGIN
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND [disabled] = 0 AND
                 ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)
           ORDER BY part, orderID
  END
  ELSE
  BEGIN
    SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT jobID, jobName, [sql], logStarted, logCompleted
            FROM zsystem.jobs
           WHERE [group] = @group AND part = @part AND [disabled] = 0 AND
                 ([day] IS NULL OR [day] = @day) AND ([week] IS NULL OR [week] = @week)
           ORDER BY part, orderID
  END

  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  WHILE @@FETCH_STATUS = 0
  BEGIN
    -- Job started event
    IF @logStarted = 1
      EXEC @eventID = zsystem.Events_TaskStarted @jobName, @int_1=@jobID, @eventTypeID=2000000021

    -- Job execute 
    BEGIN TRY
      EXEC sp_executesql @sql
    END TRY
    BEGIN CATCH
      -- Job ERROR event
      SET @eventText = ERROR_MESSAGE()
      EXEC zsystem.Events_TaskError @eventID, @eventText, @int_1=@jobID, @eventTypeID=2000000024

      DECLARE @objectName nvarchar(256)
      SET @objectName = 'zsystem.Jobs_Exec: ' + @jobName
      EXEC zsystem.CatchError @objectName
    END CATCH

    -- Job completed event
    IF @logCompleted = 1
      EXEC zsystem.Events_TaskCompleted @eventID, @int_1=@jobID, @eventTypeID=2000000023

    FETCH NEXT FROM @cursor INTO @jobID, @jobName, @sql, @logStarted, @logCompleted
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO
