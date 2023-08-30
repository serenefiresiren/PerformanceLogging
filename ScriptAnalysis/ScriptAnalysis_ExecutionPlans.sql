USE [PerformanceLogging]

IF OBJECT_ID('tempdb..#XmlRecords') IS NOT NULL
	DROP TABLE #XmlRecords;

IF OBJECT_ID('tempdb..#tmpIndexes') IS NOT NULL
	DROP TABLE #tmpIndexes 
	
;WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
SELECT RawScript 
	,TRY_CAST(ExamplePlanXML AS XML) [XMLValue]
	,ExamplePlanXML
	,collectiondate
INTO #xmlRecords
FROM Perf.RawScriptMetrics
WHERE  RawScript NOT LIKE 'INSERT INTO /[%' ESCAPE '/'
    AND RawScript LIKE '%%' 
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
	,AnyPlanRef.value('@QueryPlanHash','nvarchar(max)')  [QueryPlanHash]
	,CollectionDate
	 INTO #tmpIndexes
FROM #xmlRecords rs CROSS APPLY rs.[XMLValue].nodes ('//Object') A (AnyColRef)
CROSS APPLY rs.[XMLValue].nodes('//StmtSimple') as B(AnyPlanRef)  
WHERE AnyColRef.value(
	'@Schema'
	,'nvarchar(max)'
	) <> 'sys' 

 
/* Aggregate the scripts to counts and index usage combinations */  
;WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT RawScript, COUNT(Distinct [UsedIndexes]) [IndexCombinations]
	,COUNT ( DISTINCT [QueryPlanHash]) [GeneratedPlans]  from  
(
SELECT   RawScript
	,[QueryPlanHash]
	,STRING_AGG (
	IndexName
	,','
	) WITHIN GROUP (ORDER BY IndexName)
AS [UsedIndexes]  
FROM #tmpIndexes  
GROUP BY RawScript , [QueryPlanHash]
--ORDER BY RawScript, UsedIndexes
) a 
GROUP BY RawScript 
ORDER BY RawScript, GeneratedPlans desc
;
 