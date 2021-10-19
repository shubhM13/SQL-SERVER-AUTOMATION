select name as table_name
from sys.tables
where schema_name(schema_id) = 'stg' -- put your schema name here
order by name;