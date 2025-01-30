######################################################################################################################################################
# Output variables                                                                                                                                   #
######################################################################################################################################################
output "app_sql_server" {
  value = {
    id                  = try(azurerm_mssql_server.online_sql_server.id, null)
    name                = azurerm_mssql_server.online_sql_server.name
    resource_group_name = azurerm_mssql_server.online_sql_server.resource_group_name
    fqdn                = try(azurerm_mssql_server.online_sql_server.fully_qualified_domain_name, null)
  }
}
