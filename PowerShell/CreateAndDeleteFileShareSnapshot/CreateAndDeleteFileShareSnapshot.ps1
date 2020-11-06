##Author:      Igor Hensch
#Version:      1.0
#Last Update:  03.11.2020

#Required PS-Module:    AZ
#Required IAM Role:     CustomRole prefers
#Executes with Automation Accounts Credentials

#Function:
#Creates a new snapshot of fileshare and deletes old snapshot(s)

     Param 
    (    
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
        [String] 
        $TenantId="",
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
        [String] 
        $ResourceGroup,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
        [String] 
        $StorageAccountName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]  
        [String] 
        $ShareName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
        [String] 
        $StorageAccountKey,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
        [int] 
        $ExpireAfterDays
    )

    #Connect Azure Account
    $Credential = Get-AutomationPSCredential -Name ''
    Connect-AzAccount -TenantId $TenantId -Credential $Credential

    Write-Output "========================================================"
    Write-Output "Create File Share Snapshot"
    Write-Output "========================================================"
    Write-Output ""
    Write-Output "ResourceGroup:        $ResourceGroup"
    Write-Output "StorageAccount:       $StorageAccountName"
    Write-Output "ShareFile:            $ShareName"
    Write-Output ""
    Write-Output "--------------------------------------------------------"

    #Get Context of StorageAccount
    $storageAcct = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -StorageAccountName $StorageAccountName

    #Creates Share File Snapshot
    $share = Get-AzStorageShare -Context $storageAcct.Context -Name $shareName
    $snapshot = $share.CloudFileShare.Snapshot()

    Write-Output ""
    Write-Output "SnapshotUri:          $($snapshot.SnapshotQualifiedUri)"
    Write-Output ""
    Write-Output "========================================================"
    Write-Output "Delete Snapshots"
    Write-Output "========================================================"
    Write-Output ""
    Write-Output "Older than:           $ExpireAfterDays Days"
    Write-Output ""
    Write-Output "--------------------------------------------------------"

    #Deletes old Snapshots
    $SnapshotsToDelete = Get-AzStorageShare -Context $storageAcct.Context | Where-Object {$_.IsSnapshot -eq $true -and $_.SnapshotTime.DateTime.ToShortDateString() -le "$((Get-Date).AddDays(-$ExpireAfterDays).ToShortDateString())" -and $_.Name -eq $ShareName}
    
    $SnapshotsToDelete | ForEach-Object {

        If(!([string]::IsNullOrEmpty($_))) {
            Write-Output "SnapshotsToDelete:    $_"
            $_ | Remove-AzStorageShare -Force
        }
        
        else{
            Write-Output "SnapshotsToDelete:    None"
        }
    }