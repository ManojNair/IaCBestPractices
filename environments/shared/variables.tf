# Shared variable definitions across all environments
# Following IaC 3rd Edition configuration separation principle

variable "organization" {
  description = "Organization name for resource naming"
  type        = string
  default     = "contoso"
}

variable "workload" {
  description = "Workload identifier"
  type        = string
  default     = "webapp"
}

variable "environment" {
  description = "Environment name"
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

# Environment-aware configuration
locals {
  # Environment-specific settings following the Environment Pattern
  environment_settings = {
    dev = {
      vm_size                = "Standard_B2s"
      vm_count              = 1
      backup_enabled        = false
      monitoring_level      = "basic"
      auto_shutdown_enabled = true
      availability_zones    = ["1"]
      disk_type            = "Standard_LRS"
      network_access_tier  = "standard"
    }
    
    staging = {
      vm_size                = "Standard_D2s_v3"
      vm_count              = 2
      backup_enabled        = true
      monitoring_level      = "standard"
      auto_shutdown_enabled = false
      availability_zones    = ["1", "2"]
      disk_type            = "Premium_LRS"
      network_access_tier  = "premium"
    }
    
    prod = {
      vm_size                = "Standard_D4s_v3"
      vm_count              = 3
      backup_enabled        = true
      monitoring_level      = "premium"
      auto_shutdown_enabled = false
      availability_zones    = ["1", "2", "3"]
      disk_type            = "Premium_LRS"
      network_access_tier  = "premium"
    }
  }
  
  # Current environment configuration
  current_env = local.environment_settings[var.environment]
  
  # Common naming convention
  name_prefix = "\${var.organization}-\${var.workload}-\${var.environment}"
  
  # Environment-aware tags
  common_tags = {
    Organization  = var.organization
    Workload      = var.workload
    Environment   = var.environment
    ManagedBy     = "terraform"
    DeployedBy    = "environment-pattern"
    
    # Environment-specific tags
    BackupEnabled    = local.current_env.backup_enabled
    MonitoringLevel  = local.current_env.monitoring_level
    AutoShutdown     = local.current_env.auto_shutdown_enabled
  }
}

# Environment-specific validation rules
locals {
  # Production-specific validation rules
  prod_validations = var.environment == "prod" ? {
    backup_required       = local.current_env.backup_enabled
    multi_zone_required   = length(local.current_env.availability_zones) >= 2
    premium_disk_required = local.current_env.disk_type == "Premium_LRS"
  } : {}
  
  # Check for validation failures
  validation_failures = [
    for key, value in local.prod_validations : key if !value
  ]
}

# Fail deployment if production validations fail
resource "null_resource" "environment_validation" {
  count = length(local.validation_failures) > 0 ? 1 : 0
  
  triggers = {
    failures = join(",", local.validation_failures)
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Environment validation failed for \${var.environment}:"
      echo "Failed validations: \${join(", ", local.validation_failures)}"
      exit 1
    EOT
  }
}
