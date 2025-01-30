######################################################################################################################################################
#  Resources                                                                                                                                         #
######################################################################################################################################################
### Executing column encryption script
resource "null_resource" "encrypt_column_script" {
  for_each = local.json_array

  triggers = {
    server_name               = each.value.serverName
    database_name             = each.value.databaseName
    schema_name               = each.value.schemaName
    table_name                = each.value.tableName
    column_name               = each.value.columnName
    encryption_key_vault_name = each.value.encryptionKeyVaultName
    database_master_key_name  = each.value.databaseMasterKeyName
    column_master_key_name    = each.value.columnMasterKeyName
    column_key_name           = each.value.columnKeyName
  }

  provisioner "local-exec" {
    command = <<EOT
        ${path.module}/Encrypt-SqlColumn.ps1 `
        -ScriptFilePath "${local.full_script_file_path}" `
        -SqlDatabaseName "${var.database_name}" `
        -ServerName "${var.database_server_FQDN}" `
        -ResourceGroupName "${var.database_server_resource_group_name}" `
        -UserLocalCredentials $true `
        -SqlArguments '${jsonencode(each.value)}'
    EOT

    interpreter = ["pwsh", "-Command"]
  }
}
