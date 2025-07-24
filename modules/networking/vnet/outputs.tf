output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.main.name
}

output "subnet_id" {
  description = "VM subnet ID"
  value       = azurerm_subnet.vm_subnet.id
}

output "subnet_name" {
  description = "VM subnet name"
  value       = azurerm_subnet.vm_subnet.name
}

output "vnet_address_space" {
  description = "Virtual network address space"
  value       = azurerm_virtual_network.main.address_space
}
