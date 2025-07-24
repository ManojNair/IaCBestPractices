# Virtual Network Module
# Provides isolated network environment for VMs

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.all_tags
}

# VM Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = local.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Locals for naming and tagging
locals {
  vnet_name   = "vnet-${var.workload}-${var.environment}-${var.location_short}-${format("%03d", var.instance)}"
  subnet_name = "snet-${var.workload}-${var.environment}-${var.location_short}-${format("%03d", var.instance)}"
  
  all_tags = merge(
    var.common_tags,
    {
      Module    = "networking/vnet"
      Component = "virtual-network"
      Purpose   = "vm-hosting"
    }
  )
}
