
IF OBJECT_ID('zutil.IntToRoman') IS NOT NULL
  DROP FUNCTION zutil.IntToRoman
GO
CREATE FUNCTION zutil.IntToRoman(@intvalue int)
RETURNS varchar(20)
BEGIN
  DECLARE @str varchar(20)
  SET @str = CASE @intvalue
               WHEN 1 THEN 'I'
               WHEN 2 THEN 'II'
               WHEN 3 THEN 'III'
               WHEN 4 THEN 'IV'
               WHEN 5 THEN 'V'
               WHEN 6 THEN 'VI'
               WHEN 7 THEN 'VII'
               WHEN 8 THEN 'VIII'
               WHEN 9 THEN 'IX'
               WHEN 10 THEN 'X'
               WHEN 11 THEN 'XI'
               WHEN 12 THEN 'XII'
               WHEN 13 THEN 'XIII'
               WHEN 14 THEN 'XIV'
               WHEN 15 THEN 'XV'
               WHEN 16 THEN 'XVI'
               WHEN 17 THEN 'XVII'
               WHEN 18 THEN 'XVIII'
               WHEN 19 THEN 'XIX'
               WHEN 20 THEN 'XX'
               WHEN 21 THEN 'XXI'
               WHEN 22 THEN 'XXII'
               WHEN 23 THEN 'XXIII'
               WHEN 24 THEN 'XXIV'
               WHEN 25 THEN 'XXV'
               WHEN 26 THEN 'XXVI'
               WHEN 27 THEN 'XXVII'
               WHEN 28 THEN 'XXVIII'
               WHEN 29 THEN 'XXIX'
               WHEN 30 THEN 'XXX'
               WHEN 31 THEN 'XXXI'
               WHEN 32 THEN 'XXXII'
               WHEN 33 THEN 'XXXIII'
               WHEN 34 THEN 'XXXIV'
               WHEN 35 THEN 'XXXV'
               WHEN 36 THEN 'XXXVI'
               WHEN 37 THEN 'XXXVII'
               WHEN 38 THEN 'XXXVIII'
               WHEN 39 THEN 'XXXIX'
               WHEN 40 THEN 'XL'
               WHEN 41 THEN 'XLI'
               WHEN 42 THEN 'XLII'
               WHEN 43 THEN 'XLIII'
               WHEN 44 THEN 'XLIV'
               WHEN 45 THEN 'XLV'
               WHEN 46 THEN 'XLVI'
               WHEN 47 THEN 'XLVII'
               WHEN 48 THEN 'XLVIII'
               WHEN 49 THEN 'XLIX'
               WHEN 50 THEN 'L'
               WHEN 51 THEN 'LI'
               WHEN 52 THEN 'LII'
               WHEN 53 THEN 'LIII'
               WHEN 54 THEN 'LIV'
               WHEN 55 THEN 'LV'
               WHEN 56 THEN 'LVI'
               WHEN 57 THEN 'LVII'
               WHEN 58 THEN 'LVIII'
               WHEN 59 THEN 'LIX'
               WHEN 60 THEN 'LX'
               ELSE '???'
             END
  RETURN @str
END
GO
GRANT EXEC ON zutil.IntToRoman TO public
GO
