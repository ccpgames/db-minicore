
IF OBJECT_ID('zsystem.Tables_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Tables_Select
GO
CREATE PROCEDURE zsystem.Tables_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM zsystem.tables
GO
GRANT EXEC ON zsystem.Tables_Select TO zzp_server
GO
