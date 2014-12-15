
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.FloatListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.FloatListToOrderedTable
GO
CREATE FUNCTION zutil.FloatListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(float, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.FloatListToOrderedTable TO zzp_server
GO
