terraform {
  backend "azurerm" {
    storage_account_name = "stateterraform129"      # Replace with Storage account created
    container_name       = "ct-terraform-state-129" # Replace with Container created
    key                  = "demo-tf.tfstate"        # Desired name of tfstate file
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.22.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "=0.1.7"
    }
  }
}

provider "azuredevops" {
  personal_access_token = var.azdo_personal_access_token
  org_service_url       = "https://dev.azure.com/enterprise-conclave/"
}

provider "azurerm" {
  subscription_id = var.subscription-id # Add your subscription id in "" or add secret in keyvault
  features {}
  client_id     = var.spn-client-id
  client_secret = var.spn-client-secret
  tenant_id     = var.spn-tenant-id
}

data "azuredevops_project" "current_project" {
  name = "avengers"
}

# Define 'module' for modules in subfolder
module "modules" {
  source = "./modules"
}

resource "azurerm_resource_group" "aks-rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_role_assignment" "role_acrpull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.aks-rg.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  location            = var.location
  resource_group_name = azurerm_resource_group.aks-rg.name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = "Standard_DS2_v2"
    type                = "VirtualMachineScaleSets"
    #availability_zones  = [1,2,3]
    enable_auto_scaling = false
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    load_balancer_sku = "standard"
    network_plugin    = "kubenet"
  }

}