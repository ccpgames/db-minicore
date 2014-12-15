
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.BigintListToTable') IS NOT NULL
  DROP FUNCTION zutil.BigintListToTable
GO
CREATE FUNCTION zutil.BigintListToTable(@list varchar(max))
  RETURNS TABLE
  RETURN SELECT number = CONVERT(bigint, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.BigintListToTable TO zzp_server
GO
