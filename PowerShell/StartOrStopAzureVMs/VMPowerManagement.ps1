##Author:      Igor Hensch
#Version:      1.0
#Last Update:  03.11.2020

#Required PS-Module:    AZ
#Required IAM Role:     CustomRole prefers
#Executes with Automation Accounts Credentials

#Function:
#Allocates or deallocates Azure VMs via assigned AAD Group and restarts the action if something went wrong

Param 
(    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $TenantId="",
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $AssignmentGroup,
    [Parameter(Mandatory=$true)][ValidateSet("Start","Stop")] 
    [String] 
    $Action
) 

#Login to Azure Account via AZ Module   
$Credential = Get-AutomationPSCredential -Name ''
Connect-AzAccount -TenantId $TenantId -Credential $Credential | Out-Null

Write-Output "========================================================"
Write-Output "$Action Azure VMs"
Write-Output "========================================================"
Write-Output ""
Write-Output "Assignment Group: $AssignmentGroup"
Write-Output ""
Write-Output "--------------------------------------------------------"

#Get all assigned Azure VMs to chosen group
$AzureVMsToHandle = (Get-AzRoleAssignment | Where-Object DisplayName -eq $AssignmentGroup).Scope | ForEach-Object {$_.Split("/")[-1]}

#Allocate or deallocate Azure VMs
function StartOrStop-VMs ($AzureVMsToHandle, $Action) {
    $number = 1   
    foreach ($AzureVM in $AzureVMsToHandle) 
    { 
        Write-Output ""
        Write-Output "VM name:      $AzureVM"
        Write-Output "Number:       $number/$($AzureVMsToHandle.Count)"
        Write-Output "Start time:   $(Get-Date -UFormat "%r") UTC"

        $Duration = ( Measure-Command {
            if($Action -eq "Stop") 
            {  
                Get-AzVM | Where-Object {$_.Name -eq $AzureVM} | Stop-azVM -Force | Out-Null
            }
            if($Action -eq "Start") 
            {  
                Get-AzVM | Where-Object {$_.Name -eq $AzureVM} | Start-azVM | Out-Null
            }
        })

        Write-Output "End time:     $(Get-Date -UFormat "%r") UTC"
        Write-Output "DUR. in sec.: $("{0:N2}" -f [math]::round($Duration.TotalSeconds, 2))"
        Write-Output "DUR. in min.: $("{0:N2}" -f [math]::round($Duration.TotalMinutes, 2))"
        Write-Output ""
        $number++
    }
}

#Returns Azure VMs what needs to be allocate or deallocate
function Test-RunStatus ($AzureVMsToHandle, $Action) {
    
    If ($Action -eq "Stop") {
        foreach ($AzureVM in $AzureVMsToHandle) { 
            If (((Get-azVM -Status | Where-Object {$_.Name -eq $AzureVM}).PowerState -eq "VM running"))
            {
                $VmsForRestart += @($AzureVM)
            }
        }
    }
    If ($Action -eq "Start") {
        foreach ($AzureVM in $AzureVMsToHandle) { 
            If (((Get-azVM -Status | Where-Object {$_.Name -eq $AzureVM}).PowerState -eq "VM deallocated"))
            {
                $VmsForRestart += @($AzureVM)
            }
        }
    }
    return $VmsForRestart
}

#Create a List of Azure VMs what needs to be allocate or deallocate
$AzureVMsForAction = Test-RunStatus -AzureVMsToHandle $AzureVMsToHandle -Action $Action

$trial = 0

do {

    #Allocate or deallocate Azure VMs
    StartOrStop-VMs -AzureVMsToHandle $AzureVMsForAction -Action $Action
    #Create a List of Azure VMs again what needs to be allocate or deallocate if still exist for next step
    $AzureVMsForAction = Test-RunStatus -AzureVMsToHandle $AzureVMsToHandle -Action $Action
    
}

#Restart action if something went wrong and wait 60 seconds
while(!([string]::IsNullOrEmpty($AzureVMsForAction))){   

    sleep 60
    StartOrStop-VMs -AzureVMsToHandle $AzureVMsForAction -Action $Action
    $AzureVMsForAction = Test-RunStatus -AzureVMsToHandle $AzureVMsToHandle -Action $Action

} | Out-Null

Write-Output "--------------------------------------------------------"
Write-Output "Retrials: $trial"