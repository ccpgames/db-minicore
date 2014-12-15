
IF OBJECT_ID('zsystem.Versions_Select') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Select
GO
CREATE PROCEDURE zsystem.Versions_Select
  @developer  varchar(20) = 'CORE'
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT TOP 1 [version], versionDate, userName, coreVersion
    FROM zsystem.versions
   WHERE developer = @developer
   ORDER BY [version] DESC
GO
GRANT EXEC ON zsystem.Versions_Select TO zzp_server
GO
