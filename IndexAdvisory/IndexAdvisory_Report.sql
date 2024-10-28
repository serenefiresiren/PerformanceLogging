USE PerformanceLogging
GO

DECLARE @Schema NVARCHAR(255) = ''
	,@TableName NVARCHAR(255) = ''

SELECT Instance
	,DatabaseName
	,SchemaName
	,TableName
	,IndexName
	,PK
	,CI
	,ROW_NUMBER() OVER (
		PARTITION BY SchemaName
		,TableName
		,IndexName ORDER BY SchemaName
			,TableName
			,IndexName
			,STATUS
			,DatabaseName
		) [DBRowNum]
	,STATUS
	,ReadWriteRatio
	,user_updates
	,user_seeks
	,user_scans
	,user_lookups
	,IndexSizeMB
	,IndexSpaceUpdatedGB
	,CollectionDate
FROM Perf.IndexAdvisory
WHERE (
		SchemaName = @Schema
		OR @Schema = ''
		)
	AND (
		TableName = @TableName
		OR @TableName = ''
		)
ORDER BY SchemaName
	,TableName
	,STATUS
	,CASE 
		WHEN PK = 1
			THEN '!'
		WHEN CI = 1
			THEN '@'
		ELSE IndexName
		END
	,DatabaseName

