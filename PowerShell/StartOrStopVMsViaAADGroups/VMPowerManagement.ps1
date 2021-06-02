#Required PS-Module:    AZ
#Required IAM Role:     Virtual Machine Operator (CustomRole)

Param 
(    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $AzureTenantId="ea28a429-321b-4a89-a208-d174a764896a",
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $AssignmentGroup,
    [Parameter(Mandatory=$true)][ValidateSet("Start","Stop")] 
    [String] 
    $Action
) 

$ErrorActionPreference = "Stop" 
$ErrMessage = $null

try { 

    #Login to Azure Account via AZ Module   
    $Credential = Get-AutomationPSCredential `
        -Name 'PrincipalName'

    Connect-AzAccount `
        -TenantId $AzureTenantId `
        -Credential $Credential | Out-Null

    Write-Output "========================================================"
    Write-Output "$Action Azure VMs"
    Write-Output "========================================================"
    Write-Output ""
    Write-Output "Executed by:      PrincipalName"
    Write-Output "Assignment Group: $AssignmentGroup"
    Write-Output ""
    Write-Output "--------------------------------------------------------"

    #Get all assigned Azure VMs to chosen group
    $AzureVMsToHandle = (Get-AzRoleAssignment | `
        Where-Object DisplayName -eq $AssignmentGroup).Scope | `
        ForEach-Object {$_.Split("/")[-1]} | Sort-Object -CaseSensitive

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
    $AzureVMsForAction = Test-RunStatus `
        -AzureVMsToHandle $AzureVMsToHandle `
        -Action $Action

    $trial = 0

    do {

        #Allocate or deallocate Azure VMs
        StartOrStop-VMs `
            -AzureVMsToHandle $AzureVMsForAction `
            -Action $Action

        sleep 300
        #Create a List of Azure VMs again what needs to be allocate or deallocate if still exist for next step
        $AzureVMsForAction = Test-RunStatus `
            -AzureVMsToHandle $AzureVMsToHandle `
            -Action $Action
        
    }

    #Restart action if somethin went wrong and wait 60 seconds (max. retrials = 10 times)
    while(!([string]::IsNullOrEmpty($AzureVMsForAction))){   

        sleep 300

        StartOrStop-VMs `
            -AzureVMsToHandle $AzureVMsForAction `
            -Action $Action

        $AzureVMsForAction = Test-RunStatus `
            -AzureVMsToHandle $AzureVMsToHandle `
            -Action $Action

        $trial++

        If($trial -eq 10){break}

    } | Out-Null

} catch {

    $ErrMessage = $_.Exception.Message

    $Body = @"
    {
        "@context": "https://schema.org/extensions",
        "@type": "MessageCard",
        "themeColor": "0072C6",
        "title": "Runbook PowerManagement Failed",
        "text": "**Exception:** $($ErrMessage)",
        "potentialAction": [
            {
                "@type": "OpenUri",
                "name": "View in Azure",
                "targets": [
                { "os": "default", "uri": "<EventUri>" }
                ]
            }
        ]
}
"@

    Invoke-WebRequest `
        -Uri "<TeamsWebHookConnectorUri>" `
        -Method POST `
        -Body $Body `
        -UseBasicParsing | Out-Null
}

Write-Output "--------------------------------------------------------"
Write-Output "Retrials: $trial"
Write-Output ""
Write-Output "========================================================"
Write-Output "Script Info"
Write-Output "========================================================"
Write-Output ""
Write-Output "Author:       Igor Hensch"
Write-Output "Version:      3.0"
Write-Output "Last Update:  02.06.2021"
