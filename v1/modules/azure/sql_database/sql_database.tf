######################################################################################################################################################
#  Resources                                                                                                                                         #
######################################################################################################################################################
module "resource_types" {
  source = "../../../../shared_resource_modules/azure/tag_resource_types"
}

### SQL database
resource "azurerm_mssql_database" "app_sql_database" {
  name                 = local.database_name
  server_id            = var.app_sql_server.id
  storage_account_type = var.sql_database.storage_account_type
  sku_name             = var.sql_database.sku_name
  max_size_gb          = var.sql_database.max_size_gb

  lifecycle {
    prevent_destroy = true # Prevent destroy to prevent data loss of DB.
  }

  depends_on = [
    var.app_sql_server
  ]

  tags = merge(var.common_tags,
    { resource_type = module.resource_types.values.data },
    { resource_group = var.resource_group_name }
  )
}

## Diagnostics
resource "azurerm_monitor_diagnostic_setting" "diagnostic_settings_db" {
  name                       = "Log all to LAW"
  target_resource_id         = azurerm_mssql_database.app_sql_database.id
  log_analytics_workspace_id = var.mgt_law_id

  enabled_log {
    category_group = "audit"
  }

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "Basic"
    enabled  = true
  }

  metric {
    category = "InstanceAndAppAdvanced"
    enabled  = true
  }

  metric {
    category = "WorkloadManagement"
    enabled  = true
  }
}

module "encrypt_database" {
  source = "../../../../v2/modules/scripts/sql_database/post_deployment/encrypt_column"

  database_server_resource_group_name = var.app_sql_server.resource_group_name
  database_server_FQDN                = var.app_sql_server.fqdn
  database_name                       = local.database_name
  dependent_database_id               = azurerm_mssql_database.app_sql_database.id
}

# Readers code
module "db_readers_group" {
  source = "../../../../shared_resource_modules/azure/azuread_group"

  environment_short_name   = var.environment
  resource_name_short_name = "sql-db"
  role_name                = "readers"
  security_enabled         = true
  assignable_to_role       = true
  members                  = var.db_readers_group_members
  application_name         = local.application_short_name
}

module "reader_database_access_script_execution" {
  source = "../post_deployment_script_sql"

  script_file_path = "${path.module}/define_db_reader_role.sql"
  database_name    = local.database_name
  database_server = {
    name                = var.app_sql_server.name
    resource_group_name = var.app_sql_server.resource_group_name
    fqdn                = var.app_sql_server.fqdn
  }
  additional_triggers = {
    security_group_name = module.db_readers_group.group.display_name
  }
  sql_arguments = "security_group_name=${module.db_readers_group.group.display_name},database_name=${local.database_name}"
}

# Writers code
module "db_writers_group" {
  source = "../../../../shared_resource_modules/azure/azuread_group"

  environment_short_name   = var.environment
  resource_name_short_name = "sql-db"
  role_name                = "writers"
  security_enabled         = true
  assignable_to_role       = true
  members                  = var.db_writers_group_members
  application_name         = local.application_short_name
}

module "role_assignments_writers" {
  source = "../../../../shared_resource_modules/azure/avm_role_assignment"

  role_assignments_azure_resource_manager = {
    role_assignment = {
      principal_id         = module.db_writers_group.group.object_id
      role_definition_name = "SQL DB Contributor"
      scope                = azurerm_mssql_database.app_sql_database.id
    }
  }
}

module "writer_database_access_script_execution" {
  source = "../post_deployment_script_sql"

  script_file_path = "${path.module}/define_db_writer_role.sql"
  database_name    = local.database_name
  database_server = {
    name                = var.app_sql_server.name
    resource_group_name = var.app_sql_server.resource_group_name
    fqdn                = var.app_sql_server.fqdn
  }
  additional_triggers = {
    security_group_name = module.db_writers_group.group.display_name
  }
  sql_arguments = "security_group_name=${module.db_writers_group.group.display_name},database_name=${local.database_name}"
}

# Management code
module "db_management_group" {
  source = "../../../../shared_resource_modules/azure/azuread_group"

  environment_short_name   = var.environment
  resource_name_short_name = "sql-db"
  role_name                = "admins"
  security_enabled         = true
  assignable_to_role       = true
  members                  = var.db_management_group_members
  application_name         = local.application_short_name
}

module "role_assignments_management" {
  source = "../../../../shared_resource_modules/azure/avm_role_assignment"

  #For assigning multiple roles, we loop through the given list of role names and
  #create an object for each name. Only the name is unique per iteration, the rest
  #of the object is the same for each role.
  role_assignments_azure_resource_manager = {
    for role_name in toset(local.database_administrators_rbac_names) : role_name => {
      principal_id         = module.db_management_group.group.object_id
      role_definition_name = role_name
      scope                = azurerm_mssql_database.app_sql_database.id
    }
  }
}

module "management_database_access_script_execution" {
  source = "../post_deployment_script_sql"

  script_file_path = "${path.module}/define_db_admin_role.sql"
  database_name    = local.database_name
  database_server = {
    name                = var.app_sql_server.name
    resource_group_name = var.app_sql_server.resource_group_name
    fqdn                = var.app_sql_server.fqdn
  }
  additional_triggers = {
    security_group_name = module.db_management_group.group.display_name
  }
  sql_arguments = "security_group_name=${module.db_management_group.group.display_name},database_name=${local.database_name}"
}
