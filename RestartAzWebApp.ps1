$global:ClientTenant = ""
$global:AzWebApps = @()
Function Set-Auth {
    Connect-AzAccount -Identity
}
Function Get-AllAzSubscriptions {
    # Retrieve Azure subscriptions
    $global:AzSubscriptions = Get-AzSubscription -WarningAction SilentlyContinue | Where-Object {$_.HomeTenantId -eq "f639ddd2-dcf9-4a35-bb2f-098c2c104bdd"}
}
Function Get-AllAzWebAppsFromPlan {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $SubscriptionId
    )
    $global:AzWebApps += Get-AzWebApp | Where-Object {$_.ServerFarmId -eq $SelectedAppServicePlanId} | Select-Object Name, Id, ResourceGroup, @{Name = "SubscriptionId"; Expression = { $SubscriptionId } }
}

Function Restart-AzWebApps {
    Foreach ($AzWebApp in $AzWebApps) {
        Set-AzContext -Subscription $AzWebApp.SubscriptionId
        Restart-AzWebApp -Name $AzWebApp.Name -ResourceGroupName $AzWebApp.ResourceGroup
    }
}

Function Main {
    #Set-Auth
    
    $SelectedAppServicePlanId = "/subscriptions/5b56cd73-d3f2-4c8f-b166-6386d864081b/resourceGroups/RG-Cargon-03/providers/Microsoft.Web/serverFarms/asp-cargon-prd-01"
    Get-AllAzSubscriptions
    Foreach ($AzSubscription in $AzSubscriptions) {
        Set-AzContext $AzSubscription.Id
        Get-AllAzWebAppsFromPlan -SubscriptionId $AzSubscription.Id
        $AzWebApps
    }
    Restart-AzWebApps
}
Main