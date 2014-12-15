
IF OBJECT_ID('zdm.sqltext') IS NOT NULL
  DROP PROCEDURE zdm.sqltext
GO
CREATE PROCEDURE zdm.sqltext
  @sql_handle  varbinary(64)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM sys.dm_exec_sql_text(@sql_handle)
GO
