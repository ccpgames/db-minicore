
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToTableTrim') IS NOT NULL
  DROP FUNCTION zutil.CharListToTableTrim
GO
CREATE FUNCTION zutil.CharListToTableTrim(@list nvarchar(max))
  RETURNS TABLE
  RETURN SELECT string = LTRIM(RTRIM(SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)))
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToTableTrim TO zzp_server
GO
