
-- *** intervalID from 2000000000 and up is reserved for CORE ***

IF OBJECT_ID('zsystem.intervals') IS NULL
BEGIN
  CREATE TABLE zsystem.intervals
  (
    intervalID     int            NOT NULL,
    intervalName   nvarchar(200)  NOT NULL,
    [description]  nvarchar(max)  NOT NULL,
    minID          bigint         NOT NULL,
    maxID          bigint         NOT NULL,
    currentID      bigint         NOT NULL,
    tableID        int            NULL,
    --
    CONSTRAINT intervals_PK PRIMARY KEY CLUSTERED (intervalID)
  )
END
GRANT SELECT ON zsystem.intervals TO zzp_server
GO



-- Data
IF NOT EXISTS(SELECT * FROM zsystem.intervals WHERE intervalID = 2000000001)
  INSERT INTO zsystem.intervals (intervalID, intervalName, [description], minID, maxID, currentID, tableID)
       VALUES (2000000001, 'CORE - Characters', 'characterID for characters in zcharacter.characters.', 500000000, 1000000000, 500000000, 2001600001)
GO
