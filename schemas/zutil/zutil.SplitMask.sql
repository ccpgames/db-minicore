
IF OBJECT_ID('zutil.SplitMask') IS NOT NULL
  DROP FUNCTION zutil.SplitMask
GO
CREATE FUNCTION zutil.SplitMask(@bitMask bigint)
  RETURNS TABLE
  RETURN SELECT [bit] = POWER(CONVERT(bigint, 2), n - 1) FROM zutil.Numbers(63) WHERE @bitMask & POWER(CONVERT(bigint, 2), n - 1) > 0
GO
