param cdbName string
param appclientId string

resource cdb 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: cdbName
}

param dataActions array = [
  'Microsoft.DocumentDB/databaseAccounts/readMetadata'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/upsert'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/create'
]
var roleDefinitionId = guid('sql-role-definition-', appclientId, cdb.id)
var roleAssignmentId = guid(roleDefinitionId, appclientId, cdb.id)
var roleDefinitionName = 'My Read Write Role- No Delete'

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2022-05-15' = {
parent: cdb
name: roleDefinitionId
properties: {
  roleName: roleDefinitionName
  type: 'CustomRole'
  assignableScopes: [
    cdb.id
  ]
  permissions: [
    {
      dataActions: dataActions
    }
  ]
}
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
parent: cdb
name: roleAssignmentId
properties: {
  roleDefinitionId: sqlRoleDefinition.id
  principalId: appclientId
  scope: cdb.id
}
}

//Cosmos DB Operator		230815da-be43-4aae-9cb4-875f7bd000aa
var cdbOperator = resourceId('Microsoft.Authorization/roleDefinitions', '230815da-be43-4aae-9cb4-875f7bd000aa')
resource cdbOperatorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cdb
  name: guid(cdb.id, appclientId, cdbOperator)
  properties: {
    roleDefinitionId: cdbOperator
    principalType: 'ServicePrincipal'
    principalId: appclientId
  }
}
