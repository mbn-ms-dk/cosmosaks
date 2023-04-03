param cdbName string
param appclientId string

resource cdb 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: cdbName
}


//DocumentDB Account Contributor	5bd9cd88-fe45-4216-938b-f97437e15450
var cdbAccountContrib = resourceId('Microsoft.Authorization/roleDefinitions', '5bd9cd88-fe45-4216-938b-f97437e1545')
resource cdbAccountContribRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cdb
  name: guid(cdb.id, appclientId, cdbAccountContrib)
  properties: {
    roleDefinitionId: cdbAccountContrib
    principalType: 'ServicePrincipal'
    principalId: appclientId
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
