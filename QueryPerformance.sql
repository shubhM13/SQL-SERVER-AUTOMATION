-- turn on statistics IO
SET STATISTICS IO ON 
GO 
SELECT * FROM [dm].[fact_assessment_analysis]
GO

SET STATISTICS IO OFF 
GO

-- turn on statistics IO
SET STATISTICS TIME ON 
GO
SELECT * FROM [dm].[fact_assessment_analysis]
GO
SET STATISTICS TIME OFF 
GO