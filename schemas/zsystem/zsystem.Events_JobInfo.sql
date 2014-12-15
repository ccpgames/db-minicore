
IF OBJECT_ID('zsystem.Events_JobInfo') IS NOT NULL
  DROP PROCEDURE zsystem.Events_JobInfo
GO
CREATE PROCEDURE zsystem.Events_JobInfo
  @jobID        int,
  @fixedText    nvarchar(450) = NULL,
  @eventText    nvarchar(max) = NULL,
  @int_2        int = NULL,
  @int_3        int = NULL,
  @int_4        int = NULL,
  @int_5        int = NULL,
  @int_6        int = NULL,
  @int_7        int = NULL,
  @int_8        int = NULL,
  @int_9        int = NULL,
  @date_1       date = NULL
AS
  SET NOCOUNT ON

  DECLARE @taskName nvarchar(450)
  SELECT @taskName = jobName FROM zsystem.jobs WHERE jobID = @jobID

  DECLARE @eventID int

  EXEC @eventID = zsystem.Events_TaskInfo NULL, @eventText, @jobID, @int_2, @int_3, @int_4, @int_5, @int_6, @int_7, @int_8, @int_9, @date_1, NULL, @taskName, @fixedText, 2000000022

  RETURN @eventID
GO
