
IF OBJECT_ID('zsystem.columns') IS NULL
BEGIN
  CREATE TABLE zsystem.columns
  (
    tableID              int            NOT NULL,
    columnName           nvarchar(128)  NOT NULL,
    --
    [readonly]           bit            NULL,
    --
    lookupTable          nvarchar(128)  NULL,
    lookupID             nvarchar(128)  NULL,
    lookupName           nvarchar(128)  NULL,
    lookupWhere          nvarchar(128)  NULL,
    --
    html                 bit     NULL,
    localizationGroupID  int     NULL,
    obsolete             int     NULL,
    --
    CONSTRAINT columns_PK PRIMARY KEY CLUSTERED (tableID, columnName)
  )
END
GRANT SELECT ON zsystem.columns TO zzp_server
GO
