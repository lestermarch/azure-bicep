@description('Specifies the name of the App Service.')
param appServiceAppName string

@allowed([
  'nonprod'
  'prod'
])
@description('Specifies the type of environment to deploy into.')
param environmentType string 

@description('Specifies the region to deploy into.')
param location string = resourceGroup().location

var uniqueId              = uniqueString(resourceGroup().id)
var appServicePlanName    = 'asp-${uniqueId}'
var appServicePlanSkuName = (environmentType == 'prod') ? 'P2v3' : 'F1'

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

output appServiceAppHostName string = appServiceApp.properties.defaultHostName
