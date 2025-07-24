# Development Environment - Ubuntu VM Deployment
# Demonstrates immutable infrastructure patterns

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  # Remote state backend
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfworkshop1753345493"
    container_name       = "tfstate"
    key                  = "dev/ubuntu-vm.tfstate"
    use_azuread_auth     = true
    # Uses service principal auth via ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID env vars
  }
}

# Configure Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Get current public IP for NSG rules
data "http" "current_ip" {
  url = "https://v4.ident.me"
}

# Common locals
locals {
  environment     = "dev"
  workload       = "webserver"
  location       = "Australia East"
  location_short = "aue"
  
  # Get SSH public key
  ssh_public_key = file("~/.ssh/terraform-demo/id_rsa.pub")
  
  # Allow SSH from current public IP only (security best practice)
  # If external IP detection fails, manually replace with your public IP
  current_ip = "${chomp(data.http.current_ip.response_body)}/32"
  # Manual override (uncomment and use if data source fails):
  # current_ip = "YOUR_PUBLIC_IP_HERE/32"
  
  # Common tags
  common_tags = {
    Environment   = local.environment
    Workload      = local.workload
    ManagedBy     = "terraform"
    Owner         = "devops-team"
    CostCenter    = "development"
    Project       = "terraform-workshop"
    CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-${local.environment}-${local.location_short}-001"
  location = local.location
  tags     = local.common_tags
}

# Network Security Group Module
module "nsg" {
  source = "../../modules/networking/nsg"
  
  name_prefix         = local.workload
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  
  allowed_ssh_ips = [local.current_ip]
  allow_http      = true
  allow_https     = true
  
  tags = local.common_tags
}

# Virtual Network Module
module "vnet" {
  source = "../../modules/networking/vnet"
  
  workload            = local.workload
  environment         = local.environment
  location            = local.location
  location_short      = local.location_short
  instance            = 1
  resource_group_name = azurerm_resource_group.main.name
  
  vnet_cidr   = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"
  
  common_tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = module.vnet.subnet_id
  network_security_group_id = module.nsg.nsg_id
}

# Virtual Machine Module
module "ubuntu_vm" {
  source = "../../modules/compute/vm"
  
  workload            = local.workload
  environment         = local.environment
  location            = local.location
  location_short      = local.location_short
  instance            = 1
  resource_group_name = azurerm_resource_group.main.name
  
  subnet_id        = module.vnet.subnet_id
  admin_username   = "azureuser"
  ssh_public_key   = local.ssh_public_key
  enable_public_ip = true
  
  vm_size      = "Standard_B2s"
  os_disk_type = "Premium_LRS"
  
  # Cloud-init script for web server setup
  custom_data = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Create simple web page
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head><title>Terraform VM Demo</title></head>
    <body>
      <h1>Hello from Terraform VM!</h1>
      <p>Environment: ${local.environment}</p>
      <p>VM Name: ${local.workload}-vm</p>
      <p>Deployed: ${formatdate("YYYY-MM-DD HH:mm:ss", timestamp())}</p>
    </body>
    </html>
    HTML
  EOT
  
  common_tags = local.common_tags
}
