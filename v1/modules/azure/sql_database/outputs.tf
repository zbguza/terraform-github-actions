######################################################################################################################################################
# Output variables                                                                                                                                   #
######################################################################################################################################################
output "sql_id" {
  value = azurerm_mssql_database.app_sql_database.id
}
