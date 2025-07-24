# Module 2: Environment Pattern & Configuration Management (IaC 3rd Edition)
## Duration: 22 minutes (12 min theory + 10 min demo)

---

## Theory Section (12 minutes)

### Environment Pattern - The Key to Scalable Infrastructure

#### **1. Environment Pattern Fundamentals**
**"Environments should be as similar as possible while accommodating necessary differences"**

The Environment Pattern from IaC 3rd Edition addresses these challenges:
- **Configuration Drift**: Different environments become inconsistent over time
- **Environment Parity**: Ensuring production matches lower environments
- **Safe Promotion**: Moving changes through environments with confidence  
- **Configuration Management**: Handling environment-specific differences

**Core Principles:**
1. **Identical Infrastructure Definition**: Same Terraform code across environments
2. **Parameterized Configuration**: Environment-specific values via variables
3. **Consistent Promotion Path**: Changes flow dev → staging → prod
4. **Minimal Environment Differences**: Only essential differences allowed

#### **2. Configuration Data Hierarchy**
**"Separate what changes from what stays the same"**

Configuration precedence (highest to lowest):
```
1. Runtime Parameters     (terraform apply -var="")
2. Environment Variables  (TF_VAR_*)
3. Environment tfvars     (dev.tfvars, prod.tfvars)
4. Workspace tfvars       (terraform.tfvars)
5. Variable Defaults      (variable "foo" { default = "bar" })
```

**Example Configuration Hierarchy:**

📁 **Working Directory**: `~/tfworkshop/environments/shared/`

```bash
# Create shared environment definitions directory
mkdir -p ~/tfworkshop/environments/shared
cd ~/tfworkshop/environments/shared

# Create variable definitions (same across all environments)
cat << 'EOF' > variables.tf
# variables.tf (definition - same across environments)
variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"  # Safe default
}

variable "instance_count" {
  description = "Number of VM instances"
  type        = number
  default     = 1
}
EOF

# Create development environment configuration
mkdir -p ../environments/dev
cat << 'EOF' > ../environments/dev/dev.tfvars
# dev.tfvars (development configuration)
vm_size        = "Standard_B2s"
instance_count = 1
EOF

# Create production environment configuration
mkdir -p ../environments/prod
cat << 'EOF' > ../environments/prod/prod.tfvars
# prod.tfvars (production configuration)
vm_size        = "Standard_D4s_v3"
instance_count = 3
EOF
```

#### **3. Environment-Specific Configuration Patterns**

**A. Environment-Aware Locals**

📁 **Working Directory**: `~/tfworkshop/stacks/compute/`

```bash
# Create compute stack with environment-aware configuration
mkdir -p ~/tfworkshop/stacks/compute
cd ~/tfworkshop/stacks/compute

# Create environment-aware compute stack
cat << 'EOF' > main.tf
locals {
  # Environment-specific configurations
  environment_config = {
    dev = {
      vm_size         = "Standard_B2s"
      backup_enabled  = false
      monitoring_tier = "basic"
      auto_shutdown   = true
    }
    staging = {
      vm_size         = "Standard_D2s_v3"
      backup_enabled  = true
      monitoring_tier = "standard"
      auto_shutdown   = false
    }
    prod = {
      vm_size         = "Standard_D4s_v3"
      backup_enabled  = true
      monitoring_tier = "premium"
      auto_shutdown   = false
    }
  }
  
  # Current environment configuration
  current_config = local.environment_config[var.environment]
}

resource "azurerm_linux_virtual_machine" "main" {
  size = local.current_config.vm_size
  # ...
}
EOF
```

**B. Conditional Resources**

```bash
# Add conditional resources to compute stack
cat << 'EOF' >> main.tf

# Create expensive resources only in production
resource "azurerm_application_gateway" "main" {
  count = var.environment == "prod" ? 1 : 0
  # ...
}

# Development-only resources
resource "azurerm_dev_test_lab" "main" {
  count = var.environment == "dev" ? 1 : 0
  # ...
}
EOF
```

#### **4. Secrets Management Across Environments**
**"Never store secrets in configuration files"**

**Azure Key Vault Integration Pattern:**

📁 **Working Directory**: `~/tfworkshop/stacks/security/`

```bash
# Create security stack for secrets management
mkdir -p ~/tfworkshop/stacks/security
cd ~/tfworkshop/stacks/security

# Create Key Vault stack with environment-specific secrets
cat << 'EOF' > main.tf
# Key Vault per environment
resource "azurerm_key_vault" "main" {
  name                = "kv-\${var.workload}-\${var.environment}-\${random_id.suffix.hex}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  # Environment-specific SKU
  sku_name = var.environment == "prod" ? "premium" : "standard"
  
  dynamic "access_policy" {
    for_each = var.key_vault_access_policies
    content {
      tenant_id = access_policy.value.tenant_id
      object_id = access_policy.value.object_id
      
      key_permissions    = access_policy.value.key_permissions
      secret_permissions = access_policy.value.secret_permissions
    }
  }
}

# Reference secrets without storing values
data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_postgresql_server" "main" {
  administrator_login_password = data.azurerm_key_vault_secret.db_password.value
  # ...
}
EOF
```

#### **5. Environment Promotion Pipeline**
**"Changes should flow through environments in a controlled manner"**

**Promotion Strategy:**
```
Developer → Feature Branch → Dev Environment
     ↓
Pull Request → Code Review → Staging Environment  
     ↓
Approval Process → Production Environment
```

**Branch-to-Environment Mapping:**
- `feature/*` → Development environment (automatic)
- `develop` → Staging environment (automatic)
- `main` → Production environment (manual approval)

#### **6. Configuration Validation and Testing**
**"Validate configuration before deployment"**

```hcl
# Variable validation
variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vm_size" {
  description = "Virtual machine size"
  type        = string
  
  validation {
    condition = can(regex("^Standard_[A-Z][0-9]+[a-z]*_v[0-9]+$", var.vm_size))
    error_message = "VM size must follow Azure naming convention."
  }
}

# Environment-specific validation
locals {
  # Validate production requirements
  prod_validation = var.environment == "prod" ? [
    for rule in [
      var.backup_enabled == true,
      var.monitoring_tier == "premium",
      length(var.availability_zones) >= 2
    ] : rule if !rule
  ] : []
}

# Fail deployment if production validation fails
resource "null_resource" "prod_validation" {
  count = length(local.prod_validation) > 0 ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Production validation failed' && exit 1"
  }
}
```

---

## Hands-on Demo Section (10 minutes)

### **Step 1: Environment-Specific Configuration Structure (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/`

```bash
# Create environment configuration structure
cd ~/tfworkshop
mkdir -p environments/{dev,staging,prod}
mkdir -p environments/shared

# Create configuration files for each environment
touch environments/dev/{main.tf,variables.tf,terraform.tfvars}
touch environments/staging/{main.tf,variables.tf,terraform.tfvars}
touch environments/prod/{main.tf,variables.tf,terraform.tfvars}
touch environments/shared/variables.tf
```

### **Step 2: Shared Environment Configuration (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/environments/shared/`

```bash
# Create shared variable definitions
cd ~/tfworkshop/environments/shared

cat << 'EOF' > variables.tf
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
  default     = "East US 2"
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
EOF
```

### **Step 3: Development Environment Implementation (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/environments/dev/`

```bash
# Create development environment configuration
cd ~/tfworkshop/environments/dev

# Create main configuration for development environment
cat << 'EOF' > main.tf
# Development Environment - Following Environment Pattern
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Environment-specific state configuration
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-dev"
    storage_account_name = "sttfstatedev001"
    container_name       = "tfstate"
    key                 = "environments/dev/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Import shared configuration
module "shared_config" {
  source = "../shared"
}

# Environment-specific locals
locals {
  environment = "dev"
  
  # Override shared configuration for development
  dev_overrides = {
    # Development-specific settings
    enable_diagnostics    = false  # Reduce costs in dev
    enable_ddos_protection = false
    log_retention_days    = 7
  }
  
  # Merge shared and environment-specific configuration
  config = merge(module.shared_config.environment_settings[local.environment], local.dev_overrides)
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-\${module.shared_config.name_prefix}-001"
  location = var.location
  
  tags = merge(module.shared_config.common_tags, {
    Purpose = "development-environment"
    CostOptimized = "true"
  })
}

# Key Vault for secrets management
resource "azurerm_key_vault" "main" {
  name                = "kv-\${var.workload}-\${local.environment}-\${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Development-specific access policy (more permissive)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
    
    key_permissions = [
      "Get", "List", "Create", "Delete", "Update"
    ]
  }

  tags = module.shared_config.common_tags
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "azurerm_client_config" "current" {}

# Development-specific virtual machine
resource "azurerm_linux_virtual_machine" "dev" {
  name                = "vm-\${var.workload}-\${local.environment}-001"  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.config.vm_size
  admin_username      = "azureuser"

  # Development-specific configuration
  disable_password_authentication = true
  
  # Cost optimization for development
  priority = "Spot"
  eviction_policy = "Deallocate"
  
  network_interface_ids = [
    azurerm_network_interface.dev.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.config.disk_type
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = local.config.common_tags
}

# Network interface for development VM
resource "azurerm_network_interface" "dev" {
  name                = "nic-\${var.workload}-\${local.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.web_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dev.id
  }

  tags = module.shared_config.common_tags
}

# Public IP for development access
resource "azurerm_public_ip" "dev" {
  name                = "pip-\${var.workload}-\${local.environment}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                = "Standard"

  tags = module.shared_config.common_tags
}

# Reference foundation stack
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  
  config = {
    resource_group_name  = "rg-terraform-state-dev"
    storage_account_name = "sttfstatedev001"
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}
EOF

# Create environment-specific terraform.tfvars
cat << 'EOF' > terraform.tfvars
# Development Environment Configuration
# Values override defaults from shared configuration

organization = "contoso"
workload     = "webapp"
environment  = "dev"
location     = "East US 2"

# Development-specific overrides
enable_auto_shutdown = true
backup_enabled       = false
monitoring_level     = "basic"
EOF
```

data "azurerm_client_config" "current" {}

# Foundation stack dependency
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state-dev"
    storage_account_name = "sttfstatedev001"
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}

# Virtual Machine with environment-specific configuration
resource "azurerm_linux_virtual_machine" "main" {
  count = local.config.vm_count
  
  name                = "vm-${module.shared_config.name_prefix}-${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.config.vm_size
  admin_username      = "azureuser"
  
  # Development: Allow password authentication for easier access
  disable_password_authentication = false
  admin_password                 = data.azurerm_key_vault_secret.vm_password.value

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.config.disk_type
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(module.shared_config.common_tags, {
    Purpose = "development-vm"
    AutoShutdown = local.config.auto_shutdown_enabled
  })
}

# Network Interface
resource "azurerm_network_interface" "main" {
  count = local.config.vm_count
  
  name                = "nic-${module.shared_config.name_prefix}-${format("%03d", count.index + 1)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.web_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }

  tags = module.shared_config.common_tags
}

# public IP (development only)
resource "azurerm_public_ip" "main" {
  count = local.config.vm_count
  
  name                = "pip-${module.shared_config.name_prefix}-${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(module.shared_config.common_tags, {
    Purpose = "development-access"
  })
}

# Auto-shutdown for cost optimization (development only)
resource "azurerm_dev_test_global_vm_shutdown_schedule" "main" {
  count = local.config.auto_shutdown_enabled ? local.config.vm_count : 0
  
  virtual_machine_id = azurerm_linux_virtual_machine.main[count.index].id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = "1900"  # 7 PM
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }

  tags = module.shared_config.common_tags
}

# Secret for VM password
data "azurerm_key_vault_secret" "vm_password" {
  name         = "vm-admin-password"
  key_vault_id = azurerm_key_vault.main.id
}
```

**environments/dev/terraform.tfvars**
```hcl
# Development Environment Configuration
# Following IaC 3rd Edition Environment Pattern

organization = "contoso"
workload     = "webapp"
environment  = "dev"
location     = "East US 2"

# Development-specific overrides
# (Most configuration comes from shared environment settings)

# Additional development tags
additional_tags = {
  CostCenter     = "development"
  Owner          = "dev-team"
  Project        = "iac-workshop"
  DeleteAfter    = "30-days"
}
```

### **Step 4: Production Environment Configuration (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/environments/prod/`

```bash
# Create production environment with enhanced security
cd ~/tfworkshop/environments/prod

# Create production main configuration
cat << 'EOF' > main.tf
# Production Environment - Following Environment Pattern
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Production state configuration
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                 = "environments/prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Import shared configuration
module "shared_config" {
  source = "../shared"
}

locals {
  environment = "prod"
  
  # Production-specific overrides
  prod_overrides = {
    enable_diagnostics     = true   # Enable comprehensive logging
    enable_ddos_protection = true   # Enhanced security
    log_retention_days     = 365    # Compliance requirement
    backup_retention_days  = 30     # Extended backup retention
  }
  
  config = merge(module.shared_config.environment_settings[local.environment], local.prod_overrides)
}

# Resource Group with enhanced protection
resource "azurerm_resource_group" "main" {
  name     = "rg-\${module.shared_config.name_prefix}-001"
  location = var.location
  
  tags = merge(module.shared_config.common_tags, {
    Purpose     = "production-environment"
    Criticality = "high"
    Compliance  = "required"
  })

  lifecycle {
    prevent_destroy = true  # Protect production resources
  }
}

# Production-grade Key Vault with enhanced security
resource "azurerm_key_vault" "main" {
  name                = "kv-\${var.workload}-\${local.environment}-\${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"  # Premium for HSM protection

  # Production security settings
  enable_rbac_authorization       = true
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Restrict access to specific IP ranges
    ip_rules = var.allowed_ip_ranges
  }

  tags = module.shared_config.common_tags
}

# Production VMs with high availability
resource "azurerm_linux_virtual_machine" "main" {
  count = local.config.vm_count
  
  name                = "vm-\${module.shared_config.name_prefix}-\${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.config.vm_size
  admin_username      = "azureuser"
  
  # Production security settings
  disable_password_authentication = true
  zone                           = local.config.availability_zones[count.index % length(local.config.availability_zones)]

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.config.disk_type
    disk_encryption_set_id = azurerm_disk_encryption_set.main.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(module.shared_config.common_tags, {
    Purpose = "production-vm"
    BackupEnabled = local.config.backup_enabled
  })
}

# Production network interfaces (no public IPs)
resource "azurerm_network_interface" "main" {
  count = local.config.vm_count
  
  name                = "nic-\${module.shared_config.name_prefix}-\${format("%03d", count.index + 1)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.app_subnet_id
    private_ip_address_allocation = "Dynamic"
    # No public IP for production security
  }

  tags = module.shared_config.common_tags
}

# Disk encryption for production compliance
resource "azurerm_disk_encryption_set" "main" {
  name                = "des-\${module.shared_config.name_prefix}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  key_vault_key_id    = azurerm_key_vault_key.main.id

  identity {
    type = "SystemAssigned"
  }

  tags = module.shared_config.common_tags
}

resource "azurerm_key_vault_key" "main" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.disk_encryption
  ]
}

# Access policy for disk encryption
resource "azurerm_key_vault_access_policy" "disk_encryption" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_disk_encryption_set.main.identity.0.tenant_id
  object_id    = azurerm_disk_encryption_set.main.identity.0.principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "azurerm_client_config" "current" {}

# Reference foundation stack
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  
  config = {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                 = "foundation/terraform.tfstate"
  }
}
EOF

# Create production terraform.tfvars
cat << 'EOF' > terraform.tfvars
# Production Environment Configuration
# Enhanced security and compliance settings

organization = "contoso"
workload     = "webapp"
environment  = "prod"
location     = "East US 2"

# Production-specific settings
backup_enabled       = true
monitoring_level     = "premium"
enable_auto_shutdown = false

# Network security
allowed_ip_ranges = [
  "10.0.0.0/8",    # Private network only
  "172.16.0.0/12", # Corporate network
]
EOF
```
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"  # Hardware security modules

  # Production security settings
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90

  # Network access restrictions
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }

  # Restrictive access policy for production
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = var.production_admin_group_id

    secret_permissions = [
      "Get", "List"  # Read-only for most operations
    ]
    
    key_permissions = [
      "Get", "List", "Decrypt", "Encrypt"
    ]
  }

  tags = module.shared_config.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# High-availability VM deployment across zones
resource "azurerm_linux_virtual_machine" "main" {
  count = local.config.vm_count
  
  name                = "vm-${module.shared_config.name_prefix}-${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = local.config.vm_size
  admin_username      = "azureuser"
  zone                = local.config.availability_zones[count.index % length(local.config.availability_zones)]
  
  # Production: SSH keys only, no passwords
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.azurerm_key_vault_secret.ssh_public_key.value
  }

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.config.disk_type
    disk_encryption_set_id = azurerm_disk_encryption_set.main.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Enable boot diagnostics
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(module.shared_config.common_tags, {
    Purpose     = "production-vm"
    Criticality = "high"
    Backup      = "required"
  })

  lifecycle {
    ignore_changes = [
      admin_ssh_key,  # Prevent drift from key rotation
    ]
  }
}

# Production storage account for diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${var.workload}${local.environment}${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  
  # Production security settings
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  tags = module.shared_config.common_tags
}

# Disk encryption for production
resource "azurerm_disk_encryption_set" "main" {
  name                = "des-${module.shared_config.name_prefix}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption.id

  identity {
    type = "SystemAssigned"
  }

  tags = module.shared_config.common_tags
}

# Key for disk encryption
resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault.main
  ]
}
```

### **Key Environment Pattern Benefits Demonstrated**
✅ **Environment Parity**: Same infrastructure code with different configurations
✅ **Configuration Separation**: Environment-specific values externalized
✅ **Promotion Safety**: Changes tested in lower environments first
✅ **Environment-Aware Resources**: Different resources per environment needs
✅ **Security Graduation**: Enhanced security controls in production
✅ **Cost Optimization**: Development cost controls vs production resilience

---

## Next Steps
In Module 3, we'll implement Immutable Infrastructure principles with blue-green deployment patterns for zero-downtime updates and enhanced reliability.
