
-- ToDo: grants, identities

IF OBJECT_ID('zdm.describe') IS NOT NULL
  DROP PROCEDURE zdm.describe
GO
CREATE PROCEDURE zdm.describe
  @objectName  nvarchar(256)
AS
  SET NOCOUNT ON
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

  DECLARE @schemaID int, @schemaName nvarchar(128), @objectID int,
          @type char(2), @typeDesc nvarchar(60),
          @createDate datetime2(0), @modifyDate datetime2(0), @isMsShipped bit,
          @i int, @text nvarchar(max), @parentID int

  SET @i = CHARINDEX('.', @objectName)
  IF @i > 0
  BEGIN
    SET @schemaName = SUBSTRING(@objectName, 1, @i - 1)
    SET @objectName = SUBSTRING(@objectName, @i + 1, 256)
    IF CHARINDEX('.', @objectName) > 0
    BEGIN
      RAISERROR ('Object name invalid', 16, 1)
      RETURN -1
    END

    SELECT @schemaID = [schema_id] FROM sys.schemas WHERE LOWER(name) = LOWER(@schemaName)
    IF @schemaID IS NULL
    BEGIN
      RAISERROR ('Schema not found', 16, 1)
      RETURN -1
    END
  END

  IF @schemaID IS NULL
  BEGIN
    SELECT TOP 2 @objectID = [object_id], @type = [type], @typeDesc = type_desc,
                 @createDate = create_date, @modifyDate = modify_date, @isMsShipped = is_ms_shipped
      FROM sys.objects
     WHERE LOWER(name) = LOWER(@objectName)
  END
  ELSE
  BEGIN
    SELECT TOP 2 @objectID = [object_id], @type = [type], @typeDesc = type_desc,
                 @createDate = create_date, @modifyDate = modify_date, @isMsShipped = is_ms_shipped
      FROM sys.objects
     WHERE [schema_id] = @schemaID AND LOWER(name) = LOWER(@objectName)
  END
  IF @@ROWCOUNT = 1
  BEGIN
    IF @schemaID IS NULL
      SELECT @schemaID = [schema_id] FROM sys.objects WHERE [object_id] = @objectID
    IF @schemaName IS NULL
      SELECT @schemaName = name FROM sys.schemas WHERE [schema_id] = @schemaID

    IF @type IN ('V', 'P', 'FN', 'IF') -- View, Procedure, Scalar Function, Table Function
    BEGIN
      PRINT ''
      SET @text = OBJECT_DEFINITION(OBJECT_ID(@schemaName + '.' + @objectName))
      EXEC zsystem.PrintMax @text
    END
    ELSE IF @type = 'C' -- Check Constraint
    BEGIN
      PRINT ''
      SELECT @text = [definition], @parentID = parent_object_id
        FROM sys.check_constraints
       WHERE [object_id] = @objectID
      EXEC zsystem.PrintMax @text
    END
    ELSE IF @type = 'D' -- Default Constraint
    BEGIN
      PRINT ''
      SELECT @text = C.name + ' = ' + DC.[definition], @parentID = DC.parent_object_id
        FROM sys.default_constraints DC
          INNER JOIN sys.columns C ON C.[object_id] = DC.parent_object_id AND C.column_id = DC.parent_column_id
       WHERE DC.[object_id] = @objectID
      EXEC zsystem.PrintMax @text
    END
    ELSE IF @type IN ('U', 'IT', 'S', 'PK') -- User Table, Internal Table, System Table, Primary Key
    BEGIN
      DECLARE @tableID int, @rows bigint
      IF @type = 'PK' -- Primary Key
      BEGIN
        SELECT [object_id], [object_name] = @schemaName + '.' + @objectName, [type], type_desc, create_date, modify_date, is_ms_shipped, parent_object_id
          FROM sys.objects
         WHERE [object_id] = @objectID

        SELECT @parentID = parent_object_id FROM sys.objects  WHERE [object_id] = @objectID
        SET @tableID = @parentID
      END
      ELSE
        SET @tableID = @objectID

      SELECT @rows = SUM(P.row_count)
        FROM sys.indexes I
          INNER JOIN sys.dm_db_partition_stats P ON P.[object_id] = I.[object_id] AND P.index_id = I.index_id
       WHERE I.[object_id] = @tableID AND I.index_id IN (0, 1)

      SELECT [object_id], [object_name] = @schemaName + '.' + @objectName, [type], type_desc, [rows] = @rows, create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [object_id] = @tableID

      SELECT C.column_id, column_name = C.name, [type_name] = TYPE_NAME(C.system_type_id), C.max_length, C.[precision], C.scale,
             C.collation_name, C.is_nullable, C.is_identity, [default] = D.[definition]
        FROM sys.columns C
          LEFT JOIN sys.default_constraints D ON D.parent_object_id = C.[object_id] AND D.parent_column_id = C.column_id
       WHERE C.[object_id] = @tableID
       ORDER BY C.column_id

      SELECT index_id, index_name = name, [type], type_desc, is_unique, is_primary_key, is_unique_constraint, has_filter, fill_factor, has_filter, filter_definition
        FROM sys.indexes
       WHERE [object_id] = @tableID
       ORDER BY index_id

      SELECT index_name = I.name, IC.key_ordinal, column_name = C.name, IC.is_included_column
        FROM sys.indexes I
          INNER JOIN sys.index_columns IC ON IC.[object_id] = I.[object_id] AND IC.index_id = I.index_id
            INNER JOIN sys.columns C ON C.[object_id] = IC.[object_id] AND C.column_id = IC.column_id
       WHERE I.[object_id] = @tableID
       ORDER BY I.index_id, IC.key_ordinal
    END
    ELSE
    BEGIN
      PRINT ''
      PRINT 'EXTRA INFORMATION NOT AVAILABLE FOR THIS TYPE OF OBJECT!'
    END

    IF @type NOT IN ('U', 'IT', 'S', 'PK')
    BEGIN
      PRINT REPLICATE('_', 100)
      IF @isMsShipped = 1
        PRINT 'THIS IS A MICROSOFT OBJECT'

      IF @parentID IS NOT NULL
        PRINT '  PARENT: ' + OBJECT_SCHEMA_NAME(@parentID) + '.' + OBJECT_NAME(@parentID)

      PRINT '    Name: ' + @schemaName + '.' + @objectName
      PRINT '    Type: ' + @typeDesc
      PRINT ' Created: ' + CONVERT(varchar, @createDate, 120)
      PRINT 'Modified: ' + CONVERT(varchar, @modifyDate, 120)
    END
  END
  ELSE
  BEGIN
    IF @schemaID IS NULL
    BEGIN
      SELECT O.[object_id], [object_name] = S.name + '.' + O.name, O.[type], O.type_desc, O.parent_object_id,
             O.create_date, O.modify_date, O.is_ms_shipped
        FROM sys.objects O
          INNER JOIN sys.schemas S ON S.[schema_id] = O.[schema_id]
       WHERE LOWER(O.name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY CASE O.[type] WHEN 'U' THEN '_A' WHEN 'V' THEN '_B' WHEN 'P' THEN '_C' WHEN 'FN' THEN '_D' WHEN 'IF' THEN '_E' WHEN 'PK' THEN '_F' ELSE O.[type] END,
                LOWER(S.name), LOWER(O.name)
    END
    ELSE
    BEGIN
      SELECT [object_id], [object_name] = @schemaName + '.' + name, [type], type_desc, parent_object_id,
             create_date, modify_date, is_ms_shipped
        FROM sys.objects
       WHERE [schema_id] = @schemaID AND LOWER(name) LIKE '%' + LOWER(@objectName) + '%'
       ORDER BY CASE [type] WHEN 'U' THEN '_A' WHEN 'V' THEN '_B' WHEN 'P' THEN '_C' WHEN 'FN' THEN '_D' WHEN 'IF' THEN '_E' WHEN 'PK' THEN '_F' ELSE [type] END,
                LOWER(name)
    END
  END
GO


IF OBJECT_ID('zdm.d') IS NOT NULL
  DROP SYNONYM zdm.d
GO
CREATE SYNONYM zdm.d FOR zdm.describe
GO
