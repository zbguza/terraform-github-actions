######################################################################################################################################################
#  Local variables                                                                                                                                   #
######################################################################################################################################################
locals {

  application_short_name              = var.application_short_name != "" ? replace(var.application_short_name, "^-", "") : ""
  application_short_name_name_segment = var.application_short_name != "" ? (startswith(var.application_short_name, "-") ? var.application_short_name : "-${var.application_short_name}") : ""
  database_name                       = "sqldb-${var.company_name.short}${local.application_short_name_name_segment}-${var.environment}-${var.location_name.short}-${var.sqldb_name_count_suffix}"

  database_administrators_rbac_names = ["SQL DB Contributor", "SQL Security Manager"]

  db_reader_script_file_path = abspath("${path.module}/post_deployment_scripts/db_reader_access.sql")
  db_writer_script_file_path = abspath("${path.module}/post_deployment_scripts/db_writer_access.sql")
  db_admin_script_file_path  = abspath("${path.module}/post_deployment_scripts/db_admin_access.sql")
}
