
IF TYPE_ID('zutil.IntTable') IS NULL
  CREATE TYPE zutil.IntTable AS TABLE (number int NOT NULL)
GO
GRANT EXECUTE ON TYPE::zutil.IntTable TO zzp_server
GO
