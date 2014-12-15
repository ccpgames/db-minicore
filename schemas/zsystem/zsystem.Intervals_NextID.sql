
IF OBJECT_ID('zsystem.Intervals_NextID') IS NOT NULL
  DROP PROCEDURE zsystem.Intervals_NextID
GO
CREATE PROCEDURE zsystem.Intervals_NextID
  @intervalID  int,
  @nextID      bigint OUTPUT
AS
  SET NOCOUNT ON

  UPDATE zsystem.intervals SET @nextID = currentID = currentID + 1 WHERE intervalID = @intervalID
GO
