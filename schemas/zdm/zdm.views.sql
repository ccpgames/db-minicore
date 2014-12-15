
IF OBJECT_ID('zdm.views') IS NOT NULL
  DROP PROCEDURE zdm.views
GO
CREATE PROCEDURE zdm.views
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.info 'views', @filter
GO
