// Parameters
@minLength(3)
@description('The basename to use for the deployment.')
param baseName string
@minLength(3)
@description('The location to use for the deployment. Defaults to Resource Groups location.')
param location string = resourceGroup().location

//create AKS using aks-construction
module aksconstr 'Aks-Construction/bicep/main.bicep' = {
    name: 'aksconstr'
    params: {
      location: location
      resourceName: baseName
      enable_aad: true
      enableAzureRBAC: true
      networkPlugin: 'kubenet'
      registries_sku: 'Premium'
      omsagent: true
      retentionInDays: 30
      agentCount: 1
      //enable workload identity
      workloadIdentity: true
      //workload identity requires OIDCIssuer to be configured on AKS
      oidcIssuer: true
      //enable CSI driver for Keyvault
      keyVaultAksCSI: true
    }
}
output aksOidcIssuerUrl string = aksconstr.outputs.aksOidcIssuerUrl
output aksClusterName string = aksconstr.outputs.aksClusterName
output aksAcrName string = aksconstr.outputs.containerRegistryName

//Create keyvault
module keyvaultconstr 'Aks-Construction/bicep/keyvault.bicep' ={
  name: 'kvtodoapp${baseName}'
  params:{
    resourceName: 'todoapp${baseName}'
    keyVaultPurgeProtection: false
    keyVaultSoftDelete: false
    location: location
    privateLinks: false
  }
}
output keyVaultName string = keyvaultconstr.outputs.keyVaultName

resource todoappId 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'id-todoapp'
  location: location

  resource fedCreds 'federatedIdentityCredentials' = {
      name: '${baseName}-todoapp'
      properties: {
        audiences: aksconstr.outputs.aksOidcFedIdentityProperties.audiences
        issuer: aksconstr.outputs.aksOidcFedIdentityProperties.issuer
        subject: 'system:serviceaccount:todoapp:todo-todoapp'
      }
  }
}
output idTodoAppClientId string = todoappId.properties.clientId
output idTodoApp string = todoappId.id
output idTodoAppPrincipalId string = todoappId.properties.principalId

module kvtodoApp 'kvRbac.bicep' = {
  name: 'kvtodoAppRbac'
  params: {
    appclientId: todoappId.properties.principalId
    kvName: keyvaultconstr.outputs.keyVaultName
  }
}
output aksUserNodePoolName string = 'npuser01' //[for nodepool in aks.properties.agentPoolProfiles: name] // 'npuser01' //hardcoding this for the moment.
output nodeResourceGroup string = aksconstr.outputs.aksNodeResourceGroup

//Set cosmosdb failover location
var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  },{
    locationName: 'northeurope'
    failoverPriority: 1
    isZoneRedundant: false
  }
]
//Create Cosmos DB
var cosmosName = toLower('cdb${baseName}-${uniqueString(resourceGroup().id)}')
resource cosmosdb 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: cosmosName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: locations
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true      // set to false if you want to use master keys in addition to RBAC
    enableAutomaticFailover: true
    enableMultipleWriteLocations: false   
    isVirtualNetworkFilterEnabled: false     // set to false if you want to use public endpoint for Cosmos
  }
}
//create database and container
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
  parent: cosmosdb
  name: 'todoapp'
  properties: {
    resource: {
      id: 'todoapp'
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  parent: database
  name: 'tasks'
  properties: {
    resource: {
      id: 'tasks'
      partitionKey: {
        paths: [
          '/id'
        ]
      }
    }
  }
}
output cosmosdbEndpoint string = cosmosdb.properties.documentEndpoint

module cdbTodoApp 'cosmosRbac.bicep' = {
  name: 'cdbTodoAppRbac'
  params: {
    cdbName: cosmosdb.name
    appclientId: todoappId.properties.principalId
  }
}
