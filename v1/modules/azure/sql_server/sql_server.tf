######################################################################################################################################################
#  Resources
######################################################################################################################################################
module "resource_types" {
  source = "../../../../shared_resource_modules/azure/tag_resource_types"
}

# Define the group that will be used for both admin access (attribute on server)
# as well as receive several SQL-related RBAC roles.
module "server_administrators_group" {
  source = "../../../../shared_resource_modules/azure/azuread_group"

  environment_short_name   = var.environment
  resource_name_short_name = "sql-server"
  role_name                = "admins"
  security_enabled         = true
  assignable_to_role       = true
  members                  = var.server_administrators_group_members
}

#TODO: replace client_config below with dynamic value when we have subscriptions as part of TF code as well.
data "azurerm_client_config" "current" {}

### SQL Server service
resource "azurerm_mssql_server" "online_sql_server" {
  name                = local.sql_server_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  azuread_administrator {
    login_username              = module.server_administrators_group.group.display_name
    object_id                   = module.server_administrators_group.group.object_id
    azuread_authentication_only = true
    tenant_id                   = data.azurerm_client_config.current.tenant_id
  }

  version             = "12.0"
  minimum_tls_version = "1.2"
  #To determine whether public network access should be enabled, we check if
  #there are any whitelisted IP ranges defined. Also note that the although it's
  #called public network access, there is actually no real 'allow from public
  #internet' option, setting this option to true enables whitelisting rules to
  #apply.
  public_network_access_enabled = length(var.whitelisted_ip_ranges) > 0

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags,
    { resource_type = module.resource_types.values.data },
    { resource_group = var.resource_group.name }
  )

  depends_on = [
    var.resource_group
  ]
}

resource "azurerm_mssql_firewall_rule" "whitelisted_ip_ranges" {
  for_each         = { for range in var.whitelisted_ip_ranges : "${range.start_ip}-${range.end_ip}" => range } # Create a unique key for each range
  name             = "AllowIP-${each.key}"
  server_id        = azurerm_mssql_server.online_sql_server.id
  start_ip_address = each.value.start_ip
  end_ip_address   = each.value.end_ip
}

## Admin access
module "role_assignments_management" {
  source = "../../../../shared_resource_modules/azure/avm_role_assignment"

  role_assignments_azure_resource_manager = {
    #For assigning multiple roles, we loop through the given list of role names and
    #create an object for each name. Only the name is unique per iteration, the rest
    #of the object is the same for each role.
    for role_name in toset(local.server_administrators_rbac_names) : role_name => {
      principal_id         = module.server_administrators_group.group.object_id
      role_definition_name = role_name
      scope                = azurerm_mssql_server.online_sql_server.id
    }
  }
}

## TDE
resource "azurerm_mssql_server_transparent_data_encryption" "encryption_settings" {
  server_id = azurerm_mssql_server.online_sql_server.id
}

## Alerts
resource "azurerm_mssql_server_security_alert_policy" "alert_settings" {
  resource_group_name = var.resource_group.name
  server_name         = azurerm_mssql_server.online_sql_server.name
  state               = "Enabled"
}

## Storage
module "sql_storage" {
  source = "../../../../v2/modules/azure/storage_account"

  company_name               = var.company_name
  application_short_name     = ""
  environment                = var.environment
  location_name              = var.location_name
  resource_group             = var.resource_group
  private_endpoint_subnet_id = var.pe_subnet_id

  blob_private_dns_zone_id = var.blob_private_dns_zone_id
  mgt_law_id               = var.mgt_law_id

  common_tags = var.common_tags
}

# Audit settings & RBAC are NOT global only, so we need a data source for the storage again.
#data "azapi_resource" "st_account" {
#  type      = "Microsoft.Storage/storageAccounts@2023-01-01"
#  name      = module.sql_storage.name
#  parent_id = azurerm_mssql_server.online_sql_server.id
#
#  response_export_values = [
#    "properties.primaryEndpoints.blob",
#    "id"
#  ]
#
#  depends_on = [
#    azurerm_mssql_server.online_sql_server
#  ]
#}

resource "azurerm_mssql_server_extended_auditing_policy" "auditing_settings" {
  server_id                       = azurerm_mssql_server.online_sql_server.id
  storage_account_subscription_id = var.subscription_id
  storage_endpoint                = module.sql_storage.primary_blob_endpoint
}

resource "azurerm_role_assignment" "rbac_assignment_db_server_blob_contributor" {
  scope                = module.sql_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_mssql_server.online_sql_server.identity[0].principal_id
}

## Enable Threat detection for SQL Server
# Commented due to https://github.com/SpendLab-Technology/infrastructure/pull/17#discussion_r1745350119
# Will be here just in case if needed in the future.
#resource "azurerm_mssql_server_security_alert_policy" "sql_server_threat_detection" {
#  server_name         = azurerm_mssql_server.online_sql_server.name
#  resource_group_name = var.resource_group.name
#
#  state = "Enabled"
#
#  storage_endpoint           = data.azapi_resource.st_account.primary_blob_endpoint
#  storage_account_access_key = data.azapi_resource.st_account.primary_access_key
#
#  retention_days = 30
#
#  disabled_alerts = [
#    "Sql_Injection",
#    "Sql_Injection_Vulnerability",
#    "Access_Anomaly",
#  ]
#
#  email_addresses = [var.owner]
#}
#

module "private_endpoint_db" {
  source = "../../../../shared_resource_modules/azure/private_endpoint"

  resource_group                 = var.resource_group
  environment                    = var.environment
  location_name                  = var.location_name
  company_name                   = var.company_name
  subnet_id                      = var.pe_subnet_id
  private_dns_zone_ids           = [var.sql_private_dns_zone_id]
  private_connection_resource_id = azurerm_mssql_server.online_sql_server.id
  parent_resource_name           = "sqlServer"
  parent_resource_type           = "sql"
  mgt_law_id                     = var.mgt_law_id
  common_tags                    = var.common_tags #module handles resource type and resource group name
}
