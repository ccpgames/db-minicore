
IF OBJECT_ID('zsystem.identities') IS NULL
BEGIN
  CREATE TABLE zsystem.identities
  (
    tableID           int     NOT NULL,
    identityDate      date    NOT NULL,
    identityInt       int     NULL,
    identityBigInt    bigint  NULL,
    --
    CONSTRAINT identities_PK PRIMARY KEY CLUSTERED (tableID, identityDate)
  )
END
GRANT SELECT ON zsystem.identities TO zzp_server
GO
