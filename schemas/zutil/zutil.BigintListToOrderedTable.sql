
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.BigintListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.BigintListToOrderedTable
GO
CREATE FUNCTION zutil.BigintListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(bigint, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.BigintListToOrderedTable TO zzp_server
GO
