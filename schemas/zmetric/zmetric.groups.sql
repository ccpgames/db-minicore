
-- *** groupID from 30000 and up is reserved for CORE ***

IF OBJECT_ID('zmetric.groups') IS NULL
BEGIN
  CREATE TABLE zmetric.groups
  (
    groupID        smallint                                     NOT NULL,
    groupName      nvarchar(200)  COLLATE Latin1_General_CI_AI  NOT NULL,
    [description]  nvarchar(max)                                NULL,
    [order]        smallint                                     NOT NULL  DEFAULT 0,
    parentGroupID  smallint                                     NULL,
    --
    CONSTRAINT groups_PK PRIMARY KEY CLUSTERED (groupID)
  )
END
GRANT SELECT ON zmetric.groups TO zzp_server
GO
