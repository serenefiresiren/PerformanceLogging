USE PerformanceLogging
GO

DECLARE @Schema NVARCHAR(255) = ''
	,@TableName NVARCHAR(255) = ''

SELECT Instance
	,DatabaseName
	,SchemaName
	,TableName
	,IndexName
	,PrimaryKey
	,Cluster
	,UniqueKey
	,KeyColumns
	,Includes
	,Filter
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
	,Updates
	,Seeks
	,Scans
	,Lookups
	,IndexSizeMB
	,IndexSpaceUpdatedGB
	,CollectionDate
FROM Perf.IndexSummary
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
		WHEN PrimaryKey = 1
			THEN '!'
		WHEN Cluster = 1
			THEN '@'
		ELSE IndexName
		END
	,DatabaseName

