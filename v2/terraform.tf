terraform {
  backend "azurerm" {
    resource_group_name  = "migration-spendlab"
    storage_account_name = "stspendlabbackup"
    container_name       = "terraform"
    key                  = "opentofu.tfstate"
    use_azuread_auth     = true
    subscription_id      = "42037b9b-88c0-4f49-8e69-d5e6e50ea63e"
    tenant_id            = "0f78f8fe-84a3-4cfc-bf03-fccb71a7fbe9"
  }


  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.105.0"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}
