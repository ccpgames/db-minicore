
IF OBJECT_ID('zdm.indexes') IS NOT NULL
  DROP PROCEDURE zdm.indexes
GO
CREATE PROCEDURE zdm.indexes
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  EXEC zdm.info 'indexes', @filter
GO
