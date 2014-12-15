
IF OBJECT_ID('zsystem.EventTypes_Select') IS NOT NULL
  DROP PROCEDURE zsystem.EventTypes_Select
GO
CREATE PROCEDURE zsystem.EventTypes_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT eventTypeID, eventTypeName FROM zsystem.eventTypes ORDER BY eventTypeID
GO
GRANT EXEC ON zsystem.EventTypes_Select TO zzp_server
GO
