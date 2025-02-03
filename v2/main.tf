resource "azurerm_resource_group" "rg-01" {
  name     = "rg-open-tofu-01"
  location = "West Europe"
}

resource "azurerm_storage_account" "st-01" {
  name                     = var.st_acc_name
  resource_group_name      = azurerm_resource_group.rg-01.name
  location                 = azurerm_resource_group.rg-01.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "st-02" {
  name                     = "${var.st_acc_name}06"
  resource_group_name      = azurerm_resource_group.rg-01.name
  location                 = azurerm_resource_group.rg-01.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
