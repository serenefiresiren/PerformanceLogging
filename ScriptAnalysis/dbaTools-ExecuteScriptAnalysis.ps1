cd "C:\GIT\PerformanceLogging\ScriptAnalysis"
$Connection = Connect-DbaInstance -SqlInstance "ServerName"
$DataSet = Get-DbaDatabase -SqlInstance $Connection  -ExcludeSystem -OnlyAccessible   | Invoke-DbaQuery -File ScriptPerformance_DataCollection.sql

Write-DbaDbTableData -SqlInstance LocalHost -InputObject $DataSet -Database PerformanceLogging -Schema Perf -Table RawScriptMetrics  

 