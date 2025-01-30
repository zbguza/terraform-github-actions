locals {
  common_tags = {
    company     = var.company_name.full
    owner       = var.owner
    environment = var.environment
    location    = var.location_name.full

    resource_group = "N/A" #default value, to be overridden in most cases
    resource_type  = "N/A" #default value, to be overridden in most cases
  }
}

locals {
  subnet_aks_nodes_cirds = { for key, value in var.vnet_weu.subnet_ranges_cidr :
    key => value
    if startswith(key, "snet_aks_node_")
  }
}

locals {
  subnet_aks_pods_cidrs = { for key, value in var.vnet_weu.subnet_ranges_cidr :
    key => value
    if startswith(key, "snet_aks_pod_")
  }
}

locals {
  sql_admin_users      = [for user in data.azuread_user.admin_users : user.object_id]
  sql_admin_identities = [for identity in data.azuread_application.admin_identities : identity.object_id]
}
