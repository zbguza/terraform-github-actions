######################################################################################################################################################
#  Local variables                                                                                                                                   #
######################################################################################################################################################
locals {
  sql_server_name = "sql-${var.company_name.short}-${var.environment}-${var.location_name.short}-${var.sql_server_name_count_suffix}"

  server_administrators_rbac_names = ["SQL Server Contributor", "SQL Security Manager"]
}
