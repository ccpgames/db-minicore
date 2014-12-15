
-- Based on code from Itzik Ben-Gan

IF OBJECT_ID('zutil.CharListToTable') IS NOT NULL
  DROP FUNCTION zutil.CharListToTable
GO
CREATE FUNCTION zutil.CharListToTable(@list nvarchar(max))
  RETURNS TABLE
  RETURN SELECT string = SUBSTRING(@list, n, CHARINDEX(',', @list + ',', n) - n)
           FROM zutil.Numbers(LEN(@list) + 1)
          WHERE SUBSTRING(',' + @list, n, 1) = ','
GO
GRANT SELECT ON zutil.CharListToTable TO zzp_server
GO
