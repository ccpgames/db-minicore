
IF OBJECT_ID('zutil.IpLocations_Select') IS NOT NULL
  DROP PROCEDURE zutil.IpLocations_Select
GO
CREATE PROCEDURE zutil.IpLocations_Select
  @ip  varchar(15)
AS
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  SET NOCOUNT ON

  DECLARE @ipInt bigint = zutil.IpLocations_IpInt(@ip)
  SELECT TOP 1 countryID, countryCode, countryName, region, city, latitude, longitude, zipCode, timeZone, ispName, domainName
    FROM zutil.ipLocations
   WHERE ipFrom <= @ipInt
   ORDER BY ipFrom DESC
GO
GRANT EXEC ON zutil.IpLocations_Select TO zzp_server
GO
