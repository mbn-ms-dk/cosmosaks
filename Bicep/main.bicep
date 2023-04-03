// Parameters
param baseName string
param resourceGroupName string 

param location string = resourceGroup().location


//cosmos naming
var rnd = uniqueString(subscription().subscriptionId, deployment().name,resourceGroupName)

var cosmosName = 'cdb${baseName}${take(rnd, 3)}'



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
        subject: 'system:serviceaccount:todoapp:todoapp'
      }
  }
}
output idTodoAppClientId string = todoappId.properties.clientId
output idTodoApp string = todoappId.id

module kvtodoApp 'kvRbac.bicep' = {
  name: 'kvtodoAppRbac'
  params: {
    appclientId: todoappId.properties.clientId
    kvName: keyvaultconstr.outputs.keyVaultName
  }
}
output aksUserNodePoolName string = 'npuser01' //[for nodepool in aks.properties.agentPoolProfiles: name] // 'npuser01' //hardcoding this for the moment.
output nodeResourceGroup string = aksconstr.outputs.aksNodeResourceGroup
//Create Cosmos DB
module cosmosdb 'modules/cosmos/cosmos.bicep'={
  scope:resourceGroup(resourceGroupName)
  name:'cosmosDB'
  params:{
    location: location
    principalId:todoappId.properties.principalId
    accountName:cosmosName
  }
}
output cosmosdbEndpoint string = cosmosdb.outputs.cosmosdbEndpoint
output principalId string = todoappId.properties.principalId

module cdbTodoApp 'cosmosRbac.bicep' = {
  name: 'cdbTodoAppRbac'
  params: {
    cdbName: cosmosdb.name
    appclientId: todoappId.properties.clientId
  }
}
