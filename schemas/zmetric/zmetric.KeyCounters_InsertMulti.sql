
IF OBJECT_ID('zmetric.KeyCounters_InsertMulti') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_InsertMulti
GO
CREATE PROCEDURE zmetric.KeyCounters_InsertMulti
  @counterID      smallint,
  @interval       char(1) = 'D',  -- D:Day, W:Week, M:Month, Y:Year
  @counterDate    date = NULL,
  @lookupTableID  int,
  @keyID          int = NULL,     -- If NULL then zsystem.Texts_ID is used
  @keyText        nvarchar(450),
  @value1         float = NULL,
  @value2         float = NULL,
  @value3         float = NULL,
  @value4         float = NULL,
  @value5         float = NULL,
  @value6         float = NULL,
  @value7         float = NULL,
  @value8         float = NULL,
  @value9         float = NULL,
  @value10        float = NULL
AS
  -- Set values for multiple columns
  -- @value1 goes into columnID = 1, @value2 goes into columnID = 2 and so on
  SET NOCOUNT ON

  IF @counterDate IS NULL SET @counterDate = GETUTCDATE()

  IF @interval = 'W' SET @counterDate = zutil.DateWeek(@counterDate)
  ELSE IF @interval = 'M' SET @counterDate = zutil.DateMonth(@counterDate)
  ELSE IF @interval = 'Y' SET @counterDate = zutil.DateYear(@counterDate)

  IF @keyText IS NOT NULL
    EXEC @keyID = zsystem.LookupValues_Update @lookupTableID, @keyID, @keyText

  IF ISNULL(@value1, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 1, @keyID, @value1)

  IF ISNULL(@value2, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 2, @keyID, @value2)

  IF ISNULL(@value3, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 3, @keyID, @value3)

  IF ISNULL(@value4, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 4, @keyID, @value4)

  IF ISNULL(@value5, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 5, @keyID, @value5)

  IF ISNULL(@value6, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 6, @keyID, @value6)

  IF ISNULL(@value7, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 7, @keyID, @value7)

  IF ISNULL(@value8, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 8, @keyID, @value8)

  IF ISNULL(@value9, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 9, @keyID, @value9)

  IF ISNULL(@value10, 0.0) != 0.0
    INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 10, @keyID, @value10)
GO
GRANT EXEC ON zmetric.KeyCounters_InsertMulti TO zzp_server
GO
