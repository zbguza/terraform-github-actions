#Disabled in favour of custom object, see locals_custom.tf
# variable "location" {
#   type        = string
#   description = "The Azure region where the resources should be deployed."
#   nullable    = false
# }

#Disabled in favour of custom naming convention, see locals_custom.tf
# variable "name" {
#   type        = string
#   description = "The name for the AKS resources created in the specified Azure Resource Group. This variable overwrites the 'prefix' var (The 'prefix' var will still be applied to the dns_prefix if it is set)"

#   validation {
#     condition     = can(regex("^[a-zA-Z0-9]$|^[a-zA-Z0-9][-_a-zA-Z0-9]{0,61}[a-zA-Z0-9]$", var.name))
#     error_message = "Check naming rules here https://learn.microsoft.com/en-us/rest/api/aks/managed-clusters/create-or-update?view=rest-aks-2023-10-01&tabs=HTTP"
#   }
# }

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
  nullable    = false
}

variable "agents_tags" {
  type        = map(string)
  default     = {}
  description = "(Optional) A mapping of tags to assign to the Node Pool."
}

variable "client_id" {
  type        = string
  default     = ""
  description = "(Optional) The Client ID (appId) for the Service Principal used for the AKS deployment"
  nullable    = false
}

variable "client_secret" {
  type        = string
  default     = ""
  description = "(Optional) The Client Secret (password) for the Service Principal used for the AKS deployment"
  nullable    = false
}

variable "key_vault_secrets_provider_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Whether to use the Azure Key Vault Provider for Secrets Store CSI Driver in an AKS cluster. For more details: https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver"
  nullable    = false
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Specify which Kubernetes release to use. Specify only minor version, such as '1.28'."
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
  Controls the Resource Lock configuration for this resource. The following properties can be specified:
  
  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
  DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the Log Analytics Workspace to use for the OMS agent as well as the diagnostic settings."
}

variable "log_analytics_workspace_name" {
  type        = string
  default     = null
  description = "(Optional) The name of the Log Analytics Workspace to use for the OMS agent as well as the diagnostic settings."
}

variable "streams" {
  default     = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory", "Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents", "Microsoft-InsightsMetrics", "Microsoft-ContainerInventory", "Microsoft-ContainerNodeInventory", "Microsoft-Perf"]
  description = "Specific data types collected by Azure Monitor's Container Insights."
}

variable "syslog_facilities" {
  type        = list(string)
  default     = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7"]
  description = "Each facility represents a type of system service or process that generates logs. local0–local7: Customizable facilities for user-defined purposes, often used by applications."
}

variable "syslog_levels" {
  type        = list(string)
  default     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
  description = "List of syslog severity levels to specify the types of log messages collected."
}

variable "data_collection_interval" {
  default     = "1m"
  description = "The frequency at which data is collected."
}

variable "namespace_filtering_mode_for_data_collection" {
  default     = "Off"
  description = "Specifies the mode for namespace filtering during data collection. Options include 'Off' (no filtering) or 'Include' (collect data only from specified namespaces)."
}

variable "namespaces_for_data_collection" {
  default     = ["kube-system"]
  description = "List of Kubernetes namespaces from which data will be collected. Only applicable when namespace filtering is enabled."
}

variable "enableContainerLogV2" {
  default     = true
  description = "Boolean flag to enable ContainerLogV2 schema. If set to true, the stdout/stderr Logs are ingested to ContainerLogV2 table."
}

variable "monitor_metrics" {
  type = object({
    annotations_allowed = optional(string)
    labels_allowed      = optional(string)
  })
  default     = null
  description = <<-EOT
  (Optional) Specifies a Prometheus add-on profile for the Kubernetes Cluster
  object({
    annotations_allowed = "(Optional) Specifies a comma-separated list of Kubernetes annotation keys that will be used in the resource's labels metric."
    labels_allowed      = "(Optional) Specifies a comma-separated list of additional Kubernetes label keys that will be used in the resource's labels metric."
  })
EOT
}

variable "pod_cidr" {
  type        = string
  default     = null
  description = "(Optional) The CIDR to use for pod IPs in the Kubernetes cluster. Should only ever be set when networking_plugin_mode is 'overlay' and will require a large range that doesn't conflict with the node CIDR range (e.g. if node range is 10.1.0.0/24, the pod_cidr must be a range such as 192.168.0.0/16). Changing this forces a new resource to be created."
}

variable "node_pools" {
  type = map(object({
    name                 = string
    vm_size              = string
    orchestrator_version = string
    # do not add nodecount because we enforce the use of auto-scaling
    max_count       = optional(number)
    min_count       = optional(number)
    os_sku          = optional(string)
    mode            = optional(string)
    os_disk_size_gb = optional(number, null)
    tags            = optional(map(string), {})
    zones           = optional(set(string))
  }))
  default     = {}
  description = <<-EOT
A map of node pools that need to be created and attached on the Kubernetes cluster. The key of the map can be the name of the node pool, and the key must be static string. The value of the map is a `node_pool` block as defined below:
map(object({
  name                 = (Required) The name of the Node Pool which should be created within the Kubernetes Cluster. Changing this forces a new resource to be created. A Windows Node Pool cannot have a `name` longer than 6 characters. A random suffix of 4 characters is always added to the name to avoid clashes during recreates.
  vm_size              = (Required) The SKU which should be used for the Virtual Machines used in this Node Pool. Changing this forces a new resource to be created.
  orchestrator_version = (Required) The version of Kubernetes which should be used for this Node Pool. Changing this forces a new resource to be created.
  max_count            = (Optional) The maximum number of nodes which should exist within this Node Pool. Valid values are between `0` and `1000` and must be greater than or equal to `min_count`.
  min_count            = (Optional) The minimum number of nodes which should exist within this Node Pool. Valid values are between `0` and `1000` and must be less than or equal to `max_count`.
  os_sku               = (Optional) Specifies the OS SKU used by the agent pool. Possible values include: `Ubuntu`, `CBLMariner`, `Mariner`, `Windows2019`, `Windows2022`. If not specified, the default is `Ubuntu` if OSType=Linux or `Windows2019` if OSType=Windows. And the default Windows OSSKU will be changed to `Windows2022` after Windows2019 is deprecated. Changing this forces a new resource to be created.
  mode                 = (Optional) Should this Node Pool be used for System or User resources? Possible values are `System` and `User`. Defaults to `User`.
  os_disk_size_gb      = (Optional) The Agent Operating System disk size in GB. Changing this forces a new resource to be created.
  tags                 = (Optional) A mapping of tags to assign to the resource. At this time there's a bug in the AKS API where Tags for a Node Pool are not stored in the correct case - you [may wish to use Terraform's `ignore_changes` functionality to ignore changes to the casing](https://www.terraform.io/language/meta-arguments/lifecycle#ignore_changess) until this is fixed in the AKS API.
  zones                = (Optional) Specifies a list of Availability Zones in which this Kubernetes Cluster Node Pool should be located. Changing this forces a new Kubernetes Cluster Node Pool to be created.
}))

Example input:
```terraform 
  node_pools = {
    workload = {
      name                 = "workload"
      vm_size              = "Standard_D2d_v5"
      orchestrator_version = "1.28"
      max_count            = 110
      min_count            = 2
      os_sku               = "Ubuntu"
      mode                 = "User"
    },
    ingress = {
      name                 = "ingress"
      vm_size              = "Standard_D2d_v5"
      orchestrator_version = "1.28"
      max_count            = 4
      min_count            = 2
      os_sku               = "Ubuntu"
      mode                 = "User"
    }
  }
  ```
EOT
  nullable    = false
}

variable "orchestrator_version" {
  type        = string
  default     = null
  description = "Specify which Kubernetes release to use. Specify only minor version, such as '1.28'."
}

variable "rbac_aad_admin_group_object_ids" {
  type        = list(string)
  default     = null
  description = "Object ID of groups with admin access."
}

variable "rbac_aad_azure_rbac_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Is Role Based Access Control based on Azure AD enabled?"
}

variable "rbac_aad_tenant_id" {
  type        = string
  default     = null
  description = "(Optional) The Tenant ID used for Azure Active Directory Application. If this isn't specified the Tenant ID of the current Subscription is used."
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "managed_identities" {
  type = list(object({
    resource_id  = string
    principal_id = string
    type         = string
    workload_identity_settings = optional(object({
      enabled                            = optional(bool, false)
      namespace                          = string
      federated_identity_credential_name = string
      service_account_name               = string
    }))
  }))
  validation {
    condition     = alltrue(flatten([for identity in var.managed_identities : identity.type == "SystemAssigned" || identity.type == "UserAssigned"]))
    error_message = "The type must be either 'SystemAssigned' or 'UserAssigned'."
  }
}
