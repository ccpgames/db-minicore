
IF OBJECT_ID('zutil.IpLocations_SelectList') IS NOT NULL
  DROP PROCEDURE zutil.IpLocations_SelectList
GO
CREATE PROCEDURE zutil.IpLocations_SelectList
  @ips  varchar(max)
AS
  -- Code based on ip2location.dbo.IP2LocationLookupCountry
  SET NOCOUNT ON

  DECLARE @table TABLE
  (
    ipInt        bigint       PRIMARY KEY,
    ip           varchar(15),
    countryID    smallint,
    countryCode  char(2),
    countryName  varchar(100),
    region       varchar(200),
    city         varchar(200),
    latitude     real,
    longitude    real,
    zipCode      varchar(50),
    timeZone     varchar(50),
    ispName      varchar(300),
    domainName   varchar(200)
  )

  INSERT INTO @table (ipInt, ip)
       SELECT zutil.IpLocations_IpInt(string), string FROM zutil.CharListToTable(@ips)

  DECLARE @ipInt bigint,
          @countryID smallint, @countryCode char(2), @countryName varchar(100), @region varchar(200), @city varchar(200),
          @latitude real, @longitude real, @zipCode varchar(50), @timeZone varchar(50), @ispName varchar(300), @domainName varchar(200)

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT ipInt FROM @table
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @ipInt
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SELECT @countryID = NULL, @countryCode = NULL, @countryName = NULL, @region = NULL, @city = NULL,
           @latitude = NULL, @longitude = NULL, @zipCode = NULL, @timeZone = NULL, @ispName = NULL, @domainName = NULL

    SELECT TOP 1 @countryID = countryID, @countryCode = countryCode, @countryName = countryName, @region = region, @city = city,
           @latitude = latitude, @longitude = longitude, @zipCode = zipCode, @timeZone = timeZone, @ispName = ispName, @domainName = domainName
      FROM zutil.ipLocations
     WHERE ipFrom <= @ipInt
     ORDER BY ipFrom DESC

    UPDATE @table
       SET countryID = @countryID, countryCode = @countryCode, countryName = @countryName, region = @region, city = @city,
           latitude = @latitude, longitude = @longitude, zipCode = @zipCode, timeZone = @timeZone, ispName = @ispName, domainName = @domainName
     WHERE ipInt = @ipInt

    FETCH NEXT FROM @cursor INTO @ipInt
  END
  CLOSE @cursor
  DEALLOCATE @cursor

  SELECT ip, countryID, countryCode, countryName, region, city, latitude, longitude, zipCode, timeZone, ispName, domainName
    FROM @table
GO
GRANT EXEC ON zutil.IpLocations_SelectList TO zzp_server
GO
