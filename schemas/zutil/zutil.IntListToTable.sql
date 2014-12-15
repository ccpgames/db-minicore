
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.IntListToTable') IS NOT NULL
  DROP FUNCTION zutil.IntListToTable
GO
CREATE FUNCTION zutil.IntListToTable(@list varchar(max))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(int, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.IntListToTable TO zzp_server
GO
