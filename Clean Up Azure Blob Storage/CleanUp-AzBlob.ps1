<#
.SYNOPSIS
This script deletes blobs in a specified Azure Storage Account that are older than a specified number of days, using either a system-assigned or user-assigned managed identity.

.DESCRIPTION
This script connects to an Azure account using a Managed Service Identity (either system-assigned or user-assigned). It fetches the key for a specified storage account from a given Key Vault and creates a storage context.

The script then retrieves all containers within the storage account and iterates through them. For each container, it lists all blobs. Blobs that were last modified before a specified threshold date are deleted. The script keeps track of and outputs the number of deleted blobs for each container.

The script uses the Connect-AzAccount, Set-AzContext, Get-AzUserAssignedIdentity, Get-AzAutomationAccount, Get-AzKeyVaultSecret, New-AzStorageContext, Get-AzStorageContainer, Get-AzStorageBlob, and Remove-AzStorageBlob cmdlets from the Az module.

.PARAMETER resourceGroupName
The name of the resource group in Azure where the storage account and Key Vault are located.

.PARAMETER storageAccountName
The name of the Azure Storage Account from which blobs are to be deleted.

.PARAMETER keyVault
The name of the Azure Key Vault where the storage account key is stored.

.PARAMETER secretName
The name of the secret in the Key Vault that stores the storage account key.

.PARAMETER thresholdDays
The number of days past which blobs should be deleted. Blobs that were last modified before this many days ago are deleted.

.PARAMETER targetContainers
An optional list of specific containers from which to delete blobs. If not provided, all containers in the storage account are considered.

.NOTES
The script uses the following az modules: Az.Accounts, Az.Resources, Az.Automation, Az.KeyVault, Az.Storage

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$storageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$keyVault,

    [Parameter(Mandatory=$true)]
    [string]$secretName,

    [Parameter(Mandatory=$false)]
    [int]$thresholdDays,

    [Parameter(Mandatory=$false)]
    [string]$targetContainers
)
# Only modify this if you are using user managed identities
$method = "SA"

# Connect using a Managed Service Identity
try {
    $AzureContext = (Connect-AzAccount -Identity).context
}
catch{
    "There is no system-assigned user identity. Aborting."; 
    exit
}

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
-DefaultProfile $AzureContext

if ($method -eq "SA")
{
    "Using system-assigned managed identity"
}
elseif ($method -eq "UA")
{
    "Using user-assigned managed identity"

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
            "Invalid or unassigned user-assigned managed identity"
            exit
        }
}
else {
    "Invalid method. Choose UA or SA."
    exit
 }

# grab SA secret 
$storageAccountKey = Get-AzKeyVaultSecret -VaultName $keyVault -Name $secretName -AsPlainText

# Set the time threshold for deletion
$thresholdDate = (Get-Date).AddDays(-$thresholdDays)
try {
    # Get the storage account context
    "Getting storage account context..."
    $storageAccountContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

    # List all containers in the storage account
    "Listing containers in the storage account..."
    $containers = Get-AzStorageContainer -Context $storageAccountContext

    # Iterate through each container
    foreach ($container in $containers) {
        $containerName = $container.Name

        # Skip this container if it's not in the target list (if provided)
    if ($targetContainers.Count -gt 0 -and $targetContainers -notcontains $containerName) {
        continue
    }
        # List blobs in the container
        "Listing blobs in the container..."
        $blobs = Get-AzStorageBlob -Container $containerName -Context $storageAccountContext
        $blobCount = $blobs.Count
        $deletedCount = 0

        # Iterate through blobs and delete those older than two weeks
        "Checking and deleting blobs older than two weeks..."
        for ($i = 0; $i -lt $blobCount; $i++) {
            $blob = $blobs[$i]
            $blobLastModified = $blob.ICloudBlob.Properties.LastModified.UtcDateTime

            if ($blobLastModified -lt $thresholdDate) {
                Remove-AzStorageBlob -Container $containerName -Blob $blob.Name -Context $storageAccountContext
                "Deleted blob: $($blob.Name)"
                $deletedCount++
            }

            Write-Progress -Activity "Processing blobs" -Status "Processed $($i + 1) of $blobCount" -PercentComplete (($i + 1) / $blobCount * 100)
        }

        "Deleted $deletedCount blobs older than two weeks in container: $containerName`n"
    }
} catch {
    "An error occurred: $_"
}