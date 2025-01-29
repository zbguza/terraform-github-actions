provider "azurerm" {
  features {}
  # By default, always ensure we use Azure AD for storage access
  storage_use_azuread = true
}
