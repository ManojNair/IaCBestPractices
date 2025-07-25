# Key Vault per environment
# Security Stack - Azure Key Vault and Database Security Configuration

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

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.workload}-${var.environment}-${random_id.suffix.hex}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Environment-specific SKU
  sku_name = var.environment == "prod" ? "premium" : "standard"

  dynamic "access_policy" {
    for_each = var.key_vault_access_policies
    content {
      tenant_id = access_policy.value.tenant_id
      object_id = access_policy.value.object_id

      key_permissions    = access_policy.value.key_permissions
      secret_permissions = access_policy.value.secret_permissions
    }
  }
}

# Reference secrets without storing values
data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_postgresql_server" "main" {
  administrator_login_password = data.azurerm_key_vault_secret.db_password.value
  # ...
}
