#Author:       Igor Hensch
#Version:      2.0
#Last Update:  11/8/2020

 Param 
(    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $GroupName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $TeamsAppSetupPolicy = "none",
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()] 
    [String] 
    $TeamsAppPermissionPolicy = "none"
)

#Connect Azure AD
$Credential = Get-AutomationPSCredential -Name 'TeamsAutomation'
Connect-AzureAD -Credential $Credential | Out-Null

Write-Output "========================================================"
Write-Output " Run Teams Policy Assigment"
Write-Output "========================================================"
Write-Output ""
Write-Output "--------------------------------------------------------"
Write-Output ">> Connect Azure AD"
Write-Output ""

#Get the ID of the group
$GroupId = (Get-AzureADGroup -SearchString $GroupName).ObjectId

#Get all group members and save it
$GroupMembers = (Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object {$_.ObjectType -eq "User"}).UserPrincipalName

Write-Output "Group Name:        $GroupName"
Write-Output "Group Id:          $GroupId"
Write-Output "Group Members:     $($GroupMembers.Count)"
Write-Output ""
Write-Output "--------------------------------------------------------"
Write-Output ">> Connect Skype for Business Online"
Write-Output ""

#Connect Skype for Business Online
$sfbSession = New-CsOnlineSession -Credential $Credential

#Import SfB Online Powershell session
Import-PSSession $sfbSession -AllowClobber | Out-Null

#Get all SfB user Accounts that are not softdeleted an save it
$sfbUsers = Get-CsOnlineUser | Where-Object {$_.SoftDeletionTimestamp -eq $null}

#Get all User Accounts that are not group members to delete the policy later
$sfbUsers | ForEach-Object {
    if($GroupMembers -notcontains $_.UserPrincipalName)
    {
        $NoMembers += @($_)
    }
}

#Get all User Accounts wuthout this Policies to minimize effort for searching later
If(($TeamsAppSetupPolicy -ne "none") -and ($TeamsAppPermissionPolicy -ne "none")) 
{
    $sfbUsers | ForEach-Object {
        if((!($_.TeamsAppSetupPolicy -eq $TeamsAppSetupPolicy) -and !($_.TeamsAppPermissionPolicy -eq $TeamsAppPermissionPolicy)) -or (!($_.TeamsAppSetupPolicy -eq $TeamsAppSetupPolicy) -and ($_.TeamsAppPermissionPolicy -eq $TeamsAppPermissionPolicy)) -or (($_.TeamsAppSetupPolicy -eq $TeamsAppSetupPolicy) -and !($_.TeamsAppPermissionPolicy -eq $TeamsAppPermissionPolicy)))
        {
            $AccountsToCheck += @($_)
        }
    }
}

else {
    $sfbUsers | ForEach-Object {
        if((!($_.TeamsAppSetupPolicy -eq $TeamsAppSetupPolicy) -and !($_.TeamsAppPermissionPolicy -eq $TeamsAppPermissionPolicy)))
        {
            $AccountsToCheck += @($_)
        }
    }
}

$AssigmentTeamsAppSetupPolicy = 0
$AssigmentTeamsAppPermissionPolicy = 0
$RemovedTeamsAppSetupPolicy = 0
$RemovedTeamsAppPermissionPolicy = 0

#Assignes Teams App Setup and Permission Policy to User Accounts that are into the group
$GroupMembers | ForEach-Object { 
    If($AccountsToCheck.UserPrincipalName -contains $_) 
    {
        If($TeamsAppSetupPolicy -ne "none")
        {
            Grant-CsTeamsAppSetupPolicy -PolicyName $TeamsAppSetupPolicy -Identity $_ | Out-Null
            $AssigmentTeamsAppSetupPolicy++
        }
        If($TeamsAppPermissionPolicy -ne "none")
        {
            Grant-CsTeamsAppPermissionPolicy -PolicyName $TeamsAppPermissionPolicy -Identity $_ | Out-Null
            $AssigmentTeamsAppPermissionPolicy++
        }
        If($TeamsAppSetupPolicy -eq "none")
        {
            Grant-CsTeamsAppSetupPolicy -PolicyName $null -Identity $_ | Out-Null
            $RemovedTeamsAppSetupPolicy++
        }
        If($TeamsAppPermissionPolicy -eq "none")
        {
            Grant-CsTeamsAppPermissionPolicy -PolicyName $null -Identity $_ | Out-Null
            $RemovedTeamsAppPermissionPolicy++
        }
    }
}

Write-Output "Assigment App Setup Policys:          $AssigmentTeamsAppSetupPolicy"
Write-Output "Assigment App Permission Policys:     $AssigmentTeamsAppPermissionPolicy"

#Removes App Setup and Permission Policy for User Accounts that are not group members
$NoMembers | ForEach-Object {

    If($_.TeamsAppSetupPolicy -contains $TeamsAppSetupPolicy -and $_.TeamsAppPermissionPolicy -contains $null) 
    {
        Grant-CsTeamsAppSetupPolicy -PolicyName $null -Identity $_.UserPrincipalName | Out-Null
        $RemovedTeamsAppSetupPolicy++
    }
    If($_.TeamsAppPermissionPolicy -contains $TeamsAppPermissionPolicy -and $_.TeamsAppSetupPolicy -contains $null) 
    {
        Grant-CsTeamsAppPermissionPolicy -PolicyName $null -Identity $_.UserPrincipalName | Out-Null
        $RemovedTeamsAppPermissionPolicy++
    }
    If($_.TeamsAppPermissionPolicy -contains $TeamsAppPermissionPolicy -and $_.TeamsAppSetupPolicy -contains $TeamsAppSetupPolicy) 
    {
        Grant-CsTeamsAppSetupPolicy -PolicyName $null -Identity $_.UserPrincipalName | Out-Null
        Grant-CsTeamsAppPermissionPolicy -PolicyName $null -Identity $_.UserPrincipalName | Out-Null
        $RemovedTeamsAppSetupPolicy++
        $RemovedTeamsAppPermissionPolicy++
    }

}

Write-Output ""
Write-Output "Removed App Setup Policies:            $RemovedTeamsAppSetupPolicy"
Write-Output "Removed App Permission Policies:       $RemovedTeamsAppPermissionPolicy"
Write-Output ""
Write-Output "========================================================"
Write-Output " Script Info"
Write-Output "========================================================"
Write-Output ""
Write-Output "Author:       Igor Hensch"
Write-Output "Version:      2.0"
Write-Output "Last Update:  07.11.2020"