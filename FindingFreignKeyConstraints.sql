   SELECT name AS 'Foreign Key Constraint Name', 
	       OBJECT_SCHEMA_NAME(parent_object_id) + '.' + OBJECT_NAME(parent_object_id) AS 'Child Table'
   FROM sys.foreign_keys 
   WHERE OBJECT_SCHEMA_NAME(referenced_object_id) = 'dm' AND 
              OBJECT_NAME(referenced_object_id) = 'fact_nsc_plantlet_assessment'

alter table [childTable]]
drop constraint [FK_Name];

-- Check which foreigh key column doesn't match pk column
select FK_column from FK_table
WHERE FK_column NOT IN
(SELECT PK_column from PK_table)


--Drop and Add COnstraint 
ALTER TABLE [dm].[fact_nsc_plantlet_assessment]
DROP CONSTRAINT FK__fact_nsc___entit__4ACEC037


ALTER TABLE [dm].[fact_nsc_plantlet_assessment]
ADD FOREIGN KEY (entityId)
REFERENCES [dm].[dim_entity_master](entityId); 