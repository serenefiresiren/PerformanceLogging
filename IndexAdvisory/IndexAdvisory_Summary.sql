USE PerformanceLogging

DECLARE @Schema NVARCHAR(255) = ''
	,@TableName NVARCHAR(255) = ''

SELECT SchemaName
	,TableName
	,IndexName
	,PK
	,CI
	,STRING_AGG(STATUS, ', ') WITHIN
GROUP (
		ORDER BY STATUS
		) [Status]
	,Count(DatabaseName)
	,AVG(user_updates) TotalUpdates
	,AVG(user_seeks) TotalSeeks
	,AVG(user_scans) TotalScans
	,AVG(user_lookups) TotalLookups
FROM (
	SELECT SchemaName
		,TableName
		,IndexName
		,PK
		,CI
		,DatabaseName
		,STATUS
		,AVG(user_updates) user_updates
		,AVG(user_seeks) user_seeks
		,AVG(user_scans) user_scans
		,AVG(user_lookups) user_lookups
	FROM Perf.IndexAdvisory
	GROUP BY SchemaName
		,TableName
		,DatabaseName
		,IndexName
		,PK
		,CI
		,STATUS
	) t
WHERE (
		SchemaName = @Schema
		OR @Schema = ''
		)
	AND (
		TableName = @TableName
		OR @TableName = ''
		)
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

