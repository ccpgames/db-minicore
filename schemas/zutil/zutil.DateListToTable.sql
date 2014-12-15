
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.DateListToTable') IS NOT NULL
  DROP FUNCTION zutil.DateListToTable
GO
CREATE FUNCTION zutil.DateListToTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT dateValue = CONVERT(datetime2(0), SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.DateListToTable TO zzp_server
GO
