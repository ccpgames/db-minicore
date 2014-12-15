
IF TYPE_ID('zutil.BigintTable') IS NULL
  CREATE TYPE zutil.BigintTable AS TABLE (number bigint NOT NULL)
GO
GRANT EXECUTE ON TYPE::zutil.BigintTable TO zzp_server
GO
