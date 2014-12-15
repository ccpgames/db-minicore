
IF OBJECT_ID('zsystem.CatchError') IS NOT NULL
  DROP PROCEDURE zsystem.CatchError
GO
CREATE PROCEDURE zsystem.CatchError
  @objectName  nvarchar(256) = NULL,
  @rollback    bit = 1
AS
  SET NOCOUNT ON

  DECLARE @message nvarchar(4000), @number int, @severity int, @state int, @line int, @procedure nvarchar(200)
  SELECT @number = ERROR_NUMBER(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE(),
         @line = ERROR_LINE(), @procedure = ISNULL(ERROR_PROCEDURE(), '?'), @message = ISNULL(ERROR_MESSAGE(), '?')

  IF @rollback = 1
  BEGIN
    IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION
  END

  IF @procedure = 'CatchError'
    SET @message = ISNULL(@objectName, '?') + ' >> ' + @message
  ELSE
  BEGIN
    IF @number = 50000
      SET @message = ISNULL(@objectName, @procedure) + ' (line ' + ISNULL(CONVERT(nvarchar, @line), '?') + ') >> ' + @message
    ELSE
    BEGIN
      SET @message = ISNULL(@objectName, @procedure) + ' (line ' + ISNULL(CONVERT(nvarchar, @line), '?')
                   + ', error ' + ISNULL(CONVERT(nvarchar, @number), '?') + ') >> ' + @message
    END
  END

  RAISERROR (@message, @severity, @state)
GO
