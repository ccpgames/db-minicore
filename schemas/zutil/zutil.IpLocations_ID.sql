
IF OBJECT_ID('zutil.IpLocations_ID') IS NOT NULL
  DROP FUNCTION zutil.IpLocations_ID
GO
CREATE FUNCTION zutil.IpLocations_ID(@ip varchar(15))
RETURNS smallint
BEGIN
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  DECLARE @ipInt bigint = zutil.IpLocations_IpInt(@ip)
  DECLARE @countryID smallint
  SELECT TOP 1 @countryID = countryID FROM zutil.ipLocations WHERE ipFrom <= @ipInt ORDER BY ipFrom DESC
  RETURN @countryID
END
GO
