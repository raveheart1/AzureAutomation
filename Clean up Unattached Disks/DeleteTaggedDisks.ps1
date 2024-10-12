<#
.SYNOPSIS
This script deletes Azure disks that have been tagged with "ToDelete:Yes" and are older than 30 days.

.EXAMPLE
Run this in an automation runbook, the automation account will need to be able to read, write, and delete disks in the subscription.

.DESCRIPTION
This PowerShell script, when run, deletes Azure disks that have been tagged with "ToDelete:Yes" and have been in existence for more than 30 days.

.NOTES
Az.Accounts required
Az.Compute required

#>
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

$currentDate = Get-Date

try {
    Write-Progress -Activity "Retrieving disks from the subscription..."
    $disks = Get-AzDisk
} catch {
    Write-Error "Failed to retrieve disks from the subscription: $_"
    return
}

$diskCount = $disks.Count
$processedCount = 0

foreach ($disk in $disks) {
    $processedCount++
    "Processing disk $processedCount of $diskCount: $($disk.Name)"
    
    if ($disk.Tags["ToDelete"] -eq "Yes" -and ($currentDate - $disk.TimeCreated).Days -gt 30) {
        
        try {
            Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force
             "Deleted disk $($disk.Name)"
        } catch {
            Write-Warning "Failed to delete disk $($disk.Name): $_"
        }
    }
}

Write-Progress -Activity "Processing complete" -Completed
 "Processing complete. All eligible disks have been deleted."
