cd "C:\GIT\PerformanceReporting\IndexAdvisory"
$Connection = Connect-DbaInstance -SqlInstance "ServerName"
$DataSet = Get-DbaDatabase -SqlInstance $Connection  -ExcludeSystem -OnlyAccessible | Invoke-DbaQuery -File IndexAdvisory_DataCollection.sql

Write-DbaDbTableData -SqlInstance localhost -InputObject $DataSet -Database PerformanceLogging -Schema Perf -Table IndexAdvisory -AutoCreate 