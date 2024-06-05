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
    key                  = "terraform.tfstate"
    use_oidc             = true
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
  name                  = "workspace-code9-st08-weu-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-aks.name
  sku                   = "PerGB2018"
  retention_in_days     = 30
}

resource "azurerm_application_insights" "appi-code9-01" {
  name                  = "appi-code9-st08-weu-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-aks.name
  workspace_id          = azurerm_log_analytics_workspace.log-code9-01.id
  application_type      = "web"
}


### App services

resource "azurerm_service_plan" "plan-code9-api-01" {
  name                 = "asp-code9-api-st08-weu-01"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg-aks.name
  os_type              = "Windows"
  sku_name             = "B1"
}

resource "azurerm_windows_web_app" "app-code9-api-01" {
  name                   = "app-code9-api-st08-weu-01"
  resource_group_name    = azurerm_resource_group.rg-aks.name
  location               = var.location
  service_plan_id        = azurerm_service_plan.plan-code9-api-01.id
  https_only             = true 

  site_config {
    ftps_state           = "FtpsOnly"
    load_balancing_mode  = "LeastRequests"
    use_32_bit_worker    = false

    application_stack {
      current_stack      = "dotnet"
      dotnet_version     = "v8.0"
    }
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
  administrator_login               = "sqladmin"
  administrator_login_password 	  	= "4v3ry53!cr37p455w0rd"
  version                           = "12.0"
  minimum_tls_version               = "1.2"
  public_network_access_enabled     = true  
}


resource "azurerm_mssql_database" "sqldb-code9-01" {
  name                              = "sqldb-code9-st08-weu-01"
  server_id                         = azurerm_mssql_server.sql-code9-server-01.id
  collation                         = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                       = 2
  sku_name                          = "Basic"
  zone_redundant                    = false

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}


### Storage account

resource "azurerm_storage_account" "st-code9-01" {
  name                        		  = "stcode9st08neu01"
  resource_group_name          		  = azurerm_resource_group.rg-aks.name
  location                  	  	  = var.location
  account_tier               	  	  = "Standard"
  account_replication_type 	    	  = "LRS"
  access_tier               	  	  = "Hot"
  public_network_access_enabled     = true
}

resource "azurerm_storage_container" "st-code9-container-01" {
  name                              = "code9files"
  storage_account_name              = azurerm_storage_account.st-code9-01.name
  container_access_type             = "private"
}
