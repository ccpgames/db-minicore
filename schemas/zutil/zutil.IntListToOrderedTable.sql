
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.IntListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.IntListToOrderedTable
GO
CREATE FUNCTION zutil.IntListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(int, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.IntListToOrderedTable TO zzp_server
GO
