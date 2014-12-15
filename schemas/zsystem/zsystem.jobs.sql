
-- *** jobID from 2000000000 and up is reserved for CORE ***

IF OBJECT_ID('zsystem.jobs') IS NULL
BEGIN
  CREATE TABLE zsystem.jobs
  (
    jobID          int            NOT NULL,
    jobName        nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    [sql]          nvarchar(max)  NOT NULL,
    --
    [hour]         tinyint        NULL,  -- 0, 1, 2, ..., 22, 23
    [minute]       tinyint        NULL,  -- 0, 10, 20, 30, 40, 50
    [day]          tinyint        NULL,  -- 1-7 (day of week, WHERE 1 is sunday and 6 is saturday)
    [week]         tinyint        NULL,  -- 1-4 (week of month)
    --
    [group]        nvarchar(100)  NULL,  -- Typically SCHEDULE or DOWNTIME
    part           smallint       NULL,  -- NULL for SCHEDULE, set for DOWNTIME
    --
    orderID        int            NOT NULL  DEFAULT 0,
    --
    [disabled]     bit            NOT NULL  DEFAULT 0,
    --
    logStarted     bit            NOT NULL  DEFAULT 1,
    logCompleted   bit            NOT NULL  DEFAULT 1,
    --
    CONSTRAINT jobs_PK PRIMARY KEY CLUSTERED (jobID),
    --
    CONSTRAINT jobs_CK_Hour CHECK ([hour] >= 0 AND [hour] <= 23),
    CONSTRAINT jobs_CK_Minute CHECK ([minute] >= 0 AND [minute] <= 50 AND [minute] % 10 = 0),
    CONSTRAINT jobs_CK_Day CHECK ([day] >= 1 AND [day] <= 7),
    CONSTRAINT jobs_CK_Week CHECK ([week] >= 1 AND [week] <= 4),
  )
END
GRANT SELECT ON zsystem.jobs TO zzp_server
GO



-- Data
IF NOT EXISTS(SELECT * FROM zsystem.jobs WHERE jobID = 2000000001)
  INSERT INTO  zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], orderID)
       VALUES (2000000001, 'CORE - zsystem - Insert identity statistics', '', 'EXEC zsystem.Identities_Insert', 'SCHEDULE', 0, 0, -10)
IF NOT EXISTS(SELECT * FROM zsystem.jobs WHERE jobID = 2000000031)
  INSERT INTO  zsystem.jobs (jobID, jobName, [description], [sql], [group], [hour], [minute], [day], orderID, [disabled])
       VALUES (2000000031, 'CORE - zsystem - interval overflow alert', '', 'EXEC zsystem.Intervals_OverflowAlert', 'SCHEDULE', 7, 0, 4, -7, 1)
GO
