
IF OBJECT_ID('zsystem.Identities_BigInt') IS NOT NULL
  DROP FUNCTION zsystem.Identities_BigInt
GO
CREATE FUNCTION zsystem.Identities_BigInt(@tableID int, @identityDate date, @days smallint, @seek smallint)
  RETURNS bigint
BEGIN
  IF @identityDate IS NULL SET @identityDate = GETUTCDATE()
  IF @days IS NOT NULL SET @identityDate = DATEADD(day, @days, @identityDate)

  DECLARE @identityBigInt bigint

  IF @seek < 0
  BEGIN
    SELECT TOP 1 @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate <= @identityDate
     ORDER BY identityDate DESC
  END
  ELSE IF @seek > 0
  BEGIN
    SELECT TOP 1 @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate >= @identityDate
     ORDER BY identityDate
  END
  ELSE
  BEGIN
    SELECT @identityBigInt = identityBigInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate = @identityDate
  END

  RETURN ISNULL(@identityBigInt, -1)
END
GO
GRANT EXEC ON zsystem.Identities_BigInt TO zzp_server
GO
