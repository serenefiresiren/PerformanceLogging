USE PerformanceLogging
GO

CREATE OR ALTER PROCEDURE Perf.sprptIndexUsageSearch (
	@AllResults BIT = 0
	,@Instance NVARCHAR(255) = NULL
	,@DatabaseName NVARCHAR(255) = NULL
	,@TableNAme NVARCHAR(255) = NULL
	,@IndexName NVARCHAR(255) = NULL
	,@CollectionDateBegin DATETIME = NULL
	,@CollectionDateEnd DATETIME = NULL
	)
AS
IF @AllResults = 1
BEGIN
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
END
ELSE
BEGIN
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
	WHERE (@Instance IS NULL OR Instance = @Instance)  
	AND (@DatabaseName IS NULL OR DatabaseName = @DatabaseName)
	AND (@TableNAme IS NULL OR TableNAme = @TableNAme)
	AND (@IndexName IS NULL OR IndexName = @IndexName)
	AND CollectionDate BETWEEN @CollectionDateBegin AND @CollectionDateEnd 
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
END

