SELECT @@ServerName [Instance]
	,DB_NAME() AS DatabaseName
, sd.name AS schema_name
	,td.name AS table_name
	,id.name AS index_name
	,id.is_primary_key [PK] 
	,CAST(CASE WHEN id.Type = 1 THEN 1 ELSE 0 END as bit)  [Clustered]
	,id.is_unique [Unique]
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
	,CAST(GetdatE() as date) [Collection]
FROM sys.indexes id
INNER JOIN sys.tables td ON td.object_id = id.object_id
INNER JOIN sys.schemas sd ON sd.schema_id = td.schema_id
WHERE td.is_ms_shipped = 0
	AND id.type_desc IN (
		'NONCLUSTERED'
		,'CLUSTERED'
		)
ORDER BY 1
	,2
	,3

