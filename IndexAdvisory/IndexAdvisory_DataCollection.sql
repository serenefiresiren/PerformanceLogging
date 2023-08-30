IF (Object_ID('tempdb..#index_space')) IS NOT NULL
	DROP TABLE #index_space

SELECT object_id
	,index_id
	,CAST(SUM(used_page_count) * 8 / 1024.0 AS DECIMAL(10, 2)) AS IndexSizeMB
	,row_count [Rows]
INTO #index_space
FROM sys.dm_db_partition_stats
GROUP BY object_id
	,index_id
	,row_count

IF (Object_ID('tempdb..#index_usage')) IS NOT NULL
	DROP TABLE #index_usage

SELECT object_id
	,index_id
	,SUM(user_seeks) AS user_seeks
	,SUM(user_scans) AS user_scans
	,SUM(user_lookups) AS user_lookups
	,SUM(user_updates) AS user_updates
	,SUM(ISNULL(user_scans, 0) + ISNULL(user_lookups, 0)) AS user_scl
	,SUM(ISNULL(user_seeks, 0) + ISNULL(user_scans, 0) + ISNULL(user_lookups, 0)) AS [user_reads]
INTO #index_usage
FROM sys.dm_db_index_usage_stats
WHERE database_id = DB_ID()
GROUP BY object_id
	,index_id

IF (Object_ID('tempdb..#index_count')) IS NOT NULL
	DROP TABLE #index_count

SELECT i.object_ID
	,COUNT(DISTINCT i.index_ID) [Index_Count]
	,AVG(ss.user_read_nc) [user_read_nc]
	,AVG(ss.user_seeks_nc_max) [user_seeks_nc_max]
INTO #Index_count
FROM sys.indexes i
LEFT OUTER JOIN (
	SELECT iu.object_id
		,SUM(iu.user_seeks + iu.user_scans) [user_read_nc]
		,MAX(iu.user_Seeks) [user_seeks_nc_max]
	FROM #index_usage iu
	INNER JOIN sys.indexes id ON id.object_id = iu.object_id
		AND id.index_id = iu.index_id
	WHERE id.type <> 1
	GROUP BY iu.object_id
	) ss ON i.object_id = ss.object_ID
GROUP BY i.object_ID

IF (Object_ID('tempdb..#gen_count')) IS NOT NULL
	DROP TABLE #gen_count

SELECT o.object_id
	,COUNT(DISTINCT pfk.object_id) [fk_count]
	,COUNT(DISTINCT c.column_id) [Column_Count]
INTO #gen_count
FROM sys.objects o
LEFT OUTER JOIN sys.foreign_keys pfk ON o.object_id = pfk.parent_object_id
LEFT OUTER JOIN sys.columns c ON o.object_id = c.object_id
WHERE SCHEMA_NAME(o.schema_id) NOT IN ('sys', 'conversion')
GROUP BY o.object_id

SELECT @@ServerName [Instance]
	,DB_NAME() AS DatabaseName
	,s.name AS SchemaName
	,o.name AS TableName
	,i.name AS IndexName
	,i.IS_PRimary_Key [PK]
	,CASE i.Type
		WHEN 1
			THEN 1
		ELSE 0
		END [CI]
	,i.is_unique [UC]
	,CASE 
		WHEN gc.Column_Count = 1
			AND ic.Index_count = 1
			THEN '-'
		WHEN i.Type = 1
			AND ic.Index_Count = 1
			AND (iu.user_updates + iu.user_reads) = 0
			THEN '-'
		WHEN i.Type = 1
			AND sp.IndexSizeMB < 1
			AND ic.Index_Count = 1
			THEN '-'
		WHEN i.Type = 1
			AND (ic.user_read_nc + iu.user_updates + iu.user_reads) > 0
			THEN CASE 
					WHEN ic.Index_Count = 1
						THEN CASE 
								WHEN gc.fk_count > 0
									AND iu.user_scl = 0
									THEN 'Missing FK Column Index (Opt.)'
								WHEN iu.user_lookups > ic.user_read_nc
									THEN 'Missing FK Column Index'
								WHEN iu.user_seeks < iu.user_scl
									THEN 'Missing NCI'
								WHEN (iu.user_seeks + iu.user_scans) > (iu.user_updates * .5)
									AND iu.user_lookups = 0
									AND iu.user_seeks < (iu.user_scans * .1)
									THEN 'Missing NCI'
								WHEN iu.user_updates > 0
									AND (iu.user_seeks + iu.user_lookups) = 0
									AND iu.user_scans > 0
									THEN 'Missing NCI'
								WHEN (iu.user_scl) = 0
									AND iu.user_seeks > 0
									THEN 'Great'
								WHEN (iu.user_seeks * .1) > iu.user_scl
									THEN 'Great'
								WHEN (iu.user_seeks * .5) > iu.user_scl
									THEN 'Adequate'
								WHEN iu.user_seeks < iu.user_lookups
									THEN 'Review Table'
								ELSE 'Adequate'
								END
					WHEN ic.Index_Count > 1
						THEN CASE 
								WHEN gc.fk_count > 0
									AND ic.user_read_nc < iu.user_lookups
									THEN 'Missing FK Column Index'
								WHEN iu.user_lookups <= ic.user_seeks_nc_max
									AND iu.user_seeks < ic.user_seeks_nc_max
									THEN 'Better CI Available'
								WHEN iu.user_seeks < iu.user_scl
									AND iu.user_seeks > ic.user_seeks_nc_max
									THEN 'Review NCIs'
								WHEN iu.user_lookups > (iu.user_seeks * .1)
									AND iu.user_lookups < ic.user_seeks_nc_max
									THEN 'Review NCIs'
								WHEN iu.user_reads = 0
									AND iu.user_updates > 0
									THEN 'Review Table'
								WHEN iu.user_lookups > ic.user_seeks_nc_max
									THEN 'Review Table'
								WHEN iu.user_updates < ic.user_read_nc
									THEN 'Great'
								WHEN iu.user_seeks > ic.user_read_nc
									THEN 'Great'
								ELSE 'Review Table'
								END
					ELSE 'Review Table'
					END
		WHEN i.Type = 2
			THEN CASE 
					WHEN iu.user_updates > 0
						AND iu.user_reads < (iu.user_updates * .05)
						THEN 'Bloat'
					WHEN iu.user_Updates > 0
						AND iu.user_reads < (iu.user_updates * .1)
						THEN 'Less Efficient'
					WHEN iu.User_seeks < (iu.user_scans * 2)
						THEN 'Less Efficient'
					WHEN iu.user_Scans = 0
						AND iu.user_updates < iu.user_seeks
						THEN 'Great'
					WHEN iu.user_seeks > (iu.user_scans * 100)
						THEN 'Great'
					ELSE 'Adequate'
					END
		ELSE 'Review Table'
		END [Status]
	,CASE 
		WHEN iu.user_updates + iu.user_reads = 0
			THEN ''
		WHEN iu.user_updates > 0
			THEN CASE 
					WHEN (iu.user_reads / (iu.user_updates * 1.0)) >= 0.55
						THEN CAST(CEILING(iu.user_reads / (iu.user_updates * 1.0)) AS VARCHAR(50)) + ' : 1'
					WHEN (iu.user_reads / (iu.user_updates * 1.0)) > 0.055
						THEN CAST(CEILING((iu.user_reads / (iu.user_updates * 1.0)) * 10) AS VARCHAR(50)) + ' : 10'
					WHEN (iu.user_reads / (iu.user_updates * 1.0)) > 0.0055
						THEN CAST(CEILING((iu.user_reads / (iu.user_updates * 1.0)) * 100) AS VARCHAR(50)) + ' : 100'
					WHEN (iu.user_reads / (iu.user_updates * 1.0)) > 0.00055
						THEN CAST(CEILING((iu.user_reads / (iu.user_updates * 1.0)) * 1000) AS VARCHAR(50)) + ' : 1000'
					ELSE '0 : 1'
					END
		ELSE '1 : 0'
		END ReadWriteRatio
	,iu.user_updates
	,iu.user_seeks
	,iu.user_scans
	,iu.user_lookups
	,sp.IndexSizeMB
	,(sp.IndexSizeMB * iu.user_updates) / 1024.0 AS IndexSpaceUpdatedGB
	,GetDate() [CollectionDate]
FROM #index_usage iu
INNER JOIN sys.objects o ON o.object_id = iu.object_id
INNER JOIN sys.indexes i ON i.index_id = iu.index_id
	AND i.object_id = iu.object_id
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT OUTER JOIN #index_space sp ON sp.object_id = i.object_id
	AND sp.index_id = i.index_id
LEFT OUTER JOIN #index_count ic ON o.object_id = ic.object_id
LEFT OUTER JOIN #gen_count gc ON o.object_id = gc.object_id
WHERE s.name NOT IN ('sys', 'conversion')
	AND EXISTS (
		SELECT 1
		FROM sys.indexes c
		WHERE c.object_id = o.object_id
			AND c.type = 1
		)
ORDER BY SchemaName
	,TableName
	,CI DESC
	,IndexName

