
IF OBJECT_ID('zmetric.SimpleCounters_Select') IS NOT NULL
  DROP PROCEDURE zmetric.SimpleCounters_Select
GO
CREATE PROCEDURE zmetric.SimpleCounters_Select
  @counterID  smallint,
  @fromDate   datetime2(0) = NULL,
  @toDate     datetime2(0) = NULL,
  @rows       int = 1000000
AS
  SET NOCOUNT ON

  SELECT TOP (@rows) counterDate, value
    FROM zmetric.simpleCounters
   WHERE counterID = @counterID AND
         counterDate BETWEEN ISNULL(@fromDate, CONVERT(datetime2(0), '0001-01-01')) AND ISNULL(@toDate, CONVERT(datetime2(0), '9999-12-31'))
   ORDER BY counterDate
GO
GRANT EXEC ON zmetric.SimpleCounters_Select TO zzp_server
GO
