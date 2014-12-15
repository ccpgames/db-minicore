
IF OBJECT_ID('zsystem.Tasks_DynamicID') IS NOT NULL
  DROP PROCEDURE zsystem.Tasks_DynamicID
GO
CREATE PROCEDURE zsystem.Tasks_DynamicID
  @taskName  nvarchar(450)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @taskID int
  SELECT @taskID = taskID FROM zsystem.tasks WHERE taskName = @taskName AND taskID > 100000000
  IF @taskID IS NULL
  BEGIN
    SELECT @taskID = MAX(taskID) + 1 FROM zsystem.tasks

    INSERT INTO zsystem.tasks (taskID, taskName) VALUES (@taskID, @taskName)
  END
  RETURN @taskID
GO
