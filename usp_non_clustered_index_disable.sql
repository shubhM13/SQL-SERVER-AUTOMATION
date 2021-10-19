/**************************************************************************************************************************************                
   Name         : [usp_non_clustered_index_disable]           
   Purpose      : Disable all non-clustered indexes on a table.  
   Used By      : ETL Pre Script  
   Created by   : Shubham Mishra              
   Created on   : 27/01/2021                
****************************************************************************************************************************************/

-- Disable all non-clustered indexes on a table.

CREATE PROCEDURE [dm].[usp_non_clustered_index_disable]
	@fact_table_name NVARCHAR(150)
AS
BEGIN
	DECLARE @sql_command NVARCHAR(MAX) = N''
	BEGIN TRY
		SELECT @sql_command += N'
			ALTER INDEX ' + QUOTENAME(ix.[name]) + ' ON ' 
			+ OBJECT_NAME(ID) + ' DISABLE; '
		FROM  sysindexes ix
		WHERE ix.indid > 1 --Nonclustered index(>1)
              AND QUOTENAME(ix.[Name]) like '%IX_fact_%'
              AND OBJECT_NAME(ID) = @fact_table_name
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

