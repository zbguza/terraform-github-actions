# Main module for entire infrastructure (all platforms)

# Deploy Azure resources, variable values are defined in tfvars files
module "azure" {
  source = "./modules/azure"

  company_name            = var.company_name
  location_name           = var.location_name
  owner                   = var.owner
  environment             = var.environment
  subscription_id         = var.subscription_id
  sql_server_admins       = var.sql_server_admins
  spendproof_sql_database = var.spendproof_sql_database
  disap_sql_database      = var.disap_sql_database
  stmt_sql_database       = var.stmt_sql_database
  vnet_weu                = var.vnet_weu
  rg_dns_zones_name       = var.rg_dns_zones_name
  node_pools              = var.node_pools
}
