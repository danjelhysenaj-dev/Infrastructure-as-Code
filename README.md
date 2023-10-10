# Deploy on Azure Cloud with Terraform
# Pipeline Architecture
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/5acd6ed2-09bd-492b-89a3-1ca409959eae)

# What we will include in this pipeline in order to deploy on Azure
- Working with Azure DevOps services such as Azure repos like (creating branches, pull requests, code reviews) Azure Pipelines, Azure Artifacts, etc.
- Creating Terraform backend, SPN (Service Principal), Key Vaults & secrets on Azure with CLI PowerShell script.
- It will include creating a Terraform Multi-Stage YAML pipeline with Manual Validation task, Artifacts, Approvals, Triggers, and much more.
- Integrating Azure keyvault, Terraform and Azure DevOps Pipeline Libraries.

# Description of Pipeline Architecture
1.  A DevOps Engineer initiates the creation of a new branch for either amending or generating fresh code.
2.  The code is then committed to this newly created branch, but only on a local level.
3.  Subsequently, the engineer pushes this code from their local environment to the remote repository in Azure DevOps.
4.  The DevOps Engineer takes a step further by initiating a pull request, aiming to merge this code into the main branch, which stems from the branch created in the first step.
5.  Following this, a pipeline is triggered to perform validation and planning tasks with Terraform.
6.  In tandem with this pull request, an automatic code review request is sent out to other engineers.
7.  If the code review results in rejection, the pull request may be closed, and the code revised to restart the process.
8.  Once the merge is successfully completed, it triggers the Terraform Build & Release pipeline.
9.  Before this pipeline commences, approval is required.
10. The pipeline is set into motion, with the Terraform "Plan" stage taking the lead.
11. A copy of the tf.plan file is made and stored as an artifact, reserved for use in the "Apply" stage (step 12).
12. Reviewers carefully inspect the Terraform plan to ensure it aligns with the intended deployment; if not, the release can be declined. If everything is in order, we proceed to the Terraform "Apply" stage.
13. The Terraform "Apply" stage is then initiated, leading to the deployment and/or destruction of resources.

# Terraform Deployment

- Resource Group is used to group the resources on Azure
- Service connections are needed to securely integrate and interact with various azure services and external systems allowing streamlined automation.
- Key Vault is going to be used in this project in order for us to store our secrets which later are going to be used on the pipeline.
- Storage Accounts will be used to store our statefile in a Blob container, which will handle the state configuration of the file of Terraform.
- ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/3c3e601b-6265-41f9-9858-851f87c6dee9)

# Now lets deploy our first Script to initialize our first resources on Azure

- Open the Azure Portal
- Click on top right corner "Power Shell"
- View the current subscription id in order to identify your current login
---
    az account list -o table
---
- Set your subscription that you want to work with
---
    az account set --subscription "<your subscription id>"
---
- Create a script on Powershell Copy the script below and paste it into your script. (Every step I have commented on and explained in order to show you what resources are going to get created.
---
      # Set Variables
    $RANDOM = Get-Random -Minimum 100 -Maximum 200
    $RESOURCE_GROUP_NAME="rg-terraform-infra-$RANDOM"
    $STORAGE_ACCOUNT_NAME="stateterraform$RANDOM"
    $CONTAINER_NAME="ct-terraform-state-$RANDOM"
    $LOCATION="westeurope"
    $SPN_NAME="terraform-azdevops-$RANDOM"
    $KEYVAULT="kvterraform$RANDOM"
    $OUTPUT="none" # Set to "none" for no output or "json" for default output
    
    # Create resource group
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION --output $OUTPUT
    
    # Create storage account with public access disabled and minimal TLS version
    echo "Creating storage account "$STORAGE_ACCOUNT_NAME" in "$RESOURCE_GROUP_NAME"..."
    az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob --min-tls-version TLS1_2 --allow-blob-public-access false --output $OUTPUT
    # If storage account gets deleted or corrupt you can restore from the past 7 days
    echo "Setting delete retention to 7 days"
    az storage account blob-service-properties update --enable-container-delete-retention true --container-delete-retention-days 7 --enable-versioning true --account-name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --output $OUTPUT
    
    # Get storage account key
    $ACCOUNT_KEY1=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query '[0].value' -o tsv)
    $ACCOUNT_KEY2=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query '[1].value' -o tsv)
    
    # Create blob container
    echo "Create blob container"
    az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY1 --output $OUTPUT
    #az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login --output $OUTPUT
    
    # Create KeyVault and store keys
    echo "Create KeyVault and store keys"
    az keyvault create --name "$KEYVAULT" --resource-group "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output $OUTPUT
    az keyvault secret set --vault-name "$KEYVAULT" --name "$STORAGE_ACCOUNT_NAME-key1" --value "$ACCOUNT_KEY1" --output $OUTPUT
    az keyvault secret set --vault-name "$KEYVAULT" --name "$STORAGE_ACCOUNT_NAME-key2" --value "$ACCOUNT_KEY2" --output $OUTPUT
    
    # Create SPN, add contributor role and store password in keyvault
    echo "Create SPN and store password in keyvault"
    $SPN_SECRET=$(az ad sp create-for-rbac --name "$SPN_NAME" --role contributor --scopes /subscriptions/$(az account show --query id -o tsv) --query password -o tsv)
    $SPN_CLIENT_ID=$(az ad sp list --display-name $SPN_NAME --query [].appId -o tsv)
    $SPN_TENANT_ID=$(az ad sp list --display-name $SPN_NAME --query [].appOwnerOrganizationId -o tsv)
    
    az keyvault secret set --vault-name "$KEYVAULT" --name "terraform-azdevops-spn-secret" --value "$SPN_SECRET" --output $OUTPUT
    az keyvault secret set --vault-name "$KEYVAULT" --name "terraform-azdevops-spn-client-id" --value "$SPN_CLIENT_ID" --output $OUTPUT
    az keyvault secret set --vault-name "$KEYVAULT" --name "terraform-azdevops-spn-tenant-id" --value "$SPN_TENANT_ID" --output $OUTPUT
    
    #Grant SPN permission to keyvault
    echo "Grant SPN permission to keyvault"
    az keyvault set-policy -n $KEYVAULT --secret-permissions get list --spn $SPN_CLIENT_ID --output $OUTPUT

---
NOTE: You can update the variable that I have declared above on your free will.

- nano tfbackend.ps1
- ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/77b4faf9-6aa6-4bd7-9814-0644574331fc)
- Control + X, Hit save the file then run the script ./tfbackend.ps1
- After executing the script you should see these resources created on Azure portal
- ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/c2a59143-e8d0-48c6-a903-6fbe32f90f14)


# Configure Azure DevOps 

- Access Azure DevOps Portal
- Go to your Project and Create a new one
- Then after creating the Project Navigate at 'Service Connection' of your newly project created.
- ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/866f21fa-3c9e-4e5f-bca9-b99c3daa298a)
- Click Azure Resource Manager
- Select 'Service principal (manual)' In order to choose the SPN that we created from the script above.





TODO: Give a short introduction of your project. Let this section explain the objectives or the motivation behind this project. 

# Getting Started
TODO: Guide users through getting your code up and running on their own system. In this section you can talk about:
1.	Installation process
2.	Software dependencies
3.	Latest releases
4.	API references

# Build and Test
TODO: Describe and show how to build your code and run the tests. 

# Contribute
TODO: Explain how other users and developers can contribute to make your code better. 

If you want to learn more about creating good readme files then refer the following [guidelines](https://docs.microsoft.com/en-us/azure/devops/repos/git/create-a-readme?view=azure-devops). You can also seek inspiration from the below readme files:
- [ASP.NET Core](https://github.com/aspnet/Home)
- [Visual Studio Code](https://github.com/Microsoft/vscode)
- [Chakra Core](https://github.com/Microsoft/ChakraCore)
