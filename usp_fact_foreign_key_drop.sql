/**************************************************************************************************************************************                
   Name         : usp_fact_foreign_key_drop             
   Purpose      : Drop all foreign keys in the fact tables       
   Used By      : ETL Pre Script  
   Created by   : Shubham Mishra              
   Created on   : 27/01/2021              
   Task         : Todo Portal V2.1     
****************************************************************************************************************************************/

CREATE PROCEDURE [dm].[usp_fact_foreign_key_drop]
@fact_table_name NVARCHAR(150) = NULL
AS

BEGIN

DECLARE @sql_command NVARCHAR(MAX) = N''

BEGIN TRY

SELECT @sql_command +=N'
ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) 
+ ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';'
FROM sys.foreign_keys AS fk INNER JOIN sys.tables AS ct
	ON fk.parent_object_id = ct.[object_id]
INNER JOIN sys.schemas AS cs 
	ON ct.[schema_id] = cs.[schema_id]
WHERE ct.name = @fact_table_name OR @fact_table_name is NULL ;

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

      RETURN 1

END CATCH

RETURN 0

END