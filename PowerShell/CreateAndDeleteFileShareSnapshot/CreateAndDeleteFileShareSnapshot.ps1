##Author:      Igor Hensch
#Version:      1.1
#Last Update:  22.11.2020

     Param 
    (    
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
        $ExpireAfterDays
        
    )

    #Connect Azure Account
    $Credential = Get-AutomationPSCredential -Name 'AutomationPSCredential'
    Connect-AzAccount -Credential $Credential | Out-Null

    Write-Output "========================================================"
    Write-Output "Create File Share Snapshot"
    Write-Output "========================================================"
    Write-Output ""
    Write-Output "Executed by:          StorageAdmin"
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
    $SnapshotsToDelete = Get-AzStorageShare -Context $storageAcct.Context | Where-Object {$_.IsSnapshot -eq $true -and $_.SnapshotTime.DateTime -le "$((Get-Date).AddDays(-$ExpireAfterDays).ToShortDateString())" -and $_.Name -eq $ShareName}
    If(!([string]::IsNullOrEmpty($SnapshotsToDelete))) 
    {
        $SnapshotsToDelete | ForEach-Object {

            Write-Output "SnapshotsToDelete:    $($_ | select Name, IsSnapshot, SnapshotTime)"
            Remove-AzStorageShare $_.CloudFileShare -Force
            
        }
    }
    else
    {
        Write-Output "SnapshotsToDelete:    None"
    }