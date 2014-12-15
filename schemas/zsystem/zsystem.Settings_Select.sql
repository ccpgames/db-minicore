
IF OBJECT_ID('zsystem.Settings_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Settings_Select
GO
CREATE PROCEDURE zsystem.Settings_Select
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [group], [key], [value], critical, allowUpdate, defaultValue, [description], orderID FROM zsystem.settings
  UNION ALL
  SELECT 'zsystem', 'DB_NAME', DB_NAME(), 0, 0, NULL, '', NULL
  ORDER BY 1, 8, 2
GO
GRANT EXEC ON zsystem.Settings_Select TO zzp_server
GO
