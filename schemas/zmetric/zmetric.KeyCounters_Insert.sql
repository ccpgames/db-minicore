
IF OBJECT_ID('zmetric.KeyCounters_Insert') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_Insert
GO
CREATE PROCEDURE zmetric.KeyCounters_Insert
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

  INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value)
       VALUES (@counterID, @counterDate, @columnID, @keyID, @value)
GO
GRANT EXEC ON zmetric.KeyCounters_Insert TO zzp_server
GO
