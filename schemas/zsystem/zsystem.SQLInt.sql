
IF OBJECT_ID('zsystem.SQLInt') IS NOT NULL
  DROP PROCEDURE zsystem.SQLInt
GO
CREATE PROCEDURE zsystem.SQLInt
  @sqlSelect        nvarchar(500),
  @sqlFrom          nvarchar(500),
  @sqlWhere         nvarchar(500) = NULL,
  @sqlOrder         nvarchar(500) = NULL,
  @parameterName    nvarchar(100),
  @parameterValue   int,
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
  EXEC sp_executesql @stmt, N'@pParameterValue int', @pParameterValue = @parameterValue
GO
GRANT EXEC ON zsystem.SQLInt TO zzp_server
GO
