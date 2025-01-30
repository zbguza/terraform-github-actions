locals {

  #identifier, used to reference the cluster by name in supporting resources (e.g. as dns_prefix)
  identifier = "${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"
  #full name, used for the actual cluster resource name
  full_name                                     = "aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"
  monitor_data_collection_rule_name             = "dcr-aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"
  monitor_data_collection_rule_association_name = "dcra-aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"

  aks_app_insights_name = "appi-${local.full_name}"
  aks_node_alert_name   = "node-[node]-alert-aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"
  aks_pod_alert_name    = "pod-[pods]-alert-aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"

  aks_cpu_alert_name = "cpu-alert-aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"
  cpu_treshold       = 90

  aks_ram_alert_name = "ram-alert-aks-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.instance_count_suffix}"
  ram_treshold       = 90
}
