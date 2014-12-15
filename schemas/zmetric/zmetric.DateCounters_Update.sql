
IF OBJECT_ID('zmetric.DateCounters_Update') IS NOT NULL
  DROP PROCEDURE zmetric.DateCounters_Update
GO
CREATE PROCEDURE zmetric.DateCounters_Update
  @counterID    smallint,
  @subjectID    int = 0,
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

  UPDATE zmetric.dateCounters
     SET value = value + @value
   WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
  IF @@ROWCOUNT = 0
  BEGIN TRY
    INSERT INTO zmetric.dateCounters (counterID, counterDate, subjectID, keyID, value)
         VALUES (@counterID, @counterDate, @subjectID, @keyID, @value)
  END TRY
  BEGIN CATCH
    IF ERROR_NUMBER() = 2627 -- Violation of PRIMARY KEY constraint
    BEGIN
      UPDATE zmetric.dateCounters
         SET value = value + @value
       WHERE counterID = @counterID AND subjectID = @subjectID AND keyID = @keyID AND counterDate = @counterDate
    END
    ELSE
    BEGIN
      EXEC zsystem.CatchError 'zmetric.DateCounters_Update'
      RETURN -1
    END
  END CATCH
GO
GRANT EXEC ON zmetric.DateCounters_Update TO zzp_server
GO
