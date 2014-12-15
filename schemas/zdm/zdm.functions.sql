
IF OBJECT_ID('zdm.functions') IS NOT NULL
  DROP PROCEDURE zdm.functions
GO
CREATE PROCEDURE zdm.functions
  @filter  nvarchar(300) = ''
AS
  SET NOCOUNT ON

  EXEC zdm.info 'functions', @filter
GO
