<#
.SYNOPSIS
Script para gerar planilha excel com detalhes sobre para FINOPS.

Prerequesitos
Ter o os modulos Az e Import-Excel

Para instalar rode os comandos abaixo
Install-Module Az
Install-Module ImportExcel

.Description
Esse script gera um excel com detalhes de:
    1 - APIM
    2 - APP Services
    3 - APP Service Plan

Criado por Gianlucas Almeida
4MSTech

.PARAMETER Scope
Informe o escopo onde o script será rodado

VALORES:
All - Rodara o Script em todos os Tenants e Subscriptions.
Tenant - Rodara o script em todas as Subscriptions do Tenant.
Subscription - Rodara o script em um Subscription.
#>

#Dependeces
#Install-Module Az.Reservations -Force
#Install-Module Az.Advisor -Force
#Install-Module Az.Context -Force
#Azure CLI

# Regular expression pattern for subscription names
$RegexSubscription = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"

# Global Array to store Azure resource groups
$Global:AzureResourceGroups = @()

# Global variables for dates
$global:DateLast30Days = (get-date).AddDays(-30)
$global:DateToday = Get-Date

# Arrays to store different types of resources
$global:APIMS = @()
$global:APPServices = @()
$global:AppServicePlans = @()
$global:CosmoDBs = @()
$global:VMs = @()

$global:ProgressPreference = "SilentlyContinue"
$global:i = 0

$ExcelParams = @{
    Path      = 'C:\Temp\Finops.xlsx'
    Show      = $false
    Verbose   = $false
}
Function Write-Logo {
    Clear-Host

    # Define the cursor icon
    $CursorIcon = [System.Convert]::toInt32("27A1", 16)  # Unicode code point for the cursor icon
    $CursorIcon = [System.Char]::ConvertFromUtf32($CursorIcon)  # Convert the code point to a character

    # Define the money icon
    $MoneyIcon = [System.Convert]::toInt32("1F4B8", 16)  # Unicode code point for the money icon
    $MoneyIcon = [System.Char]::ConvertFromUtf32($MoneyIcon)  # Convert the code point to a character

    # Define the cloud icon
    $CloudIcon = [System.Convert]::toInt32("2601", 16)  # Unicode code point for the cloud icon
    $CloudIcon = [System.Char]::ConvertFromUtf32($CloudIcon)  # Convert the code point to a character

    # Define the logo string
    $logo = "     _     _____     _____ _                       
    / \   |__  /    |  ___(_)_ __   ___  _ __  ___ 
   / _ \    / /_____| |_  | | '_ \ / _ \| '_ \/ __|
  / ___ \  / /|_____|  _| | | | | | (_) | |_) \__ \
 /_/   \_\/____|    |_|   |_|_| |_|\___/| .__/|___/
               _____           _        |_|        
              |_   _|__   ___ | |                  
                | |/ _ \ / _ \| |                  
                | | (_) | (_) | |                  
                |_|\___/ \___/|_|                  
  _____ _____ _____ _____ _____ _____ _____ _____  
 |_____|_____|_____|_____|_____|_____|_____|_____| 
 $MoneyIcon   $CloudIcon     $MoneyIcon    $CloudIcon     $MoneyIcon    $CloudIcon     $MoneyIcon    $CloudIcon     $MoneyIcon
                                                   "

    # Apply the gum style to the logo
    gum style --foreground 6 --border-foreground 212 --border rounded --bold --align center --width 70 --margin "0 10" --padding "1 2" $logo

}
function Update-ProgressBar {
    param(
        [int] $PercentComplete
    )

    $progressBarWidth = 50
    $completedLength = [math]::Ceiling($progressBarWidth * ($PercentComplete / 100))
    $remainingLength = $progressBarWidth - $completedLength
    $progressBar = ('#' * $completedLength) + ('-' * $remainingLength)

    Write-Host -NoNewline "`r[$progressBar] $PercentComplete%"
}
Function Set-Login {
    # Get the current login ID from the Azure context
    $loginId = Get-AzContext | Select-Object Account

    # Prompt the user to enter their login ID
    $loginId = gum input --value $loginId.Account --header "Please provide your loginId:" --placeholder "Email or UPN" --header.foreground="2"

    # Try to connect to Azure using the provided login ID
    try {
        Connect-AzAccount -AccountId $loginId -WarningAction SilentlyContinue -ErrorAction Stop
        az login --only-show-errors | Out-Null
    }
    catch {
        # If the login fails, display an error message and prompt the user to try again
        Write-Host "Login Failed, please try again" -ForegroundColor Red
        Set-Login
    }
}
Function Get-AllAzTenants {
    # Get all Azure tenants and store them in the global variable $AzTenants
    $global:AzTenants = Get-AzTenant -WarningAction SilentlyContinue
}
Function Get-AllAzSubscriptions {
    # Retrieve Azure subscriptions
    $global:AzSubscriptions = Get-AzSubscription -WarningAction SilentlyContinue
}
Function Set-SelectedAzSubscriptions {
    # Prompt the user to select a subscription
    $global:SelectedSubscriptions = gum choose --no-limit $AzSubscriptions.Name --header "Select the Subscription:" --cursor "$CursorIcon  " --cursor-prefix="[ ] " --selected-prefix="[X] " --unselected-prefix="[ ] "

    # Check if a subscription was selected
    if ($null -eq $SelectedSubscriptions) {
        # If no subscription was selected, display an error message
        Write-Host "No Subscription Selected!" -ForegroundColor Red
        Clear-Host
        Main
    }
}
Function Get-APIMs {
    
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $SubscriptionName
    )

    # Define the APIM class
    class APIM {
        [string]$Name
        [string]$ResourceGroupName
        [string]$SubscriptionId
        [string]$SubscriptionName
        [string]$SKU
        [string]$Location
        [string]$Requests
        [string]$Id
    }

    # Get the Azure API Management instances
    $AzureAPIMS = Get-AzApiManagement | Select-Object Name, ResourceGroupName, SKU, Location, Id

    # Count the number of APIM instances
    $APIMcount = $AzureAPIMS | Measure-Object
    $APIMcount = $APIMcount.Count

    # Display the number of APIM instances found
    Write-Host "Numero de APIM encontradas na subscription " -NoNewline -f White ; Write-Host $SubscriptionName -NoNewline -f Green ; Write-Host ':'$APIMcount -ForegroundColor Yellow

    # Iterate through each APIM instance
    foreach ($AP in $AzureAPIMS) {
        # Create an instance of the APIM class
        [APIM]$APIM = [APIM]::new()
    
        # Set the properties of the APIM instance
        $APIM.Name = $AP.Name
        $APIM.ResourceGroupName = $AP.ResourceGroupName
        $APIM.SubscriptionId = $AP.Id
        $APIM.SubscriptionId -Match $RegexSubscription | Out-Null
        $APIM.SubscriptionId = $Matches[1]
        $APIM.SubscriptionName = (Get-AzSubscription -SubscriptionID $APIM.SubscriptionId | Select-Object).Name
        $APIM.SKU = $AP.SKU
        $APIM.Location = $AP.Location
        $APIM.Id = $AP.Id
    
        # Get the APIM metrics for the "Requests" metric
        $APIMMetricas = Get-AzMetric -ResourceId $AP.ID -MetricName "Requests" -StartTime $DateLast30Days -EndTime $DateToday -TimeGrain 01:00:00:00 -AggregationType "Total" -WarningAction 0
    
        # Calculate the total requests for the APIM instance
        $APIMTotalRequests = $APIMMetricas.Data.Total | Measure-Object -Sum
        $APIM.Requests = $APIMTotalRequests.Sum
    
        # Add the APIM instance to the global APIMS variable
        $global:APIMS += $APIM
    }
}
Function Get-APPService {
    # Parameter help description
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $SubscriptionName
    )
    class APPService {
        [string]$Name
        [string]$ResourceGroup
        [string]$SubscriptionId
        [string]$SubscriptionName
        [string]$State
        [string]$Enabled
        [string]$Location
        [string]$Requests
        [string]$Id
    }
    #$APPServices = @()  
    $AzureAppServices = Get-AzWebApp | Select-Object Name, ResourceGroup, State, Enabled, Location, Id

    #Contar AppService
    $AppServicecount = $AzureAppServices | Measure-Object
    $AppServicecount = $AppServicecount.Count
    Write-Host "Numero de APP Service encontradas na subscription " -NoNewline -f White ; Write-Host $SubscriptionName -NoNewline -f Green ; Write-Host ':'$AppServicecount -ForegroundColor Yellow
    

    Foreach ($APPSer in $AzureAppServices) {
        [APPService]$APPService = [APPService]::new()
        $APPService.Name = $APPSer.Name
        $APPService.ResourceGroup = $APPSer.ResourceGroup
        $APPService.SubscriptionId = $APPSer.Id
        $APPService.SubscriptionId -Match $RegexSubscription | Out-Null
        $APPService.SubscriptionId = $Matches[1]
        $APPService.SubscriptionName = (Get-AzSubscription -SubscriptionID $APPService.SubscriptionId | Select-Object).Name
        $APPService.State = $APPSer.State
        $APPService.Enabled = $APPSer.Enabled
        $APPService.Location = $APPSer.Location
        $APPService.Id = $APPSer.Id
        $AppServiceMetricas = Get-AzMetric -ResourceId $APPSer.ID -MetricName "Requests" -StartTime $DateLast30Days -EndTime $DateToday -TimeGrain 01:00:00:00  -AggregationType "Total" -WarningAction 0
        $AppServiceTotalRequets = $AppServiceMetricas.Data.Total | Measure-Object -Sum
        $APPService.Requests = $AppServiceTotalRequets.Sum 
        $global:AppServices += $APPService
    }
}
Function Get-AppServicePlan {
    # Parameter help description
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $SubscriptionName
    )
    class AppServicePlan {
        [string]$Name
        [string]$ResourceGroup
        [string]$SubscriptionId
        [string]$SubscriptionName
        [string]$NumberOfSites
        [string]$Status
        [string]$SKU
        [string]$Tier
        [string]$Location
        [string]$Id
    }
    #$AppServicePlans = @()
    $AzureAppServicePlans = Get-AzAppServicePlan | Select-Object Name, ResourceGroup, NumberOfSites, Status, SKU, Location, Id
    
    #Contar AppServicePlan
    $AppServicePlancount = $AzureAppServicePlans | Measure-Object
    $AppServicePlancount = $AppServicePlancount.Count
    Write-Host "Numero de APP Service Plan encontradas na subscription " -NoNewline -f White ; Write-Host $SubscriptionName -NoNewline -f Green ; Write-Host ':'$AppServicePlancount -ForegroundColor Yellow
        
    Foreach ($APS in $AzureAppServicePlans) {
        [AppServicePlan]$AppServicePlan = [AppServicePlan]::new()
        $AppServicePlan.Name = $APS.Name
        $AppServicePlan.ResourceGroup = $APS.ResourceGroup
        $APPServicePlan.SubscriptionId = $APS.Id
        $APPServicePlan.SubscriptionId -Match $RegexSubscription | Out-Null
        $APPServicePlan.SubscriptionId = $Matches[1]
        $APPServicePlan.SubscriptionName = (Get-AzSubscription -SubscriptionID $APPServicePlan.SubscriptionId | Select-Object).Name
        $AppServicePlan.NumberOfSites = $APS.NumberOfSites
        $AppServicePlan.Status = $APS.Status
        $AppServicePlan.SKU = $APS.SKU.Name
        $AppServicePlan.Tier = $APS.SKU.Tier
        $AppServicePlan.Location = $APS.Location
        $AppServicePlan.Id = $APS.Id
        $global:AppServicePlans += $AppServicePlan
    }
}
Function Get-StartStopVMs {
    # Parameter help description
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $SubscriptionName
    )
    class VM {
        [string]$Name
        [string]$VmSize
        [string]$OsType
        [string]$LicenseType
        [string]$ResourceGroupName
        [string]$SubscriptionId
        [string]$SubscriptionName
        [string]$Location
        [string]$PowerState
        [string]$Tags
        [string]$Id
    }
    $AzureVMs = Get-AzVM -status | Select-Object Name, HardwareProfile, StorageProfile, Licensetype, ResourceGroupName, Location, PowerState, Tags, Id
    $VMcount = $AzureVMs | Measure-Object
    $VMcount = $VMcount.Count
    Write-Host "Numero de VM encontradas na subscription " -NoNewline -f White ; Write-Host $SubscriptionName -NoNewline -f Green ; Write-Host ':'$VMcount -ForegroundColor Yellow

    Foreach ($AVM in $AzureVMs) {
        [VM]$VM = [VM]::new()
        $VM.Name = $AVM.Name
        $VM.VmSize = $AVM.HardwareProfile.VmSize
        $VM.OsType = $AVM.StorageProfile.ImageReference.Publisher
        $VM.LicenseType = $AVM.LicenseType
        $VM.ResourceGroupName = $AVM.ResourceGroupName
        $VM.Location = $AVM.Location
        $VM.PowerState = $AVM.PowerState
        #Verificando TAG de Start/Stop
        [Hashtable]$VMTag = $AVM.Tags
        foreach ($h in $VMTag.GetEnumerator()) {
            if (($h.Name -eq "StartWorkday") -or ($h.Name -eq "StartWeekend")) {   
                Write-Host $h.Name
                $AVM.Tags = "Com Tag de START/STOP"
            }
        }
        if ($AVM.Tags -ne "Com Tag de Start/Stop") {
            $AVM.Tags = "Sem Tag de START/STOP"
        }
        $VM.Tags = $AVM.Tags
        $VM.Id = $AVM.Id
        $VM.SubscriptionId = $AVM.Id
        $VM.SubscriptionId -Match $RegexSubscription | Out-Null
        $VM.SubscriptionId = $Matches[1]
        $VM.SubscriptionName = (Get-AzSubscription -SubscriptionID $VM.SubscriptionId | Select-Object).Name
        $global:VMs += $VM
    }
}
Function Get-CosmoDBs {
    $AzureCosmoDBs = @()
    Foreach ($AzureResourceGroup in $AzureResourceGroups) {
        $AzureCosmoDBs += Get-AzCosmosDBAccount -ResourceGroupName $AzureResourceGroup.ResourceGroupName
    }

    #Contar CosmoDBs
    $CosmoDBcount = $AzureCosmoDBs | Measure-Object
    $CosmoDBcount = $CosmoDBcount.Count
    Write-Host "Numero de CosmoDB encontrados na subscription " -NoNewline -f White ; Write-Host $AzureSubscription.Name -NoNewline -f Green ; Write-Host ':'$CosmoDBcount -ForegroundColor Yellow


    #$CosmoDBs = @()
    class CosmoDb {
        [string]$Name
        [string]$Location
        [string]$SubscriptionId
        [string]$SubscriptionName
        [string]$ResourceGroup
        [string]$DatabaseAccountOfferType
        [string]$Kind
        [string]$IsServerless
        [string]$Requests
        [String]$Id
    }
    Foreach ($CDB in $AzureCosmoDBs) {
        [CosmoDb]$CosmoDB = [CosmoDb]::new()
        $CosmoDB.Name = $CDB.Name
        $CosmoDB.Location = $CDB.Location
        $CosmoDB.DatabaseAccountOfferType = $CDB.DatabaseAccountOfferType
        $CosmoDB.Kind = $CDB.Kind
        if ($CDB.Capabilities.Name -eq "EnableServerless") {
            $CosmoDB.IsServerless = 'True'
        }
        else {
            $CosmoDB.IsServerless = 'False'
        }
        $CosmoDBsMetrics = Get-AzMetric -ResourceId $CDB.Id -MetricName "TotalRequests" -StartTime $DateLast30Days -EndTime $DateToday -TimeGrain 01:00:00:00 -AggregationType "Count" -WarningAction 0
        $CosmoDBMetricsCount = $CosmoDBsMetrics.Data | Select-Object Count
        $CosmoDB.Requests = ($CosmoDBMetricsCount | ForEach-Object Count | Measure-Object -Sum).Sum
        $CosmoDB.Id = $CDB.Id
        $CosmoDB.SubscriptionId = $CDB.Id
        $CosmoDB.SubscriptionId -Match $RegexSubscription | Out-Null
        $CosmoDB.SubscriptionId = $Matches[1]
        $CosmoDB.SubscriptionName = (Get-AzSubscription -SubscriptionID $CosmoDB.SubscriptionId | Select-Object).Name
        $CosmoDB.ResourceGroup = $CDB.Id
        $CosmoDB.ResourceGroup -Match $RegexRG | Out-Null
        #Write-host $Matches
        $CosmoDB.ResourceGroup = $Matches[0]
        $global:CosmoDBs += $CosmoDB
    }
}
Function Get-CosmoDBsThroughput {

    $CosmoDBAccountNames = $CosmoDBs | Where-Object IsServerless -eq "False"
    class CosmoDbDatabase {
        [string]$Database
        [string]$AccountName
        [string]$Throughput
        [string]$Type
    }

    Foreach ($CDBAN in $CosmoDBAccountNames) {
        [CosmoDbDatabase]$CosmoDbDatabase = [CosmoDbDatabase]::new()
        $CosmoDbDatabase.AccountName = $CDBAN.Name
        
        $CosmosDbContext = New-CosmosDbContext -Account $CDBAN.Name -ResourceGroupName $CDBAN.ResourceGroup -MasterKeyType 'SecondaryMasterKey' -erroraction 'silentlycontinue'

        $CDDatabase = Get-CosmosDbDatabase -Context $CosmosDbContext -erroraction "silentlycontinue" | ForEach-Object {
            $CosmoDbDatabase.Database = $_.Id

            $CDDatabaseTroughput = Get-CosmosDbOffer -Context $CosmosDbcontext
            $CosmoDbDatabase.Throughput = $CDDatabaseTroughput.content.offerThroughput
    
            $CosmoDbDatabase.Type = $CDDatabaseTroughput.content.offerIsRUPerMinuteThroughputEnabled
            if ($CosmoDbDatabase.Type -eq "False") {
                $CosmoDbDatabase.Type = "Manual"
            }
            else {
                $CosmoDbDatabase.Type = "AutoScale"
            }
            $global:CosmoDbDatabases += $CosmoDbDatabase
        }
    
    }
}
Function ExportTo-Excel {
    Param(
        [Parameter()]
        [array]$Table,
        [string]$WorkSheetName
    )
    switch ($WorkSheetName) {
        'API Management' {
            $ConditionalText = $(
                New-ConditionalText -ConditionalType LessThanOrEqual 0 DarkRed LightPink
            )
        }
        'App Services' {
            $ConditionalText = $(
                New-ConditionalText -ConditionalType LessThanOrEqual 0 DarkRed LightPink
            )
        }
        'App Service Plan' {
            $ConditionalText = $(
                New-ConditionalText -ConditionalType LessThanOrEqual 0 DarkRed LightPink
            )
        }
        'CosmoDB' {
            $ConditionalText = $(
                New-ConditionalText -ConditionalType LessThanOrEqual 0 DarkRed LightPink
            )
        }
        "Virtual Machines" { 
            $ConditionalText = $(
                New-ConditionalText -ConditionalType LessThanOrEqual 0 DarkRed LightPink
                New-ConditionalText -ConditionalType Equal "Sem Tag de START/STOP" DarkRed LightPink
                New-COnditionalText -ConditionalType Equal "Com Tag de START/STOP" White Green
            )
        }
        "Recommendations" {
            $ConditionalText = $(
                New-ConditionalText -ConditionalType LessThanOrEqual 0 DarkRed LightPink
            )
        }

    }
    $Table | Export-Excel @ExcelParams -WorksheetName $WorkSheetName -AutoSize -ConditionalText $ConditionalText -erroraction 'silentlycontinue'
}
Function Get-AdvisorCostRecommendations {
    # $global:AzureAdvisorRecommendations = @()
    # $global:AzureAdvisorRecommendations = Get-AzAdvisorRecommendation | Where-Object {$_.Category -eq "Cost"} | Select-Object ImpactedValue, ShortDescriptionSolution, LastUpdated

    # class Recommendation {
    #     [string]$ImpactedValue
    #     [string]$ShortDescriptionSolution
    #     [string]$LastUpdated
    # }
    # $global:Recomendations = @()
    # Foreach ($AzureRecommendation in $AzureAdvisorRecommendations) {
    #     [Recommendation]$Recommendation = [Recommendation]::new()
    #     $Recommendation.ImpactedValue = $AzureRecommendation.ImpactedValue
    #     $Recommendation.ShortDescriptionSolution = $AzureRecommendation.ShortDescriptionSolution
    #     $Recommendation.LastUpdated = $AzureRecommendation.LastUpdated
    #     $global:Recomendations += $Recommendation
    
    # $filter = "serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_D4' and armRegionName eq 'southcentralus'"
    # $PriceUri = "https://prices.azure.com/api/retail/prices?$filter"
    # $Items = Invoke-WebRequest -Uri $PriceUri

    
    $AzureRecommendations = az advisor recommendation list
    $AzureRecommendations = $AzureRecommendations | ConvertFrom-Json
    $AzureRecommendations = $AzureRecommendations | Where-Object {$_.category -eq "Cost"}

    class Recommendation {
        [string]$ImpactedField
        [string]$ImpactedValue
        [string]$ActualSKU
        [string]$RegionId
        [string]$ShortDescriptionProblem
        [string]$ShortDescriptionSolution
        [string]$AnnualSavingsAmount
        [string]$RecommendationType
        [string]$TargetSku
        [string]$QtyRI
        [string]$RI
        [string]$LastUpdated
    }
    $global:Recommendations = @()
    Foreach ($AzureRecommendation in $AzureRecommendations) {
        [Recommendation]$Recommendation = [Recommendation]::new()
        $Recommendation.ImpactedField = $AzureRecommendation.ImpactedField
        $Recommendation.ImpactedValue = $AzureRecommendation.ImpactedValue
        $Recommendation.ActualSKU = $AzureRecommendation.extendedProperties.DisplaySKU
        $Recommendation.RegionId = $AzureRecommendation.extendedProperties.RegionId
        $Recommendation.ShortDescriptionProblem = $AzureRecommendation.ShortDescription.Problem
        $Recommendation.ShortDescriptionSolution = $AzureRecommendation.ShortDescription.Solution
        $Recommendation.AnnualSavingsAmount = "$($AzureRecommendation.extendedProperties.savingsCurrency) $($AzureRecommendation.extendedProperties.AnnualSavingsAmount)"
        $Recommendation.RecommendationType = $AzureRecommendation.extendedProperties.RecommendationType
        $Recommendation.TargetSku = $AzureRecommendation.extendedProperties.TargetSku
        $Recommendation.QtyRI = $AzureRecommendation.extendedProperties.displayQty
        $Recommendation.RI = $AzureRecommendation.extendedProperties.term
        $Recommendation.LastUpdated = $AzureRecommendation.LastUpdated
        $global:Recommendations += $Recommendation
    }
}
Function Main {
    Write-Logo
    Set-Login
   
    # Prompt the user to select the scope
    $SelectedScope = gum choose Tenant Subscription --header "Select the Scope:" --cursor "$CursorIcon  "
   
    switch ($SelectedScope) {
        'Tenant' {
            # Get all Azure tenants
            Get-AllAzTenants
   
            # Prompt the user to select a tenant
            $SelectedTenant = gum choose $AzTenants.Name --header "Select the Tenant:" --cursor "$CursorIcon  "  --header.foreground="212"
            #Set-AzContext -Tenant $SelectedTenant -WarningAction SilentlyContinue | Out-Null
            # Get all Azure subscriptions
            Get-AllAzSubscriptions
   
            # Loop through each subscription and perform actions
            Foreach ($AzSubscription in $AzSubscriptions) {
                $i++
                Set-AzContext -Subscription $AzSubscription.ID -WarningAction SilentlyContinue | Out-Null

                Get-APIMs -SubscriptionName $AzSubscription.Name
                Get-AppService -SubscriptionName $AzSubscription.Name
                Get-AppServicePlan -SubscriptionName $AzSubscription.Name
                Get-StartStopVMs -SubscriptionName $AzSubscription.Name
                Get-AdvisorCostRecommendations

                Write-Host
                $percentage = ($i / $AzSubscriptions.Count) * 100
                Update-ProgressBar -PercentComplete $percentage
                Write-Host
               
                #Start-Sleep -Seconds 1
            }
   
            # Export data to Excel for each resource type
            ExportTo-Excel $APIMS 'API Management'
            ExportTo-Excel $APPServices 'App Services'
            ExportTo-Excel $AppServicePlans 'App Service Plan'
            #ExportTo-Excel $CosmoDBs 'CosmoDB'
            ExportTo-Excel $VMs 'Virtual Machines'
            ExportTo-Excel $Recommendations 'Recommendations'
        }
        'Subscription' {
            # Get all Azure subscriptions
            Get-AllAzSubscriptions
   
            # Set the selected subscriptions
            Set-SelectedAzSubscriptions
   
            Write-Host "Getting APIMS..." -ForegroundColor Yellow
   
            # Loop through each selected subscription and perform actions
            Foreach ($AzSubscription in $SelectedSubscriptions) {
                Set-AzContext -Subscription $AzSubscription -WarningAction SilentlyContinue | Out-Null
                Get-APIMs -SubscriptionName $AzSubscription
                Get-AppService -SubscriptionName $AzSubscription
                Get-AppServicePlan -SubscriptionName $AzSubscription
                Get-StartStopVMs -SubscriptionName $AzSubscription
                Get-AdvisorCostRecommendations
            }
   
            # Export data to Excel for each resource type
            ExportTo-Excel $APIMS 'API Management'
            ExportTo-Excel $APPServices 'App Services'
            ExportTo-Excel $AppServicePlans 'App Service Plan'
            #ExportTo-Excel $CosmoDBs 'CosmoDB'
            ExportTo-Excel $VMs 'Virtual Machines'
            ExportTo-Excel $Recommendations 'Recommendations'
        }
    }
}
Main



# #Chartting
# $StartDate = $(Get-Date).AddDays(-1)
# $EndDate = Get-Date
# $Data = $null
# $Datapoints = $null
# $ResourceId = "/subscriptions/18f066b4-b8f0-42d0-8a25-547d797ab539/resourceGroups/RG-PRD/providers/Microsoft.Compute/virtualMachines/vm-lprd1"
# $Data = Get-AzMetric -ResourceId $ResourceID -AggregationType "Max" -MetricName "Percentage CPU" -TimeGrain 00:15:00 -StartTime $StartDate -EndTime $EndDate -ResultType Data| Select-Object unit, data
# $Datapoints = $Data.data.maximum.foreach({[int]$_})

# Show-Graph -Datapoints $Datapoints -GraphTitle 'CPU (% age)'cc