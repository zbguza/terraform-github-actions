######################################################################################################################################################
#  Local variables                                                                                                                                   #
######################################################################################################################################################
locals {
  application_short_name         = var.application_short_name != "" ? (startswith(var.application_short_name, "-") ? var.application_short_name : "-${var.application_short_name}") : ""
  application_short_name_trimmed = trim(local.application_short_name, "-")

  storage_account_name = "st${var.company_name.short}${local.application_short_name_trimmed}${var.environment}${var.location_name.short}${var.storage_name_count_suffix}"
}
