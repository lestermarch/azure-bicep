@description('Specifies the name of the App Service.')
param appServiceName string = 'app-toy-launch-${uniqueString(resourceGroup().id)}'

@allowed([
  'nonprod'
  'prod'
])
@description('Specifies the environment to deploy into.')
param environmentType string

@description('Specifies the location for resources.')
param location string = 'uksouth' //resourceGroup().location

@description('Specifies the name of the Storage Account.')
param storageAccountName string = 'toylaunch${uniqueString(resourceGroup().id)}'

@description('Selects the appropriate Storage Account SKU based on the deployment environment.')
var storageAccountSkuName = (environmentType == 'prod') ? 'Standard_GRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    location: location
    appServiceAppName: appServiceName
    environmentType: environmentType
  }
}

output appServiceAppHostName string = appService.outputs.appServiceAppHostName
