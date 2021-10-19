----------------------------------------------------------------------------------------
declare @results table
(
ID varchar(36),
TableName varchar(250),
ColumnName varchar(250),
DataType varchar(250),
MaxLength varchar(250),
Longest varchar(250),
SQLText varchar(250)
)

INSERT INTO @results(ID,TableName,ColumnName,DataType,MaxLength,Longest,SQLText)
SELECT 
    NEWID(),
    Object_Name(c.object_id),
    c.name,
    t.Name,
    case 
        when c.max_length = -1 then 'Max' 
        else CAST(c.max_length as varchar)
    end,
    'NA',
    'SELECT Max(Len(' + c.name + ')) FROM ' + OBJECT_SCHEMA_NAME(c.object_id) + '.' + Object_Name(c.object_id)
FROM    
    sys.columns c
INNER JOIN 
    sys.types t ON c.system_type_id = t.system_type_id
WHERE
    c.object_id = OBJECT_ID('[dm].[fact_assessment_analysis]')    


DECLARE @id varchar(36)
DECLARE @sql varchar(200)
declare @receiver table(theCount int)

DECLARE length_cursor CURSOR
    FOR SELECT ID, SQLText FROM @results WHERE MaxLength != 'NA'
OPEN length_cursor
FETCH NEXT FROM length_cursor
INTO @id, @sql
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO @receiver (theCount)
    exec(@sql)

    UPDATE @results
    SET Longest = (SELECT theCount FROM @receiver)
    WHERE ID = @id

    DELETE FROM @receiver

    FETCH NEXT FROM length_cursor
    INTO @id, @sql
END
CLOSE length_cursor
DEALLOCATE length_cursor


SELECT 
    TableName, 
    ColumnName, 
    DataType, 
    MaxLength, 
    Longest 
FROM 
    @results


-------------------------------------------------------------------------------

DECLARE @YourTableName sysname;
DECLARE @sql nvarchar(MAX) = ''
SET @YourTableName = '[dm].[fact_assessment_analysis]'
CREATE TABLE #resultsTable (columnName varchar(100), columnLargestValueInData int, columnMaxLength int)

DECLARE @whileIter int = 1
DECLARE @whileTotal int  

SELECT @whileTotal = COUNT(*) FROM sys.columns c
                            INNER JOIN 
                                sys.types t ON c.user_type_id = t.user_type_id
                            WHERE
                                c.object_id = OBJECT_ID(@YourTableName)
print 'whileTotal: ' + CONVERT(VARCHAR,@whileTotal) -- used for testing
WHILE @whileIter <= @whileTotal
BEGIN

SELECT  @sql =  N'INSERT INTO #resultsTable (columnName,  columnLargestValueInData, columnMaxLength) SELECT ''' + sc.name + ''' AS columnName, max(len([' + sc.name + '])), ' + CONVERT(varchar,sc.max_length) + ' FROM [' + t.name + ']'  
FROM  sys.tables AS t
INNER JOIN sys.columns AS sc ON t.object_id = sc.object_id
INNER JOIN sys.types AS st ON sc.system_type_id = st.system_type_id
WHERE column_id = @whileIter
AND t.name = @YourTableName
AND st.name IN ('char', 'varchar', 'nchar', 'nvarchar')

PRINT @sql;

exec sp_executesql @sql;
SET @whileIter += 1
END
SELECT * FROM #resultsTable

TRUNCATE TABLE #resultsTable
DROP TABLE #resultsTable

----------------------------------------------------------------------------------------------------------------------------------

set nocount on;
declare @TableName varchar(150) = 'TableName';
declare @Schema varchar(20) = 'TableSchema';
declare @Columns varchar(max);
declare @Unpivot varchar(max);
declare @SQL varchar(max);

select  @Columns = STUFF((
select  ',max(len(replace([' + COLUMN_NAME + '],'' '',''_'')))[' + COLUMN_NAME + '/' 
        + isnull(ltrim(CHARACTER_MAXIMUM_LENGTH),DATA_TYPE) + ']' + CHAR(10) + CHAR(9)
from    INFORMATION_SCHEMA.COLUMNS
where   TABLE_SCHEMA = @Schema
        and TABLE_NAME = @TableName
order   by ORDINAL_POSITION
for XML PATH('')),1,1,'')

select  @Unpivot = STUFF((
select  ',[' + COLUMN_NAME + '/' + isnull(ltrim(CHARACTER_MAXIMUM_LENGTH),DATA_TYPE) + ']'
from    INFORMATION_SCHEMA.COLUMNS
where   TABLE_SCHEMA = @Schema
        and TABLE_NAME = @TableName
order   by ORDINAL_POSITION
for XML PATH('')),1,1,'')

select  @SQL = 
'select DataSize, ColumnName [ColumnName/Size]
from    (
        select ' + @Columns + 'from [' + @Schema + '].[' + @TableName + ']
        )x 
unpivot (DataSize for ColumnName in (' + @Unpivot + '))p'

print (@SQL)
exec (@SQL)