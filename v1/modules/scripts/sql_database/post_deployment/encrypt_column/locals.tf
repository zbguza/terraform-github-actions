######################################################################################################################################################
#  Local variables                                                                                                                                   #
######################################################################################################################################################
locals {
  full_script_file_path = "${path.module}/encrypt_column.sql"

  json_content = file("${path.module}/encrypt_column.json")
  json_array   = tomap(jsondecode(local.json_content))
}
