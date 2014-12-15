
-- *** taskID under 100 mills are reserved for fixed taskID's                                                    ***
-- *** taksID over 100 mills are automagically generated from taskName if taskName used not found over 100 mills ***

IF OBJECT_ID('zsystem.tasks') IS NULL
BEGIN
  CREATE TABLE zsystem.tasks
  (
    taskID         int                                          NOT NULL,
    taskName       nvarchar(450)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]  nvarchar(max)                                NULL,
    --
    CONSTRAINT tasks_PK PRIMARY KEY CLUSTERED (taskID)
  )

  CREATE NONCLUSTERED INDEX tasks_IX_Name ON zsystem.tasks (taskName)
END
GRANT SELECT ON zsystem.tasks TO zzp_server
GO


IF NOT EXISTS(SELECT * FROM zsystem.tasks WHERE taskID = 100000000)
  INSERT INTO zsystem.tasks (taskID, taskName, [description])
       VALUES (100000000, 'DUMMY TASK - 100 MILLS', 'A dummy task to make MAX(taskID) start over 100 mills')
GO
