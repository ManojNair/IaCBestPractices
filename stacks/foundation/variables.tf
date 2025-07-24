# Foundation Stack Variables
# Implementing configuration data separation principle

# Stack Configuration
variable "organization" {
  description = "Organization name for resource naming"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.organization))
    error_message = "Organization must contain only lowercase letters and numbers."
  }
}

variable "workload" {
  description = "Workload name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Australia East"
}

# State Management Configuration
variable "state_resource_group_name" {
  description = "Resource group name for Terraform state storage"
  type        = string
}

variable "state_storage_account_name" {
  description = "Storage account name for Terraform state"
  type        = string
}

# Network Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "VNet address space must be a valid CIDR block."
  }
}

variable "web_subnet_cidr" {
  description = "CIDR block for web tier subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_subnet_cidr" {
  description = "CIDR block for application tier subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "data_subnet_cidr" {
  description = "CIDR block for data tier subnet"  
  type        = string
  default     = "10.0.3.0/24"
}

# Tagging
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
