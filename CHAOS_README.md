# Azure Chaos Studio

This will describe how to configure and use the [Azure Chaos Studio](http://aka.ms/AzureChaosStudio) with Azure Kubernetes Service (AKS) and Azure Cosmos DB.
From the [readme](README.md) we have installed the following:

**AKS Cluster, configured as an OIDC issuer for Workload Identity with the CSI Secrets driver installed**
![Azure Portal](assets/images/azure_portal_post%20deployment.png)

Now we will "install" the Chaos Studio and configure it to use the AKS cluster and Cosmos DB.
From the Azure Portal search for "Chaos Studio" and click on the "Chaos Studio" icon.

![Chaos Studio](assets/images/azure_portal_select_chaos_studio.png)

We will use [Chaos Mesh](https://chaos-mesh.org/) for AKS in this setup so we need to configure AKS with Chaos Mesh.
```bash
# Install Chaos Mesh
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update
kubectl create ns chaos-testing
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
```

Verify that Chaos Mesh is installed

```bash
kubectl get po -n chaos-testing
```

![Chaos Mesh](assets/images/chaos_mesh_installed.png)


View the Chaos Mesh dashboard

```bash
kubectl port-forward -n chaos-testing svc/chaos-dashboard 2333:2333
```

Then navigate to http://localhost:2333

![Chaos Mesh Dashboard](assets/images/chaos_mesh_dashboard.png)

## Configure Chaos Studio
Chaos Studio have Targets and Experiments.
Targets are the resources we want to test, and Experiments are the tests we want to run.

### Targets

First we need to select the targets for the experiments. We will use the AKS cluster and Cosmos DB we have deployed in the previous step.

![Chaos Targets](assets/images/chaos_studio_targets.png)

Then enable the targets we want to use.

![Enable targets](assets/images/chaos_studio_enable_targets.png)

Verify deployment

![Chaos targets complete](assets/images/chaos_studio_enable_targets_complete.png)

### Experiments

We need to create Experiments to test the targets.
We will create one experiment with two branches, one to test the AKS cluster and one to test Cosmos DB.

Navigat to the experiments tab and click "Create Chaos Experiment".

![Chaos Experiments](assets/images/chaos_studio_experiments.png)

Set the resource group to the one we deployed the AKS cluster and Cosmos DB to and name your experiment

![Create Chaos Experiment](assets/images/chaos_studio_create_experiment.png)

Next we will configure the experiment in the designer

Rename Step 1 to "AKS and Cosmos" and rename the branch to "AKS stress"

![Chaos Studio action and fault](assets/images/chaos_studio_experiment_designer.png)

select add action and add fault and select AKS Stress and fill in the details

![Chaos Studio Experiment details](assets/images/chaos_studio_experiment_designer_aks_stress.png)
![Chaos Studio Experiment details](assets/images/chaos_studio_add_fault.png)

Details for the experiment

```note
{"action":"pod-failure","mode":"one","selector":{"namespaces":["todoapp","default","ingress-controllers","kube-node-lease","kube-public","kube-system","kv"]},"stressors":{"cpu":{"workers":2,"load":100}},"scheduler":{"cron":"@every 10m"}}
```

Set targets and press add

![Chaos Studio Experiment targets](assets/images/chaos_studio_add_fault_step_2.png)

Add another branch and name it "Cosmos DB failover"

![Chaos Studio branch](assets/images/chaos_studio_add_branch.png)

Add action and fault and select Cosmos DB Failover and fill in the details

![Chaos Studio Cosmos DB Failover](assets/images/chaos_studio_branch_two_add_fault.png)

Select Cosmos DB failover

![Chaos Studio Cosmos DB Failover](assets/images/chaos_studio_branch_two_cosmos_fault.png)

Set read region to North Europe and select targets

![Chaos Studio Set region](assets/images/chaos_studio_branch_two_read_region.png)

Select Cosmos DB and press add

![Chaos Studio Add targets](assets/images/chaos_studio_branch_two_select_target.png)

Press review and create

![Chaos Studio Review and create](assets/images/chaoas_studio_review_and_create.png)

Select Create (next we will setup identitites to be able to run the expeqriments)

![Chaos Studio Create](assets/images/chaos_studio_create.png)

As seen Chaos Studio creates an identity

![Chaos Studio Identity](assets/images/chaos_studio_experiment_done.png)

### Setting permissions for Chaos Studio

When you create a chaos experiment, Chaos Studio creates a system-assigned managed identity that executes faults against your target resources. This identity must be given appropriate permissions to the target resource for the experiment to run successfully. For example, if you are running a fault against an Azure Kubernetes Service (AKS) cluster, the identity must be granted the Azure Kubernetes Service Cluster User Role. For more information, see [Chaos Studio permissions](https://docs.microsoft.com/en-us/azure/azure-chaos-studio/chaos-studio-permissions).

1. Navigate to your AKS cluster and click on Access control (IAM)

![Chaos Studio IAM](assets/images/chaos_studio_iam.png)

2. Click on "Add role assignment"

![Chaos Studio IAM](assets/images/chaos_studio_iam_add_role.png)

3. Search for Azure Kubernetes Service Cluster Admin Role and select the role. Click Next

![Chaos Studio IAM](assets/images/chaos_studio_iam_add_role_aks_cluster_admin.png)

4. Click Select members and search for your experiment name. Select your experiment and click Select

![Chaos Studio IAM](assets/images/chaos_studio_iam_add_role_select_members.png)

5. Click Review + assign then Review + assign.

6. Do the same for Cosmos DB but assign the Cosmos DB Operator Role.

![Chaos Studio IAM](assets/images/chaos_studio_iam_add_role_cosmos_db_operator.png)

7. Click Review + assign then Review + assign.

### Run the experiment

Go to chaos studio and select the experiment we created and press start

![Chaos Studio Run experiment](assets/images/chaos_studio_run_experiment.png)

