######################################################################################################################################################
# Output variables                                                                                                                                   #
######################################################################################################################################################
output "primary_blob_endpoint" {
  value = jsondecode(azapi_resource.app_storage_account.output).properties.primaryEndpoints.blob
}

output "id" {
  value = azapi_resource.app_storage_account.id
}


output "name" {
  value = azapi_resource.app_storage_account.name
}
