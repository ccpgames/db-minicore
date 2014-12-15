
IF OBJECT_ID('zsystem.Identities_Int') IS NOT NULL
  DROP FUNCTION zsystem.Identities_Int
GO
CREATE FUNCTION zsystem.Identities_Int(@tableID int, @identityDate date, @days smallint, @seek smallint)
  RETURNS int
BEGIN
  IF @identityDate IS NULL SET @identityDate = GETUTCDATE()
  IF @days IS NOT NULL SET @identityDate = DATEADD(day, @days, @identityDate)

  DECLARE @identityInt int

  IF @seek < 0
  BEGIN
    SELECT TOP 1 @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate <= @identityDate
     ORDER BY identityDate DESC
  END
  ELSE IF @seek > 0
  BEGIN
    SELECT TOP 1 @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate >= @identityDate
     ORDER BY identityDate
  END
  ELSE
  BEGIN
    SELECT @identityInt = identityInt
      FROM zsystem.identities
     WHERE tableID = @tableID AND identityDate = @identityDate
  END

  RETURN ISNULL(@identityInt, -1)
END
GO
GRANT EXEC ON zsystem.Identities_Int TO zzp_server
GO
