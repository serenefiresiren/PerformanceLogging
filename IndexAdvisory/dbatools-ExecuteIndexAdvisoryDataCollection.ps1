param ( 
    [Parameter(Mandatory=$True)] [Array] $Instance,
    [Parameter(Mandatory=$False)][Array] $ExcludeDatabases,
    [Parameter(Mandatory=$True)] [string] $Destination, 
    [Parameter(Mandatory=$True)] [string] $DestinationDatabase
    )
 
$DataSet = Get-DbaDatabase -SqlInstance $Instance  -ExcludeSystem -OnlyAccessible |Where-Object {$_.Name -notin $ExcludeDatabases} |  Invoke-DbaQuery  -File IndexAdvisory_DataCollection.sql

Write-DbaDbTableData -SqlInstance $Destination -InputObject $DataSet -Database $DestinationDatabase -Schema Perf -Table IndexAdvisory -AutoCreate 