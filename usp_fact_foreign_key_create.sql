/**************************************************************************************************************************************                
   Name         : [usp_fact_foreign_key_create]             
   Purpose      : Re-create all foreign keys in the fact tables.     
   Used By      : ETL Post Script  
   Created by   : Shubham Mishra              
   Created on   : 27/01/2021                
****************************************************************************************************************************************/

-- Re-create all foreign keys in the fact tables.

CREATE PROCEDURE [dm].[usp_fact_foreign_key_create]

@fact_table_name NVARCHAR(150) = NULL

AS

BEGIN

DECLARE @sql_command NVARCHAR(MAX) = N'';

BEGIN TRY

WITH fact_cte
AS
(
SELECT s.[name] as schemas_name
   ,t.[name] as fact_table_name
   ,c.[name] as column_name   
FROM sys.columns c
INNER JOIN sys.tables  t ON c.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.[name] LIKE 'fact_%' and c.[name] LIKE '%_key'
),
dim_cte
AS
(
SELECT s.[name] as schemas_name
   ,t.[name] as dim_table_name
   ,c.[name] as column_name   
FROM sys.columns c
INNER JOIN sys.tables  t ON c.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.[name] LIKE 'dim_%' and c.[name] LIKE '%_key'
)
SELECT @sql_command += N'
ALTER TABLE ' + QUOTENAME(f.schemas_name) + '.' + QUOTENAME(f.fact_table_name) 
+ ' ADD CONSTRAINT [FK_' + f.fact_table_name + '_' + d.dim_table_name 
+ '] FOREIGN KEY (' +  QUOTENAME(f.column_name) + ') '
+ 'REFERENCES ' + QUOTENAME(d.schemas_name) + '.' + QUOTENAME(d.dim_table_name)
+ '(' + QUOTENAME(d.column_name) +');'
FROM fact_cte f INNER JOIN dim_cte d ON f.column_name = d.column_name
WHERE f.fact_table_name = @fact_table_name OR @fact_table_name is NULL; 
EXEC (@sql_command)

END TRY

BEGIN CATCH

 DECLARE @ErrorMessage NVARCHAR(4000);
 DECLARE @ErrorSeverity INT;
 DECLARE @ErrorState INT;
 SELECT @ErrorMessage = ERROR_MESSAGE(),
  @ErrorSeverity = ERROR_SEVERITY(),
  @ErrorState = ERROR_STATE();

 RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState );
 INSERT INTO dbo.DB_Errors VALUES()
 RETURN 1

END CATCH

RETURN 0

END	

