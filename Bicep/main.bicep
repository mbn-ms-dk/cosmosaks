targetScope = 'subscription'

// Parameters
param baseName string

param location string = deployment().location


//acr and cosmos adds
var rnd = uniqueString(subscription().subscriptionId, deployment().name)
var rndEnd = uniqueString(substring(rnd, 0, 5))

var rgName = 'rg-${baseName}${rndEnd}'
var acrName = 'acr${baseName}${rndEnd}'
var cosmosName = 'cdb${baseName}${rndEnd}'
var kvName = 'kv${baseName}${rndEnd}'


//Create Resource Group
module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
  }
}

//Create identity
module aksIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'managedIdentity'
  params: {
    basename: '${baseName}${rndEnd}'
    location: location
  }
}

//Create Vnet Resource
resource vnetAKSRes 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: vnetAKS.outputs.vnetName
}

//Create Vnet
module vnetAKS 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksVNet'
  params: {
    vnetNamePrefix: 'aks'
    location: location
  }
  dependsOn: [
    rg
  ]
}

//Create ACR
module acrDeploy 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrInstance'
  params: {
    acrName: acrName
    principalId: aksIdentity.outputs.principalId
    location: location
  }
}


//Create Log Analytics Workspace
module akslaworkspace 'modules/laworkspace/la.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'akslaworkspace'
  params: {
    basename: 'la${baseName}${rndEnd}'
    location: location
  }
}

//Create Subnet
resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: 'aksSubNet'
  parent: vnetAKSRes
}

//Assign Roles
module aksMangedIDOperator 'modules/Identity/role.bicep' = {
  name: 'aksMangedIDOperator'
  scope: resourceGroup(rg.name)
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830' //ManagedIdentity Operator Role
  }
}

module aksNetworkContributor 'modules/Identity/role.bicep' = {
  name: 'aksNetworkContributor'
  scope: resourceGroup(rg.name)
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: '4d97b98b-1d4f-4787-a291-c67834d212e7'  //Network Contributor
  }
}

//Create AKS
module aksCluster 'modules/aks/aks.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksCluster'
  dependsOn: [
    aksMangedIDOperator
    aksNetworkContributor    
  ]
  params: {
    location: location
    basename: '${baseName}${rndEnd}'
    logworkspaceid: akslaworkspace.outputs.laworkspaceId   
    podBindingSelector: 'cosmostodo-apppodidentity'
    podIdentityName: 'cosmostodo-apppodidentity'
    podIdentityNamespace: 'todoapp'
    subnetId: subnetaks.id
    clientId: aksIdentity.outputs.clientId
    identityid: aksIdentity.outputs.identityid
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
    principalId: aksIdentity.outputs.principalId
  }
}

//Create Cosmos DB
module cosmosdb 'modules/cosmos/cosmos.bicep'={
  scope:resourceGroup(rg.name)
  name:'cosmosDB'
  params:{
    location: location
    principalId:aksIdentity.outputs.principalId
    accountName:cosmosName
  }
}

//Create Key Vault
module keyvault 'modules/keyvault/keyvault.bicep'={
  name :'keyVault'
  scope:resourceGroup(rg.name)  
  params:{
    kvName:kvName
    location:location
    principalId:aksIdentity.outputs.principalId
    cosmosEndpoint: cosmosdb.outputs.cosmosEndpoint
  }
}

