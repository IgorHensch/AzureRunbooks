param (
    [Parameter (Mandatory = $false)]
    [object] $WebHookData
)

if ($WebhookData)
{

    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    # Get the info needed to identify the VM (depends on the payload schema)
    $schemaId = $WebhookBody.schemaId
   
    if ($schemaId -eq "azureMonitorCommonAlertSchema") {
        # This is the common Metric Alert schema (released March 2019)
        $Essentials = [object] ($WebhookBody.data).essentials
        $AlertRule = $Essentials.alertRule 
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split("/")
        $SubId = ($alertTargetIdArray)[2]
        $ResourceGroupName = ($alertTargetIdArray)[4]
        $ResourceType = ($alertTargetIdArray)[6] + "/" + ($alertTargetIdArray)[7]
        $ResourceName = ($alertTargetIdArray)[-1]
        $status = $Essentials.monitorCondition
    }
    elseif ($schemaId -eq "AzureMonitorMetricAlert") {
        # This is the near-real-time Metric Alert schema
        $AlertContext = [object] ($WebhookBody.data).context
        $AlertRule = $AlertContext.alertRule 
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq "Microsoft.Insights/activityLogs") {
        # This is the Activity Log Alert schema
        $AlertContext = [object] (($WebhookBody.data).context).activityLog
        $AlertRule = $AlertContext.alertRule
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = (($AlertContext.resourceId).Split("/"))[-1]
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq $null) {
        # This is the original Metric Alert schema
        $AlertContext = [object] $WebhookBody.context
        $AlertRule = $AlertContext.alertRule
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = $WebhookBody.status
    }
    else {
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }

    $Body = @"
    {
        "@context": "https://schema.org/extensions",
        "@type": "MessageCard",
        "themeColor": "0072C6",
        "title": "$($AlertRule)",
        "text": "$($ResourceType) $($status)",
        "sections": [{
            "facts": [{
                "name": "SubId",
                "value": "$($SubId)"
            }, {
                "name": "Resource Group Name",
                "value": "$($ResourceGroupName)"
            }, {
                "name": "Resource Type",
                "value": "$($ResourceType)"
            }, {
                "name": "Resource Name",
                "value": "$($ResourceName)"
            }, {
                "name": "Status",
                "value": "$($status)"
            }],
            "markdown": true
        }],
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

    Write-output $Body
    Invoke-WebRequest `
        -Uri "<TeamsWebHookConnectorUri>" `
        -Method POST `
        -Body $Body `
        -UseBasicParsing | Out-Null
}