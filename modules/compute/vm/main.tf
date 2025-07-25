# Ubuntu Virtual Machine Module
# Implements immutable infrastructure principles

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = local.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.main[0].id : null
  }

  tags = local.all_tags
}

# Public IP (conditional)
resource "azurerm_public_ip" "main" {
  count = var.enable_public_ip ? 1 : 0

  name                = local.pip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.all_tags
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = local.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Security settings
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  # Custom data for cloud-init
  custom_data = var.custom_data != null ? base64encode(var.custom_data) : null

  tags = local.all_tags

  lifecycle {
    create_before_destroy = true # Immutable infrastructure principle
  }
}

# Locals for naming and tagging
locals {
  vm_name  = "vm-${var.workload}-${var.environment}-${var.location_short}-${format("%03d", var.instance)}"
  nic_name = "nic-${var.workload}-${var.environment}-${var.location_short}-${format("%03d", var.instance)}"
  pip_name = "pip-${var.workload}-${var.environment}-${var.location_short}-${format("%03d", var.instance)}"

  all_tags = merge(
    var.common_tags,
    {
      Module    = "compute/vm"
      Component = "virtual-machine"
      Instance  = var.instance
      VMSize    = var.vm_size
    }
  )
}
