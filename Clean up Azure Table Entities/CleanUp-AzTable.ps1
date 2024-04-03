<#
.SYNOPSIS
This script retrieves and deletes Azure storage table rows based on a timestamp condition.

.DESCRIPTION
The script first authenticates to Azure using the provided subscription ID, then retrieves the storage account key for the specified storage account. It then establishes a context with the storage account, retrieves all tables within the storage account, and iterates over each table to retrieve all entities (rows) within each table. If the timestamp of an entity is older than the current date (threshold date), the script attempts to remove the entity from the table.

.PARAMETER resourceGroupName
The resource group where the storage account is located.

.PARAMETER storageAccountName
The storage account name from where the tables will be retrieved and potentially modified.

.AUTHOR
Gordon McWilliams
#>

Param(
    [Parameter(Mandatory=$true,HelpMessage="Enter the value for the resource group name")][String]$resourceGroupName,
    [Parameter(Mandatory=$true,HelpMessage="Enter the value for the storage account name")][String]$storageAccountName
)
# Only modify this if you are using user managed identities
$method = "SA"

# Connect using a Managed Service Identity
try {
    $AzureContext = (Connect-AzAccount -Identity).context
}
catch{
    Write-Output "There is no system-assigned user identity. Aborting."; 
    exit
}

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
-DefaultProfile $AzureContext

if ($method -eq "SA")
{
    Write-Output "Using system-assigned managed identity"
}
elseif ($method -eq "UA")
{
    Write-Output "Using user-assigned managed identity"

    # Connects using the Managed Service Identity of the named user-assigned managed identity
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroup `
        -Name $UAMI -DefaultProfile $AzureContext

    # validates assignment only, not perms
    if ((Get-AzAutomationAccount -ResourceGroupName $resourceGroup `
            -Name $automationAccount `
            -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId))
        {
            $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

            # set and store context
            $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
        }
    else {
            Write-Output "Invalid or unassigned user-assigned managed identity"
            exit
        }
}
else {
    Write-Output "Invalid method. Choose UA or SA."
    exit
 }
try {
    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]

    $context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

    $tables = Get-AzStorageTable -Context $context

    $thresholdDate = (Get-Date).AddDays(0)

    foreach ($table in $tables) {
        try {

            $cloudTable = (Get-AzStorageTable -Name $table.Name -Context $context).CloudTable


            $entities = Get-AzTableRow -Table $cloudTable
            

            foreach ($entity in $entities) {
                try {
                    if ([DateTime]$entity.TableTimestamp.DateTime -lt $thresholdDate) {
                        Remove-AzTableRow -Table $cloudTable -PartitionKey $entity.PartitionKey -RowKey $entity.RowKey
                    }
                } catch {
                    Write-Error "Failed to remove entity with RowKey $($entity.RowKey) from table $($table.Name). Error: $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Error "Failed to get entities from table $($table.Name). Error: $($_.Exception.Message)"
        }
    }
} catch {
    Write-Error "Failed to connect to Azure account or get the storage account key. Error: $($_.Exception.Message)"
}
