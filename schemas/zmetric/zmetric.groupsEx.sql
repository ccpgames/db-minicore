
IF OBJECT_ID('zmetric.groupsEx') IS NOT NULL
  DROP VIEW zmetric.groupsEx
GO
CREATE VIEW zmetric.groupsEx
AS
  WITH CTE ([level], fullName, parentGroupID, groupID, groupName, [description], [order]) AS
  (
      SELECT [level] = 1, fullName = CONVERT(nvarchar(4000), groupName),
             parentGroupID, groupID, groupName, [description], [order]
        FROM zmetric.groups G
       WHERE parentGroupID IS NULL
      UNION ALL
      SELECT CTE.[level] + 1, CTE.fullName + N', ' + CONVERT(nvarchar(4000), X.groupName),
             X.parentGroupID, X.groupID, X.groupName,  X.[description], X.[order]
        FROM CTE
          INNER JOIN zmetric.groups X ON X.parentGroupID = CTE.groupID
  )
  SELECT [level], fullName, parentGroupID, groupID, groupName, [description], [order]
    FROM CTE
GO
GRANT SELECT ON zmetric.groupsEx TO zzp_server
GO
