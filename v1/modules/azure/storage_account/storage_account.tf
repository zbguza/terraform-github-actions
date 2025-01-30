######################################################################################################################################################
#  Resources                                                                                                                                         #
######################################################################################################################################################
module "resource_types" {
  source = "../../../../shared_resource_modules/azure/tag_resource_types"
}

### Storage Accounts
resource "azapi_resource" "app_storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-01-01"
  name      = local.storage_account_name
  location  = var.resource_group.location
  parent_id = var.resource_group.id
  tags = merge(var.common_tags,
    { resource_type = module.resource_types.values.data },
    { resource_group = var.resource_group.name }
  )

  body = jsonencode({
    properties = {
      allowSharedKeyAccess         = false
      allowBlobPublicAccess        = false
      allowCrossTenantReplication  = false
      defaultToOAuthAuthentication = true
      isHnsEnabled                 = true
      publicNetworkAccess          = "Disabled"
      accessTier                   = "Hot"
      minimumTlsVersion            = "TLS1_2"
      isNfsV3Enabled               = false
      isSftpEnabled                = false
      supportsHttpsTrafficOnly     = true

      encryption = {
        keySource = "Microsoft.Storage"
        services = {
          blob = {
            enabled = true
            keyType = "Account"
          }

          file = {
            enabled = true
            keyType = "Account"
          }
        }
      }

      networkAcls = {
        bypass              = "AzureServices"
        defaultAction       = "Allow"
        ipRules             = []
        virtualNetworkRules = []
      }
    }

    sku = {
      name = "Standard_LRS"
    }

    kind = "StorageV2"

  })

  response_export_values = ["properties.primaryEndpoints.blob"]
}

# Blob Service is on by default these days; no declaration for blob service.

# Diagnostic settings for application storage account
resource "azurerm_monitor_diagnostic_setting" "storage_account_diagnostic_settings" {
  name                       = "Log all to LAW"
  target_resource_id         = azapi_resource.app_storage_account.id
  log_analytics_workspace_id = var.mgt_law_id

  metric {
    category = "Capacity"
    enabled  = true
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

# Diagnostic settings for application storage account's blob service
resource "azurerm_monitor_diagnostic_setting" "app_blob_service_diagnostic_settings" {
  name = "Log all to LAW"

  target_resource_id         = "${azapi_resource.app_storage_account.id}/blobServices/default"
  log_analytics_workspace_id = var.mgt_law_id

  enabled_log {
    category_group = "AllLogs"
  }

  enabled_log {
    category_group = "Audit"
  }

  metric {
    category = "Capacity"
    enabled  = true
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

### Network
## Private endpoint for application storage account
module "private_endpoint_storage" {
  source = "../../../../shared_resource_modules/azure/private_endpoint"

  environment   = var.environment
  location_name = var.location_name
  company_name  = var.company_name

  resource_group = {
    name     = var.resource_group.name
    location = var.resource_group.location
  }

  subnet_id                      = var.private_endpoint_subnet_id
  private_dns_zone_ids           = [var.blob_private_dns_zone_id]
  private_connection_resource_id = azapi_resource.app_storage_account.id

  parent_resource_name = "blob"
  parent_resource_type = "st"

  mgt_law_id = var.mgt_law_id

  common_tags = var.common_tags
}
