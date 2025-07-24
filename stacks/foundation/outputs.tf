# Foundation Stack Outputs
# These outputs define the stack's interface for other stacks

# Resource Group Information
output "resource_group_name" {
  description = "Name of the foundation resource group"
  value       = azurerm_resource_group.foundation.name
}

output "resource_group_id" {
  description = "ID of the foundation resource group"
  value       = azurerm_resource_group.foundation.id
}

# Network Information - Stack Interface
output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.main.address_space
}

# Subnet Information for Stack Composition
output "web_subnet_id" {
  description = "ID of the web tier subnet"
  value       = azurerm_subnet.web_tier.id
}

output "app_subnet_id" {
  description = "ID of the application tier subnet"
  value       = azurerm_subnet.app_tier.id
}

output "data_subnet_id" {
  description = "ID of the data tier subnet"
  value       = azurerm_subnet.data_tier.id
}

# Security Group Information
output "web_nsg_id" {
  description = "ID of the web tier network security group"
  value       = azurerm_network_security_group.web_tier.id
}

# Stack Metadata
output "stack_info" {
  description = "Foundation stack metadata"
  value = {
    name         = "foundation"
    version      = "1.0.0"
    location     = var.location
    environment  = var.environment
  }
}
