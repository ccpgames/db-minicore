
IF OBJECT_ID('zdm.transactions') IS NOT NULL
  DROP PROCEDURE zdm.transactions
GO
CREATE PROCEDURE zdm.transactions
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT [description] = 'All active transactions that have done something...'
  SELECT tat.*, tdt.*
    FROM sys.dm_tran_database_transactions tdt
      LEFT JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = tdt.transaction_id
   WHERE tdt.database_id = DB_ID()
   ORDER BY tdt.database_transaction_begin_time

  SELECT [description] = 'Active transactions that have done nothing...'
  SELECT *
    FROM sys.dm_tran_active_transactions tat
      LEFT JOIN sys.dm_tran_database_transactions tdt ON tdt.transaction_id = tat.transaction_id
   WHERE tdt.transaction_id IS NULL
   ORDER BY tat.transaction_begin_time
GO
