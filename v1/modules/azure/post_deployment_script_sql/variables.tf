variable "database_name" {
  type = string
}

variable "database_server" {
  description = "Server object containing the name, resource group name and the FQDN of the server (e.g. sql-my-server-001.database.windows.net)"
  type = object({
    name                = string
    resource_group_name = string
    fqdn                = string
  })
}

variable "additional_triggers" {
  description = "(Optional) Additional triggers for the null resource. By default, the server name and database name are used as triggers."
  type        = map(string)
  default     = {}
}

variable "script_file_path" {
  type = string
}

variable "sql_arguments" {
  description = "(Optional) A string of arguments to pass to the SQL script, e.g. 'security_group_name=my_group'. Does not need any quotes."
  type        = string
  default     = ""
}
