@description('The name of the SQL logical server.')
param serverName string = uniqueString('sql', resourceGroup().id)

@description('The name of the SQL Database.')
param sqlDBName string = 'dabclitestdb'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The administrator username of the SQL logical server.')
param administratorLogin string = 'sysadmin'

@description('The administrator password of the SQL logical server.')
@secure()
param administratorLoginPassword string

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDBName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

output sqlname string = sqlServer.name
output dbname string = sqlDBName
output administratorLogin string = administratorLogin

