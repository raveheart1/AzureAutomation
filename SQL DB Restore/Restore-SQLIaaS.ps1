<#
.SYNOPSIS
This PowerShell script restores a backup of a SQL database from Azure Recovery Services Vault using either a system-assigned or user-assigned managed identity.

.DESCRIPTION
The script is intended to be run in an automation account using a Managed Service Identity (either system-assigned or user-assigned) and retrieves information about the Recovery Services Vault and the backup items stored in it. It then fetches the recovery points for a specific backup item within a defined time period and selects the latest 'full' recovery point. It also obtains the configuration details of the backup, such as the container, server name, and instance of the database.

The script has the ability to optionally alter the database restoration configurations such as overwriting an existing workload or changing the restored database name. It then updates the target path of various database elements before initiating the restoration of the database with the updated configurations.

Note: The actual restore function is commented out in the final line of the script.

Required Az Modules in the automation account should just be Az.Accounts and Az.RecoveryServices

.PARAMETER sqlInstance
The SQL instance for the operation.

.PARAMETER targetServerName
The target server for the operation.

.PARAMETER backupServerName
The backup server name for the operation.

.PARAMETER sqldbname
The name of the SQL database for the operation.

.PARAMETER VaultName
The name of the Recovery Services Vault.

.PARAMETER ContainerName
The container name in the Recovery Services Vault.

.PARAMETER overwriteWLIFPresent
Option to overwrite existing workload if present.

.PARAMETER restoredbname
The name for the restored database.

.PARAMETER mssqlname
The name of the MSSQL database.

.NOTES
The script uses the Az module for Azure operations.

.AUTHOR
Gordon McWilliams

.VERSION
1.0
#>

inlineScript {
    try {
        "Initializing script parameters..."

        $sqlInstance = "sqlinstance;mssqlserver"
        $targetServerName = "lcg-dbdev07"
        $backupServerName = "lcg-dbprd07"
        $sqldbname = "SQLDataBase;mssqlserver;marsods"
        $VaultName = "lcgncubackup01p-asr"
        $ContainerName = "VMAppContainer;compute;lcgncubi-rg;lcg-dbprd07"
        $overwriteWLIFPresent = 'yes'
        $restoredbname = "MARSODS-Daily"
        $mssqlname = "MARSODS"

        "Connecting to Azure using a Managed Service Identity..."
        
        $method = "SA"
        Disable-AzContextAutosave -Scope Process
        $AzureContext = (Connect-AzAccount -Identity).context

        "Connected to Azure."

        "Fetching Vault Information..."
        $Vault = Get-AzRecoveryServicesVault -name $VaultName

        "Fetching Backup Items..."
        $bkpItems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL -Name $mssqlname -VaultId $Vault.ID
        $bkpItem = $bkpItems | where Name -ceq $sqldbname | where ContainerName -eq $ContainerName

        "Fetching Times for Full Backup Item..."
        
        $startDate = (Get-Date).AddDays(-14).ToUniversalTime()
        $endDate = (Get-Date).ToUniversalTime()

        $logbackup = Get-AzRecoveryServicesBackupRecoveryPoint -Item $bkpItem -VaultId $Vault.ID -StartDate $startdate -EndDate $endDate | where RecoveryPointType -eq 'FULL'
        $logpointmax = $logbackup.RecoveryPointTime | Measure-Object -Maximum
        $logpointintime = [dateTime]$logpointmax.Maximum
        $recoverypoint = $logbackup | Where-Object RecoveryPointType -eq "Full" | Sort-Object -Descending -Property RecoveryPointTime | Select-Object -First 1

        "Fetching Container, Servername, and Instance of DB..."

        $TargetContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -Vault $Vault.ID | where Name -eq $ContainerName
        $targetFullServername = $targetServerName + '.cttlc.com'
        $TargetInstance = Get-AzRecoveryServicesBackupProtectableItem -WorkloadType MSSQL -ItemType SQLInstance -Name $sqlInstance -ServerName $targetFullServerName -VaultId $Vault.ID

        "Generating Config..."
        $AnotherInstanceWithLogConfig = Get-AzRecoveryServicesBackupWorkloadRecoveryConfig -AlternateWorkloadRestore -RecoveryPoint $recoverypoint -TargetItem $TargetInstance -VaultId $Vault.ID -TargetContainer $TargetContainer

        "Restoring Database..."
        Restore-AzRecoveryServicesBackupItem -WLRecoveryConfig $AnotherInstanceWithLogConfig -VaultId $Vault.ID

        "Database restored."
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}
