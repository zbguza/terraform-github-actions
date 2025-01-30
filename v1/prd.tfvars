# General resource variables
company_name = {
  full  = "SpendLab"
  short = "sl"
}
location_name = {
  full  = "West Europe",
  short = "weu"
}
environment = "prd"
owner       = "SpendLab DevOps Team"

subscription_id = "f44e9ef6-afad-4689-83b8-70eece44356b"

# Networking 
vnet_weu = {
  name                = "vnet-sl-spoke-weu-01"
  resource_group_name = "rg-sl-vnet-weu-01"

  existing_subnet_names = {
    snet_pe = "snet-pe-sl-prd-weu-01"
  }

  # Network segmentation in ADR: https://www.notion.so/spendlab/Networking-infra-v2-a71bc73f1d724bd995a9a89315ab2429
  subnet_ranges_cidr = {
    # AKS node pool subnets
    snet_aks_node_spendproof = "10.1.63.0/26"
    snet_aks_node_dagster    = "10.1.63.64/26"
    snet_aks_node_internal   = "10.1.63.128/26"
    snet_aks_node_system     = "10.1.63.192/26"
    #snet_aks_node_spendproof_ext = "10.1.63.216/29"
    #snet_aks_node_dagster = "10.1.63.224/28"
    #snet_aks_node_dagster_ext = "10.1.63.240/29"

    # AKS pod subnets
    snet_aks_pod_spendproof = "10.1.8.0/24"
    snet_aks_pod_dagster    = "10.1.10.0/24"
    snet_aks_pod_internal   = "10.1.13.0/24"
    snet_aks_pod_system     = "10.1.15.0/24"
    #snet_aks_pod_spendproof_ext = "10.1.9.0/24"    
    #snet_aks_pod_dagster_ext = "10.1.11.0/24"
    #snet_aks_pod_internal_ext = "10.1.12.0/24"    
    #snet_aks_pod_system_ext = "10.1.14.0/24"    
  }
}

# AKS PRD node pools configuration
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
