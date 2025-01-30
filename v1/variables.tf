variable "company_name" {
  type = object({
    full  = string,
    short = string
  })
}

variable "location_name" {
  description = "The location where to place all resources in this module."
  type = object({
    full  = string,
    short = string
  })
}

variable "owner" {
  description = "The username to set as owner in a tag on created resource (e.g. John.Doe@Spendlab.com)."
  type        = string
}

variable "environment" {
  description = "Application's environment."
  type        = string
}

variable "subscription_id" {
  description = "The Id of subscription on which resources are created."
  type        = string
}

variable "vnet_weu" {
  description = "WEU VNet resource generals."
  type = object({
    name                = string
    resource_group_name = string
    #Existing subnets are created by mgt project.
    existing_subnet_names = map(string) #key is subnet purpose (e.g. snet_pe), value is full subnet name (e.g. snet-pe-sl-weu-01).
    subnet_ranges_cidr    = map(string) #key is subnet purpose (e.g. snet_pe), value is subnet cidr (e.g. 10.1.1.0/24).
  })
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

variable "rg_dns_zones_name" {
  description = "The name of the resource group that contains the private DNS zones."
  type        = string
}

variable "sql_server_admins" {
  description = "List of user principals that will have Administrator rights on SQL Server."
  type        = list(string)
}

variable "spendproof_sql_database" {
  description = "Spendproof SQL Database resource generals."
  type = object({
    storage_account_type = optional(string),
    sku_name             = optional(string),
    max_size_gb          = optional(string)
  })
}

variable "disap_sql_database" {
  description = "Disap SQL Database resource generals."
  type = object({
    storage_account_type = optional(string),
    sku_name             = optional(string),
    max_size_gb          = optional(string)
  })
}

variable "stmt_sql_database" {
  description = "Statement SQL Database resource generals."
  type = object({
    storage_account_type = optional(string),
    sku_name             = optional(string),
    max_size_gb          = optional(string)
  })
}
