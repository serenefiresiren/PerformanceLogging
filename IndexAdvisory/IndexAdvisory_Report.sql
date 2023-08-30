USE PerformanceLogging
GO

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
ORDER BY SchemaName
	,TableName
	,CASE 
		WHEN PK = 1
			THEN '!'
		WHEN CI = 1
			THEN '@'
		ELSE IndexName
		END
	,STATUS
	,DatabaseName

