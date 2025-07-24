locals {
  # Environment-specific configurations
  environment_config = {
    dev = {
      vm_size         = "Standard_B2s"
      backup_enabled  = false
      monitoring_tier = "basic"
      auto_shutdown   = true
    }
    staging = {
      vm_size         = "Standard_D2s_v3"
      backup_enabled  = true
      monitoring_tier = "standard"
      auto_shutdown   = false
    }
    prod = {
      vm_size         = "Standard_D4s_v3"
      backup_enabled  = true
      monitoring_tier = "premium"
      auto_shutdown   = false
    }
  }
  
  # Current environment configuration
  current_config = local.environment_config[var.environment]
}

resource "azurerm_linux_virtual_machine" "main" {
  size = local.current_config.vm_size
  # ...
}

# Create expensive resources only in production
resource "azurerm_application_gateway" "main" {
  count = var.environment == "prod" ? 1 : 0
  # ...
}

# Development-only resources
resource "azurerm_dev_test_lab" "main" {
  count = var.environment == "dev" ? 1 : 0
  # ...
}
