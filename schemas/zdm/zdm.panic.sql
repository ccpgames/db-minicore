
IF OBJECT_ID('zdm.panic') IS NOT NULL
  DROP PROCEDURE zdm.panic
GO
CREATE PROCEDURE zdm.panic
AS
  SET NOCOUNT ON

  PRINT ''
  PRINT '#######################'
  PRINT '# DBA Panic Checklist #'
  PRINT '#######################'
  PRINT ''
  PRINT 'Web page: http://wiki/display/db/DBA+Panic+Checklist'
  PRINT ''
  PRINT '------------------------------------------------'
  PRINT 'STORED PROCEDURES TO USE IN A PANIC SITUATION...'
  PRINT '------------------------------------------------'
  PRINT '  zdm.topsql        /  zdm.topsqlp'
  PRINT '  zdm.counters'
  PRINT '  zdm.sessioninfo   /  zdm.processinfo'
  PRINT '  zdm.transactions'
  PRINT '  zdm.applocks'
  PRINT '  zdm.memory'
GO
