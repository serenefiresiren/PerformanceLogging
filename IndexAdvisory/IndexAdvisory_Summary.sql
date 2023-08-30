USE PerformanceLogging
GO

SELECT SchemaName
	,TableName
	,IndexName
	,PK
	,CI
	,STRING_AGG(STATUS, ', ') WITHIN
GROUP (
		ORDER BY STATUS
		) [Status]
	,SUM(user_updates)  TotalUpdates
	,SUM(user_seeks)	TotalSeeks
	,SUM(user_scans)	TotalScans
	,SUM(user_lookups)	TotalLookups
FROM (
	SELECT SchemaName
		,TableName
		,IndexName
		,PK
		,CI
		,STATUS
		,SUM(user_updates) user_updates
		,SUM(user_seeks) user_seeks
		,SUM(user_scans) user_scans
		,SUM(user_lookups) user_lookups
	FROM Perf.IndexAdvisory 
	GROUP BY SchemaName
		,TableName
		,IndexName
		,PK
		,CI
		,STATUS
	) t
GROUP BY SchemaName
	,TableName
	,IndexName
	,PK
	,CI 
ORDER BY SchemaName
	,TableName
	,CASE 
		WHEN PK = 1
			THEN '!'
		WHEN CI = 1
			THEN '@'
		ELSE IndexName
		END

