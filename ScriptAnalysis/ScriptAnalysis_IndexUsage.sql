USE [PerformanceLogging]

IF OBJECT_ID('tempdb..#XmlRecords') IS NOT NULL
	DROP TABLE #XmlRecords;

IF OBJECT_ID('tempdb..#tmpIndexes') IS NOT NULL
	DROP TABLE #tmpIndexes 

;WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
SELECT  RawScript 
	,TRY_CAST(ExamplePlanXML AS XML) [XMLValue]
	,ExamplePlanXML
INTO #xmlRecords
FROM Perf.RawScriptMetrics
WHERE  RawScript NOT LIKE 'INSERT INTO /[%' ESCAPE '/'
	AND RawScript NOT LIKE 'UPDATE /[%' ESCAPE '/' 
	AND RawScript NOT LIKE 'DELETE%FROM%' ESCAPE '/' 
	AND RawScript NOT LIKE '%Change_tracking%'
	AND RawScript NOT LIKE '%CHANGETABLE%'
	AND RawScript NOT LIKE '%column fulltextkey%'  

/* Get the indexes used in the script */	
;WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
SELECT DISTINCT rs.RawScript
	,AnyColRef.value (
	'@Schema'
	,'nvarchar(max)'
	) + '.' + AnyColRef.value(
	'@Table'
	,'nvarchar(max)'
	) + '.' + AnyColRef.value(
	'@Index'
	,'nvarchar(max)'
	) [IndexName]
	INTO #tmpIndexes
FROM #xmlRecords rs CROSS APPLY rs.[XMLValue].nodes ('//Object') A (AnyColRef)
WHERE AnyColRef.value(
	'@Schema'
	,'nvarchar(max)'
	) <> 'sys'


/* Aggregate the scripts to counts and index usage combinations */  
;WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
--SELECT * from 
--(
SELECT   RawScript
	,COUNT (  RawScript) [Executions]
	,STRING_AGG (
	IndexName
	,','
	) WITHIN GROUP (ORDER BY IndexName)
AS [UsedIndexes] 
FROM #tmpIndexes  

GROUP BY RawScript 
ORDER BY Executions DESC
--) a
--WHERE   a.UsedIndexes     LIKE '%%' 
--ORDER BY UsedIndexes
--;