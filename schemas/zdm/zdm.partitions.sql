
IF OBJECT_ID('zdm.partitions') IS NOT NULL
  DROP PROCEDURE zdm.partitions
GO
CREATE PROCEDURE zdm.partitions
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'partitions', @filter
GO
