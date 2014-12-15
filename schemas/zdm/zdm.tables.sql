
IF OBJECT_ID('zdm.tables') IS NOT NULL
  DROP PROCEDURE zdm.tables
GO
CREATE PROCEDURE zdm.tables
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'tables', @filter
GO
