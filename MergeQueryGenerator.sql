ALTER PROCEDURE [dm].[GenerateMergeSQL] @TgtSchemaName VARCHAR(100), 
@TgtTableName VARCHAR(100) AS BEGIN 
SET 
  NOCOUNT ON DECLARE @sql VARCHAR(8000), 
  @SourceInsertColumns VARCHAR(8000), 
  @DestInsertColumns VARCHAR(8000), 
  @UpdateClause VARCHAR(8000) DECLARE @ColumnName VARCHAR(100), 
  @identityColName VARCHAR(100) DECLARE @IsIdentity INT, 
  @IsComputed INT, 
  @Data_Type VARCHAR(50) DECLARE @SourceDB AS VARCHAR(200) -- source/dest i.e. 'instance.catalog.owner.' - table names will be appended to this  
  -- the destination is your current db context  
SET 
  @SourceDB = '' 
SET 
  @sql = '' 
SET 
  @SourceInsertColumns = '' 
SET 
  @DestInsertColumns = '' 
SET 
  @UpdateClause = '' 
SET 
  @ColumnName = '' 
SET 
  @isIdentity = 0 
SET 
  @IsComputed = 0 
SET 
  @identityColName = '' 
SET 
  @Data_Type = '' DECLARE @ColNames CURSOR 
SET 
  @ColNames = CURSOR FOR 
SELECT 
  A.column_name, 
  CASE WHEN C.COLUMN_NAME = A.COLUMN_NAME THEN 1 ELSE 0 END AS IsIdentity, 
  COLUMNPROPERTY(
    object_id(
      @TgtSchemaName + '.' + @TgtTableName
    ), 
    A.COLUMN_NAME, 
    'IsComputed'
  ) AS IsComputed, 
  A.DATA_TYPE 
FROM 
  information_schema.columns AS A 
  INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS B ON A.TABLE_NAME = B.TABLE_NAME 
  AND A.TABLE_SCHEMA = B.TABLE_SCHEMA 
  INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS C ON B.TABLE_NAME = C.TABLE_NAME 
  AND B.TABLE_SCHEMA = C.TABLE_SCHEMA 
  AND B.CONSTRAINT_CATALOG = C.CONSTRAINT_CATALOG 
  AND B.CONSTRAINT_SCHEMA = C.CONSTRAINT_SCHEMA 
  AND B.CONSTRAINT_NAME = C.CONSTRAINT_NAME 
WHERE 
  A.TABLE_NAME = @TgtTableName 
  AND A.TABLE_SCHEMA = @TgtSchemaName 
ORDER BY 
  A.ordinal_position OPEN @ColNames FETCH NEXT 
FROM 
  @ColNames INTO @ColumnName, 
  @isIdentity, 
  @IsComputed, 
  @DATA_TYPE WHILE @@FETCH_STATUS = 0 BEGIN IF @IsComputed = 0 
  AND @DATA_TYPE <> 'timestamp' BEGIN 
SET 
  @SourceInsertColumns = @SourceInsertColumns + CASE WHEN @SourceInsertColumns = '' THEN '' ELSE ',' END + 'S.' + '[' + @ColumnName + ']' 
SET 
  @DestInsertColumns = @DestInsertColumns + CASE WHEN @DestInsertColumns = '' THEN '' ELSE ',' END + '[' + @ColumnName + ']' IF @isIdentity = 0 BEGIN 
SET 
  @UpdateClause = @UpdateClause + CASE WHEN @UpdateClause = '' THEN '' ELSE ',' END + '[' + @ColumnName + ']' + ' = ' + 'S.' + '[' + @ColumnName + ']' + CHAR(10) END IF @isIdentity = 1 
SET 
  @identityColName = @ColumnName END FETCH NEXT 
FROM 
  @ColNames INTO @ColumnName, 
  @isIdentity, 
  @IsComputed, 
  @DATA_TYPE END CLOSE @ColNames DEALLOCATE @ColNames 
SET 
  @sql = '  
/*******************************************  
 Name   : ' + @TgtSchemaName + '.' + 'usp_merge_' + @TgtTableName + '  
 Author     : Shubham Mishra  
 Created On : ' + FORMAT(
    getdate(), 
    'dd, MMM, yyyy'
  ) + '  
 PURPOSE    : Data Model Incremental Setup  
 *******************************************/  
--drop procedure ' + @TgtSchemaName + '.' + 'usp_merge_' + @TgtTableName + '  
CREATE PROCEDURE ' + @TgtSchemaName + '.' + 'usp_merge_' + @TgtTableName + ' (@pipeline_name AS VARCHAR(100) = NULL, @run_id AS VARCHAR(100) = NULL)  
AS  
BEGIN  
 DECLARE @ERROR_PROC VARCHAR(5000), @CURRENT_PROC NVARCHAR(255), @ROW INT  
 DECLARE @StartDate datetime, @EndDate datetime
 SET @StartDate = getdate()
 SET @ERROR_PROC = ''[AUDIT].[usp_insert_data_model_merge_error]''
 SET @CURRENT_PROC = ''' + @TgtSchemaName + '.' + 'usp_merge_' + @TgtTableName + '''
 BEGIN TRY  
  MERGE ' + @TgtSchemaName + '.' + @TgtTableName + ' AS D  
  USING ' + @TgtSchemaName + '.' + 'view_' + @TgtTableName + ' AS S  
   ON (D.' + @identityColName + ' = S.' + @identityColName + ')  
  WHEN NOT MATCHED BY TARGET  
   THEN  
    INSERT (' + @DestInsertColumns + ')  
    VALUES (' + @SourceInsertColumns + ')  
  WHEN MATCHED  
   THEN  
    UPDATE  
    SET ' + @UpdateClause + '  
  WHEN NOT MATCHED BY SOURCE  
   THEN  
    DELETE  
  OUTPUT $ACTION  
   ,Inserted.*  
   ,Deleted.*;  
  SET @ROW = (  
    SELECT @@ROWCOUNT  
    );  
  SET @EndDate = getdate();
  INSERT INTO [AUDIT].[data_model_merge_log] (  
   schema_name, table_name ,last_run_ts ,last_run_status, count, pipeline_name, run_id, run_time_sec, start_time, end_time, merge_proc_name
   )  
  VALUES (  
   ' + '''' + @TgtSchemaName + '''' + ', ' + '''' + @TgtTableName + '''' + ', CURRENT_TIMESTAMP, ''SUCCESS'', @ROW, @pipeline_name, @run_id, datediff(ss,@StartDate, @EndDate), @StartDate, @EndDate, @CURRENT_PROC
   );  
 END TRY  
 BEGIN CATCH  
  EXEC @ERROR_PROC @pipeline_name = @pipeline_name  
   ,@run_id = @run_id;  
  INSERT INTO [AUDIT].[data_model_merge_log] (  
   schema_name, table_name ,last_run_ts ,last_run_status, count, pipeline_name, run_id, run_time_sec, start_time, end_time, merge_proc_name  
   )  
  VALUES (  
   ' + '''' + @TgtSchemaName + '''' + ', ' + '''' + @TgtTableName + '''' + ', CURRENT_TIMESTAMP, ''FAIL'', NULL, @pipeline_name, @run_id, datediff(ss,@StartDate, @EndDate), @StartDate, @EndDate, @CURRENT_PROC  
   );  
 END CATCH  
END   
GO' PRINT @SQL END;
