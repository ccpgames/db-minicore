
IF OBJECT_ID('zsystem.versions') IS NULL
BEGIN
  CREATE TABLE zsystem.versions
  (
    developer       varchar(20)    NOT NULL,
    [version]       int            NOT NULL,
    versionDate     datetime2(2)   NOT NULL,
    userName        nvarchar(100)  NOT NULL,
    loginName       nvarchar(256)  NOT NULL,
    executionCount  int            NOT NULL,
    lastDate        datetime2(2)   NULL,
    lastLoginName   nvarchar(256)  NULL,
    coreVersion     int            NULL,
    firstDuration   int            NULL,
    lastDuration    int            NULL,
    executingSPID   int            NULL
    --
    CONSTRAINT versions_PK PRIMARY KEY CLUSTERED (developer, [version])
  )
END
GRANT SELECT ON zsystem.versions TO zzp_server
GO
