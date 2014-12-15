
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.CharListToOrderedTable
GO
CREATE FUNCTION zutil.CharListToOrderedTable(@list nvarchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                string = SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToOrderedTable TO zzp_server
GO
