DROP TABLE

IF EXISTS #index_space
	SELECT object_id
		,index_id
		,CAST(SUM(used_page_count) * 8 / 1024.0 AS DECIMAL(10, 2)) AS IndexSizeMB
		,row_count [Rows]
	INTO #index_space
	FROM sys.dm_db_partition_stats
	GROUP BY object_id
		,index_id
		,row_count

DROP TABLE

IF EXISTS #index_usage
	SELECT object_id
		,index_id
		,OBJECT_SCHEMA_NAME(object_id) [Schema]
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

DROP TABLE

IF EXISTS #index_count
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

DROP TABLE

IF EXISTS #gen_count
	SELECT o.object_id
		,COUNT(DISTINCT pfk.object_id) [fk_count]
		,COUNT(DISTINCT c.column_id) [Column_Count]
	INTO #gen_count
	FROM sys.objects o
	LEFT OUTER JOIN sys.foreign_keys pfk ON o.object_id = pfk.parent_object_id
	LEFT OUTER JOIN sys.columns c ON o.object_id = c.object_id
	WHERE SCHEMA_NAME(o.schema_id) NOT IN (
			'sys'
			,'conversion'
			)
	GROUP BY o.object_id

DROP TABLE

IF EXISTS #index_def
	SELECT id.is_primary_key [PK]
		,id.index_id
		,id.object_id
		,sd.schema_id
		,CAST(CASE 
				WHEN id.Type = 1
					THEN 1
				ELSE 0
				END AS BIT) [Clustered]
		,STUFF((
				SELECT ', ' + c_key.name + ' ' + CASE 
						WHEN ic_key.is_descending_key = 1
							THEN 'DESC'
						ELSE 'ASC'
						END -- Include column order (ASC / DESC)
				FROM sys.tables AS T
				INNER JOIN sys.indexes i_key ON T.object_id = i_key.object_id
				INNER JOIN sys.index_columns ic_key ON i_key.object_id = ic_key.object_id
					AND i_key.index_id = ic_key.index_id
				INNER JOIN sys.columns c_key ON T.object_id = c_key.object_id
					AND ic_key.column_id = c_key.column_id
				WHERE id.object_id = i_key.object_id
					AND id.index_id = i_key.index_id
					AND ic_key.is_included_column = 0
				ORDER BY ic_key.key_ordinal
				FOR XML PATH('')
				), 1, 2, '') AS key_column_list
		,STUFF((
				SELECT ', ' + c_inc.name
				FROM sys.tables AS T
				INNER JOIN sys.indexes id_inc ON T.object_id = id_inc.object_id
				INNER JOIN sys.index_columns ic_inc ON id_inc.object_id = ic_inc.object_id
					AND id_inc.index_id = ic_inc.index_id
				INNER JOIN sys.columns c_inc ON T.object_id = c_inc.object_id
					AND ic_inc.column_id = c_inc.column_id
				WHERE id.object_id = id_inc.object_id
					AND id.index_id = id_inc.index_id
					AND ic_inc.is_included_column = 1
				ORDER BY ic_inc.key_ordinal
				FOR XML PATH('')
				), 1, 2, '') AS include_column_list
		,id.filter_definition
		,id.is_disabled -- Check if index is disabled before determining which dupe to drop (if applicable)
	INTO #index_def
	FROM sys.indexes id
	INNER JOIN sys.tables td ON td.object_id = id.object_id
	INNER JOIN sys.schemas sd ON sd.schema_id = td.schema_id
	WHERE td.is_ms_shipped = 0
		AND sd.name NOT IN (
			'sys'
			,'History'
			)
		AND id.type_desc IN (
			'NONCLUSTERED'
			,'CLUSTERED'
			)
	ORDER BY 1
		,2
		,3

SELECT @@ServerName [Instance]
	,DB_NAME() AS DatabaseName
	,s.name AS SchemaName
	,o.name AS TableName
	,i.name AS IndexName
	,i.IS_PRimary_Key [PrimaryKey]
	,CAST(CASE i.Type
			WHEN 1
				THEN 1
			ELSE 0
			END AS BIT) [Clustered]
	,i.is_unique [Unique]
	,ixd.key_column_list
	,ixd.include_column_list
	,ixd.filter_definition
	,CASE 
		WHEN iu.index_id IS NULL
			THEN NULL
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
		WHEN iu.index_id IS NULL
			THEN NULL
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
	,CAST(((sp.IndexSizeMB * iu.user_updates) / 1024.0) AS DECIMAL(20, 2)) AS IndexSpaceUpdatedGB
	,GetDate() [CollectionDate]
FROM #index_def ixd
INNER JOIN sys.objects o ON o.object_id = ixd.object_id
INNER JOIN sys.indexes i ON i.index_id = ixd.index_id
	AND i.object_id = ixd.object_id
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN #index_usage iu ON o.object_id = iu.object_id
	AND iu.index_id = i.index_id
LEFT OUTER JOIN #index_space sp ON sp.object_id = iu.object_id
	AND sp.index_id = ixd.index_id
LEFT OUTER JOIN #index_count ic ON o.object_id = ic.object_id
LEFT OUTER JOIN #gen_count gc ON o.object_id = gc.object_id
WHERE EXISTS (
		SELECT 1
		FROM sys.indexes c
		WHERE c.object_id = o.object_id
			AND c.type = 1
		)

