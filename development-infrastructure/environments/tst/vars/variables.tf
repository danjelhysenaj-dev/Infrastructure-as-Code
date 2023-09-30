variable "subscription-id" {
  default = "443f092c-f85c-4605-9257-ecfa50926f37"
}
variable "spn-client-id" {}
variable "spn-client-secret" {}
variable "spn-tenant-id" {}
variable "azdo_personal_access_token" {
  default = ""
}

# Create your Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-tf-main-demo"
  location = "West Europe"
}

variable "resource_group_name" {
  type        = string
  description = "RG name in Azure"
}

variable "location" {
  type        = string
  description = "Resources location in Azure"
}

variable "cluster_name" {
  type        = string
  description = "AKS name in Azure"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "system_node_count" {
  type        = string
  description = "Nmber of AKS worker nodes"
}

variable "acr_name" {
  type        = string
  description = "ACR name"
}
