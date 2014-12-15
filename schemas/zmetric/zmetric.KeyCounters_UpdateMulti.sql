
IF OBJECT_ID('zmetric.KeyCounters_UpdateMulti') IS NOT NULL
  DROP PROCEDURE zmetric.KeyCounters_UpdateMulti
GO
CREATE PROCEDURE zmetric.KeyCounters_UpdateMulti
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
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value1 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 1 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 1, @keyID, @value1)
  END

  IF ISNULL(@value2, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value2 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 2 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 2, @keyID, @value2)
  END

  IF ISNULL(@value3, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value3 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 3 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 3, @keyID, @value3)
  END

  IF ISNULL(@value4, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value4 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 4 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 4, @keyID, @value4)
  END

  IF ISNULL(@value5, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value5 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 5 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 5, @keyID, @value5)
  END

  IF ISNULL(@value6, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value6 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 6 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 6, @keyID, @value6)
  END

  IF ISNULL(@value7, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value7 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 7 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 7, @keyID, @value7)
  END

  IF ISNULL(@value8, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value8 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 8 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 8, @keyID, @value8)
  END

  IF ISNULL(@value9, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value9 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 9 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 9, @keyID, @value9)
  END

  IF ISNULL(@value10, 0.0) != 0.0
  BEGIN
    UPDATE zmetric.keyCounters SET value = value + @value10 WHERE counterID = @counterID AND counterDate = @counterDate AND columnID = 10 AND keyID = @keyID
    IF @@ROWCOUNT = 0
      INSERT INTO zmetric.keyCounters (counterID, counterDate, columnID, keyID, value) VALUES (@counterID, @counterDate, 10, @keyID, @value10)
  END
GO
GRANT EXEC ON zmetric.KeyCounters_UpdateMulti TO zzp_server
GO
