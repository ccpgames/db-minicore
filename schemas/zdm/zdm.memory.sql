
IF OBJECT_ID('zdm.memory') IS NOT NULL
  DROP PROCEDURE zdm.memory
GO
CREATE PROCEDURE zdm.memory
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [object_name], counter_name,
         cntr_value = CASE WHEN counter_name LIKE '%(KB)%' THEN CASE WHEN cntr_value > 1048576 THEN CONVERT(varchar, CONVERT(money, cntr_value / 1048576.0)) + ' GB'
                                                                     WHEN cntr_value > 1024 THEN CONVERT(varchar, CONVERT(money, cntr_value / 1024.0)) + ' MB'
                                                                     ELSE CONVERT(varchar, cntr_value) + ' KB' END
                           ELSE CONVERT(varchar, cntr_value) END
    FROM sys.dm_os_performance_counters
   WHERE [object_name] = 'SQLServer:Memory Manager'
   ORDER BY instance_name, [object_name], counter_name
GO
