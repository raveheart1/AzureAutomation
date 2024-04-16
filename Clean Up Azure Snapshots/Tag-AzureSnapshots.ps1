<#
.SYNOPSIS
This script tags Azure managed disk snapshots that are older than a specified number of days.

.DESCRIPTION
The script iterates through all managed disk snapshots in a given subscription, checking their creation time. 
Snapshots older than the specified threshold are tagged with "SnapshotDelete: True" to mark them for deletion.

.PARAMETER DaysOld
The age of the snapshot in days to qualify for tagging.

.NOTES
This script requires the Az.Compute module.

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

Param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the number of days for snapshot age threshold")]
    [int]$DaysOld = 14
)

# Ensuring Azure PowerShell is available
if (-not(Get-Module -ListAvailable -Name Az.Compute)) {
    Install-Module -Name Az.Compute -Force
    Import-Module Az.Compute
}

# Connect to Azure Account
Connect-AzAccount -Identity

# Retrieve all snapshots in the subscription
$snapshots = Get-AzSnapshot

foreach ($snapshot in $snapshots) {
    # Calculate if the snapshot is older than the specified number of days
    $creationTime = $snapshot.TimeCreated
    $timeSpan = New-TimeSpan -Start $creationTime -End (Get-Date)
    
    if ($timeSpan.Days -ge $DaysOld) {
        # Define the tag to add
        $tags = $snapshot.Tags
        $tags["SnapshotDelete"] = "True"
        
        # Update the snapshot with the new tag
        Set-AzSnapshot -Snapshot $snapshot -Tag $tags
        
        Write-Output "Tagged snapshot: $($snapshot.Id) with 'SnapshotDelete: True'"
    }
}
