param([string]$Environment = "DEV")

$ErrorActionPreference = "Stop"
$baseName = "biztalkfile$($Environment.ToLower())"
$rgName = "rg-biztalkfile-$($Environment.ToLower())"
$location = "canadacentral"

Write-Host "rgName is $rgName" -ForegroundColor Yellow

Write-Host "Creating resources for $Environment..."

New-AzResourceGroup -Name $rgName -Location $location -Force

# Storage for Function runtime (default)
$funcStorageName = "stfunc$baseName"
Write-Host "funcStorageName is $funcStorageName" -ForegroundColor Yellow
$funcStorage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $funcStorageName -ErrorAction SilentlyContinue
if ($null -eq $funcStorage) {
    Write-Host "Storage account '$funcStorageName' not found. Creating it now..." -ForegroundColor Cyan
    
    # 2. Create the storage account
    $funcStorage = New-AzStorageAccount -ResourceGroupName $rgName -Name "stfunc$baseName" -Location $location -SkuName Standard_LRS -Kind StorageV2
                         
    Write-Host "Storage account created successfully." -ForegroundColor Green
} else {
    Write-Host "Storage account '$funcStorageName' already exists. Skipping creation." -ForegroundColor Yellow
}
$funcConn = "DefaultEndpointsProtocol=https;AccountName=stfunc$baseName;AccountKey=$((Get-AzStorageAccountKey -ResourceGroupName $rgName -Name "$funcStorageName")[0].Value);EndpointSuffix=core.windows.net"

# Storage for data File Shares
$dataStorageName = "stdata$baseName"
Write-Host "dataStorageName is $dataStorageName" -ForegroundColor Yellow
$dataStorage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $dataStorageName -ErrorAction SilentlyContinue
if ($null -eq $funcStorage) {
    Write-Host "Storage account '$dataStorageName' not found. Creating it now..." -ForegroundColor Cyan
    
    $dataStorage = New-AzStorageAccount -ResourceGroupName $rgName -Name "stdata$baseName" -Location $location -SkuName Standard_LRS -Kind StorageV2
                         
    Write-Host "Storage account created successfully." -ForegroundColor Green
} else {
    Write-Host "Storage account '$dataStorageName' already exists. Skipping creation." -ForegroundColor Yellow
}
$dataConn = "DefaultEndpointsProtocol=https;AccountName=stdata$baseName;AccountKey=$((Get-AzStorageAccountKey -ResourceGroupName $rgName -Name "$dataStorageName")[0].Value);EndpointSuffix=core.windows.net"

# File Shares
$inputName = "input"
$inputShare = Get-AzStorageShare -Context $dataStorage.Context -Name $inputName -ErrorAction SilentlyContinue
if ($null -eq $inputShare) {
    Write-Host "Share '$inputName' not found. Creating now..." -ForegroundColor Cyan
    New-AzStorageShare -Name $inputName -Context $dataStorage.Context
} else {
    Write-Host "Share '$inputName' already exists. Skipping creation." -ForegroundColor Yellow
}
$outputName = "output"
$outputShare = Get-AzStorageShare -Context $dataStorage.Context -Name $outputName -ErrorAction SilentlyContinue
if ($null -eq $outputShare) {
    Write-Host "Share '$outputShare' not found. Creating now..." -ForegroundColor Cyan
    New-AzStorageShare -Name $outputName -Context $dataStorage.Context
} else {
    Write-Host "Share '$outputName' already exists. Skipping creation." -ForegroundColor Yellow
}

# Azure App Configuration
$appConfigName = "appconfig-biztalkfile-$($Environment.ToLower())"
Write-Host "appConfigName is $appConfigName" -ForegroundColor Yellow
New-AzAppConfigurationStore -ResourceGroupName $rgName -Name $appConfigName -Location $location -Sku free
$appConfigConn = (Get-AzAppConfigurationStoreKey -ResourceGroupName $rgName -Name $appConfigName).ConnectionString[0]

# Populate settings in App Config (exact BizTalk-style)
az appconfig kv set --name $appConfigName --key InputStorageConnectionString --value $dataConn --yes
az appconfig kv set --name $appConfigName --key InputFileShareName --value "input" --yes
az appconfig kv set --name $appConfigName --key InputDirectory --value "/" --yes
az appconfig kv set --name $appConfigName --key InputFileMask --value "*.xml" --yes
az appconfig kv set --name $appConfigName --key OutputStorageConnectionString --value $dataConn --yes
az appconfig kv set --name $appConfigName --key OutputFileShareName --value "output" --yes
az appconfig kv set --name $appConfigName --key OutputDirectory --value "/" --yes
az appconfig kv set --name $appConfigName --key OutputFileNameTemplate --value "Processed_%SourceFileName%_%datetime%_%MessageID%.%Extension%" --yes

# Function App (consumption)
#
# See https://gemini.google.com/share/840fbdac7ecb
# Gemini: Summarize and list parameters for New-AzFunctionApp and give an example for pay as you go
# See https://gemini.google.com/share/7b797d53efc2
# Gemini: Summarize and list parameters for New-AzFunctionAppPlan  and give an example for pay as you go
#
#$plan = New-AzAppServicePlan -ResourceGroupName $rgName -Name "plan-biztalkfile-$($Environment.ToLower())" -Location $location -Tier Dynamic -WorkerSize ExtraSmall -Kind functionapp
#New-AzFunctionApp -ResourceGroupName $rgName -Name "func-biztalkfile-$($Environment.ToLower())" -StorageAccountName "stfunc$baseName" -Runtime dotnet-isolated -RuntimeVersion 8 -OsType Windows -PlanName $plan.Name
#$plan = New-AzFunctionAppPlan -ResourceGroupName $rgName -Name "plan-biztalkfile-$($Environment.ToLower())" -Location $location -WorkerType Linux -Sku "FC1"  # FC1 is the Flex Consumption SKU
$funcName = "func-biztalkfile-$($Environment.ToLower())"
Write-Host "funcName is $funcName" -ForegroundColor Yellow

$existingApp = Get-AzFunctionApp -ResourceGroupName $rgName -Name $funcName -ErrorAction SilentlyContinue
if ($null -eq $existingApp) {
    Write-Host "Function App '$funcName' not found. Creating it now..." -ForegroundColor Cyan
    New-AzFunctionApp -Name $funcName -ResourceGroupName $rgName -Location $location -StorageAccountName $funcStorageName -Runtime "dotnet-isolated" -RuntimeVersion 8 -FunctionsVersion 4 -OsType "Linux"
} else {
    Write-Host "Function App '$funcName' already exists. Skipping creation." -ForegroundColor Yellow
}

# Set required app settings on Function App
az functionapp config appsettings set --name $funcName --resource-group $rgName --settings `
    "AppConfigConnectionString=$appConfigConn" `
    "AzureWebJobsStorage=$funcConn" `
    "FUNCTIONS_WORKER_RUNTIME=dotnet-isolated" `
    "PollingSchedule=0 */5 * * * *" --yes

Write-Host "✅ Resources created for $Environment. Function App: func-biztalkfile-$($Environment.ToLower())"
