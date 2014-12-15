
IF OBJECT_ID('zdm.applocks') IS NOT NULL
  DROP PROCEDURE zdm.applocks
GO
CREATE PROCEDURE zdm.applocks
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  SELECT resource_database_id, resource_database_name = DB_NAME(resource_database_id), resource_description,
         request_mode, request_type, request_status, request_reference_count, request_session_id, request_owner_type
    FROM sys.dm_tran_locks
   WHERE resource_type = 'APPLICATION'
GO
