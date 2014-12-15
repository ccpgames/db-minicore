
IF OBJECT_ID('zdm.plantext') IS NOT NULL
  DROP PROCEDURE zdm.plantext
GO
CREATE PROCEDURE zdm.plantext
  @plan_handle  varbinary(64)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM sys.dm_exec_query_plan(@plan_handle)
GO
