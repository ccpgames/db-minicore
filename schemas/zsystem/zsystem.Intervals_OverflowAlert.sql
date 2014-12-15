
IF OBJECT_ID('zsystem.Intervals_OverflowAlert') IS NOT NULL
  DROP PROCEDURE zsystem.Intervals_OverflowAlert
GO
CREATE PROCEDURE zsystem.Intervals_OverflowAlert
  @alertLevel  real = 0.05 -- default alert level (we alert when less than 5% of the ids are left)
AS
  SET NOCOUNT ON

  IF EXISTS (SELECT * FROM zsystem.intervals WHERE (maxID - currentID) / CONVERT(real, (maxID - minID)) <= @alertLevel)
  BEGIN
    DECLARE @recipients varchar(max)
    SET @recipients = zsystem.Settings_Value('zsystem', 'Recipients-Operations-Software')

    IF @recipients != '' AND zsystem.Settings_Value('zsystem', 'Database') = DB_NAME()
    BEGIN
      DECLARE @intervalID int
      DECLARE @intervalName nvarchar(400)
      DECLARE @maxID int
      DECLARE @currentID int
      DECLARE @body nvarchar(max)

      DECLARE @cursor CURSOR
      SET @cursor = CURSOR LOCAL FAST_FORWARD
      FOR SELECT intervalID, intervalName, maxID, currentID
            FROM zsystem.intervals
           WHERE (maxID - currentID) / CONVERT(real, (maxID - minID)) <= @alertLevel
      OPEN @cursor
      FETCH NEXT FROM @cursor INTO @intervalID, @intervalName, @maxID, @currentID
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @body = N'ID''s for the interval: <b>' + @intervalName  + N' (intervalID: '
                  + CONVERT(nvarchar, @intervalID) + N')</b> is getting low.<br>'
                  + N'The current counter is now at ' + CONVERT(nvarchar, @currentID) + N' and the maximum it can '
                  + N'get up to is ' + CONVERT(nvarchar, @maxID) + N', so we will run out after '
                  + CONVERT(nvarchar, (@maxID-@currentID)) + N' ID''s.<br><br>'
                  + N'We need to find another range for it very soon, so please don''t just ignore this mail! <br><br>'
                  + N'That was all <br>  Your friendly automatic e-mail sender'

        EXEC zsystem.SendMail @recipients, 'INTERVAL OVERFLOW ALERT!', @body, 'HTML'
        FETCH NEXT FROM @cursor INTO @intervalID, @intervalName, @maxID, @currentID
      END
      CLOSE @cursor
      DEALLOCATE @cursor
    END
  END
GO
