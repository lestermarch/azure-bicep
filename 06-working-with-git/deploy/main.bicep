@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('The type of environment into which the resources should be deployed.')
@allowed([
  'nonprod'
  'prod'
])
param environmentType string

@description('The globally unique name of the App Service app.')
param appServiceAppName string = 'toyweb-${uniqueString(resourceGroup().id)}'

module appService 'modules/app-service.bicep' = {
  name: 'app-service'
  params: {
    appServiceAppName: appServiceAppName
    environmentType: environmentType
    location: location
  }
}
