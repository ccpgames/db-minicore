
-- The reason for text being nvarchar(450) is that the maximum key length in SQL Server is 900

IF OBJECT_ID('zsystem.texts') IS NULL
BEGIN
  CREATE TABLE zsystem.texts
  (
    textID  int                                          NOT NULL  IDENTITY(1, 1),
    [text]  nvarchar(450)  COLLATE Latin1_General_CI_AI  NOT NULL,
    --
    CONSTRAINT texts_PK PRIMARY KEY CLUSTERED (textID)
  )

  CREATE UNIQUE NONCLUSTERED INDEX texts_IX_Text ON zsystem.texts ([text])
END
GRANT SELECT ON zsystem.texts TO zzp_server
GO
