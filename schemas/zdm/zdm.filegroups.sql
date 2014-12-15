
IF OBJECT_ID('zdm.filegroups') IS NOT NULL
  DROP PROCEDURE zdm.filegroups
GO
CREATE PROCEDURE zdm.filegroups
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.info 'filegroups', @filter
GO
