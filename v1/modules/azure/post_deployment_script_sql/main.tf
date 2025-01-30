resource "null_resource" "apply_db_script" {
  triggers = merge({
    server_name   = var.database_server.name
    database_name = var.database_name
    script_change = filemd5("${var.script_file_path}")
  }, var.additional_triggers)

  provisioner "local-exec" {
    command = <<EOT
        ${path.module}/execute_sql_with_sqlcmd.ps1 `
        -ScriptFilePath "${var.script_file_path}" `
        -SqlDatabaseName "${var.database_name}" `
        -ServerName "${var.database_server.fqdn}" `
        -UserLocalCredentials $false `
        -SqlArguments "${var.sql_arguments}"
    EOT

    interpreter = ["pwsh", "-Command"]
  }
}