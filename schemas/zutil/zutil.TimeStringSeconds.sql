
IF OBJECT_ID('zutil.TimeStringSeconds') IS NOT NULL
  DROP FUNCTION zutil.TimeStringSeconds
GO
CREATE FUNCTION zutil.TimeStringSeconds(@timeString varchar(20))
RETURNS int
BEGIN
  DECLARE @seconds int, @minutesSeconds char(5), @hours varchar(14)

  SET @minutesSeconds = RIGHT(@timeString, 5)
  SET @hours = LEFT(@timeString, LEN(@timeString) - 6)

  SET @seconds = CONVERT(int, RIGHT(@minutesSeconds, 2))
  SET @seconds = @seconds + (CONVERT(int, LEFT(@minutesSeconds, 2) * 60))
  SET @seconds = @seconds + (CONVERT(int, @hours * 3600))

  RETURN @seconds
END
GO
GRANT EXEC ON zutil.TimeStringSeconds TO zzp_server
GO
