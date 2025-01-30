locals {
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

locals {
  locations_cached_or_live        = data.local_file.locations.content
  regions_by_display_name         = { for v in local.regions_recommended_or_not : v.display_name => v }
  regions_by_name                 = { for v in local.regions_recommended_or_not : v.name => v }
  regions_by_name_or_display_name = merge(local.regions_by_display_name, local.regions_by_name)
  regions_data_merged = [
    for v in jsondecode(local.locations_cached_or_live).value :
    merge(
      {
        name               = v.name
        display_name       = v.displayName
        paired_region_name = try(one(v.metadata.pairedRegion).name, null)
        geography          = v.metadata.geography
        geography_group    = v.metadata.geographyGroup
        recommended        = v.metadata.regionCategory == "Recommended"
      },
      {
        zones = sort(lookup(local.regions_to_zones_map, v.displayName, []))
      }
    ) if v.metadata.regionType == "Physical"
  ]
  # Filter out regions that are not recommended
  regions_recommended_or_not          = [for v in local.regions_data_merged : v if v.recommended]
  regions_to_zones_map                = { for v in local.regions_zonemappings : v.location => v.zones }
  regions_zonemappings                = flatten([for v in jsondecode(local.regions_zonemappings_cached_or_live).resourceTypes : v.zoneMappings if v.resourceType == "virtualMachines"])
  regions_zonemappings_cached_or_live = data.local_file.compute_provider.content
}
locals {
  # Flatten a list of var.node_pools and zones
  node_pools = flatten([
    for pool in var.node_pools : [
      for zone in try(local.regions_by_name_or_display_name[var.location_name.full].zones, [""]) : {
        # concatenate name and zone trim to 12 characters
        name                 = "${substr(pool.name, 0, 11)}${zone}"
        vm_size              = pool.vm_size
        orchestrator_version = pool.orchestrator_version
        max_count            = pool.max_count
        min_count            = pool.min_count
        os_sku               = pool.os_sku
        zone                 = zone
      }
    ]
  ])
}

locals {
  log_analytics_tables = ["AKSAudit", "AKSAuditAdmin", "AKSControlPlane", "ContainerLogV2"]
}

locals {
  system_node_pool = { for k, v in var.node_pools : k => v if k == "system" }
}

locals {
  non_system_node_pools = { for k, v in var.node_pools : k => v if k != "system" }
}
