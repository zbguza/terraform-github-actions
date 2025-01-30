######################################################################################################################################################
#  Module arguments                                                                                                                                  #
######################################################################################################################################################
variable "database_server_resource_group_name" {
  description = "The full name of the resource group where the databases for this module will be created."
  type        = string
}

variable "database_server_FQDN" {
  description = "The FQDN of the server, e.g. sql-my-server-001.database.windows.net."
  type        = string
}

variable "database_name" {
  type = string
}

variable "dependent_database_id" {
  type = string
}
