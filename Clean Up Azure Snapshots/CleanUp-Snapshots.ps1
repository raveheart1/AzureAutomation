<#
.SYNOPSIS
Deletes Azure snapshots that are tagged with "SnapshotDelete: True".

.DESCRIPTION
The script scans through all managed disk snapshots in a given subscription and deletes those that have been tagged with "SnapshotDelete: True".

.NOTES
Ensure that the Az.Compute module is available and loaded before running this script.

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

# Ensuring Azure PowerShell is available
if (-not(Get-Module -ListAvailable -Name Az.Compute)) {
    Install-Module -Name Az.Compute -Force
    Import-Module Az.Compute
}

# Connect to Azure Account
Connect-AzAccount -Identity

# Retrieve all snapshots that have the "SnapshotDelete: True" tag
$snapshots = Get-AzSnapshot | Where-Object { $_.Tags["SnapshotDelete"] -eq "True" }

foreach ($snapshot in $snapshots) {
    try {
        # Attempt to delete the snapshot
        Remove-AzSnapshot -SnapshotName $snapshot.Name -ResourceGroupName $snapshot.ResourceGroupName -Force
        Write-Output "Deleted snapshot: $($snapshot.Name)"
    } catch {
        Write-Error "Failed to delete snapshot: $($snapshot.Name). Error: $_"
    }
}
