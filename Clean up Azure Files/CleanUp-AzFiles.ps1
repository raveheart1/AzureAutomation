<#
.SYNOPSIS
This script deletes blobs in a specified Azure Storage Account that are older than a specified number of days, using either a system-assigned or user-assigned managed identity.

.DESCRIPTION
This script connects to an Azure account using a Managed Service Identity (either system-assigned or user-assigned). It fetches the key for a specified storage account from a given Key Vault and creates a storage context.

The script then retrieves all containers within the storage account and iterates through them. For each container, it lists all blobs. Blobs that were last modified before a specified threshold date are deleted. The script keeps track of and outputs the number of deleted blobs for each container.

The script uses the Connect-AzAccount, Set-AzContext, Get-AzUserAssignedIdentity, Get-AzAutomationAccount, Get-AzKeyVaultSecret, New-AzStorageContext, Get-AzStorageContainer, Get-AzStorageBlob, and Remove-AzStorageBlob cmdlets from the Az module.

.PARAMETER storageAccountName
The name of the Azure Storage Account from which blobs are to be deleted.

.PARAMETER keyVault
The name of the Azure Key Vault where the storage account key is stored.

.PARAMETER secretName
The name of the secret in the Key Vault that stores the storage account key.

.PARAMETER FileShareName
Another mandatory parameter, this is the name of the Azure File Share from which the files are to be deleted.

.NOTES
The script uses the following az modules: Az.Accounts, Az.KeyVault, Az.Storage

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

Param(
[Parameter(Mandatory=$true,HelpMessage="Enter the value for the source storage account")][String]$StorageAccountName,
[Parameter(Mandatory=$true,HelpMessage="Enter the value for file share name")][String]$FileShareName,
[Parameter(Mandatory=$true,HelpMessage="Enter the value for keyvault name")][String]$keyVault,
[Parameter(Mandatory=$true,HelpMessage="Enter the value for secret name")][String]$secretName
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
$key = Get-AzKeyVaultSecret -VaultName $keyVault -Name $secretName -AsPlainText
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key  
$shareName = $FileShareName 
  
$DirIndex = 0  
$dirsToList = New-Object System.Collections.Generic.List[System.Object]  
  
$shareroot = Get-AzStorageFile -ShareName $shareName -Path . -context $ctx   
$dirsToList += $shareroot   
  
While ($dirsToList.Count -gt $DirIndex)  
{  
    $dir = $dirsToList[$DirIndex]  
    $DirIndex ++  
    $fileListItems = $dir | Get-AzStorageFile  
    $dirsListOut = $fileListItems | where {$_.GetType().Name -eq "AzureStorageFileDirectory"}  
    $dirsToList += $dirsListOut  
    $files = $fileListItems | where {$_.GetType().Name -eq "AzureStorageFile"}  
  
    foreach($file in $files)  
    {  
        $task = $file.CloudFile.FetchAttributesAsync()  
        $task.Wait()  
  
        if ($file.CloudFile.Properties.LastModified -lt (Get-Date).AddDays(-14))  
        {  
  
            $file | Remove-AzStorageFile  
        }  
    }  
}
Write-Host "Files have been cleaned up."