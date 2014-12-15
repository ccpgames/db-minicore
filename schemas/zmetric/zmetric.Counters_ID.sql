
IF OBJECT_ID('zmetric.Counters_ID') IS NOT NULL
  DROP FUNCTION zmetric.Counters_ID
GO
CREATE FUNCTION zmetric.Counters_ID(@counterIdentifier varchar(500))
RETURNS smallint
BEGIN
  DECLARE @counterID int
  SELECT @counterID = counterID FROM zmetric.counters WHERE counterIdentifier = @counterIdentifier
  RETURN @counterID
END
GO
GRANT EXEC ON zmetric.Counters_ID TO zzp_server
GO
