  drop procedure [dm].[proc_PivotPrepare];
  CREATE PROCEDURE [dm].[proc_PivotPrepare] 
    (
    @DB_Name        nvarchar(128),
    @TableName      nvarchar(128)
    )
    AS
            SELECT @DB_Name = ISNULL(@DB_Name,db_name())
    DECLARE @SQL_Code nvarchar(max)

    DECLARE @MyTab TABLE (ID smallint identity(1,1), [Column_Name] nvarchar(128), [Type] nchar(1), [Set Action SQL] nvarchar(max));

    SELECT @SQL_Code        =   'SELECT [<| SQL_Code |>] = '' '' '
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''-----| Declare user defined type [ID] / [ColumnName] / [PivotAction] '' '
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''DECLARE @ColumnListWithActions ColumnActionList;'''
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''-----| Set [PivotAction] (''''S'''' as default) to select dimentions and values '' '
                                        + 'UNION ALL '
                                        + 'SELECT ''-----|'''
                                        + 'UNION ALL '
                                        + 'SELECT ''-----| ''''S'''' = Stable column || ''''D'''' = Dimention column || ''''V'''' = Value column '' '
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''INSERT INTO  @ColumnListWithActions VALUES ('' + CAST( ROW_NUMBER() OVER (ORDER BY [NAME]) as nvarchar(10)) + '', '' + '''''''' + [NAME] + ''''''''+ '', ''''S'''');'''
                                        + 'FROM [' + @DB_Name + '].sys.columns  '
                                        + 'WHERE object_id = object_id(''[' + @DB_Name + ']..[' + @TableName + ']'') '
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''-----| Execute sp_PivotExecute with parameters: columns and dimentions and main table name'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '
                                        + 'UNION ALL '
                                        + 'SELECT ''EXEC [dm].[sp_PivotExecute] @ColumnListWithActions, ' + '''''' + @TableName + '''''' + ';'''
                                        + 'UNION ALL '
                                        + 'SELECT ''----------------------------------------------------------------------------------------------------'' '                            
EXECUTE SP_EXECUTESQL @SQL_Code;

GO

CREATE PROCEDURE [dm].[sp_PivotExecute]
(
@ColumnListWithActions  ColumnActionList ReadOnly
,@TableName                     nvarchar(128)
)
AS


--#######################################################################################################################
--###| Step 1 - Select our user-defined-table-variable into temp table
--#######################################################################################################################

IF OBJECT_ID('tempdb.dm.#ColumnListWithActions', 'U') IS NOT NULL DROP TABLE #ColumnListWithActions; 
SELECT * INTO #ColumnListWithActions FROM @ColumnListWithActions;

--#######################################################################################################################
--###| Step 2 - Preparing lists of column groups as strings:
--#######################################################################################################################

DECLARE @ColumnName                     nvarchar(128)
DECLARE @Destiny                        nchar(1)

DECLARE @ListOfColumns_Stable           nvarchar(max)
DECLARE @ListOfColumns_Dimension    nvarchar(max)
DECLARE @ListOfColumns_Variable     nvarchar(max)
--############################
--###| Cursor for List of Stable Columns
--############################

DECLARE ColumnListStringCreator_S CURSOR FOR
SELECT      [ColumnName]
FROM        #ColumnListWithActions
WHERE       [Action] = 'S'
OPEN ColumnListStringCreator_S;
FETCH NEXT FROM ColumnListStringCreator_S
INTO @ColumnName
  WHILE @@FETCH_STATUS = 0

   BEGIN
        SELECT @ListOfColumns_Stable = ISNULL(@ListOfColumns_Stable, '') + ' [' + @ColumnName + '] ,';
        FETCH NEXT FROM ColumnListStringCreator_S INTO @ColumnName
   END

CLOSE ColumnListStringCreator_S;
DEALLOCATE ColumnListStringCreator_S;

--############################
--###| Cursor for List of Dimension Columns
--############################

DECLARE ColumnListStringCreator_D CURSOR FOR
SELECT      [ColumnName]
FROM        #ColumnListWithActions
WHERE       [Action] = 'D'
OPEN ColumnListStringCreator_D;
FETCH NEXT FROM ColumnListStringCreator_D
INTO @ColumnName
  WHILE @@FETCH_STATUS = 0

   BEGIN
        SELECT @ListOfColumns_Dimension = ISNULL(@ListOfColumns_Dimension, '') + ' [' + @ColumnName + '] ,';
        FETCH NEXT FROM ColumnListStringCreator_D INTO @ColumnName
   END

CLOSE ColumnListStringCreator_D;
DEALLOCATE ColumnListStringCreator_D;

--############################
--###| Cursor for List of Variable Columns
--############################

DECLARE ColumnListStringCreator_V CURSOR FOR
SELECT      [ColumnName]
FROM        #ColumnListWithActions
WHERE       [Action] = 'V'
OPEN ColumnListStringCreator_V;
FETCH NEXT FROM ColumnListStringCreator_V
INTO @ColumnName
  WHILE @@FETCH_STATUS = 0

   BEGIN
        SELECT @ListOfColumns_Variable = ISNULL(@ListOfColumns_Variable, '') + ' [' + @ColumnName + '] ,';
        FETCH NEXT FROM ColumnListStringCreator_V INTO @ColumnName
   END

CLOSE ColumnListStringCreator_V;
DEALLOCATE ColumnListStringCreator_V;

SELECT @ListOfColumns_Variable      = LEFT(@ListOfColumns_Variable, LEN(@ListOfColumns_Variable) - 1);
SELECT @ListOfColumns_Dimension = LEFT(@ListOfColumns_Dimension, LEN(@ListOfColumns_Dimension) - 1);
SELECT @ListOfColumns_Stable            = LEFT(@ListOfColumns_Stable, LEN(@ListOfColumns_Stable) - 1);

--#######################################################################################################################
--###| Step 3 - Preparing table with all possible connections between Dimension columns excluding NULLs
--#######################################################################################################################
DECLARE @DIM_TAB TABLE ([DIM_ID] smallint, [ColumnName] nvarchar(128))
INSERT INTO @DIM_TAB 
SELECT [DIM_ID] = ROW_NUMBER() OVER(ORDER BY [ColumnName]), [ColumnName] FROM #ColumnListWithActions WHERE [Action] = 'D';

DECLARE @DIM_ID smallint;
SELECT      @DIM_ID = 1;


DECLARE @SQL_Dimentions nvarchar(max);

IF OBJECT_ID('tempdb.dm.##ALL_Dimentions', 'U') IS NOT NULL DROP TABLE ##ALL_Dimentions; 

SELECT @SQL_Dimentions      = 'SELECT [xxx_ID_xxx] = ROW_NUMBER() OVER (ORDER BY ' + @ListOfColumns_Dimension + '), ' + @ListOfColumns_Dimension
                                            + ' INTO ##ALL_Dimentions '
                                            + ' FROM (SELECT DISTINCT' + @ListOfColumns_Dimension + ' FROM  ' + @TableName
                                            + ' WHERE ' + (SELECT [ColumnName] FROM @DIM_TAB WHERE [DIM_ID] = @DIM_ID) + ' IS NOT NULL ';
                                            SELECT @DIM_ID = @DIM_ID + 1;
            WHILE @DIM_ID <= (SELECT MAX([DIM_ID]) FROM @DIM_TAB)
            BEGIN
            SELECT @SQL_Dimentions = @SQL_Dimentions + 'AND ' + (SELECT [ColumnName] FROM @DIM_TAB WHERE [DIM_ID] = @DIM_ID) +  ' IS NOT NULL ';
            SELECT @DIM_ID = @DIM_ID + 1;
            END

SELECT @SQL_Dimentions   = @SQL_Dimentions + ' )x';

EXECUTE SP_EXECUTESQL  @SQL_Dimentions;

--#######################################################################################################################
--###| Step 4 - Preparing table with all possible connections between Stable columns excluding NULLs
--#######################################################################################################################
DECLARE @StabPos_TAB TABLE ([StabPos_ID] smallint, [ColumnName] nvarchar(128))
INSERT INTO @StabPos_TAB 
SELECT [StabPos_ID] = ROW_NUMBER() OVER(ORDER BY [ColumnName]), [ColumnName] FROM #ColumnListWithActions WHERE [Action] = 'S';

DECLARE @StabPos_ID smallint;
SELECT      @StabPos_ID = 1;


DECLARE @SQL_MainStableColumnTable nvarchar(max);

IF OBJECT_ID('tempdb.dm.##ALL_StableColumns', 'U') IS NOT NULL DROP TABLE ##ALL_StableColumns; 

SELECT @SQL_MainStableColumnTable       = 'SELECT xxx_ID_xxx = ROW_NUMBER() OVER (ORDER BY ' + @ListOfColumns_Stable + '), ' + @ListOfColumns_Stable
                                            + ' INTO ##ALL_StableColumns '
                                            + ' FROM (SELECT DISTINCT' + @ListOfColumns_Stable + ' FROM  ' + @TableName
                                            + ' WHERE ' + (SELECT [ColumnName] FROM @StabPos_TAB WHERE [StabPos_ID] = @StabPos_ID) + ' IS NOT NULL ';
                                            SELECT @StabPos_ID = @StabPos_ID + 1;
            WHILE @StabPos_ID <= (SELECT MAX([StabPos_ID]) FROM @StabPos_TAB)
            BEGIN
            SELECT @SQL_MainStableColumnTable = @SQL_MainStableColumnTable + 'AND ' + (SELECT [ColumnName] FROM @StabPos_TAB WHERE [StabPos_ID] = @StabPos_ID) +  ' IS NOT NULL ';
            SELECT @StabPos_ID = @StabPos_ID + 1;
            END

SELECT @SQL_MainStableColumnTable    = @SQL_MainStableColumnTable + ' )x';

EXECUTE SP_EXECUTESQL  @SQL_MainStableColumnTable;

--#######################################################################################################################
--###| Step 5 - Preparing table with all options ID
--#######################################################################################################################

DECLARE @FULL_SQL_1 NVARCHAR(MAX)
SELECT @FULL_SQL_1 = ''

DECLARE @i smallint

IF OBJECT_ID('tempdb.dm.##FinalTab', 'U') IS NOT NULL DROP TABLE ##FinalTab; 

SELECT @FULL_SQL_1 = 'SELECT t.*, dim.[xxx_ID_xxx] '
                                    + ' INTO ##FinalTab '
                                    +   'FROM ' + @TableName + ' t '
                                    +   'JOIN ##ALL_Dimentions dim '
                                    +   'ON t.' + (SELECT [ColumnName] FROM @DIM_TAB WHERE [DIM_ID] = 1) + ' = dim.' + (SELECT [ColumnName] FROM @DIM_TAB WHERE [DIM_ID] = 1);
                                SELECT @i = 2                               
                                WHILE @i <= (SELECT MAX([DIM_ID]) FROM @DIM_TAB)
                                    BEGIN
                                    SELECT @FULL_SQL_1 = @FULL_SQL_1 + ' AND t.' + (SELECT [ColumnName] FROM @DIM_TAB WHERE [DIM_ID] = @i) + ' = dim.' + (SELECT [ColumnName] FROM @DIM_TAB WHERE [DIM_ID] = @i)
                                    SELECT @i = @i +1
                                END
EXECUTE SP_EXECUTESQL @FULL_SQL_1

--#######################################################################################################################
--###| Step 6 - Selecting final data
--#######################################################################################################################
DECLARE @STAB_TAB TABLE ([STAB_ID] smallint, [ColumnName] nvarchar(128))
INSERT INTO @STAB_TAB 
SELECT [STAB_ID] = ROW_NUMBER() OVER(ORDER BY [ColumnName]), [ColumnName]
FROM #ColumnListWithActions WHERE [Action] = 'S';

DECLARE @VAR_TAB TABLE ([VAR_ID] smallint, [ColumnName] nvarchar(128))
INSERT INTO @VAR_TAB 
SELECT [VAR_ID] = ROW_NUMBER() OVER(ORDER BY [ColumnName]), [ColumnName]
FROM #ColumnListWithActions WHERE [Action] = 'V';

DECLARE @y smallint;
DECLARE @x smallint;
DECLARE @z smallint;


DECLARE @FinalCode nvarchar(max)

SELECT @FinalCode = ' SELECT ID1.*'
                                        SELECT @y = 1
                                        WHILE @y <= (SELECT MAX([xxx_ID_xxx]) FROM ##FinalTab)
                                            BEGIN
                                                SELECT @z = 1
                                                WHILE @z <= (SELECT MAX([VAR_ID]) FROM @VAR_TAB)
                                                    BEGIN
                                                        SELECT @FinalCode = @FinalCode +    ', [ID' + CAST((@y) as varchar(10)) + '.' + (SELECT [ColumnName] FROM @VAR_TAB WHERE [VAR_ID] = @z) + '] =  ID' + CAST((@y + 1) as varchar(10)) + '.' + (SELECT [ColumnName] FROM @VAR_TAB WHERE [VAR_ID] = @z)
                                                        SELECT @z = @z + 1
                                                    END
                                                    SELECT @y = @y + 1
                                                END
        SELECT @FinalCode = @FinalCode + 
                                        ' FROM ( SELECT * FROM ##ALL_StableColumns)ID1';
                                        SELECT @y = 1
                                        WHILE @y <= (SELECT MAX([xxx_ID_xxx]) FROM ##FinalTab)
                                        BEGIN
                                            SELECT @x = 1
                                            SELECT @FinalCode = @FinalCode 
                                                                                + ' LEFT JOIN (SELECT ' +  @ListOfColumns_Stable + ' , ' + @ListOfColumns_Variable 
                                                                                + ' FROM ##FinalTab WHERE [xxx_ID_xxx] = ' 
                                                                                + CAST(@y as varchar(10)) + ' )ID' + CAST((@y + 1) as varchar(10))  
                                                                                + ' ON 1 = 1' 
                                                                                WHILE @x <= (SELECT MAX([STAB_ID]) FROM @STAB_TAB)
                                                                                BEGIN
                                                                                    SELECT @FinalCode = @FinalCode + ' AND ID1.' + (SELECT [ColumnName] FROM @STAB_TAB WHERE [STAB_ID] = @x) + ' = ID' + CAST((@y+1) as varchar(10)) + '.' + (SELECT [ColumnName] FROM @STAB_TAB WHERE [STAB_ID] = @x)
                                                                                    SELECT @x = @x +1
                                                                                END
                                            SELECT @y = @y + 1
                                        END

SELECT * FROM ##ALL_Dimentions;
EXECUTE SP_EXECUTESQL @FinalCode;