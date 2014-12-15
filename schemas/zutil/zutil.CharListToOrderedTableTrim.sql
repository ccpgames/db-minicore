
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToOrderedTableTrim') IS NOT NULL
  DROP FUNCTION zutil.CharListToOrderedTableTrim
GO
CREATE FUNCTION zutil.CharListToOrderedTableTrim(@list nvarchar(MAX))
  RETURNS TABLE
  RETURN SELECT row = ROW_NUMBER() OVER(ORDER BY n),
                string = LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToOrderedTableTrim TO zzp_server
GO
