/*==============================================
  Parameters
==============================================*/
@description('The globally unique App Service app name.')
param appServiceAppName string = 'app-${uniqueString(resourceGroup().id)}'

@description('The environment into which resources will be deployed.')
@allowed([
  'nonprod'
  'prod'
])
param envrionemnt string = 'nonprod'

@description('The Azure region into which resources will be deployed.')
param location string = resourceGroup().location

@description('The name of the managed identity to use for this workload.')
param managedIdentityName string = 'msi-${uniqueString(resourceGroup().id)}'

@description('The administrator username for the SQL Server.')
param sqlAdministratorLogin string

@description('The administrator password for the SQL Server.')
@secure()
param sqlAdministratorLoginPassword string

@description('The name of the SQL Server to be deployed for this workload.')
param sqlServerName string = 'sql-${uniqueString(resourceGroup().id)}'

@description('A list of tags to be applied to each resource.')
param tags object = {
  CostCenter: 'Marketing'
  DataClassification: 'Public'
  Owner: 'WebsiteTeam'
  Environment: 'Production'
}

/*==============================================
  Variables
==============================================*/
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

@description('A list of Storage Account containers to be created for this workload.')
var productContainers = [
  'productspecs'
  'productmanuals'
]

@description('The role to be assigned to the managed identity for this workload.')
var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' 

@description('The name of the SQL Server database.')
var sqlDatabaseName = 'ToyCompanyWebsite'

@description('The connection string for the Storage Account.')
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'

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
  tags: tags

  resource blobServices 'blobServices' existing = {
    name: 'default'
  }
}

resource productStorageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = [for container in productContainers: {
  parent: storageAccount::blobServices
  name: container
}]

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
  tags: tags
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
  tags: tags
}

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2014-04-01' = {
  name: '${sqlServer.name}/AllowAllAzureIPs'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
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
  tags: tags
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
          value: storageAccountConnectionString
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
  tags: tags
}

resource appInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: 'AppInsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
  tags: tags
}

/*==============================================
  Managed Identity and Role Assignment
==============================================*/
resource managedServiceIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
  tags: tags
}

resource managedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorRoleDefinitionId, resourceGroup().id)

  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: managedServiceIdentity.properties.principalId
  }
}
