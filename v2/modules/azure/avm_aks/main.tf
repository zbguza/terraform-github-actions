module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"
}

resource "azurerm_role_assignment" "acr" {
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  skip_service_principal_aad_check = true
}

resource "azurerm_kubernetes_cluster" "this" {
  location                          = var.location_name.full
  name                              = local.full_name #custom: using locals for name that follows SpendLab's naming convention
  resource_group_name               = var.resource_group_name
  automatic_channel_upgrade         = "patch"
  azure_policy_enabled              = true
  dns_prefix                        = local.identifier
  kubernetes_version                = var.kubernetes_version
  local_account_disabled            = false
  node_os_channel_upgrade           = "NodeImage"
  oidc_issuer_enabled               = true
  private_cluster_enabled           = true
  role_based_access_control_enabled = true
  sku_tier                          = "Standard"
  tags                              = var.tags
  #Enable workload identity if any managed identity objects have workload identity settings enabled (since this setting applies to the whole cluster)
  workload_identity_enabled = anytrue([for v in var.managed_identities : v.workload_identity_settings.enabled])

  default_node_pool {
    name                        = local.system_node_pool.system.name
    vm_size                     = local.system_node_pool.system.vm_size
    enable_auto_scaling         = var.auto_scaling_settings.enable_auto_scaling
    enable_host_encryption      = var.enable_host_encryption
    min_count                   = var.auto_scaling_settings.enable_auto_scaling ? var.auto_scaling_settings.min_count : null
    node_count                  = 1
    orchestrator_version        = var.orchestrator_version
    os_sku                      = "Ubuntu"
    tags                        = merge(var.tags, var.agents_tags, { "pool_name" = local.system_node_pool.system.name })
    vnet_subnet_id              = var.subnet_id_nodes[0]
    zones                       = try([for zone in local.regions_by_name_or_display_name[var.location_name.full].zones : zone], null)
    temporary_name_for_rotation = "rota${substr(local.system_node_pool.system.name, 0, 3)}"

    #explictly set max_surge to 10% since not setting it will trigger changes in
    #plan, see
    #https://github.com/hashicorp/terraform-provider-azurerm/issues/24020
    upgrade_settings {
      max_surge = "10%"
    }
  }

  auto_scaler_profile {
    balance_similar_node_groups = true
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.rbac_aad_admin_group_object_ids
    azure_rbac_enabled     = var.rbac_aad_azure_rbac_enabled
    managed                = true
    tenant_id              = var.rbac_aad_tenant_id
  }

  ## Resources that only support UserAssigned
  dynamic "identity" {
    for_each = var.managed_identities
    content {
      type         = identity.value.type
      identity_ids = [identity.value.resource_id]
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  monitor_metrics {
    annotations_allowed = try(var.monitor_metrics.annotations_allowed, null)
    labels_allowed      = try(var.monitor_metrics.labels_allowed, null)
  }

  network_profile {
    network_plugin    = "azure" #using azure-based plugin (i.e. no kubenet)
    load_balancer_sku = "standard"
    network_policy    = "azure" #CNI policy, using azure-based CNI (i.e. no Cilium or Calico)
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  lifecycle {
    ignore_changes = [
      kubernetes_version
    ]
  }
}

# resource "kubernetes_namespace" "spendproof" {
#   metadata {
#     name = "spendproof"
#   }
# }

# #Create service account for federated workload identity
# resource "kubernetes_service_account" "managed_identities" {
#   for_each = { for identity in var.managed_identities : identity.type => identity }

#   metadata {
#     name      = each.value.workload_identity_settings.service_account_name
#     namespace = each.value.workload_identity_settings.namespace
#     annotations = {
#       "azure.workload.identity/client-id" = each.value.principal_id
#     }
#   }

#   depends_on = [kubernetes_namespace.spendproof]
# }

resource "azurerm_federated_identity_credential" "federated_identity_credential" {
  for_each = { for identity in var.managed_identities : identity.type => identity }

  name                = each.value.workload_identity_settings.federated_identity_credential_name
  resource_group_name = var.resource_group_name
  parent_id           = each.value.resource_id
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.workload_identity_settings.namespace}:${each.value.workload_identity_settings.service_account_name}"
  audience            = ["api://AzureADTokenExchange"]
}

# The following null_resource is used to trigger the update of the AKS cluster when the kubernetes_version changes
# This is necessary because the azurerm_kubernetes_cluster resource ignores changes to the kubernetes_version attribute
# because AKS patch versions are upgraded automatically by Azure
# The kubernetes_version_keeper and aks_cluster_post_create resources implement a mechanism to force the update
# when the minor kubernetes version changes in var.kubernetes_version

resource "null_resource" "kubernetes_version_keeper" {
  triggers = {
    version = var.kubernetes_version
  }
}

resource "azapi_update_resource" "aks_cluster_post_create" {
  type = "Microsoft.ContainerService/managedClusters@2023-01-02-preview"
  body = jsonencode({
    properties = {
      kubernetesVersion = var.kubernetes_version
    }
  })
  resource_id = azurerm_kubernetes_cluster.this.id

  lifecycle {
    ignore_changes       = all
    replace_triggered_by = [null_resource.kubernetes_version_keeper.id]
  }
}

resource "azurerm_log_analytics_workspace_table" "this" {
  for_each = toset(local.log_analytics_tables)

  name         = each.value
  workspace_id = var.log_analytics_workspace_id
  plan         = "Basic"
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                           = "Log all to LAW"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_destination_type = "Dedicated"
  log_analytics_workspace_id     = var.log_analytics_workspace_id

  # Kubernetes API Server
  enabled_log {
    category = "kube-apiserver"
  }
  # Kubernetes Audit
  enabled_log {
    category = "kube-audit"
  }
  # Kubernetes Audit Admin Logs
  enabled_log {
    category = "kube-audit-admin"
  }
  # Kubernetes Controller Manager
  enabled_log {
    category = "kube-controller-manager"
  }
  # Kubernetes Scheduler
  enabled_log {
    category = "kube-scheduler"
  }
  #Kubernetes Cluster Autoscaler
  enabled_log {
    category = "cluster-autoscaler"
  }
  #Kubernetes Cloud Controller Manager
  enabled_log {
    category = "cloud-controller-manager"
  }
  #guard
  enabled_log {
    category = "guard"
  }
  #csi-azuredisk-controller
  enabled_log {
    category = "csi-azuredisk-controller"
  }
  #csi-azurefile-controller
  enabled_log {
    category = "csi-azurefile-controller"
  }
  #csi-snapshot-controller
  enabled_log {
    category = "csi-snapshot-controller"
  }
  metric {
    category = "AllMetrics"
  }
}

#Enabling Container insights with Data Collection Rule
#https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=terraform#enable-container-insights
#https://github.com/microsoft/Docker-Provider/tree/ci_prod/scripts/onboarding/aks/onboarding-msi-terraform-syslog
resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = local.monitor_data_collection_rule_name
  resource_group_name = var.resource_group_name
  location            = var.location_name.full

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = var.log_analytics_workspace_name
    }
  }

  data_flow {
    streams      = var.streams
    destinations = [var.log_analytics_workspace_name]
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = [var.log_analytics_workspace_name]
  }

  data_sources {
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = var.syslog_facilities
      log_levels     = var.syslog_levels
      name           = "sysLogsDataSource"
    }

    extension {
      streams        = var.streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : var.data_collection_interval,
          "namespaceFilteringMode" : var.namespace_filtering_mode_for_data_collection,
          "namespaces" : var.namespaces_for_data_collection
          "enableContainerLogV2" : var.enableContainerLogV2
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  description = "DCR for Azure Monitor Container Insights"
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_kubernetes_cluster.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}


# Creating node pools for AKS cluster.
resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = { for idx, pool in local.non_system_node_pools : idx => pool }

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  name                  = "np${each.value.name}"
  vm_size               = each.value.vm_size
  enable_auto_scaling   = true
  max_count             = each.value.max_count
  min_count             = each.value.min_count
  orchestrator_version  = each.value.orchestrator_version
  os_sku                = each.value.os_sku
  tags                  = var.tags
  vnet_subnet_id        = var.subnet_id_nodes[index(keys(local.non_system_node_pools), each.value.name) + 1]
  zones                 = each.value.zones

  depends_on = [azapi_update_resource.aks_cluster_post_create]
}



# ingress-controller for applications
# module "ingress_controller" {
#   source = "../../../../v2/aks_modules/services/ingress_controller"

#   node_pool_name = local.system_node_pool.system.name
# }



# These resources allow the use of consistent local data files,and semver versioning
data "local_file" "compute_provider" {
  filename = "${path.module}/data/microsoft.compute_resourceTypes.json"
}

data "local_file" "locations" {
  filename = "${path.module}/data/locations.json"
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_cpu_alert" {
  name                = local.aks_cpu_alert_name
  resource_group_name = var.resource_group_name
  location            = var.location_name.full
  scopes              = [var.log_analytics_workspace_id]
  description         = "Alert for CPU usage exceeding ${local.cpu_treshold}% in ${azurerm_kubernetes_cluster.this.name} AKS cluster"

  criteria {
    query = <<-KQL
        AzureMetrics
        | where Resource == toupper("${azurerm_kubernetes_cluster.this.name}")
        | where MetricName == "node_cpu_usage_percentage" and Average > ${local.cpu_treshold}
      KQL

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_ram_alert" {
  name                = local.aks_ram_alert_name
  resource_group_name = var.resource_group_name
  location            = var.location_name.full
  scopes              = [var.log_analytics_workspace_id]
  description         = "Alert for RAM usage exceeding ${local.ram_treshold}% in ${azurerm_kubernetes_cluster.this.name} AKS cluster"

  criteria {
    query = <<-KQL
        AzureMetrics
        | where Resource == toupper("${azurerm_kubernetes_cluster.this.name}")
        | where MetricName == "node_memory_working_set_percentage" and Average > ${local.ram_treshold}
      KQL

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
}



resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pod_errors_alert" {
  for_each = { for idx, pool in var.node_pools : idx => pool }

  name                = replace(local.aks_pod_alert_name, "[pods]", "${each.value.name}")
  location            = var.location_name.full
  resource_group_name = var.resource_group_name
  description         = "Alert pods experience error in node pool ${each.value.name} for ${azurerm_kubernetes_cluster.this.name} AKS cluster"
  enabled             = true

  scopes = [var.log_analytics_workspace_id]

  criteria {
    query = <<-KQL
      KubeMonAgentEvents
      | where ClusterName == "${azurerm_kubernetes_cluster.this.name}"
      | extend NodePool = split(trim_start('aks-np',Computer), '-')[0]
      | where NodePool == "${each.value.name}" and Message != "No errors"
      | summarize NumberOfMessages = count() by tostring(NodePool)
    KQL

    time_aggregation_method = "Average"
    threshold               = 0
    operator                = "GreaterThan"
    metric_measure_column   = "NumberOfMessages"
  }

  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
}


resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_node_availability_alert" {
  for_each = { for idx, pool in var.node_pools : idx => pool }

  name                = replace(local.aks_node_alert_name, "[node]", "${each.value.name}")
  location            = var.location_name.full
  resource_group_name = var.resource_group_name
  description         = "Alert when number of running pods in node pool ${each.value.name} for ${azurerm_kubernetes_cluster.this.name} AKS cluster falls below threshold"
  enabled             = true

  scopes = [var.log_analytics_workspace_id]

  criteria {
    query = <<-KQL
      InsightsMetrics
      | extend NodePool = split(trim_start('aks-',Computer), '-')[0]
      | where parse_json(Tags)['container.azm.ms/clusterName'] == "${azurerm_kubernetes_cluster.this.name}"
      | where NodePool == '${each.value.name}' and Name == "kubelet_running_pods"
      | summarize AvgAvailability = avg(Val) by bin(TimeGenerated, 5m), Name
    KQL

    time_aggregation_method = "Average"
    threshold               = 1
    operator                = "LessThan"
    metric_measure_column   = "AvgAvailability"
  }

  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pod_availability_alert" {
  name                = replace(local.aks_pod_alert_name, "[pods]", "all")
  location            = var.location_name.full
  resource_group_name = var.resource_group_name
  description         = "Alert for unavailable pods in AKS cluster ${azurerm_kubernetes_cluster.this.name}"
  enabled             = true

  scopes = [var.log_analytics_workspace_id]

  criteria {
    query = <<-KQL
        KubePodInventory
        | where ClusterName == "${azurerm_kubernetes_cluster.this.name}" and PodStatus != "Running"
        | summarize CountUnavailablePods = count() by bin(TimeGenerated, 5m), Computer
        | where CountUnavailablePods > 0
      KQL

    time_aggregation_method = "Total"
    operator                = "GreaterThan"
    threshold               = 0
    metric_measure_column   = "CountUnavailablePods"
  }

  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
}
