
IF OBJECT_ID('zsystem.SQLBigInt') IS NOT NULL
  DROP PROCEDURE zsystem.SQLBigInt
GO
CREATE PROCEDURE zsystem.SQLBigInt
  @sqlSelect        nvarchar(500),
  @sqlFrom          nvarchar(500),
  @sqlWhere         nvarchar(500) = NULL,
  @sqlOrder         nvarchar(500) = NULL,
  @parameterName    nvarchar(100),
  @parameterValue   bigint,
  @comparison       nchar(1) = '='
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @stmt nvarchar(max)
  SET @stmt = 'SELECT ' + @sqlSelect + ' FROM ' + @sqlFrom + ' WHERE '
  IF NOT (@sqlWhere IS NULL OR @sqlWhere = '')
    SET @stmt = @stmt + @sqlWhere + ' AND '
  SET @stmt = @stmt + @parameterName + ' ' + @comparison + ' @pParameterValue'
  IF NOT (@sqlOrder IS NULL OR @sqlOrder = '')
    SET @stmt = @stmt + ' ORDER BY ' + @sqlOrder
  EXEC sp_executesql @stmt, N'@pParameterValue bigint', @pParameterValue = @parameterValue
GO
GRANT EXEC ON zsystem.SQLBigInt TO zzp_server
GO
