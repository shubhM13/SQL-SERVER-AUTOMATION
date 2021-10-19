/****** Object:  StoredProcedure [AUDIT].[DELTA_LOAD_DYNAMIC]    Script Date: 04-10-2021 22:55:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [AUDIT].[DELTA_LOAD_DYNAMIC] (@Tablename VARCHAR(5000), @HistoryLoad INT)
AS
BEGIN
	---Truncate Target Table for History Load
    IF @HistoryLoad = 1
    BEGIN
        DECLARE @TRUNCATE_SQL VARCHAR(200)
		SET @TRUNCATE_SQL ='TRUNCATE TABLE DWH.' + @Tablename
		EXEC (@TRUNCATE_SQL)
    END
	---Declare all the required variables---------
	--DECLARE @Tablename  VARCHAR(5000)
	DECLARE @Schemaname_stg VARCHAR(5000)
	DECLARE @Schemaname_dwh VARCHAR(5000)
	DECLARE @DWHTABLE VARCHAR(5000)
	DECLARE @STGTABLE VARCHAR(5000)
	DECLARE @KEY1 VARCHAR(5000)
	DECLARE @KEY2 VARCHAR(5000)
	DECLARE @KEY_COLUMN VARCHAR(5000)
	DECLARE @UPDATECOLUMNS VARCHAR(5000)
	DECLARE @INSERTCOLUMNS VARCHAR(4000)
	DECLARE @INSERTCOLUMNSVALUES VARCHAR(4000)
	DECLARE @DWHTABLE_T TABLE (COL VARCHAR(5000))
	DECLARE @STGTABLE_T TABLE (COL VARCHAR(5000))
	DECLARE @KEY1_T TABLE (COL VARCHAR(5000))
	DECLARE @KEY2_T TABLE (COL VARCHAR(5000))
	DECLARE @KEY_COLUMN_T TABLE (COL VARCHAR(5000))
	DECLARE @UPDATECOLUMNS_T TABLE (COL VARCHAR(5000))
	DECLARE @INSERTCOLUMNS_T TABLE (COL VARCHAR(5000))
	DECLARE @INSERTCOLUMNSVALUES_T TABLE (COL VARCHAR(5000))
	DECLARE @DWHTABLE_V VARCHAR(5000)
	DECLARE @STGTABLE_V VARCHAR(5000)
	DECLARE @KEY1_V VARCHAR(5000)
	DECLARE @KEY2_V VARCHAR(5000)
	DECLARE @KEY_COLUMN_V VARCHAR(5000)
	DECLARE @UPDATECOLUMNS_V VARCHAR(5000)
	DECLARE @INSERTCOLUMNS_V VARCHAR(4000)
	DECLARE @INSERTCOLUMNSVALUES_V VARCHAR(4000)
	DECLARE @MERGE VARCHAR(5000)
	DECLARE @ERROR_PROC VARCHAR(5000)
	DECLARE @ROW INT
	DECLARE @STG_COUNT VARCHAR(5000)
	DECLARE @STG_COUNT_V VARCHAR(5000)
	DECLARE @STG_COUNT_T TABLE (COL VARCHAR(5000))

	----Set the values of all the variables which are going to use for operation-----
	--SET @Tablename='AT_Criteria'
	SET @Schemaname_stg = 'stg'
	SET @Schemaname_dwh = 'dwh'
	SET @ERROR_PROC = 'AUDIT.spGetErrorInfo'
	----Getting the values from SP_Control_Table-----
	SET @DWHTABLE = ('select DISTINCT Schemaname+' + '''.''' + '+Tablename AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_dwh + '''')
	SET @STGTABLE = ('select DISTINCT Schemaname+' + '''.''' + '+Tablename AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_stg + '''')
	SET @KEY1 = ('select DISTINCT ''B.''+Columnname AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_dwh + '''' + ' and Primarycolumn=''Y''')
	SET @KEY2 = ('select DISTINCT ''A.''+Columnname AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_stg + '''' + ' and Primarycolumn=''Y''')
	SET @KEY_COLUMN = ('select Key_Columns AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_stg + '''' + ' and Primarycolumn=''Y''')
	SET @UPDATECOLUMNS = ('select  STRING_AGG(''A.[''+Columnname+'']=''+''B.[''+Columnname+'']'','','') AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_dwh + '''' + ' and Primarycolumn<>''Y''')
	SET @INSERTCOLUMNS = ('select  STRING_AGG(''[''+Columnname+'']'','','') AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_dwh + '''')
	SET @INSERTCOLUMNSVALUES = ('select  STRING_AGG(''B.[''+Columnname+'']'','','') AS COL from AUDIT.SP_CONTROL_TABLE where Tablename=' + '''' + @Tablename + '''' + ' and Schemaname =' + '''' + @Schemaname_dwh + '''')
	SET @STG_COUNT = ('Select COUNT(*) FROM stg.' + @Tablename)

	----Insert into TEMPTABLES-----------
	INSERT INTO @DWHTABLE_T
	EXEC (@DWHTABLE)

	INSERT INTO @STGTABLE_T
	EXEC (@STGTABLE)

	INSERT INTO @KEY1_T
	EXEC (@KEY1)

	INSERT INTO @KEY2_T
	EXEC (@KEY2)

	INSERT INTO @KEY_COLUMN_T
	EXEC (@KEY_COLUMN)

	INSERT INTO @UPDATECOLUMNS_T
	EXEC (@UPDATECOLUMNS)

	INSERT INTO @INSERTCOLUMNS_T
	EXEC (@INSERTCOLUMNS)

	INSERT INTO @INSERTCOLUMNSVALUES_T
	EXEC (@INSERTCOLUMNSVALUES)

	INSERT INTO @STG_COUNT_T
	EXEC (@STG_COUNT)

	----Assign the insert values into Variables------------
	SET @DWHTABLE_V = (
			SELECT *
			FROM @DWHTABLE_T
			)
	SET @STGTABLE_V = (
			SELECT *
			FROM @STGTABLE_T
			)
	SET @KEY1_V = (
			SELECT *
			FROM @KEY1_T
			)
	SET @KEY2_V = (
			SELECT *
			FROM @KEY2_T
			)
	SET @KEY_COLUMN_V = (
			SELECT *
			FROM @KEY_COLUMN_T
			)
	SET @UPDATECOLUMNS_V = (
			SELECT *
			FROM @UPDATECOLUMNS_T
			)
	SET @INSERTCOLUMNS_V = (
			SELECT *
			FROM @INSERTCOLUMNS_T
			)
	SET @INSERTCOLUMNSVALUES_V = (
			SELECT *
			FROM @INSERTCOLUMNSVALUES_T
			)
	SET @STG_COUNT_V = (
			SELECT *
			FROM @STG_COUNT_T
			)
	-----Merge Framework for insert and update-------------------
	SET @MERGE = (
			'DECLARE @ROW INT MERGE INTO ' + @DWHTABLE_V + ' A USING ' + @STGTABLE_V + ' B ON (' + @KEY_COLUMN_V + ') 
WHEN MATCHED 
THEN UPDATE 
SET ' + @UPDATECOLUMNS_V + ',ADF_Action_Flag=''UPDATE'',ADF_Action_Date=CAST(GETDATE() AS DATETIME)  
WHEN NOT MATCHED
THEN INSERT ' + ' (' + @INSERTCOLUMNS_V + ',ADF_Action_Flag,ADF_Action_Date) VALUES (' + @INSERTCOLUMNSVALUES_V + ' ,''INSERT'',CAST(GETDATE() AS DATETIME) )
		OUTPUT $ACTION
			,Inserted.*;
			SET @ROW = (
				SELECT @@ROWCOUNT
				)
INSERT INTO [AUDIT].[adf_pipeline_logs] (
			adfname
			,pipelinename
			,activityname
			,tablename
			,runid
			,triggername
			,triggertime
			,rowsread
			,rowscopied
			,copyduration,
			throughput
			,errors
			)
		VALUES ( ''glbl-dv-coffeeecosystem-id-euno-adf''
		,''PL_SAP_To_ADLS_To_STG_Delta_Load''
			,''Copy Table from STG to DWH'',''' + @Tablename + '''' + ',''StoredProedure''
			,''SP_Delta''
			,CURRENT_TIMESTAMP,' + @STG_COUNT_V + ',@ROW
			,0
			,0
			,''NA'');'
			)

	PRINT (@MERGE)

	EXEC (@MERGE)

	BEGIN TRY
		UPDATE AUDIT.SP_CONTROL_TABLE
		SET Last_Run_Date = CURRENT_TIMESTAMP
			,Last_Run_Status = 'Completed'
		WHERE Tablename = @Tablename
			AND Primarycolumn = 'Y'
			AND Schemaname = 'dwh';
	END TRY

	BEGIN CATCH
		EXEC @ERROR_PROC @Tablename = @Tablename;

		UPDATE AUDIT.SP_CONTROL_TABLE
		SET Last_Run_Date = CURRENT_TIMESTAMP
			,Last_Run_Status = 'Failed'
		WHERE Tablename = @Tablename
			AND Primarycolumn = 'Y'
			AND Schemaname = 'dwh';
	END CATCH
END
GO

DECLARE @HistoryLoad INT
SET @HistoryLoad = 1
IF @HistoryLoad = 1
BEGIN
	DECLARE @Tablename VARCHAR(100)
	SET @Tablename = 'AT_Observation'
    DECLARE @TRUNCATE_SQL VARCHAR(200)
	SET @TRUNCATE_SQL ='TRUNCATE TABLE STG.' + @Tablename
	EXEC (@TRUNCATE_SQL)
END
select * from STG.AT_Observation;