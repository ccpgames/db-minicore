
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.MoneyListToOrderedTable') IS NOT NULL
  DROP FUNCTION zutil.MoneyListToOrderedTable
GO
CREATE FUNCTION zutil.MoneyListToOrderedTable(@list varchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                number = CONVERT(money, SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.MoneyListToOrderedTable TO zzp_server
GO