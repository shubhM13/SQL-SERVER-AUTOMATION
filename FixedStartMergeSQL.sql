ALTER PROCEDURE [dm].[GenerateFixedStartMergeSQL] @TgtSchemaName VARCHAR(100)
	,@TgtTableName VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @sql VARCHAR(8000)

	SET @sql = '  
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
 SET @CURRENT_PROC = ' + @TgtSchemaName + '.' + 'usp_merge_' + @TgtTableName + '
  BEGIN TRY  '

	PRINT @SQL
END;