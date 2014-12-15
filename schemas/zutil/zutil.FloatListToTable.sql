
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.FloatListToTable') IS NOT NULL
  DROP FUNCTION zutil.FloatListToTable
GO
CREATE FUNCTION zutil.FloatListToTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(float, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.FloatListToTable TO zzp_server
GO
