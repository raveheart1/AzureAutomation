<#
.SYNOPSIS
This script retrieves and processes backup information related to Virtual Machines (VMs) and SQL servers across multiple Azure subscriptions.

.DESCRIPTION
This script focuses on multiple Azure subscription IDs specified at the beginning. For each subscription, it:
- Sets the context for the specified subscription.
- Retrieves all Recovery Services Vaults associated with the subscription.
- Processes and potentially stores data (based on the later segments of the script) related to VM and SQL backups.

The script expects paths to two CSV files (`VM_Backups.csv` and `SQL_Backups.csv`) to be defined, which are likely used for output or data processing.

The script utilizes cmdlets from the Az module like `Set-AzContext` and `Get-AzRecoveryServicesVault`.

.PARAMETER subscriptionIds
An array of Azure subscription IDs to be processed.

.PARAMETER vmCsvPath
The path to the CSV file related to VM backups.

.PARAMETER sqlCsvPath
The path to the CSV file related to SQL backups.

.NOTES
The script primarily uses the Az module for Azure operations.

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

# Specify the subscription IDs
$subscriptionIds = @(
    'subid1',
    'subid2'
    # ... add more subscription IDs as needed
)


# Specify the paths to the CSV files
$vmCsvPath = "VM_Backups.csv"
$sqlCsvPath = "SQL_Backups.csv"
$azureFilesCsvPath = "AzureFiles_Backups.csv"

# Create arrays to store the output objects
$vmOutputArray = @()
$sqlOutputArray = @()
$azureFilesOutputArray = @()

# Iterate through each subscription ID
Write-Progress -PercentComplete 0 -Status "Starting processing subscriptions" -Activity "Initialization"
$subscriptionCount = $subscriptionIds.Length
$currentSubscriptionIndex = 0
foreach ($subscriptionId in $subscriptionIds) {
    $currentSubscriptionIndex++
    $percentComplete = ($currentSubscriptionIndex / $subscriptionCount) * 100
    Write-Progress -PercentComplete $percentComplete -Status "Processing subscription $subscriptionId" -Activity "Processing Subscriptions"
    # Set the context to the current subscription
    Set-AzContext -SubscriptionId $subscriptionId

    Write-Host "Processing subscription: $subscriptionId"

    # Get all Recovery Services Vaults
    $vaults = Get-AzRecoveryServicesVault

    Write-Host "Found $($vaults.Count) vaults."

    # Iterate through each vault
    foreach ($vault in $vaults) {
        # Set the Recovery Services vault context
        Set-AzRecoveryServicesVaultContext -Vault $vault
        
        Write-Host "Processing vault: $($vault.Name)"

        # Get the list of backup policies
        $backupPolicies = Get-AzRecoveryServicesBackupProtectionPolicy

        # Process Azure VM backup policies
        $vmBackupPolicies = $backupPolicies | Where-Object { $_.WorkloadType -eq 'AzureVM' }
        foreach ($policy in $vmBackupPolicies) {
            $protectedItems = Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM -BackupManagementType AzureVM
            foreach ($item in $protectedItems) {
                if ($item.PolicyId -eq $policy.Id) {
                    $vmName = $item.Name -split ';' | Select-Object -Last 1
                    $outputObject = [PSCustomObject]@{
                        SubscriptionId = $subscriptionId
                        VaultName = $vault.Name
                        PolicyName = $policy.Name
                        VMName = $vmName
                        Schedule = $policy.SchedulePolicy
                        Retention = $policy.RetentionPolicy
                    }
                    $vmOutputArray += $outputObject
                }
            }
        }

        # Process SQL backup policies
        $sqlBackupPolicies = $backupPolicies | Where-Object { $_.WorkloadType -eq 'MSSQL' }
        foreach ($policy in $sqlBackupPolicies) {
            $protectedItems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL
            foreach ($item in $protectedItems) {
                if ($item.PolicyId -eq $policy.Id) {
                    $outputObject = [PSCustomObject]@{
                        SubscriptionId = $subscriptionId
                        VaultName = $vault.Name
                        StorageAccountName = ($item.ContainerName -split ';')[2]
                        PolicyName = $policy.Name
                        DatabaseName = $item.Name
                        IsDifferentialEnabled = $policy.IsDifferentialBackupEnabled
                        IsLogBackupEnabled = $policy.IsLogBackupEnabled
                        FullBackupSchedulePolicy = $policy.FullBackupSchedulePolicy
                        DifferentialBackupSchedulePolicy = $policy.DifferentialBackupSchedulePolicy
                        LogBackupSchedulePolicy = $policy.LogBackupSchedulePolicy
                        FullBackupRetentionPolicy = $policy.FullBackupRetentionPolicy
                        DifferentialBackupRetentionPolicy = $policy.DifferentialBackupRetentionPolicy
                        LogBackupRetentionPolicy = $policy.LogBackupRetentionPolicy                        
                    }
                    $sqlOutputArray += $outputObject
                }
            }
        }

        # Process Azure Files backup policies
        $azureFilesBackupPolicies = $backupPolicies | Where-Object { $_.WorkloadType -eq 'AzureFiles' }
        foreach ($policy in $azureFilesBackupPolicies) {
            $protectedItems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureStorage -WorkloadType AzureFiles
            foreach ($item in $protectedItems) {
                if ($item.PolicyId -eq $policy.Id) {
                    $outputObject = [PSCustomObject]@{
                        SubscriptionId = $subscriptionId
                        VaultName = $vault.Name
                        StorageAccountName = ($item.ContainerName -split ';')[2]
                        PolicyName = $policy.Name
                        ShareName = $item.Name
                        Schedule = $policy.SchedulePolicy
                        Retention = $policy.RetentionPolicy
                    }
                    $azureFilesOutputArray += $outputObject
                }
            }
        }
    }

    # Notify the user that the script has completed
    Write-Host "Script completed"

    # After all loops have completed, output the arrays to CSV files
    $vmOutputArray | Export-Csv -Path $vmCsvPath -NoTypeInformation
    $sqlOutputArray | Export-Csv -Path $sqlCsvPath -NoTypeInformation
    $azureFilesOutputArray | Export-Csv -Path $azureFilesCsvPath -NoTypeInformation

    # Notify the user that the data has been exported
    Write-Host "Data exported to $vmCsvPath, $sqlCsvPath, and $azureFilesCsvPath"
}