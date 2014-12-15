
-- Table based on ip2location DB12 table

IF OBJECT_ID('zutil.ipLocations_SWITCH') IS NULL
BEGIN
  CREATE TABLE zutil.ipLocations_SWITCH
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
    CONSTRAINT ipLocations_SWITCH_PK PRIMARY KEY CLUSTERED (ipFrom, ipTo)
  )
END
GO
