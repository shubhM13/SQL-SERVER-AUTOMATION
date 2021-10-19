
DECLARE @sql nvarchar(max) = N'';
SELECT @sql += '
DROP TABLE ' 
    + QUOTENAME(s.name)
    + '.' + QUOTENAME(t.name) + ';'
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
    ON t.[schema_id] = s.[schema_id] 
    WHERE s.name LIKE 'STG%';

PRINT @sql;
EXEC sp_executesql @sql;