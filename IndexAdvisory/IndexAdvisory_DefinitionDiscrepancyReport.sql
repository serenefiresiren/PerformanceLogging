DECLARE @SchemaName NVARCHAR(255)  = ''
	,@TableName NVARCHAR(255)  = ''
	,@CollectionDate DATETIME = ''
;WITH idx
AS
(
	SELECT	SchemaName
		,TableName
		,IndexName
		,PrimaryKey
		,Cluster 
		,UniqueKey
		,KeyColumns
		,Includes
		,Filter
		,Seeks
		,Scans
		,Lookups
		,[Databases]
	FROM (
	SELECT	SchemaName               
		,TableName                   
		,IndexName                   
		,PrimaryKey                  
		,Cluster                          
		,UniqueKey                          
		,KeyColumns                  
		,Includes                    
		,Filter                      
		,Count(1)                     [AltDef]
		,AVG(Seeks)              Seeks
		,AVG(Scans)              Scans
		,AVG(Lookups)            Lookups
		,COUNT(DISTINCT(DatabaseName)) [Databases]
	FROM perf.IndexSummary
	WHERE  Instance NOT IN ('DBGroupA')
		AND	(@CollectionDate = ''
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
	) uqd
--HAVING count(1) > 1--, PrimaryKey, CI, UQ, KeyColumns,Includes, Filter
)

SELECT DISTINCT	idx.SchemaName
	,idx.TableName
	,idx.IndexName
	,idx.PrimaryKey
	,idx.Cluster  
	,idx.UniqueKey
	,idx.KeyColumns
	,idx.Includes
	,idx.Filter
	,idx.[Databases]
	,idx.Seeks
	,idx.Scans
	,idx.Lookups 
FROM      idx                
LEFT JOIN Perf.IndexSummary s
		ON idx.SchemaName = s.SchemaName
			AND idx.TableName = s.TableName
			AND idx.IndexName = s.IndexName
			AND (
				idx.KeyColumns IS NULL
				OR idx.KeyColumns = s.KeyColumns)
			AND (
				idx.PrimaryKey IS NULL
				OR idx.PrimaryKey = s.PrimaryKey)
			AND (
				idx.Cluster IS NULL
				OR idx.Cluster = s.Cluster)
			AND (
				idx.UniqueKey IS NULL
				OR idx.UniqueKey = s.UniqueKey)
			AND (
				idx.Includes IS NULL
				OR idx.Includes = s.Includes)
			AND (
				idx.Filter IS NULL
				OR idx.Filter = s.Filter)
			AND s.Instance  IN ('DBGroupB')
--where	s.IndexNAme is null
GROUP BY idx.SchemaName
	,idx.TableName
	,idx.IndexName
	,idx.PrimaryKey
	,idx.Cluster
	,idx.UniqueKey
	,idx.KeyColumns
	,idx.Includes
	,idx.Filter
	,Idx.Databases
	,idx.Seeks
	,idx.Scans
	,idx.Lookups
ORDER BY idx.SchemaName
	,idx.TableName
	,idx.IndexName
	 
	  