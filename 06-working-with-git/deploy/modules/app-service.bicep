@description('The Azure region into which resources should be deployed.')
param location string

@description('The type of environment into which resources should be deployed.')
@allowed([
  'nonprod'
  'prod'
])
param environmentType string

@description('The globally unique name of the App Service app.')
param appServiceAppName string 

var appServicePlanName = 'asp-toy-website'
var appServicePlanSkuName = (environmentType == 'prod') ? 'P2v3' : 'F1'
var appServicePlanTierName = (environmentType == 'prod') ? 'PremiumV3' : 'Free'

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
    tier: appServicePlanTierName
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
