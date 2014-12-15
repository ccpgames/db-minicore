
IF OBJECT_ID('zmetric.KeyCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_Update
GO
CREATE PROCEDURE zmetric.KeyCounters_Update
  @counterID    smallint,
  @columnID     tinyint = 0,
  @keyID        int = 0,
  @value        float,
  @interval     char(1) = 'D', -- D:Day, W:Week, M:Month, Y:Year
  @counterDate  date = NULL
AS
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  UPDATE zmetric.keyCounters
      SET value = value + @value
    WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
          VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.keyCounters
         SET value = value + @value
       WHERE counterID = @counterID AND columnID = @columnID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.KeyCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.KeyCounters_Update TO zzp_server
GO
