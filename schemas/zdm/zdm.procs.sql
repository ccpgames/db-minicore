
IF OBJECT_ID('zdm.procs') IS NOT NULL
  DROP PROCEDURE zdm.procs
GO
CREATE PROCEDURE zdm.procs
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'procs', @filter
GO
