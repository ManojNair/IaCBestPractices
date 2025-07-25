# Remote State Backend Stack
# Implements reliable state management following IaC principles

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate unique suffix for storage account
resource "random_id" "state_suffix" {
  byte_length = 4
}

# Resource group for state management
resource "azurerm_resource_group" "state" {
  name     = "rg-terraform-state-${var.environment}"
  location = var.location

  tags = {
    Purpose      = "terraform-state-management"
    Environment  = var.environment
    ManagedBy    = "terraform"
    CriticalData = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Storage account for Terraform state with enterprise security
resource "azurerm_storage_account" "state" {
  name                     = "sttfstate${var.environment}${random_id.state_suffix.hex}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant for disaster recovery

  # Security configuration following IaC 3rd Edition principles
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Use Azure AD authentication

  # Enable versioning for state file history
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  # Network access control
  network_rules {
    default_action = "Deny"
    ip_rules       = var.allowed_ip_ranges
    bypass         = ["AzureServices"]
  }

  tags = azurerm_resource_group.state.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Container for state files with proper organization
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# Enable state locking with Cosmos DB
resource "azurerm_cosmosdb_account" "state_lock" {
  name                = "cosmos-tflock-${var.environment}-${random_id.state_suffix.hex}"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = azurerm_resource_group.state.tags
}
