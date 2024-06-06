terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
  }

  # Update this block with the location of your terraform state file
  backend "azurerm" {
    resource_group_name  = "rg-terraform-github-actions-state"
    storage_account_name = "tfstategithubzbguza"
    container_name       = "tfstate"
    # key                  = "terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

# Define any Azure resources to be created here. A simple resource group is shown here as a minimal example.
resource "azurerm_resource_group" "rg-aks" {
  name     = var.resource_group_name
  location = var.location
}

### Application Insights

resource "azurerm_log_analytics_workspace" "log-code9-01" {
  name                  = "workspace-code9-st08-neu-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-aks.name
  sku                   = "PerGB2018"
  retention_in_days     = 30
}

resource "azurerm_application_insights" "appi-code9-01" {
  name                  = "appi-code9-st08-neu-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-aks.name
  workspace_id          = azurerm_log_analytics_workspace.log-code9-01.id
  application_type      = "web"
}


### App services

resource "azurerm_service_plan" "plan-code9-01" {
  name                 = "asp-code9-st08-neu-01"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg-aks.name
  os_type              = "Windows"
  sku_name             = "P0v3"
  worker_count         = 2
  zone_balancing_enabled = true
}

resource "azurerm_windows_web_app" "app-code9-api-01" {
  name                   = "app-code9-api-st08-neu-01"
  resource_group_name    = azurerm_resource_group.rg-aks.name
  location               = var.location
  service_plan_id        = azurerm_service_plan.plan-code9-01.id
  https_only             = true 
  public_network_access_enabled = false

  site_config {
    ftps_state           = "FtpsOnly"
    load_balancing_mode  = "LeastRequests"
    use_32_bit_worker    = false
    health_check_path    = "/healtz"
    http2_enabled        = true

    application_stack {
      current_stack      = "dotnet"
      dotnet_version     = "v8.0"
    }
  }

  logs {
      failed_request_tracing = true
      detailed_error_messages = true
      http_logs {
        file_system {
          retention_in_days = 4
          retention_in_mb = 25
        }
      }
  }

  identity {
      type = "SystemAssigned"
  }

  auth_settings {
      enabled = true
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"                  = azurerm_application_insights.appi-code9-01.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"           = azurerm_application_insights.appi-code9-01.connection_string
    "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~2"
    "DiagnosticServices_EXTENSION_VERSION"            = "~3"
    "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
    "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
    "WEBSITE_NODE_DEFAULT_VERSION"                    = "6.9.1"
    "WEBSITE_RUN_FROM_PACKAGE"                        = 0
  }
}


### MS SQL Service resource
resource "azurerm_mssql_server" "sql-code9-server-01" {
  name                              = "sqlcode9st08neu01"
  resource_group_name               = azurerm_resource_group.rg-aks.name
  location                          = "northeurope"
  version                           = "12.0"
  minimum_tls_version               = "1.2"
  public_network_access_enabled     = false 

  azuread_administrator {
    azuread_authentication_only = true
    login_username = "IT Cloud Administrators"
    object_id      = "8f6a3b2e-f93b-4feb-a6a2-ad114f31bca7"
 }
}


resource "azurerm_mssql_database" "sqldb-code9-01" {
  name                              = "sqldb-code9-st08-neu-01"
  server_id                         = azurerm_mssql_server.sql-code9-server-01.id
  collation                         = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                       = 2
  sku_name                          = "S0"
  zone_redundant                    = true
  ledger_enabled                    = true

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "sqlaud-code9-audit-neu-01" {
  server_id                               = azurerm_mssql_server.sql-code9-server-01.id
  storage_endpoint                        = azurerm_storage_account.st-code9-01.primary_blob_endpoint
  storage_account_access_key              = azurerm_storage_account.st-code9-01.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 90
}


### Storage account

resource "azurerm_storage_account" "st-code9-01" {
  name                        		  = "stgithubst08neu01"
  resource_group_name          		  = azurerm_resource_group.rg-aks.name
  location                  	  	  = var.location
  account_tier               	  	  = "Standard"
  account_replication_type 	    	  = "GRS"
  access_tier               	  	  = "Hot"
  public_network_access_enabled     = false
  allow_nested_items_to_be_public   = false
  min_tls_version                   = "TLS1_2"
  shared_access_key_enabled         = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  sas_policy {
    expiration_period = "90.00:00:00"
    expiration_action = "Log"
  }

  queue_properties  {
    logging {
          delete                = true
          read                  = true
          write                 = true
          version               = "1.0"
          retention_policy_days = 10
    }
  }
}

resource "azurerm_storage_container" "st-code9-container-01" {
  name                              = "code9files"
  storage_account_name              = azurerm_storage_account.st-code9-01.name
  container_access_type             = "private"
}

resource "azurerm_log_analytics_storage_insights" "st-code9-storage-insights-01" {
  name                = "stinsights-code9-storageinsightconfig"
  resource_group_name = azurerm_resource_group.rg-aks.name
  workspace_id        = azurerm_log_analytics_workspace.log-code9-01.id

  storage_account_id  = azurerm_storage_account.st-code9-01.id
  storage_account_key = azurerm_storage_account.st-code9-01.primary_access_key
  blob_container_names= [azurerm_storage_container.st-code9-container-01.name]
}
