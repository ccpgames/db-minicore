
IF OBJECT_ID('zsystem.PrintFlush') IS NOT NULL
  DROP PROCEDURE zsystem.PrintFlush
GO
CREATE PROCEDURE zsystem.PrintFlush
AS
  SET NOCOUNT ON

  BEGIN TRY
    RAISERROR ('', 11, 1) WITH NOWAIT;
  END TRY
  BEGIN CATCH
  END CATCH
GO