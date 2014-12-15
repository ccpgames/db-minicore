
IF OBJECT_ID('zsystem.Schemas_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Schemas_Select
GO
CREATE PROCEDURE zsystem.Schemas_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT * FROM zsystem.schemas
GO
GRANT EXEC ON zsystem.Schemas_Select TO zzp_server
GO
