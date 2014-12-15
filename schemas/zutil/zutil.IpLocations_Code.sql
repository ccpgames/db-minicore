
IF OBJECT_ID('zutil.IpLocations_Code') IS NOT NULL
  DROP FUNCTION zutil.IpLocations_Code
GO
CREATE FUNCTION zutil.IpLocations_Code(@ip varchar(15))
RETURNS char(2)
BEGIN
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  DECLARE @ipInt bigint = zutil.IpLocations_IpInt(@ip)
  DECLARE @countryCode char(2)
  SELECT TOP 1 @countryCode = countryCode FROM zutil.ipLocations WHERE ipFrom <= @ipInt ORDER BY ipFrom DESC
  RETURN @countryCode
END
GO
