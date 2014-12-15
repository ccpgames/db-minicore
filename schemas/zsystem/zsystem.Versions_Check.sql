
IF OBJECT_ID('zsystem.Versions_Check') IS NOT NULL
  DROP PROCEDURE zsystem.Versions_Check
GO
CREATE PROCEDURE zsystem.Versions_Check
  @developer  varchar(20) = NULL
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @developers TABLE (developer varchar(20))

  IF @developer IS NULL
  BEGIN
    INSERT INTO @developers (developer)
         SELECT DISTINCT developer FROM zsystem.versions
  END
  ELSE
    INSERT INTO @developers (developer) VALUES (@developer)

  DECLARE @version int, @firstVersion int

  DECLARE @cursor CURSOR
  SET @cursor = CURSOR LOCAL FAST_FORWARD
    FOR SELECT developer FROM @developers ORDER BY developer
  OPEN @cursor
  FETCH NEXT FROM @cursor INTO @developer
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SELECT @firstVersion = MIN([version]) - 1 FROM zsystem.versions WHERE developer = @developer;

    WITH CTE (rowID, versionID, [version]) AS
    (
      SELECT ROW_NUMBER() OVER(ORDER BY [version]),
             [version] - @firstVersion, [version]
        FROM zsystem.versions
        WHERE developer = @developer
    )
    SELECT @version = MAX([version]) FROM CTE WHERE rowID = versionID

    SELECT developer,
           info = CASE WHEN [version] = @version THEN 'LAST CONTINUOUS VERSION' ELSE 'MISSING PRIOR VERSIONS' END,
           [version], versionDate, userName, executionCount, lastDate, coreVersion,
           firstDuration = zutil.TimeString(firstDuration), lastDuration = zutil.TimeString(lastDuration)
      FROM zsystem.versions
     WHERE developer = @developer AND [version] >= @version


    FETCH NEXT FROM @cursor INTO @developer
  END
  CLOSE @cursor
  DEALLOCATE @cursor
GO
GRANT EXEC ON zsystem.Versions_Check TO zzp_server
GO
