# Foundation Stack - Core Infrastructure
# Following Stack Pattern principles from IaC 3rd Edition

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote state for foundation stack
  backend "azurerm" {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Local values for stack-wide configuration
locals {
  # Stack metadata
  stack_name = "foundation"
  stack_version = "1.0.0"
  
  # Naming convention
  name_prefix = "${var.organization}-${var.workload}-${var.environment}"
  
  # Common tags applied to all resources in this stack
  common_tags = merge(var.common_tags, {
    Stack         = local.stack_name
    StackVersion  = local.stack_version
    ManagedBy     = "terraform"
    LastModified  = timestamp()
  })
}

# Resource Group - Stack boundary
resource "azurerm_resource_group" "foundation" {
  name     = "rg-${local.name_prefix}-foundation-001"
  location = var.location
  
  tags = merge(local.common_tags, {
    Purpose = "foundation-infrastructure"
  })

  lifecycle {
    prevent_destroy = true  # Protect critical foundation resources
  }
}

# Virtual Network - Core networking
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}-001"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name

  tags = local.common_tags
}

# Subnets for different tiers
resource "azurerm_subnet" "web_tier" {
  name                 = "snet-web-${var.environment}-001"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.web_subnet_cidr]
}

resource "azurerm_subnet" "app_tier" {
  name                 = "snet-app-${var.environment}-001" 
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.app_subnet_cidr]
}

resource "azurerm_subnet" "data_tier" {
  name                 = "snet-data-${var.environment}-001"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.data_subnet_cidr]
}

# Network Security Group - Zero trust networking
resource "azurerm_network_security_group" "web_tier" {
  name                = "nsg-web-${var.environment}-001"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name

  # Default deny all - explicit allow required
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "web_tier" {
  subnet_id                 = azurerm_subnet.web_tier.id
  network_security_group_id = azurerm_network_security_group.web_tier.id
}
