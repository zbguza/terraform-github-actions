# General resource variables
company_name = {
  full  = "SpendLab"
  short = "sl"
}
location_name = {
  full  = "West Europe",
  short = "weu"
}
environment = "qa"
owner       = "SpendLab DevOps Team"

#TODO make dynamic
subscription_id = "f44e9ef6-afad-4689-83b8-70eece44356b"

# Networking 
vnet_weu = {
  name                = "vnet-sl-spoke-weu-01"
  resource_group_name = "rg-sl-vnet-weu-01"

  existing_subnet_names = {
    snet_pe = "snet-pe-sl-qa-weu-01"
  }

  # Network segmentation in ADR: https://www.notion.so/spendlab/Networking-infra-v2-a71bc73f1d724bd995a9a89315ab2429
  subnet_ranges_cidr = {
    # AKS node pool subnets
    snet_aks_node_spendproof = "10.1.127.0/26"
    snet_aks_node_dagster    = "10.1.127.64/26"
    snet_aks_node_internal   = "10.1.127.128/26"
    snet_aks_node_system     = "10.1.127.192/26"

    # AKS pod subnets
    snet_aks_pod_spendproof = "10.1.72.0/24"
    snet_aks_pod_dagster    = "10.1.74.0/24"
    snet_aks_pod_internal   = "10.1.77.0/24"
    snet_aks_pod_system     = "10.1.79.0/24"
    #snet_aks_pod_spendproof_ext = "10.1.73.0/24"    
    #snet_aks_pod_dagster_ext = "10.1.75.0/24"
    #snet_aks_pod_internal_ext = "10.1.76.0/24"    
    #snet_aks_pod_system_ext = "10.1.78.0/24"    
  }
}

# AKS QA node pools configuration
node_pools = {
  system = {
    name                 = "system"
    vm_size              = "Standard_DS2_v2"
    orchestrator_version = "1.29"
    max_count            = 1
    min_count            = 1
    os_sku               = "Ubuntu"
    mode                 = "User"
  },
  # internal = {
  #   name                 = "internal"
  #   vm_size              = "Standard_DS2_v2"
  #   orchestrator_version = "1.29"
  #   max_count            = 1
  #   min_count            = 1
  #   os_sku               = "Ubuntu"
  #   mode                 = "User"
  # },
  spendproof = {
    name                 = "spendproof"
    vm_size              = "Standard_DS2_v2"
    orchestrator_version = "1.29"
    max_count            = 1
    min_count            = 1
    os_sku               = "Ubuntu"
    mode                 = "User"
  },
  # dagster = {
  #   name                 = "dagster"
  #   vm_size              = "Standard_DS2_v2"
  #   orchestrator_version = "1.29"
  #   max_count            = 1
  #   min_count            = 1
  #   os_sku               = "Ubuntu"
  #   mode                 = "User"
  # }
}

rg_dns_zones_name = "rg-sl-con-weu-01"

sql_server_admins = [
  "dragan.skrinjar@spendlab.com",
  "djordje.novakovic@spendlab.com"
]

spendproof_sql_database = {
  storage_account_type = "Local",
  sku_name             = "Basic",
  max_size_gb          = 2
}

disap_sql_database = {
  storage_account_type = "Local",
  sku_name             = "Basic",
  max_size_gb          = 2
}

stmt_sql_database = {
  storage_account_type = "Local",
  sku_name             = "Basic",
  max_size_gb          = 2
}
