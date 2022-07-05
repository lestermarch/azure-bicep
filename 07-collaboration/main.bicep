@description('The environment into which resources will be deployed.')
@allowed([
  'nonprod'
  'prod'
])
param envrionemnt string = 'nonprod'

@description('The Azure region into which resources will be deployed.')
param location string = resourceGroup().location

@description('The administrator username for the SQL Server.')
param sqlAdministratorLogin string

@description('The administrator password for the SQL Server.')
@secure()
param sqlAdministratorLoginPassword string

@description('The name of the managed identity to use for this workload.')
param managedIdentityName string = 'msi-${uniqueString(resourceGroup().id)}'

@description('The globally unique App Service app name.')
param appServiceAppName string = 'app-${uniqueString(resourceGroup().id)}'

@description('The default Storage Account container name.')
param storageAccountContainerName string = 'productspecs'

@description('The Storage Account subcontainer name for product manuals.')
param productManualsStorageContainerName string = 'productmanuals'

@description('The App Service Plan name to be deployed for this workload.')
var appServicePlanName = 'asp-${uniqueString(resourceGroup().id)}'

@description('A map of resource configurations per environment type.')
var environmentConfigurationMap = {
  prod: {
    appServicePlan: {
      skuName: 'S1'
      instanceCount: 2
    }
    storageAccount: {
      skuName: 'Standard_GRS'
    }
    sqlDatabase: {
      skuName: 'S1'
    }
  }
  nonprod: {
    appServicePlan: {
      skuName: 'F1'
      instanceCount: 1
    }
    storageAccount: {
      skuName: 'Standard_LRS'
    }
    sqlDatabase: {
      skuName: 'Basic'
    }
  }
}

@description('The role to be assigned to the managed identity for this workload.')
var roleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor

@description('The name of the SQL Server database.')
var sqlDatabaseName = 'ToyCompanyWebsite'

@description('The name of the SQL Server to be deployed for this workload.')
var sqlServerName = 'sql-${uniqueString(resourceGroup().id)}'

@description('The Storage Account name to be used for this workload.')
var storageAccountName = 'toywebsite${uniqueString(resourceGroup().id)}'

/*==============================================
  Storage Account and Containers
==============================================*/
resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: environmentConfigurationMap[envrionemnt].storageAccount.skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }

  resource blobServices 'blobServices' existing = {
    name: 'default'
  }
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  parent: storageAccount::blobServices
  name: storageAccountContainerName
}

resource productManualsStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storageAccount.name}/default/${productManualsStorageContainerName}'
}

/*==============================================
  SQL Server and Database
==============================================*/
resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${sqlServer.name}/${sqlDatabaseName}'
  location: location
  sku: {
    name: environmentConfigurationMap[envrionemnt].sqlDatabase.skuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824
  }
}

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2014-04-01' = {
  name: '${sqlServer.name}/AllowAllAzureIPs'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
  dependsOn: [
    sqlServer
  ]
}

/*==============================================
  App Service Plan, App, and Insights
==============================================*/
resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: environmentConfigurationMap[envrionemnt].appServicePlan.skuName
    capacity: environmentConfigurationMap[envrionemnt].appServicePlan.instanceCount
  }
}

resource appServiceApp 'Microsoft.Web/sites@2020-06-01' = {
  name: appServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'StorageAccountConnectionString'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedServiceIdentity.id}': {}
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: 'AppInsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// We don't need this anymore. We use a managed identity to access the database instead.
//resource webSiteConnectionStrings 'Microsoft.Web/sites/config@2020-06-01' = {
//  name: '${webSite.name}/connectionstrings'
//  properties: {
//    DefaultConnection: {
//      value: 'Data Source=tcp:${sqlserver.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databaseName};User Id=${sqlAdministratorLogin}@${sqlserver.properties.fullyQualifiedDomainName};Password=${sqlAdministratorLoginPassword};'
//      type: 'SQLAzure'
//    }
//  }
//}

/*==============================================
  Managed Identity and Role Assignment
==============================================*/
resource managedServiceIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

resource managedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleDefinitionId, resourceGroup().id)

  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: managedServiceIdentity.properties.principalId
  }
}
