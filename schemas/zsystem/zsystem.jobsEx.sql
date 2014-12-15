
IF OBJECT_ID('zsystem.jobsEx') IS NOT NULL
  DROP VIEW zsystem.jobsEx
GO
CREATE VIEW zsystem.jobsEx
AS
  SELECT jobID, jobName, [description], [sql], [hour], [minute],
         [time] = CASE WHEN part IS NOT NULL THEN NULL
                       WHEN [week] IS NULL AND [day] IS NULL AND [hour] IS NULL AND [minute] IS NULL THEN 'XX:X0'
                       WHEN [week] IS NULL AND [day] IS NULL AND [hour] IS NULL THEN 'XX:' + RIGHT('0' + CONVERT(varchar, [minute]), 2)
                       ELSE RIGHT('0' + CONVERT(varchar, [hour]), 2) + ':' + RIGHT('0' + CONVERT(varchar, [minute]), 2) END,
         [day], dayText = CASE [day] WHEN 1 THEN 'Sunday' WHEN 2 THEN 'Monday' WHEN 3 THEN 'Tuesday'
                                     WHEN 4 THEN 'Wednesday' WHEN 5 THEN 'Thursday' WHEN 6 THEN 'Friday'
                                     WHEN 7 THEN 'Saturday' END,
         [week], weekText = CASE [week] WHEN 1 THEN 'First (days 1-7 of month)'
                                        WHEN 2 THEN 'Second (days 8-14 of month)'
                                        WHEN 3 THEN 'Third (days 15-21 of month)'
                                        WHEN 4 THEN 'Fourth (days 22-28 of month)' END,
         [group], part, logStarted, logCompleted, orderID, [disabled]
    FROM zsystem.jobs
GO
GRANT SELECT ON zsystem.jobsEx TO zzp_server
GO
