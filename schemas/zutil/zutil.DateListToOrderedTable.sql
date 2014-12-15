
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.DateListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.DateListToOrderedTable
GO
CREATE FUNCTION zutil.DateListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                dateValue = CONVERT(datetime2(0), SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.DateListToOrderedTable TO zzp_server
GO
