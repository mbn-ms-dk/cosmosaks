# AKS Cluster, Cosmos DB, Key Vault, and ACR using Bicep

## Overview

This repository explains on how to use modular approach for Infrastructure as Code to provision a AKS cluster and few related resources. The AKS is configured to run a Sample Todo App where access control is manged using RBAC and Managed Identity.

The [Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/overview?tabs=bicep) modules in the repository are designed keeping baseline architecture in mind. You can start using these modules as is or modify to suit the needs.

The Bicep modules will provision the following Azure Resources under subscription scope.

1. A Resource Group
2. A Managed Identity
3. An Azure Container Registry for storing images
4. A VNet required for configuring the AKS
5. An AKS Cluster
6. A Cosmos DB SQL API Account along with a Database, Container, and SQL Role to manage RBAC
7. A Key Vault to store secure keys
8. A Log Analytics Workspace 

### Architecture

![Architecture Diagram](assets/images/cosmos-todo-aks-architecture.png)


## Deploy infrastructure with Bicep

**1. Clone the repository**

Clone or fork the repository and move to Bicep folder

```shell
cd Bicep
```

**2. Login to your Azure Account**

```shell
az login

az account set -s <Subscription ID>
```
**3. Initialize Parameters**

Create a param.json file by using the following JSON, replace the {Base Name} placeholders with your own values for Base name. 

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "baseName": {
      "value": "<BASE_NAME>"
    }
  }
}
```

**4. Run Deployment**

Run the following script to create the deployment

```bash
rg='rg-chaos'
location='westeurope' # Location for deploying the resources - set to westeurope with failover in northeurope
# Create resource group
az group create -n $rg -l $location
DEP=$(az deployment group create -g $rg -f main.bicep --parameters baseName='awi' resourceGroupName=$rg -o json) 
OIDCISSUERURL=$(echo $DEP | jq -r '.properties.outputs.aksOidcIssuerUrl.value')
AKSCLUSTER=$(echo $DEP | jq -r '.properties.outputs.aksClusterName.value')
KVNAME=$(echo $DEP | jq -r '.properties.outputs.keyVaultName.value')
TODOAPP=$(echo $DEP | jq -r '.properties.outputs.idTodoAppClientId.value')
COSMOS=$(echo $DEP | jq -r '.properties.outputs.cosmosdbEndpoint.value')
PIP=$(echo $DEP | jq -r '.properties.outputs.principalId.value')
az aks get-credentials -n $AKSCLUSTER -g $rg --admin --overwrite-existing
```

![Deployment Started](assets/images/bicep_running.png)

The deployment could take somewhere around 20 to 30 mins. Once provisioning is completed you should see a JSON output with Succeeded as provisioning state.

![Deployment Success](assets/images/bicep_success.png)

You can also see the deployment status in the Resource Group

![Deployment Status inside RG](assets/images/rg_postdeployment.png)

**5. Deploy
```bash
TENANTID=$(az account show --query tenantId -o tsv)
helm upgrade --install todo charts/todoapp --set azureWorkloadIdentity.tenantId=$TENANTID,azureWorkloadIdentity.clientId=$TODOAPP,keyvaultName=$KVNAME,secretName=arbitrarySecret -n todoapp --create-namespace
```

**9. Push the container image to Azure Container Registry**

The application can be built and pushed to ACR using VS Code

**Using Visual Studio Code**

Prerequisites:
* [Docker Desktop](https://docs.docker.com/desktop/)
* [Visual Studio Code](https://code.visualstudio.com/)
* [C# for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp)
* [Docker extension for Visual Studio Code](https://code.visualstudio.com/docs/containers/overview)
* [Azure Account extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azure-account)

    1. To build the code, open the Application folder in VS code. Select Yes to the warning message to add the missing build and debug assets. Pressing the F5 button to run the application.

    2. To create a container image from the Explorer tab on VS Code, right click on the Docker and select BuildImage. You will then get a prompt asking for the name and version to tag the image. Type cosmosaks:latest.

        ![Build Image VS Code](assets/images/build_image.png)

    3. To push the built image to ACR open the Docker tab.You will find the built image under the Images node. Open the todo node, right-click on latest and select "Push...". You will then get prompts to select your Azure Subscription, ACR, and Image tag. Image tag format should be {acrname}.azurecr.io/cosmosaks:latest.

        ![Push Image to ACR](assets/images/image_push.png)

    4. Wait for VS Code  to push the  image to ACR.

**10. Prepare Deployment YAML**

Using the following YAML template create a akstododeploy.yml file. Make sure to replace the values for {ACR Name}, {Image Name}, {Version}, and {Resource Group Name} placeholders.

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo
  labels:
    aadpodidbinding: "cosmostodo-apppodidentity"
    app: todo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo
  template:
    metadata:
      labels:
        app: todo
        aadpodidbinding: "cosmostodo-apppodidentity"
    spec:
      containers:
      - name: mycontainer
        image: "{ACR Name}/{Image Name}:{Version}"   # update as per your environment, example myacrname.azurecr.io/todo:latest. Do NOT add https:// in ACR Name
        ports:
        - containerPort: 80
        env:
        - name: KeyVaultName
          value: "{Keyvault Name}"       # Replace resource group name. Key Vault name is generated by Bicep
      nodeSelector:
        kubernetes.io/os: linux
      volumes:
        - name: secrets-store01-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "azure-kvname-podid"       
---
    
kind: Service
apiVersion: v1
metadata:
  name: todo
spec:
  selector:
    app: todo
    aadpodidbinding: "cosmostodo-apppodidentity"    
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
``` 

**11. Apply Deployment YAML**

The following command deploys the application pods and exposes the pods via a load balancer.

```shell
kubectl apply -f akstododeploy.yml --n todoapp
```

**12. Access the deployed application**

Run the following command to view the external IP exposed by the load balancer

```shell
kubectl get services --n todoapp
```

Open the IP received as output in a browser to access the application.

## Cleanup

Use the below commands to delete the Resource Group and Deployment

```azurecli
az group delete -g $rgName -y
az deployment sub delete -n 'env-create'
```
