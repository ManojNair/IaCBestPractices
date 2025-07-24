# Module 1: IaC Foundations & Stack Pattern (IaC 3rd Edition)
## Duration: 18 minutes (10 min theory + 8 min demo)

---

## Theory Section (10 minutes)

### Infrastructure as Code Core Principles (Kief Morris Framework)

#### **1. Definition Clarity Principle**
**"Infrastructure should be defined using files that can be processed by automated tools"**

Infrastructure as Code means defining your infrastructure in **declarative definition files** that:
- Describe the desired state, not the steps to achieve it
- Are version controlled like application code
- Can be reviewed, tested, and approved through standard development practices
- Serve as the single source of truth for infrastructure state

```hcl
# Example: Declarative vs Imperative
# ❌ Imperative (how to do it)
# 1. Create resource group
# 2. Create storage account  
# 3. Configure access policies

# ✅ Declarative (what you want)
resource "azurerm_resource_group" "main" {
  name     = "rg-webapp-prod-eus2-001"
  location = "East US 2"
}
```

#### **2. Stack Pattern - The Foundation of Scalable IaC**
**"A stack is a collection of infrastructure that is managed as a unit"**

The Stack Pattern organizes infrastructure into logical, cohesive units that:
- **Encapsulate related resources**: All resources needed for a specific purpose
- **Have clear boundaries**: Well-defined inputs, outputs, and dependencies  
- **Can be managed independently**: Deploy, update, and destroy as a unit
- **Enable composition**: Stacks can depend on other stacks

**Stack Design Principles:**
1. **Single Responsibility**: Each stack has one clear purpose
2. **Minimal Dependencies**: Reduce coupling between stacks
3. **Clear Interfaces**: Well-defined parameters and outputs
4. **Appropriate Granularity**: Not too big, not too small

```
Example Stack Organization:
├── foundation-stack/     # Core networking, security baseline
├── platform-stack/      # Shared services (container registry, key vault)
├── data-stack/          # Databases, storage accounts
└── application-stack/   # Application-specific resources
```

#### **3. State Management - The Engine of IaC**
**"Infrastructure state must be managed reliably and consistently"**

**State File Principles:**
- **Single Source of Truth**: State file reflects actual infrastructure
- **Consistency**: State must be consistent across team members
- **Locking**: Prevent concurrent modifications
- **Backup and Recovery**: State files must be recoverable
- **Security**: State files may contain sensitive information

**Remote State Benefits:**
```hcl
# Remote state enables:
# 1. Team collaboration without conflicts
# 2. State locking for safety
# 3. Encryption at rest and in transit
# 4. Audit trail of state changes
# 5. Disaster recovery capabilities

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate${var.environment}"
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}
```

#### **4. Configuration Data Management**
**"Separate configuration data from infrastructure definition"**

**Configuration Hierarchy** (from highest to lowest precedence):
1. **Command-line flags**: `terraform apply -var="instance_count=3"`
2. **Environment variables**: `TF_VAR_instance_count=3`
3. **terraform.tfvars files**: Environment-specific values
4. **variable defaults**: Fallback values in variable definitions

```hcl
# Variable Definition (infrastructure definition)
variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
  
  validation {
    condition = contains([
      "Standard_B1s", "Standard_B2s", "Standard_D2s_v3"
    ], var.vm_size)
    error_message = "VM size must be from approved list."
  }
}

# Configuration Data (terraform.tfvars)
vm_size = "Standard_D2s_v3"  # Production override
```

#### **5. Stack Dependencies and Composition**
**"Stacks should compose cleanly with minimal coupling"**

**Dependency Patterns:**
1. **Data Sources**: Read outputs from other stacks
2. **Remote State**: Reference state from other stacks
3. **Explicit Dependencies**: Use `depends_on` when needed

```hcl
# Foundation stack output
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

# Application stack input
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatefoundation"
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}

resource "azurerm_subnet" "app" {
  virtual_network_name = data.terraform_remote_state.foundation.outputs.vnet_name
  # ...
}
```

---

## Hands-on Demo Section (8 minutes)

### **Step 1: Stack-Based Project Organization (2 minutes)**

**📁 Working Directory: `/Users/manojnair/RiderProjects/tfworkshop`**

Let's implement the Stack Pattern following IaC 3rd Edition principles:

```bash
# Create enterprise stack structure
mkdir -p terraform-iac-stacks/{stacks,shared,modules}

# Foundation Stack - Core infrastructure
mkdir -p stacks/foundation/{networking,security,monitoring}

# Platform Stack - Shared services  
mkdir -p stacks/platform/{container-registry,key-vault,log-analytics}

# Application Stack - App-specific resources
mkdir -p stacks/application/{compute,storage,load-balancer}

# Shared Components
mkdir -p shared/{backend,variables,policies}
mkdir -p modules/{networking,compute,security}
```

### **Step 2: Foundation Stack Implementation (3 minutes)**

**📁 Working Directory: `/Users/manojnair/RiderProjects/tfworkshop/stacks/foundation`**

```bash
# Create the foundation stack main configuration
cat << 'EOF' > main.tf
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
  name_prefix = "\${var.organization}-\${var.workload}-\${var.environment}"
  
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
  name     = "rg-\${local.name_prefix}-foundation-001"
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
  name                = "vnet-\${local.name_prefix}-001"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name

  tags = local.common_tags
}

# Subnets for different tiers
resource "azurerm_subnet" "web_tier" {
  name                 = "snet-web-\${var.environment}-001"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.web_subnet_cidr]
}

resource "azurerm_subnet" "app_tier" {
  name                 = "snet-app-\${var.environment}-001" 
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.app_subnet_cidr]
}

resource "azurerm_subnet" "data_tier" {
  name                 = "snet-data-\${var.environment}-001"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.data_subnet_cidr]
}

# Network Security Group - Zero trust networking
resource "azurerm_network_security_group" "web_tier" {
  name                = "nsg-web-\${var.environment}-001"
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
EOF

# Create the variables file
cat << 'EOF' > variables.tf
# Foundation Stack Variables
# Implementing configuration data separation principle

# Stack Configuration
variable "organization" {
  description = "Organization name for resource naming"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]+\$", var.organization))
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
  default     = "East US 2"
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
EOF

# Create the outputs file
cat << 'EOF' > outputs.tf
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
    location     = \${var.location}
    environment  = \${var.environment}
  }
}
```

### **Step 3: Remote State Backend with Locking (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/shared/backend/`

```bash
# Create backend stack directory structure
mkdir -p ~/tfworkshop/shared/backend
cd ~/tfworkshop/shared/backend

# Create the backend infrastructure file
cat << 'EOF' > main.tf
# Remote State Backend Stack
# Implements reliable state management following IaC principles

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate unique suffix for storage account
resource "random_id" "state_suffix" {
  byte_length = 4
}

# Resource group for state management
resource "azurerm_resource_group" "state" {
  name     = "rg-terraform-state-\${var.environment}"
  location = var.location

  tags = {
    Purpose      = "terraform-state-management"
    Environment  = var.environment
    ManagedBy    = "terraform"
    CriticalData = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Storage account for Terraform state with enterprise security
resource "azurerm_storage_account" "state" {
  name                     = "sttfstate\${var.environment}\${random_id.state_suffix.hex}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant for disaster recovery
  
  # Security configuration following IaC 3rd Edition principles
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false  # Use Azure AD authentication
  
  # Enable versioning for state file history
  blob_properties {
    versioning_enabled  = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  # Network access control
  network_rules {
    default_action = "Deny"
    ip_rules       = var.allowed_ip_ranges
    bypass         = ["AzureServices"]
  }

  tags = azurerm_resource_group.state.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Container for state files with proper organization
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# Enable state locking with Cosmos DB
resource "azurerm_cosmosdb_account" "state_lock" {
  name                = "cosmos-tflock-\${var.environment}-\${random_id.state_suffix.hex}"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = azurerm_resource_group.state.tags
}
EOF
```

### **Key IaC 3rd Edition Principles Demonstrated**
✅ **Stack Pattern**: Foundation stack with clear boundaries and responsibilities
✅ **Definition Clarity**: Declarative infrastructure with comprehensive documentation
✅ **State Management**: Remote state with locking, versioning, and security
✅ **Configuration Separation**: Variables separated from infrastructure definition
✅ **Immutable Infrastructure**: Lifecycle rules and prevent_destroy for critical resources
✅ **Stack Composition**: Clear outputs for inter-stack dependencies

---

## Next Steps
In Module 2, we'll implement the Environment Pattern to manage configuration across multiple environments while maintaining consistency and enabling safe promotion of infrastructure changes.
