--Synchronize the target table with refreshed data from source table
MERGE Products AS TARGET
USING UpdatedProducts AS SOURCE 
ON (TARGET.ProductID = SOURCE.ProductID) 
--When records are matched, update the records if there is any change
WHEN MATCHED AND TARGET.ProductName <> SOURCE.ProductName OR TARGET.Rate <> SOURCE.Rate 
THEN UPDATE SET TARGET.ProductName = SOURCE.ProductName, TARGET.Rate = SOURCE.Rate 
--When no records are matched, insert the incoming records from source table to target table
WHEN NOT MATCHED BY TARGET 
THEN INSERT (ProductID, ProductName, Rate) VALUES (SOURCE.ProductID, SOURCE.ProductName, SOURCE.Rate)
--When there is a row that exists in target and same record does not exist in source then delete this record target
WHEN NOT MATCHED BY SOURCE 
THEN DELETE 
--$action specifies a column of type nvarchar(10) in the OUTPUT clause that returns 
--one of three values for each row: 'INSERT', 'UPDATE', or 'DELETE' according to the action that was performed on that row
OUTPUT $action, 
DELETED.ProductID AS TargetProductID, 
DELETED.ProductName AS TargetProductName, 
DELETED.Rate AS TargetRate, 
INSERTED.ProductID AS SourceProductID, 
INSERTED.ProductName AS SourceProductName, 
INSERTED.Rate AS SourceRate; 
SELECT @@ROWCOUNT;
GO


-- INSERT W/O SPECIFYING COL. LIST
INSERT INTO dbo.account
SELECT
  'The Pokemon Company',
  '4/23/1998',
  'Roppongi Hills Mori Tower 8F, Tokyo, Japan',
  'LIVE',
  GETUTCDATE(),
  'Very valuable.  They make all the Pokemon!',
   1;