$FilePath = "$($env:TEMP)\QuotaExport.csv"

$VerbosePreference = "SilentlyContinue"

$QuotasAll = @()

#Get Azure Module Version
$AzureModuleVersion = (Get-Module -Name "AzureRM" -ListAvailable).Version
Write-Verbose "Azure Version: $($AzureModuleVersion.Major)"
switch ($AzureModuleVersion.Major) {
    {$_ -ge 4} {
        $SubIdVar = "Id"
        $SubNameVar = "Name"
        break}
    {$_ -lt 4} {
        $SubIdVar = "SubscriptionId"
        $SubNameVar = "SubscriptionName"
        break}
}

$Locations = Get-AzureRmLocation | Select DisplayName, Location | Sort-Object "Location" | Out-GridView -Title "Select Location(s) (Ctrl/Shift click for multiples)" -PassThru 
$Locations.Location 

$SelectedSubscriptions = @()
$SelectedSubscriptions = Get-AzureRmSubscription | Select "$($SubNameVar)", "$($SubIdVar)" | Out-GridView -Title "Select Subscriptions (Ctrl/Shift click for multiples)" -PassThru 


foreach ($Sub in $SelectedSubscriptions) {
    Write-Output $Sub.SubscriptionName
    
    $SubDet = Select-AzureRmSubscription -SubscriptionId $Sub.$SubIdVar
    $AllResources = Get-AzureRmResource | Where-Object {$_.location -in $Locations.Location} 
    $ResLocns = $AllResources.Location | Sort-Object -Unique
    foreach ($VNetLocn in $ResLocns) {
        Write-Output "`t$($VNetLocn)"
                
        $Locn = $Locations | Where-Object {$_.Location -eq $VNetLocn}

        $ResourceProviders = Get-AzureRmResourceProvider -ListAvailable -Location $Locn.Location  | Where-Object {$_.RegistrationState -eq "Registered"}
        
        foreach ($ResProv in $ResourceProviders.ProviderNamespace) {
            #$ResType
            $ResSummary.TypeNames
            $ResSummary = $AllResources | Where-Object {$_.ResourceType -like "$($ResProv)*" -and $_.Location -eq $Locn.Location}
            $ResourceTypes = $ResSummary.ResourceType | Sort-Object -Unique
            foreach ($ResType in $ResourceTypes) {
                write-output "`t`t$($ResType)"
                $ResCount = ($ResSummary | Where-Object {$_.ResourceType -eq $ResType}).count
                if ($ResCount -eq $null) {
                    $ResCount = 1
                }

                $ResourceInfo = [pscustomobject]@{
                    'SubscriptionName'=$Sub.$SubNameVar
                    'SubscriptionId'=$Sub.$SubIdVar
                    'Location'=$Locn.DisplayName
                    'LocalizedName'=$ResProv
                    'Name'=$ResType
                    'CurrentValue' = $ResCount
                    'Limit' = 0
                }
                $QuotasAll += $ResourceInfo

            }
        }
        
        $Quotas = Get-AzureRmVMUsage -Location $Locn.Location
        write-output "`t`tVMs"
        foreach ($Quota in $Quotas) {
            $QuotaInfo = [pscustomobject]@{
                'SubscriptionName'=$Sub.$SubNameVar
                'SubscriptionId'=$Sub.$SubIdVar
                'Location'=$Locn.DisplayName
                'LocalizedName'=$Quota.Name.LocalizedValue
                'Name'=$Quota.Name.Value
                'CurrentValue' = $Quota.CurrentValue
                'Limit' = $Quota.Limit
            }
            $QuotasAll += $QuotaInfo
        }
        
    }
    write-output "`tStorage"
    $StorQuota = Get-AzureRmStorageUsage
    $QuotaInfo = [pscustomobject]@{
        'SubscriptionName'=$Sub.$SubNameVar
        'SubscriptionId'=$Sub.$SubIdVar
        'Location'="N/A"
        'LocalizedName'=$StorQuota.LocalizedName
        'Name'=$StorQuota.Name
        'CurrentValue' = $StorQuota.CurrentValue
        'Limit' = $StorQuota.Limit
    }
    $QuotasAll += $QuotaInfo

}
$QuotasAll | Export-Csv -Path $FilePath -NoTypeInformation -Force
Invoke-Item $FilePath