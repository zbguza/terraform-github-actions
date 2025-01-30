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

variable "environment" {
  description = "Application's environment."
  type        = string
}

variable "instance_count_suffix" {
  description = "Optional value to use as suffix for the database name instead of the default 01."
  type        = string
  default     = "01"
}

variable "subnet_id_nodes" {
  description = "List of subnet ids to use for the AKS cluster's nodes."
  type        = list(string)
}

variable "enable_host_encryption" {
  description = "Whether to enable host encryption for the AKS cluster."
  type        = bool
  default     = false
}

variable "auto_scaling_settings" {
  description = "(optional) Settings for the auto scaling of the AKS cluster."
  type = object({
    enable_auto_scaling = bool
    max_count           = number
    min_count           = number
  })
  default = {
    enable_auto_scaling = false
    max_count           = 9
    min_count           = 3
  }
}

variable "acr_id" {
  description = "The ID of the Azure Container Registry to use for the AKS cluster (the cluster will be assigned the 'AcrPull' role on this ACR)."
  type        = string
}
