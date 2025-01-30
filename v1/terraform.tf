terraform {
  backend "azurerm" {
    resource_group_name  = "rg-cicd-westeu-001"
    storage_account_name = "sttfstatewesteu002"
    container_name       = "tofu-state-v2"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
    subscription_id      = "f44e9ef6-afad-4689-83b8-70eece44356b"
    tenant_id            = "eaac3cdb-6e6d-44d1-9568-2c842c9f1a69"
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
