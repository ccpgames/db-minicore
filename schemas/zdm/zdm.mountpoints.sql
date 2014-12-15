
IF OBJECT_ID('zdm.mountpoints') IS NOT NULL
  DROP PROCEDURE zdm.mountpoints
GO
CREATE PROCEDURE zdm.mountpoints
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'mountpoints', @filter
GO
