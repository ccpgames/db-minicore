
IF OBJECT_ID('zsystem.Versions_FirstExecution') IS NOT NULL
  DROP FUNCTION zsystem.Versions_FirstExecution
GO
CREATE FUNCTION zsystem.Versions_FirstExecution()
RETURNS bit
BEGIN
  IF EXISTS(SELECT * FROM zsystem.versions WHERE executingSPID = @@SPID AND firstDuration IS NULL)
    RETURN 1
  RETURN 0
END
GO
