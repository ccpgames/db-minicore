
-- Code from Itzik Ben-Gan, a very fast inline table function that will return a table of numbers

IF OBJECT_ID('zutil.Numbers') IS NOT NULL
  DROP FUNCTION zutil.Numbers
GO
CREATE FUNCTION zutil.Numbers(@n int)
  RETURNS TABLE
  RETURN WITH L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
              L1   AS(SELECT 1 AS c FROM L0 AS A, L0 AS B),
              L2   AS(SELECT 1 AS c FROM L1 AS A, L1 AS B),
              L3   AS(SELECT 1 AS c FROM L2 AS A, L2 AS B),
              L4   AS(SELECT 1 AS c FROM L3 AS A, L3 AS B),
              L5   AS(SELECT 1 AS c FROM L4 AS A, L4 AS B),
              Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY c) AS n FROM L5)
         SELECT n FROM Nums WHERE n <= @n;
GO
GRANT SELECT ON zutil.Numbers TO zzp_server
GO
