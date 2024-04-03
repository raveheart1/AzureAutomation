<#
.SYNOPSIS
This script retrieves all the disks in an Azure subscription, checks for unattached disks that do not have "Replica" in their names and do not have a "ToDelete" tag set to "No". These disks are then tagged with "ToDelete:Yes" and are listed at the end.

.DESCRIPTION
This PowerShell script operates on the Azure disks within a specified Azure subscription. It goes through each disk and checks for a few specific conditions. 
If a disk satisfies all these conditions, the script tags it with "ToDelete:Yes". 

The conditions are as follows:

The disk is unattached.
The disk does not contain "Replica" in its name.
The disk does not have a tag "ToDelete" set to "No".

.EXAMPLE
Run this in an automation runbook, the automation account will need to be able to read, write, and delete disks in the subscription.

.AUTHOR
Gordon McWilliams

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

# Get all disks in the subscription
try {
    Write-Progress -Activity "Retrieving disks from the subscription..."
    $disks = Get-AzDisk
} catch {
    Write-Error "Failed to retrieve disks from the subscription: $_"
    return
}

$diskCount = $disks.Count
$processedCount = 0

# Initialize array to store tagged disks
$taggedDisks = @()

foreach ($disk in $disks) {
    $processedCount++
    Write-Progress -Activity "Processing disk $processedCount of $diskCount: $($disk.Name)"
    
    # Check if the disk is unattached (ManagedBy property is null), if it does not have "Replica" in the name, and if it does not have "ToDelete:No" tag
    if (-not $disk.ManagedBy -and $disk.Name -notlike '*Replica*' -and ($disk.Tags["ToDelete"] -ne "No")) {
        
        # Create or update tag
        if ($disk.Tags) {
            $disk.Tags["ToDelete"] = "Yes"
        } else {
            $disk.Tags = @{ "ToDelete" = "Yes" }
        }

        # Update the disk with the new tag
        try {
            Update-AzDisk -ResourceGroupName $disk.ResourceGroupName -Disk $disk -DiskName $disk.Name
            # Add disk to tagged disks array
            $taggedDisks += $disk
        } catch {
            Write-Warning "Failed to update disk $($disk.Name): $_"
        }
    }
}

Write-Progress -Activity "Processing complete" -Completed
"Processing complete. All eligible disks have been tagged."

# Output tagged disks
"The following disks were tagged:"
foreach ($disk in $taggedDisks) {
    $disk.Name
}
