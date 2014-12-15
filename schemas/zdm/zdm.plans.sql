
IF OBJECT_ID('zdm.plans') IS NOT NULL
  DROP PROCEDURE zdm.plans
GO
CREATE PROCEDURE zdm.plans
  @filter      nvarchar(256),
  @objectType  nvarchar(20) = 'Proc',
  @rows        smallint = 50
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT TOP (@rows) C.objtype, C.cacheobjtype, C.refcounts, C.usecounts, C.size_in_bytes,
         P.query_plan, T.[text]
    FROM sys.dm_exec_cached_plans C
      CROSS APPLY sys.dm_exec_sql_text (C.plan_handle) T
      CROSS APPLY sys.dm_exec_query_plan(C.plan_handle) P
   WHERE C.objtype = @objectType AND T.[text] like N'%' + @filter + N'%'
   ORDER BY C.usecounts DESC
GO
