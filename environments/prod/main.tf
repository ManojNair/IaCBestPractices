# Production Environment - Following Environment Pattern
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Production state configuration
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                 = "environments/prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Import shared configuration
module "shared_config" {
  source = "../shared"
}

locals {
  environment = "prod"
  
  # Production-specific overrides
  prod_overrides = {
    enable_diagnostics     = true   # Enable comprehensive logging
    enable_ddos_protection = true   # Enhanced security
    log_retention_days     = 365    # Compliance requirement
    backup_retention_days  = 30     # Extended backup retention
  }
  
  config = merge(module.shared_config.environment_settings[local.environment], local.prod_overrides)
}

# Resource Group with enhanced protection
resource "azurerm_resource_group" "main" {
  name     = "rg-\${module.shared_config.name_prefix}-001"
  location = var.location
  
  tags = merge(module.shared_config.common_tags, {
    Purpose     = "production-environment"
    Criticality = "high"
    Compliance  = "required"
  })

  lifecycle {
    prevent_destroy = true  # Protect production resources
  }
}

# Production-grade Key Vault with enhanced security
resource "azurerm_key_vault" "main" {
  name                = "kv-\${var.workload}-\${local.environment}-\${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"  # Premium for HSM protection

  # Production security settings
  enable_rbac_authorization       = true
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Restrict access to specific IP ranges
    ip_rules = var.allowed_ip_ranges
  }

  tags = module.shared_config.common_tags
}

# Production VMs with high availability
resource "azurerm_linux_virtual_machine" "main" {
  count = local.config.vm_count
  
  name                = "vm-\${module.shared_config.name_prefix}-\${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.config.vm_size
  admin_username      = "azureuser"
  
  # Production security settings
  disable_password_authentication = true
  zone                           = local.config.availability_zones[count.index % length(local.config.availability_zones)]

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.config.disk_type
    disk_encryption_set_id = azurerm_disk_encryption_set.main.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(module.shared_config.common_tags, {
    Purpose = "production-vm"
    BackupEnabled = local.config.backup_enabled
  })
}

# Production network interfaces (no public IPs)
resource "azurerm_network_interface" "main" {
  count = local.config.vm_count
  
  name                = "nic-\${module.shared_config.name_prefix}-\${format("%03d", count.index + 1)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.app_subnet_id
    private_ip_address_allocation = "Dynamic"
    # No public IP for production security
  }

  tags = module.shared_config.common_tags
}

# Disk encryption for production compliance
resource "azurerm_disk_encryption_set" "main" {
  name                = "des-\${module.shared_config.name_prefix}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  key_vault_key_id    = azurerm_key_vault_key.main.id

  identity {
    type = "SystemAssigned"
  }

  tags = module.shared_config.common_tags
}

resource "azurerm_key_vault_key" "main" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.disk_encryption
  ]
}

# Access policy for disk encryption
resource "azurerm_key_vault_access_policy" "disk_encryption" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_disk_encryption_set.main.identity.0.tenant_id
  object_id    = azurerm_disk_encryption_set.main.identity.0.principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "azurerm_client_config" "current" {}

# Reference foundation stack
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  
  config = {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}
