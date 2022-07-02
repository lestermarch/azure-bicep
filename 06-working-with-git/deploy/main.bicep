@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('The type of environment into which the resources should be deployed.')
@allowed(
  'nonprod'
  'prod'
)
param environmentType string
