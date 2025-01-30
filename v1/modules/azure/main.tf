module "resource_types" {
  source = "../../../shared_resource_modules/azure/tag_resource_types"
}

## Networking references, defined in management layer.
data "azurerm_virtual_network" "vnet_weu" {
  resource_group_name = var.vnet_weu.resource_group_name
  name                = var.vnet_weu.name
}

data "azurerm_subnet" "subnet_private_endpoints" {
  name                 = var.vnet_weu.existing_subnet_names.snet_pe
  resource_group_name  = var.vnet_weu.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.vnet_weu.name
}

# DNS zone references, also defined in management layer.
data "azurerm_private_dns_zone" "dns_zone_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.rg_dns_zones_name
}

data "azurerm_private_dns_zone" "dns_zone_db" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.rg_dns_zones_name
}

data "azurerm_private_dns_zone" "dns_zone_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.rg_dns_zones_name
}

module "resource_group_data" {
  source = "../../../shared_resource_modules/azure/resource_group"

  workload      = "data"
  environment   = var.environment
  location_name = var.location_name

  common_tags = local.common_tags
}

#LAW
data "azurerm_resource_group" "rg_base_weu" {
  name = "rg-${var.company_name.short}-base-${var.location_name.short}-01"
}

data "azurerm_log_analytics_workspace" "law" {
  name                = "law-weu-base-001"
  resource_group_name = data.azurerm_resource_group.rg_base_weu.name
}

### SQL Server that holds application databases
data "azuread_user" "admin_users" {
  for_each            = { for idx, admins in var.sql_server_admins : idx => admins if can(regex("@", admins)) }
  user_principal_name = each.value
}

data "azuread_application" "admin_identities" {
  for_each     = { for idx, admins in var.sql_server_admins : idx => admins if !can(regex("@", admins)) }
  display_name = each.value
}

module "online_sql_server" {
  source = "./sql_server"

  company_name    = var.company_name
  owner           = var.owner
  environment     = var.environment
  location_name   = var.location_name
  subscription_id = var.subscription_id
  resource_group  = module.resource_group_data.resource_group

  blob_private_dns_zone_id = data.azurerm_private_dns_zone.dns_zone_blob.id
  sql_private_dns_zone_id  = data.azurerm_private_dns_zone.dns_zone_db.id

  pe_subnet_id = data.azurerm_subnet.subnet_private_endpoints.id

  mgt_law_id                          = data.azurerm_log_analytics_workspace.law.id
  server_administrators_group_members = concat(local.sql_admin_users, local.sql_admin_identities)

  whitelisted_ip_ranges = []

  common_tags = local.common_tags
}

# Read the pre-existing Spendproof dev team group so we can grant them read
# access to their database. Membership to this group is managed via PIM, so this
# isn't a permanent assignment (only becomes active when they activate their
# membership in PIM).
data "azuread_group" "spendproof_dev_team" {
  display_name = "SLT - SpendProof Dev team"
}

resource "null_resource" "install_powershell" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
        if [ "$(dpkg -l | awk '/powershell/ {print }'|wc -l)" -lt 1 ]; then
        wget -q https://github.com/PowerShell/PowerShell/releases/download/v7.5.0/powershell_7.5.0-1.deb_amd64.deb
        wget -q http://ftp.de.debian.org/debian/pool/main/i/icu/libicu67_67.1-7_amd64.deb
        dpkg -i libicu67_67.1-7_amd64.deb 
        dpkg -i powershell_7.5.0-1.deb_amd64.deb
        apt-get install -f
        pwsh -c "Install-Module -Name Az.Accounts -Force" > /dev/null
        pwsh -c "Install-Module -Name SqlServer -Force" > /dev/null
        fi
    EOT
  }
}


## Spendproof database
module "online_db_spendproof" {
  source = "./sql_database"

  company_name                = var.company_name
  environment                 = var.environment
  location_name               = var.location_name
  resource_group_name         = module.online_sql_server.app_sql_server.resource_group_name
  application_short_name      = "sp"
  app_sql_server              = module.online_sql_server.app_sql_server
  sql_database                = var.spendproof_sql_database
  mgt_law_id                  = data.azurerm_log_analytics_workspace.law.id
  db_readers_group_members    = [data.azuread_group.spendproof_dev_team.id]
  db_writers_group_members    = [module.aks_umi_spendproof.user_assigned_identity.principal_id]
  db_management_group_members = []

  common_tags = local.common_tags
  depends_on = [
    null_resource.install_powershell
  ]
}

## Disap database
module "online_db_disap" {
  source = "./sql_database"

  company_name                = var.company_name
  environment                 = var.environment
  location_name               = var.location_name
  resource_group_name         = module.online_sql_server.app_sql_server.resource_group_name
  application_short_name      = "disap"
  app_sql_server              = module.online_sql_server.app_sql_server
  sql_database                = var.disap_sql_database
  mgt_law_id                  = data.azurerm_log_analytics_workspace.law.id
  db_readers_group_members    = []
  db_writers_group_members    = []
  db_management_group_members = []

  common_tags = local.common_tags
  depends_on = [
    null_resource.install_powershell
  ]
}

## Statements database
module "online_db_stmnt" {
  source = "./sql_database"

  company_name                = var.company_name
  environment                 = var.environment
  location_name               = var.location_name
  resource_group_name         = module.online_sql_server.app_sql_server.resource_group_name
  application_short_name      = "stmnt"
  app_sql_server              = module.online_sql_server.app_sql_server
  sql_database                = var.stmt_sql_database
  mgt_law_id                  = data.azurerm_log_analytics_workspace.law.id
  db_readers_group_members    = []
  db_writers_group_members    = []
  db_management_group_members = []

  common_tags = local.common_tags
  depends_on = [
    null_resource.install_powershell
  ]
}

### AKS compute cluster
## Resource group for AKS.
module "resource_group_aks" {
  source = "../../../shared_resource_modules/azure/resource_group"

  workload      = "aks"
  environment   = var.environment
  location_name = var.location_name

  common_tags = local.common_tags
}

data "azurerm_network_security_group" "nsg_global" {
  name                = "nsg-${var.company_name.short}-mgt-global-${var.location_name.short}-01"
  resource_group_name = data.azurerm_resource_group.rg_base_weu.name
}

## Set subnets for AKS nodes.
module "subnet_aks_nodes" {
  source = "../../../shared_resource_modules/azure/subnet"

  for_each = local.subnet_aks_nodes_cirds

  company_name        = var.company_name
  vnet_name           = var.vnet_weu.name
  resource_group_name = var.vnet_weu.resource_group_name
  location_name       = var.location_name
  environment         = var.environment
  workload            = trimprefix(replace(each.key, "_", "-"), "snet-aks-")
  global_nsg = {
    enabled = true
    id      = data.azurerm_network_security_group.nsg_global.id
  }

  subnet_range = each.value

  common_tags = local.common_tags
}

module "subnet_aks_pods" {
  source = "../../../shared_resource_modules/azure/subnet"

  for_each = local.subnet_aks_pods_cidrs

  company_name        = var.company_name
  vnet_name           = var.vnet_weu.name
  resource_group_name = var.vnet_weu.resource_group_name
  location_name       = var.location_name
  environment         = var.environment
  workload            = trimprefix(replace(each.key, "_", "-"), "snet-aks-")
  global_nsg = {
    enabled = true
    id      = data.azurerm_network_security_group.nsg_global.id
  }

  subnet_range = each.value

  common_tags = local.common_tags
}

#Extra for AKS: to use encryption at host, we need to register the feature (not
#on by default). This can take a while to complete and there is no way to check
#or wait for it, so this may result in failing AKS cluster deployment the first
#time this is run.
resource "azapi_update_resource" "encryptionathost" {
  type        = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Compute/subscriptionFeatureRegistrations/encryptionathost"
  body = jsonencode({
    properties = {}
  })
}

data "azurerm_container_registry" "acr" {
  name                = "cr${var.company_name.short}${var.location_name.short}01"
  resource_group_name = data.azurerm_resource_group.rg_base_weu.name
}

module "aks_umi_spendproof" {
  source = "../../../shared_resource_modules/azure/user_managed_identity"

  target_resource_name = "aks"
  application_name     = "spendproof"
  environment          = var.environment
  location_name        = var.location_name
  resource_group_name  = module.resource_group_aks.resource_group.name
  common_tags          = local.common_tags
}

module "aks_compute_cluster" {
  source = "./avm_aks"

  company_name  = var.company_name
  environment   = var.environment
  location_name = var.location_name

  kubernetes_version  = "1.29"
  resource_group_name = module.resource_group_aks.resource_group.name

  #subnet_id_pods             = module.subnet_aks_pods.subnet.id

  subnet_id_nodes              = tolist([for s in module.subnet_aks_nodes : s.subnet.id])
  log_analytics_workspace_id   = data.azurerm_log_analytics_workspace.law.id
  log_analytics_workspace_name = data.azurerm_log_analytics_workspace.law.name
  acr_id                       = data.azurerm_container_registry.acr.id

  node_pools = var.node_pools

  managed_identities = [
    {
      resource_id  = module.aks_umi_spendproof.user_assigned_identity.id
      principal_id = module.aks_umi_spendproof.user_assigned_identity.principal_id
      type         = "UserAssigned"
      workload_identity_settings = {
        enabled                            = true
        namespace                          = "spendproof"
        federated_identity_credential_name = "workload-identity-federated-credential-spendproof"
        service_account_name               = "workload-identity-service-account-spendproof"
      }
    }
  ]

  tags = merge(local.common_tags,
    { resource_type = module.resource_types.values.compute },
    { resource_group = module.resource_group_aks.resource_group.name }
  )

  agents_tags = merge(local.common_tags,
    { resource_type = module.resource_types.values.compute },
    { resource_group = module.resource_group_aks.resource_group.name }
  )
}

# For the storage account that will be used by applications (e.g. for storing
# attachments), we will simply re-use the existing storage account that is made
# as part of the Database server module. This was meant as the overall storage
# account for that environment anyway, so this fits well.
data "azurerm_storage_account" "storage_account_application" {
  name                = "st${var.company_name.short}${var.environment}${var.location_name.short}01"
  resource_group_name = module.resource_group_data.resource_group.name
}

# Provision a key vault for application use (e.g. storing SQL login
# credentials). We'll also store this in the same resource group as the AKS
# cluster.
module "key_vault_application" {
  source = "../../../shared_resource_modules/azure/key_vault"

  company_name    = var.company_name
  location_name   = var.location_name
  environment     = var.environment
  instance_number = "01"
  resource_group  = module.resource_group_aks.resource_group
  key_vault_sku   = "standard"

  private_endpoint_subnet_id = data.azurerm_subnet.subnet_private_endpoints.id
  private_dns_zone_ids       = [data.azurerm_private_dns_zone.dns_zone_kv.id]
  mgt_law_id                 = data.azurerm_log_analytics_workspace.law.id

  common_tags = local.common_tags
}

# Store the storage account access key in the key vault.
module "kv_secret_storage_account_access_key" {
  source = "../../../shared_resource_modules/azure/key_vault_secret"

  secret_name  = "storage-account-access-key"
  secret_value = data.azurerm_storage_account.storage_account_application.primary_access_key
  key_vault_id = module.key_vault_application.key_vault_id

  common_tags = merge(local.common_tags,
    { resource_group = module.resource_group_aks.resource_group.name }
  )
}

# Grant DevOps team secret reader access so they can use TF CLI locally
data "azuread_group" "devops" {
  display_name = "DevOps team"
}

module "role_assignments_writers" {
  source = "../../../shared_resource_modules/azure/avm_role_assignment"

  role_assignments_azure_resource_manager = {
    role_assignment = {
      principal_id         = data.azuread_group.devops.id
      role_definition_name = "Key Vault Secrets User"
      scope                = module.key_vault_application.key_vault_id
    }
  }
}
