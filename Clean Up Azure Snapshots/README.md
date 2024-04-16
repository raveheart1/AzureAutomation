# Azure Snapshot Management Scripts

These PowerShell scripts help manage Azure snapshots by tagging those older than a specified age and subsequently deleting snapshots based on tags. The scripts are intended for use within Azure Automation accounts and require specific Azure permissions and modules to function correctly.

## Scripts Overview

1. **Tag Old Snapshots**: This script tags all Azure managed disk snapshots that are older than a specified number of days with "SnapshotDelete: True".
   
2. **Delete Tagged Snapshots**: This script deletes all Azure snapshots tagged with "SnapshotDelete: True".

## Prerequisites

- **Azure Subscription**: You must have access to an Azure subscription with permissions to manage snapshots and automation accounts.
- **Azure Automation Account**: These scripts are designed to run in an Azure Automation Account environment.
- **PowerShell Modules**: The following PowerShell modules are required:
  - `Az.Accounts`: Handles authentication and account management in Azure.
  - `Az.Compute`: Provides cmdlets for managing Azure Compute resources, including snapshots.

## Setup Instructions

### Module Installation

Before running these scripts, ensure that the necessary modules are available in your Azure Automation Account:

1. Navigate to your Azure Automation Account in the Azure portal.
2. Under **Shared Resources**, click on **Modules**.
3. Click **Add a module** and upload the module packages for `Az.Accounts` and `Az.Compute` if they are not already available. These can be downloaded from the [PowerShell Gallery](https://www.powershellgallery.com/).

### Importing Scripts

1. In the Azure portal, go to your Automation Account.
2. Click on **Runbooks** under **Process Automation**.
3. Add a new runbook for each script:
   - Choose **Create a runbook**, name it, select **PowerShell** as the runbook type, and create.
   - Import the script content into the runbook editor and save.
   - Publish the runbook to make it available for scheduling or manual runs.

## Script Usage

### Running Tag Old Snapshots

- This script requires you to specify the number of days as an argument which defines the age threshold for old snapshots.
- It can be scheduled to run regularly or run manually depending on your requirements.

### Running Delete Tagged Snapshots

- Ensure that only the intended snapshots are tagged since this script will delete all snapshots tagged with "SnapshotDelete: True".
- This script should be run after reviewing tagged snapshots to avoid accidental deletions.

## Important Notes

- Test these scripts in a non-production environment to ensure they function as expected.
- Regularly review snapshot policies and permissions to maintain security and compliance.
- Snapshot deletions are irreversible; ensure proper backup policies are in place.

## Support

For any issues or additional guidance on setting up and running these scripts, refer to the official [Azure PowerShell documentation](https://docs.microsoft.com/en-us/powershell/azure/).

