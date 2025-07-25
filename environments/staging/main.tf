# Staging Environment Configuration
# A simplified version of production for testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# This is a placeholder staging environment
# In a real scenario, this would contain staging-specific resources
