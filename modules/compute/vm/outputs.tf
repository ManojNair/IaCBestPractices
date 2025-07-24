output "vm_id" {
  description = "Virtual machine ID"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_name" {
  description = "Virtual machine name"
  value       = azurerm_linux_virtual_machine.main.name
}

output "private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.main.private_ip_address
}

output "public_ip" {
  description = "Public IP address"
  value       = var.enable_public_ip ? azurerm_public_ip.main[0].ip_address : null
}

output "nic_id" {
  description = "Network interface ID"
  value       = azurerm_network_interface.main.id
}
