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
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/3c3e601b-6265-41f9-9858-851f87c6dee9)

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
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/77b4faf9-6aa6-4bd7-9814-0644574331fc)
- Control + X, Hit save the file then run the script ./tfbackend.ps1
- After executing the script you should see these resources created on Azure portal
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/c2a59143-e8d0-48c6-a903-6fbe32f90f14)


# Configure Azure DevOps 

- Access Azure DevOps Portal
- Go to your Project and Create a new one
- Then after creating the Project Navigate at 'Service Connection' of your newly project created.
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/866f21fa-3c9e-4e5f-bca9-b99c3daa298a)
- Click Azure Resource Manager
- Select 'Service principal (manual)' In order to choose the SPN that we created from the script above.
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/4d8ca717-1515-4ecb-8328-4164dfd4411a)
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/bcaa668b-8d02-4650-be51-8679bd4c25d2)
- You can find the information needed in the ‘Key Vault’ Secrets
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/2b18df0a-ca83-4f34-9a82-c014c572b306)
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/aa0bed00-62c7-4852-a489-31cd7fcd034f)
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/3be011da-ae17-4864-846a-4547c3ee12fb)
- Now create a variable group that is going to be used in the pipeline which later we will reference it to the variable group and uses the secrets as variables
 ![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/6fbbf4c2-e74b-42ab-9c03-9d0b98f1fb54)
-	Select ‘Terraform Demo’ (name of the ‘Service Connection’)
-	Select the Key Vault and authorize
-	Select the variables you want to add (all in this case)
-	Click save and on to the next steps
-	![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/7bd92677-006b-4a06-b783-34023ae16e39)

# Initializing the repository

- Go to 'Azure Repos' > ' Files'
- Select Terraform.gitignore template
- Select add README
- Initialize the repository

# Terraform & Azure DevOps

After preparing the whole environment now we are good to go creating the multi-stage pipeline YAML in order to deploy our resources. In order to do this there is needed to do certain steps first.

-	Open ‘Visual Studio Code’
-	Open the command palette with the key combination of Ctrl + Shift + P
-	At the command palette prompt, type gitcl, select the Git: Clone command, and press Enter
-	When prompted for the Repository URL, select clone from GitHub, then press Enter
-	If you are asked to sign into GitHub, complete the sign-in process
-	Enter <tobeaddedlaterlinkofGiTHUB>s in the Repository URL field
-	Select (or create) the local directory into which you want to clone the project.
  	When you receive the notification asking if you want to open the cloned repository, select Open

# First, commit 
Now that you have the demo data, copy the contents of the folder to the folder for your Azure DevOps repository created in the previous blog.
When the files are copied you see that source control has items to commit.
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/47c5c5de-3435-4478-b487-be0ab2156761)
-	Select ‘Source Control’
-	Hit the commit button (checkbox)
-	Add tekst that describes the commit and press Enter Sync the changes by pressing ‘Sync Changes’
	![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/30493304-21ca-402c-83d7-84a4b11ba66c)

# Azure DevOps

To see if the content is committed correctly we are going to view the content in the Azure repository.
-	Go to the Azure DevOps Portal 
-	Navigate to your Project
-	From within your project navigate to ‘Repos’
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/da2b50b0-2276-4731-9fd2-0839d7f9ad46)


# Adjust the pipeline

The pipeline(s) need some additional configuration changes for your own usage. I have commented on the lines that need to be changed in the terraform/pipelines folder (tf-validate-plan-apply-basic.yml), for example:

---
            Stages:
            - stage: Validate
              jobs:
              - job: ValidateInstall
                steps:
                - task: CmdLine@2
                  displayName: Terraform Init
                  inputs:
                    #replace 'example-key1' with your key from key vault. Pipelines > Library > Variable groups
                    script: terraform init -backend-config="access_key=$(example-key1)"
                    workingDirectory: terraform

---
So here you have to replace ‘example-key1’ with your key from key vault. Which can be found in Pipelines > Library > Variable groups


# Adjust the terraform files accordinally 
The terraform files need some additional configuration changes for your own usage. I have commented on the lines that need to be changed in the terraform/ folder (backend.tf)
The backend defines where Terraform stores its state data files.

---
    terraform {
      backend "azurerm" {
      storage_account_name = "stateterraform184" # Storage account created
      container_name       = "ct-terraform-state-184" # Container created
      key                  = "demo-tf.tfstate" # Desired name of tfstate file
  }
}

---

- terraform/ folder (providers.tf)
- Providers allow Terraform to interact with cloud providers, SaaS providers, and other APIs.

---
    terraform {
       required_providers {
         azurerm = {
           source  = "hashicorp/azurerm"
           version = "2.96.0"
     }
   }
 }

provider "azurerm" {
  features {}
  subscription_id = var.subscription-id # Add your subscription id in "" or add secret in keyvault
  client_id       = var.spn-client-id
  client_secret   = var.spn-client-secret
  tenant_id       = var.spn-tenant-id
}

---
- The terraform/ folder (main.tf) here you can add or change data to your preferences, I added modules as an example.
- The main.tf, variables.tf, outputs.tf. These are the recommended filenames for a minimal module, even if they’re empty. main.tf should be the primary entry point. For a simple module, this may be where all the resources are created. For a complex module, resource creation may be split into multiple files but any nested module calls should be in the main file.variables.tf and outputs.tf should contain the declarations for variables and outputs, respectively.

---
    # Create your Resource Group
    resource "azurerm_resource_group" "rg" {
      name     = "rg-tf-main-demo"
      location = "West Europe"
    }

    # Define 'module' for modules in subfolder
    module "modules" {
      source = "./modules"
    }

---

# Create Pipeline

- Navigate to ‘Pipelines’ > ‘New pipeline’ > ‘Select Azure Repos Git’
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/210e23a7-1a9f-4d3d-9e57-6ce2e9075c3c)
- Select your repository and select ‘Existing Azure Pipelines YAML file’
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/8efaabff-2cea-4cec-a4bd-655d11abee8c)
- Select: /terraform/pipelines/tf-validate-plan-apply-basic.yml and press ‘Continue’
- You are now ready to run your basic pipeline 🙂 Review you pipeline and press ‘Run’
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/5c16fbf9-90e2-4f8e-9c1c-ccc0e69d6ac3)
For the first run, the pipeline needs permission to access resources. Select ‘View’ and permit.

![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/78fbbcf3-6de2-4f22-b482-44ca444fd62e)

As you can see the pipeline has 3 stages in this example. Validate, Plan & Apply
-	Validate checks if the configuration is valid
-	Plan creates an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure:
-	Reads the current state of any already-existing remote objects to make sure that the Terraform state is up-to-date.
-	Compares the current configuration to the prior state and notes any differences.
-	Proposes a set of change actions that should, if applied, make the remote objects match the configuration.
-	Apply the terraform apply command execute the actions proposed in a Terraform plan
  
To view the stages you can click on the stage to see more info, in this example you can see the plan stage and what is going to be created:

![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/659e775c-65c9-4b33-b845-cc12254bc4e3)

# Pipeline Steps

Each steps in the stages are displayed below

Validate Step
- Initialize job
- Download secrets
- Checkout main branch
- Terraform Init (Initialize modules, backend and providers)
- Validate config

Plan Step
- Initialize job
- Download secrets
- Checkout main branch
- Terraform Init (Initialize modules, backend and providers)
- Terraform Plan
- Copy the plan file as an artifact
- Publish the plan file as an artifact
Publish Step
- Initialize job
- Download secrets
- Checkout main branch
- Terraform Init (Initialize modules, backend and providers)
- Download pipeline artifact
- Terraform apply
