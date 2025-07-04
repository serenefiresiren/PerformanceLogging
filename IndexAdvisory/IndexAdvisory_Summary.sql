DECLARE @SchemaName NVARCHAR(255)  = ''
	,@TableName NVARCHAR(255)  = ''
	,@CollectionDate DATETIME = '7/4/25'

SELECT SchemaName
	,TableName
	,IndexName
	,PrimaryKey
	,Cluster
	,KeyColumns
	,Includes
	,Filter
	,[Databases]
	,AvgUpdates
	,AvgSeeks
	,AvgScans
	,AvgLookups
	,TotalUpdates
	,TotalSeeks
	,TotalScans
	,TotalLookups
FROM (
	SELECT DISTINCT SchemaName
		,TableName
		,IndexName
		,PrimaryKey
		,Cluster
		,UniqueKey
		,KeyColumns
		,Includes
		,Filter
		,count(DatabaseName) [Databases]
		,STRING_AGG(STATUS,',') [Status]
		,AVG(Updates) AvgUpdates
		,AVG(Seeks) AvgSeeks
		,AVG(Scans) AvgScans
		,AVG(Lookups) AvgLookups
		,SUM(Updates) TotalUpdates
		,SUM(Seeks) TotalSeeks
		,SUM(Scans) TotalScans
		,SUM(Lookups) TotalLookups
	FROM Perf.IndexSummary
	WHERE (
			@CollectionDate = ''
			OR CollectionDate = @CollectionDate
			)
		AND (
			@SchemaNAme = ''
			OR SchemaName = @SchemaName
			)
		AND (
			@TableNAme = ''
			OR TableNAme = @TableName
			)
	GROUP BY SchemaName
		,TableName
		,IndexName
		,PrimaryKey
		,Cluster
		,UniqueKey		
		,KeyColumns
		,Includes
		,Filter
	) t
ORDER BY SchemaName
	,TableName
	,CASE 
		WHEN PrimaryKey = 1
			THEN '!'
		WHEN Cluster = 1
			THEN '@'
		ELSE IndexName
		END
 

