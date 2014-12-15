
-- Table based on ip2location DB12 table
-- Note that this table will be empty on most databases, will only be populated for servers where we buy ip2location

IF OBJECT_ID('zutil.ipLocations') IS NULL
BEGIN
  CREATE TABLE zutil.ipLocations
  (
    ipFrom        bigint                                      NOT NULL,
    ipTo          bigint                                      NOT NULL,
    countryID     smallint                                    NULL,
    countryCode   char(2)       COLLATE Latin1_General_CI_AI  NULL,
    countryName   varchar(100)  COLLATE Latin1_General_CI_AI  NULL,
    region        varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    city          varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    latitude      real                                        NULL,
    longitude     real                                        NULL,
    zipCode       varchar(50)   COLLATE Latin1_General_CI_AI  NULL,
    timeZone      varchar(50)   COLLATE Latin1_General_CI_AI  NULL,
    ispName       varchar(300)  COLLATE Latin1_General_CI_AI  NULL,
    domainName    varchar(200)  COLLATE Latin1_General_CI_AI  NULL,
    --
    CONSTRAINT ipLocations_PK PRIMARY KEY CLUSTERED (ipFrom, ipTo)
  )
END
GO


--
-- LOAD NEW DATA INTO THE SWITCH TABLE
--

--TRUNCATE TABLE zutil.ipLocations_SWITCH

--INSERT INTO zutil.ipLocations_SWITCH (ipFrom, ipTo, countryCode, countryName, region, city, latitude, longitude, zipCode, timeZone, ispName, domainName)
--     SELECT ipFrom, ipTo,
--            CASE WHEN countryCode = '-' THEN NULL ELSE countryCode END,
--            CASE WHEN countryName = '-' THEN NULL ELSE countryName END,
--            CASE WHEN region = '-' THEN NULL ELSE region END,
--            CASE WHEN city = '-' THEN NULL ELSE city END,
--            CASE WHEN latitude = 0 AND countryCode = '-' THEN NULL ELSE latitude END,
--            CASE WHEN longitude = 0 AND countryCode = '-' THEN NULL ELSE longitude END,
--            CASE WHEN zipCode = '-' THEN NULL ELSE zipCode END,
--            CASE WHEN timeZone = '-' THEN NULL ELSE timeZone END,
--            CASE WHEN ispName = '-' THEN NULL ELSE ispName END,
--            CASE WHEN domainName = '-' THEN NULL ELSE domainName END
--       FROM ip2location.dbo.[ip2location-2014-05-DB12]
--      ORDER BY ipFrom, ipTo
-- 01:40 (9613310 row(s) affected), 00:44 (9756295 row(s) affected)

--UPDATE I SET I.countryID = C.countryID
--  FROM zutil.ipLocations_SWITCH I
--    INNER JOIN zuser.countries C ON C.countryCode = I.countryCode
-- WHERE I.countryID IS NULL
-- 00:48 (9604544 row(s) affected), 00:47 (9747209 row(s) affected)

--UPDATE STATISTICS zutil.ipLocations_SWITCH WITH FULLSCAN
-- 00:18

--SELECT TOP 100 * FROM zutil.ipLocations ORDER BY ipFrom DESC
--SELECT TOP 100 * FROM zutil.ipLocations_SWITCH ORDER BY ipFrom DESC


--
-- SWITCH IN NEW DATA
--

--TRUNCATE TABLE zutil.ipLocations
--ALTER TABLE zutil.ipLocations_SWITCH SWITCH TO zutil.ipLocations
