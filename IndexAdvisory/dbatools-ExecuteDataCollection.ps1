param( 
    [Parameter(Mandatory = $true)][array]$Instance,
    [Parameter(Mandatory = $false)][array]$ExcludeDatabases,
    [Parameter(Mandatory = $true)][string]$LoggingInstance, 
    [Parameter(Mandatory = $true)][string]$LoggingDatabase,
    [Parameter(Mandatory = $true)][string]$LoggingTableSchema,
    [Parameter(Mandatory = $true)][string]$LoggingTable,
    [Parameter(Mandatory = $true)][string]$LoggingScript
) 
  
foreach ($Connection in $Instance) {
    Write-Host "Collect $Connection Metrics"
    $sqlConnection = Connect-DbaInstance $Connection -TrustServerCertificate
    $sqlConnection
    $dataSet = Get-DbaDatabase -SqlInstance $sqlConnection -ExcludeSystem -OnlyAccessible | 
        Where-Object { $_.Name -notin $ExcludeDatabases } | 
        Invoke-DbaQuery -File $LoggingScript
        
    $records = $dataSet.Count
    Write-Host "Write $records metrics for $Connection"
    
    Write-DbaDbTableData -SqlInstance $LoggingInstance -InputObject $dataSet `
        -Database $LoggingDatabase -Schema $LoggingTableSchema -Table $LoggingTable -AutoCreate 
}
