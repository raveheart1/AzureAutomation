<#
.SYNOPSIS
This script updates the vCores of a specified Azure SQL database using either a system-assigned or user-assigned managed identity.

.DESCRIPTION
This script updates the vCores of a specified Azure SQL database. The script first checks if there is a system-assigned user identity and then sets the Azure context for further operations. 

Depending on the method specified (either "SA" for system-assigned or "UA" for user-assigned), the script then uses the appropriate managed identity. If a user-assigned managed identity is specified, the script fetches this identity and validates its assignment. The Azure context is set again using this identity.

The script then fetches the details of the specified Azure SQL database in the provided resource group and server. If the database is successfully fetched, the script attempts to update the vCores of this database.

The script also includes a function, Handle-Error, that logs any errors encountered during the execution of the script and aborts the operation.

.PARAMETER resourceGroupName
The name of the resource group in Azure where the SQL server and database are located.

.PARAMETER serverName
The name of the SQL server in Azure where the database resides.

.PARAMETER databaseName
The name of the Azure SQL database whose vCores are to be updated.

.PARAMETER vCores
The new number of vCores to set for the database.

.NOTES
The script uses the following modules: Az.Accounts, Az.Resources, Az.Automation, Az.Sql

Make sure your automation account has a managed identity with permissions over the target sql resources.

Plans to make this script based on db tags, and nearest availble amount of vcores if you cut the total in halves or quarters - for larger environments

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$serverName,

    [Parameter(Mandatory=$true)]
    [string]$databaseName,

    [Parameter(Mandatory=$true)]
    [int]$vCores
)
# Only modify this if you are using user assigned managed identities
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

 "Getting database details for database '$databaseName' in server '$serverName' and resource group '$resourceGroupName'"
 Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -DatabaseName $databaseName
 "Setting database $databasename vCores to $vCores"
 Set-AzSqlDatabase -ResourceGroupName $resourceGroupName -DatabaseName $databaseName -ServerName $serverName -VCore $vCores
 "vCores updated to $vCores successfully"
