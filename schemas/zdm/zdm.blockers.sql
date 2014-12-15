
IF OBJECT_ID('zdm.blockers') IS NOT NULL
  DROP PROCEDURE zdm.blockers
GO
CREATE PROCEDURE zdm.blockers
  @rows  smallint = 30
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @blockingSessionID int

  SELECT TOP 1 @blockingSessionID = blocking_session_id 
    FROM sys.dm_exec_requests 
   WHERE blocking_session_id != 0
   GROUP BY blocking_session_id 
   ORDER BY COUNT(*) DESC

  IF @blockingSessionID > 0
  BEGIN
    SELECT * FROM sys.dm_exec_requests WHERE session_id = @blockingSessionID

    SELECT TOP (@rows) blocking_session_id, blocking_count = COUNT(*)
      FROM sys.dm_exec_requests
     WHERE blocking_session_id != 0
     GROUP BY blocking_session_id
     ORDER BY COUNT(*) DESC
  END
  ELSE
    PRINT 'No blockers found :-)'
GO
