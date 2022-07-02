@description('The Azure region into which resource should be deployed.')
param location string

@description('The name of the App Service App.')
param appServiceAppName string

@description('The name of the App Service Plan.')
param appServicePlanName string

@description('The name of the App Service Plan SKU.')
param appServicePlanSkuName string

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
  }
}

resource appServiceApp 'Microsoft.Web/sites@2021-03-01' = {
  name: appServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
  }
}

@description('The default host name of the App Service App.')
output appServiceAppHostName string = appServiceApp.properties.defaultHostName
