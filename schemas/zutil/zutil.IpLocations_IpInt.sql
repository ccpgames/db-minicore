
IF OBJECT_ID('zutil.IpLocations_IpInt') IS NOT NULL
  DROP FUNCTION zutil.IpLocations_IpInt
GO
CREATE FUNCTION zutil.IpLocations_IpInt(@ip varchar(15))
RETURNS bigint
BEGIN
  -- Code based on ip2location.dbo.Dot2LongIP
  DECLARE @ipA bigint, @ipB int, @ipC int, @ipD Int
  SELECT @ipA = LEFT(@ip, PATINDEX('%.%', @ip) - 1)
  SELECT @ip = RIGHT(@ip, LEN(@ip) - LEN(@ipA) - 1)
  SELECT @ipB = LEFT(@ip, PATINDEX('%.%', @ip) - 1)
  SELECT @ip = RIGHT(@ip, LEN(@ip) - LEN(@ipB) - 1)
  SELECT @ipC = LEFT(@ip, PATINDEX('%.%', @ip) - 1)
  SELECT @ip = RIGHT(@ip, LEN(@ip) - LEN(@ipC) - 1)
  SELECT @ipD = @ip
  RETURN (@ipA * 256 * 256 * 256) + (@ipB * 256*256) + (@ipC * 256) + @ipD
END
GO
