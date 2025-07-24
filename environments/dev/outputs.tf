# VM Connection Information
output "vm_connection" {
  description = "VM connection details"
  value = {
    vm_name     = module.ubuntu_vm.vm_name
    public_ip   = module.ubuntu_vm.public_ip
    private_ip  = module.ubuntu_vm.private_ip
    ssh_command = "ssh azureuser@${module.ubuntu_vm.public_ip}"
  }
}

# Resource Information
output "resource_details" {
  description = "Created resource details"
  value = {
    resource_group = azurerm_resource_group.main.name
    vnet_name      = module.vnet.vnet_name
    subnet_name    = module.vnet.subnet_name
    nsg_name       = module.nsg.nsg_name
  }
}

# Azure Portal Links
output "azure_portal_links" {
  description = "Direct links to Azure Portal"
  value = {
    vm_link = "https://portal.azure.com/#@/resource${module.ubuntu_vm.vm_id}/overview"
    rg_link = "https://portal.azure.com/#@/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/overview"
  }
}
