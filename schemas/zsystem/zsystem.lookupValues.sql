
IF OBJECT_ID('zsystem.lookupValues') IS NULL
BEGIN
  CREATE TABLE zsystem.lookupValues
  (
    lookupTableID  int                                           NOT NULL,
    lookupID       int                                           NOT NULL,
    lookupText     nvarchar(1000)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]  nvarchar(max)                                 NULL,
    parentID       int                                           NULL,
    [fullText]     nvarchar(1000)  COLLATE Latin1_General_CI_AI  NULL,
    --
    CONSTRAINT lookupValues_PK PRIMARY KEY CLUSTERED (lookupTableID, lookupID)
  )
END
GRANT SELECT ON zsystem.lookupValues TO zzp_server
GO
