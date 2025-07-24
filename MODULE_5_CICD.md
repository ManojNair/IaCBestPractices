# Module 5: Advanced Patterns & Enterprise Architecture (IaC 3rd Edition)
## Duration: 25 minutes (10 min theory + 15 min demo)

---

## Theory Section (10 minutes)

### Advanced IaC Patterns for Enterprise Scale

#### **1. Microstack Architecture Pattern**
**"Compose large systems from small, manageable infrastructure stacks"**

From IaC 3rd Edition, microstack architecture provides:
- **Independent Deployability**: Each stack can be deployed separately
- **Bounded Context**: Clear ownership and responsibility boundaries
- **Technology Diversity**: Different stacks can use different tools
- **Risk Isolation**: Failures in one stack don't affect others
- **Team Autonomy**: Teams can work independently on their stacks

**Microstack Design Principles:**
```
Network Foundation Stack    →    Shared Services
       ↓                              ↓
Application Stack A    ←→    Application Stack B
       ↓                              ↓
Monitoring Stack       ←→    Security Stack
```

**Example Stack Boundaries:**
```hcl
# Foundation Stack (Shared Infrastructure)
module "foundation" {
  source = "./stacks/foundation"
  
  network_config = {
    address_space = ["10.0.0.0/16"]
    subnets = {
      web    = "10.0.1.0/24"
      app    = "10.0.2.0/24"
      data   = "10.0.3.0/24"
    }
  }
}

# Application Stack (Service-Specific)
module "webapp_stack" {
  source = "./stacks/webapp"
  
  depends_on = [module.foundation]
  
  subnet_id = module.foundation.web_subnet_id
  shared_resources = module.foundation.shared_resources
}
```

#### **2. Service Mesh Integration Pattern**
**"Secure and manage service-to-service communication"**

**Azure Service Mesh Architecture:**
```yaml
# Service Mesh with Open Service Mesh (OSM)
apiVersion: install.openservicemesh.io/v1alpha1
kind: MeshConfig
metadata:
  name: osm-mesh-config
spec:
  sidecar:
    enablePrivilegedInitContainer: false
    logLevel: "info"
  traffic:
    enablePermissiveTrafficPolicyMode: false
    enableEgress: true
  observability:
    enableDebugServer: true
    osmLogLevel: "info"
    tracing:
      enable: true
      address: "jaeger.osm-system.svc.cluster.local"
      port: 14268
      endpoint: "/api/traces"
```

**Infrastructure as Code for Service Mesh:**
```hcl
# Service Mesh Infrastructure
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.workload}-${var.environment}"
  location           = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix         = "aks-${var.workload}-${var.environment}"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2s_v3"
    
    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  addon_profile {
    open_service_mesh {
      enabled = true
    }
  }

  identity {
    type = "SystemAssigned"
  }
}
```

#### **3. Multi-Cloud and Hybrid Patterns**
**"Design for portability and vendor independence"**

**Abstraction Layer Design:**
```hcl
# Provider-agnostic compute module interface
module "compute_service" {
  source = "./modules/compute"
  
  # Common interface across providers
  instance_type    = var.instance_size
  instance_count   = var.replicas
  availability_zones = var.zones
  
  # Provider-specific implementation
  provider_config = {
    type = "azure"  # or "aws", "gcp"
    region = var.azure_region
  }
}

# Azure-specific implementation
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  count = var.provider_config.type == "azure" ? 1 : 0
  
  name                = local.compute_name
  resource_group_name = var.resource_group_name
  location           = var.provider_config.region
  sku                = local.azure_vm_size_map[var.instance_type]
  instances          = var.instance_count
  
  # Configuration continues...
}
```

#### **4. GitOps and Infrastructure Delivery**
**"Declarative infrastructure management through Git workflows"**

**GitOps Architecture:**
```
Git Repository (Source of Truth)
       ↓
GitOps Controller (ArgoCD/Flux)
       ↓
Infrastructure State Synchronization
       ↓
Azure Resources
```

**GitOps Workflow with ArgoCD:**
```yaml
# ArgoCD Application for Infrastructure
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure-foundation
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/company/infrastructure
    targetRevision: HEAD
    path: environments/production/foundation
  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

#### **5. Cost Optimization and FinOps Patterns**
**"Implement financial operations for cloud infrastructure"**

**Cost Management Strategies:**
```hcl
# Automated cost optimization
resource "azurerm_policy_assignment" "cost_management" {
  name                 = "cost-optimization-policy"
  scope               = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/cost-optimization"
  
  parameters = jsonencode({
    "allowedVMSizes" = {
      "value" = [
        "Standard_B2s",
        "Standard_B4ms", 
        "Standard_D2s_v3"
      ]
    }
    "autoShutdownEnabled" = {
      "value" = var.environment != "production"
    }
  })
}

# Resource tagging for cost allocation
locals {
  cost_tags = {
    CostCenter     = var.cost_center
    Project        = var.project_name
    Environment    = var.environment
    Owner          = var.team_email
    BudgetAlert    = var.budget_threshold
    AutoShutdown   = var.environment != "production" ? "enabled" : "disabled"
  }
}
```

#### **6. Disaster Recovery and Business Continuity**
**"Design resilient infrastructure with automated recovery"**

**Multi-Region Disaster Recovery:**
```hcl
# Primary region infrastructure
module "primary_region" {
  source = "./modules/regional-stack"
  
  region              = var.primary_region
  environment         = var.environment
  is_primary_region   = true
  
  backup_config = {
    geo_redundant_backup_enabled = true
    backup_retention_days        = 35
    point_in_time_restore_enabled = true
  }
}

# Secondary region (disaster recovery)
module "secondary_region" {
  source = "./modules/regional-stack"
  
  region              = var.secondary_region
  environment         = var.environment
  is_primary_region   = false
  
  # Reference primary region for data replication
  primary_region_config = module.primary_region.replication_config
  
  # Reduced capacity for cost optimization
  compute_scale = 0.3  # 30% of primary region capacity
}

# Traffic Manager for failover
resource "azurerm_traffic_manager_profile" "main" {
  name               = "tm-${var.workload}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  
  traffic_routing_method = "Priority"
  
  dns_config {
    relative_name = var.workload
    ttl          = 100
  }
  
  monitor_config {
    protocol     = "HTTPS"
    port         = 443
    path         = "/health"
  }
}
```

#### **7. Enterprise Security Patterns**
**"Implement zero-trust security architecture"**

**Security Control Framework:**
```hcl
# Zero Trust Network Architecture
module "zero_trust_network" {
  source = "./modules/security/zero-trust"
  
  network_config = {
    micro_segmentation_enabled = true
    default_deny_all          = true
    encryption_in_transit     = "required"
    encryption_at_rest        = "required"
  }
  
  identity_config = {
    multi_factor_auth_required = true
    privileged_access_workstation = true
    just_in_time_access = true
  }
}

# Security monitoring and compliance
resource "azurerm_security_center_subscription_pricing" "main" {
  tier = "Standard"
}

resource "azurerm_log_analytics_workspace" "security" {
  name                = "law-security-${var.environment}"
  location           = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                = "PerGB2018"
  retention_in_days   = 365
}
```

#### **8. Advanced Monitoring and Observability**
**"Implement comprehensive infrastructure observability"**

**Three Pillars of Observability:**
1. **Metrics**: Infrastructure and application performance metrics
2. **Logs**: Structured logging for troubleshooting and audit
3. **Traces**: Distributed tracing for complex system interactions

```hcl
# Observability Stack
module "observability" {
  source = "./modules/observability"
  
  metrics_config = {
    prometheus_enabled = true
    grafana_enabled   = true
    alertmanager_enabled = true
  }
  
  logging_config = {
    elasticsearch_enabled = true
    kibana_enabled       = true
    fluentd_enabled      = true
  }
  
  tracing_config = {
    jaeger_enabled = true
    tempo_enabled  = true
  }
}
```

---

## Hands-on Demo Section (15 minutes)

### **Step 1: Microstack Architecture Implementation (5 minutes)**

📁 **Working Directory**: `~/tfworkshop/stacks/foundation/`

```bash
# Create microstack architecture
cd ~/tfworkshop
mkdir -p stacks/{foundation,platform,webapp}

# Create foundation microstack
cd ~/tfworkshop/stacks/foundation
cat << 'EOF' > main.tf
# Foundation Stack - Shared Infrastructure
# Following microstack pattern from IaC 3rd Edition

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  backend "azurerm" {
    key = "foundation.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Foundation Resource Group
resource "azurerm_resource_group" "foundation" {
  name     = "rg-foundation-\${var.environment}"
  location = var.location
  
  tags = local.foundation_tags
}

# Shared Virtual Network
resource "azurerm_virtual_network" "foundation" {
  name                = "vnet-foundation-\${var.environment}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name

  tags = local.foundation_tags
}

# Application Gateway Subnet
resource "azurerm_subnet" "app_gateway" {
  name                 = "snet-appgw-\${var.environment}"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.foundation.name
  address_prefixes     = [var.app_gateway_subnet_cidr]
}

# Application Subnet  
resource "azurerm_subnet" "application" {
  name                 = "snet-app-\${var.environment}"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.foundation.name
  address_prefixes     = [var.application_subnet_cidr]
  
  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Monitoring Infrastructure
resource "azurerm_log_analytics_workspace" "foundation" {
  name                = "law-foundation-\${var.environment}"
  location            = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = local.foundation_tags
}

locals {
  foundation_tags = merge(var.common_tags, {
    Stack      = "foundation"
    Layer      = "infrastructure"
    ManagedBy  = "terraform"
  })
}
EOF

# Create foundation variables and outputs
cat << 'EOF' > variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US 2"
}

variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_gateway_subnet_cidr" {
  description = "Application Gateway subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "application_subnet_cidr" {
  description = "Application subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "log_retention_days" {
  description = "Log retention period"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
EOF

cat << 'EOF' > outputs.tf
output "resource_group_name" {
  value = azurerm_resource_group.foundation.name
}

output "vnet_id" {
  value = azurerm_virtual_network.foundation.id
}

output "application_subnet_id" {
  value = azurerm_subnet.application.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.foundation.id
}
EOF

echo "✅ Foundation microstack created!"
```
  name                = "vnet-foundation-${var.environment}"
  address_space       = var.network_config.address_space
  location           = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  
  tags = local.foundation_tags
}

# Subnets for different tiers
resource "azurerm_subnet" "foundation_subnets" {
  for_each = var.network_config.subnets
  
  name                 = "snet-${each.key}-${var.environment}"
  resource_group_name  = azurerm_resource_group.foundation.name
  virtual_network_name = azurerm_virtual_network.foundation.name
  address_prefixes     = [each.value]
  
  # Subnet-specific configurations
  dynamic "delegation" {
    for_each = each.key == "aks" ? [1] : []
    content {
      name = "aks-delegation"
      service_delegation {
        name = "Microsoft.ContainerService/managedClusters"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action",
        ]
      }
    }
  }
}

# Shared Network Security Groups
resource "azurerm_network_security_group" "foundation_nsgs" {
  for_each = var.network_config.subnets
  
  name                = "nsg-${each.key}-${var.environment}"
  location           = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  
  tags = local.foundation_tags
}

# NSG Rules based on tier
resource "azurerm_network_security_rule" "web_tier_rules" {
  count = contains(keys(var.network_config.subnets), "web") ? 1 : 0
  
  name                        = "AllowHttpsInbound"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_ranges    = ["80", "443"]
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  resource_group_name        = azurerm_resource_group.foundation.name
  network_security_group_name = azurerm_network_security_group.foundation_nsgs["web"].name
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "foundation" {
  for_each = azurerm_subnet.foundation_subnets
  
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.foundation_nsgs[each.key].id
}

# Shared Key Vault
resource "azurerm_key_vault" "foundation" {
  name                = "kv-foundation-${var.environment}-${random_string.suffix.result}"
  location           = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  tenant_id          = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"
  
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Allow access from foundation subnets
    virtual_network_subnet_ids = [
      for subnet in azurerm_subnet.foundation_subnets : subnet.id
    ]
  }
  
  tags = local.foundation_tags
}

# Shared Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "foundation" {
  name                = "law-foundation-${var.environment}"
  location           = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  sku                = "PerGB2018"
  retention_in_days   = var.log_retention_days
  
  tags = local.foundation_tags
}

# Application Insights for shared telemetry
resource "azurerm_application_insights" "foundation" {
  name                = "ai-foundation-${var.environment}"
  location           = azurerm_resource_group.foundation.location
  resource_group_name = azurerm_resource_group.foundation.name
  workspace_id       = azurerm_log_analytics_workspace.foundation.id
  application_type   = "web"
  
  tags = local.foundation_tags
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Data sources
data "azurerm_client_config" "current" {}

# Local values
locals {
  foundation_tags = merge(var.common_tags, {
    Stack      = "foundation"
    Layer      = "infrastructure"
    ManagedBy  = "terraform"
  })
}
```

**stacks/webapp/main.tf**
```hcl
# WebApp Stack - Application-Specific Infrastructure
# Consumes foundation stack outputs

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  backend "azurerm" {
    key = "webapp.tfstate"
  }
}

# Get foundation stack outputs
data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_storage.resource_group_name
    storage_account_name = var.state_storage.storage_account_name
    container_name      = var.state_storage.container_name
    key                = "foundation.tfstate"
  }
}

# WebApp Resource Group
resource "azurerm_resource_group" "webapp" {
  name     = "rg-webapp-${var.application_name}-${var.environment}"
  location = var.location
  
  tags = local.webapp_tags
}

# Application Service Plan
resource "azurerm_service_plan" "webapp" {
  name                = "asp-${var.application_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.webapp.name
  location           = azurerm_resource_group.webapp.location
  
  os_type  = "Linux"
  sku_name = var.app_service_plan_sku
  
  tags = local.webapp_tags
}

# Linux Web App
resource "azurerm_linux_web_app" "webapp" {
  name                = "app-${var.application_name}-${var.environment}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.webapp.name
  location           = azurerm_service_plan.webapp.location
  service_plan_id    = azurerm_service_plan.webapp.id
  
  site_config {
    application_stack {
      node_version = "18-lts"
    }
    
    always_on = var.environment == "production"
    
    # CORS configuration
    cors {
      allowed_origins = ["*"]  # Configure appropriately for production
    }
  }
  
  # Application settings from Key Vault
  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = data.terraform_remote_state.foundation.outputs.application_insights_instrumentation_key
    "WEBSITE_NODE_DEFAULT_VERSION"         = "~18"
    "ENVIRONMENT"                         = var.environment
    "KEY_VAULT_URI"                      = data.terraform_remote_state.foundation.outputs.key_vault_uri
  }
  
  # Managed Identity for Key Vault access
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.webapp_tags
}

# Key Vault access policy for Web App
resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = data.terraform_remote_state.foundation.outputs.key_vault_id
  tenant_id    = azurerm_linux_web_app.webapp.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.webapp.identity[0].principal_id
  
  secret_permissions = [
    "Get",
    "List"
  ]
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "webapp" {
  app_service_id = azurerm_linux_web_app.webapp.id
  subnet_id     = data.terraform_remote_state.foundation.outputs.subnet_ids["app"]
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Local values
locals {
  webapp_tags = merge(var.common_tags, {
    Stack         = "webapp"
    Application   = var.application_name
    Layer         = "application"
    ManagedBy     = "terraform"
  })
}
```

### **Step 2: GitOps Implementation with ArgoCD (4 minutes)**

📁 **Working Directory**: `~/tfworkshop/.github/workflows/`

```bash
# Create GitOps workflow directory structure
mkdir -p ~/tfworkshop/.github/workflows
cd ~/tfworkshop/.github/workflows

# Create comprehensive GitOps sync workflow
cat << 'EOF' > gitops-sync.yml
name: 'GitOps Infrastructure Sync'

on:
  push:
    branches: [ main ]
    paths: [ 'environments/**', 'stacks/**' ]

env:
  ARGOCD_SERVER: \${{ secrets.ARGOCD_SERVER }}
  ARGOCD_AUTH_TOKEN: \${{ secrets.ARGOCD_AUTH_TOKEN }}

jobs:
  validate-and-sync:
    name: 'Validate and Sync Infrastructure'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0
        
    - name: Validate Infrastructure Code
      run: |
        find . -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do
          echo "Validating \$dir"
          cd "\$dir"
          terraform fmt -check=true
          terraform validate
          cd - > /dev/null
        done
        
    - name: Security Scan with Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
        output_format: sarif
        output_file_path: reports/results.sarif
        
    - name: GitOps Sync to ArgoCD
      run: |
        # Install ArgoCD CLI
        curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /usr/local/bin/argocd
        
        # Login to ArgoCD
        argocd login \$ARGOCD_SERVER --auth-token \$ARGOCD_AUTH_TOKEN --insecure
        
        # Sync all applications
        argocd app sync foundation-stack --timeout 600
        argocd app sync platform-stack --timeout 600
        argocd app sync application-stack --timeout 600
        
        # Wait for healthy status
        argocd app wait foundation-stack --health
        argocd app wait platform-stack --health  
        argocd app wait application-stack --health
        
    - name: Post-deployment Validation
      run: |
        echo "Running post-deployment validation..."
        
        # Check infrastructure health
        if [ -f "scripts/health-check.sh" ]; then
          ./scripts/health-check.sh prod
        fi
        
        # Validate GitOps sync status
        argocd app get foundation-stack -o json | jq '.status.sync.status'
        argocd app get platform-stack -o json | jq '.status.sync.status'
        argocd app get application-stack -o json | jq '.status.sync.status'
EOF
```
          echo "Validating $dir"
          cd "$dir"
          terraform init -backend=false
          terraform validate
          cd - > /dev/null
        done
        
    - name: Install ArgoCD CLI
      run: |
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        
    - name: ArgoCD Login
      run: |
        argocd login $ARGOCD_SERVER --auth-token $ARGOCD_AUTH_TOKEN --insecure
        
    - name: Sync Foundation Stack
      run: |
        argocd app sync infrastructure-foundation --force
        argocd app wait infrastructure-foundation --timeout 600
        
    - name: Sync Application Stacks
      run: |
        # Get list of application stacks
        for app in $(argocd app list -o name | grep -E '^infrastructure-.*' | grep -v foundation); do
          echo "Syncing $app"
          argocd app sync $app --force
          argocd app wait $app --timeout 600
        done
        
    - name: Health Check
      run: |
        # Verify all applications are healthy
        argocd app list --refresh
        
        unhealthy_apps=$(argocd app list -o json | jq -r '.[] | select(.status.health.status != "Healthy") | .metadata.name')
        
        if [ -n "$unhealthy_apps" ]; then
          echo "❌ Unhealthy applications detected:"
          echo "$unhealthy_apps"
          exit 1
        else
          echo "✅ All applications are healthy"
        fi
```

**environments/production/argocd-apps/foundation-app.yaml**
```yaml
# ArgoCD Application for Foundation Stack
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure-foundation
  namespace: argocd
  labels:
    stack: foundation
    environment: production
spec:
  project: infrastructure
  source:
    repoURL: https://github.com/company/infrastructure
    targetRevision: HEAD
    path: environments/production/foundation
    plugin:
      name: terraform
      env:
        - name: TF_VAR_environment
          value: production
        - name: TF_VAR_location
          value: "East US 2"
  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure-foundation
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 3
  
  # Health checks
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
    
  # Notification configuration
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: infrastructure-notifications
    notifications.argoproj.io/subscribe.on-health-degraded.slack: infrastructure-alerts
    notifications.argoproj.io/subscribe.on-sync-failed.slack: infrastructure-alerts
```

### **Step 3: Advanced Cost Optimization (3 minutes)**

**modules/cost-optimization/main.tf**
```hcl
# Cost Optimization Module
# Implements FinOps best practices from IaC 3rd Edition

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Budget and alerts
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${var.workload}-${var.environment}"
  resource_group_id = var.resource_group_id
  
  amount     = var.monthly_budget_limit
  time_grain = "Monthly"
  
  time_period {
    start_date = formatdate("YYYY-MM-01", timestamp())
    end_date   = formatdate("YYYY-MM-01", timeadd(timestamp(), "8760h")) # 1 year
  }
  
  filter {
    dimension {
      name = "ResourceGroupName"
      values = [
        var.resource_group_name
      ]
    }
  }
  
  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"
    
    contact_emails = var.budget_alert_emails
    contact_groups = var.budget_alert_groups
    contact_roles  = ["Owner", "Contributor"]
  }
  
  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"
    
    contact_emails = var.budget_alert_emails
    contact_groups = var.budget_alert_groups
    contact_roles  = ["Owner"]
  }
}

# Auto-shutdown for non-production resources
resource "azurerm_dev_test_global_vm_shutdown_schedule" "main" {
  for_each = var.auto_shutdown_enabled ? var.virtual_machine_ids : {}
  
  virtual_machine_id = each.value
  location          = var.location
  enabled           = true
  
  daily_recurrence_time = var.auto_shutdown_time
  timezone             = var.timezone
  
  notification_settings {
    enabled         = true
    time_in_minutes = 30
    email          = var.shutdown_notification_email
  }
  
  tags = var.tags
}

# Cost anomaly detection
resource "azurerm_monitor_metric_alert" "cost_anomaly" {
  name                = "cost-anomaly-${var.workload}-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes             = [var.resource_group_id]
  
  description = "Alert when cost increases significantly"
  frequency   = "PT1H"
  window_size = "PT6H"
  
  criteria {
    metric_namespace = "Microsoft.Consumption/budgets"
    metric_name      = "ActualCost"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.cost_anomaly_threshold
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.cost_alerts.id
  }
  
  tags = var.tags
}

# Action group for cost alerts
resource "azurerm_monitor_action_group" "cost_alerts" {
  name                = "cost-alerts-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name         = "costalert"
  
  email_receiver {
    name          = "cost-team"
    email_address = var.cost_team_email
  }
  
  sms_receiver {
    name         = "oncall"
    country_code = "1"
    phone_number = var.oncall_phone
  }
  
  webhook_receiver {
    name        = "cost-webhook"
    service_uri = var.cost_webhook_url
  }
  
  tags = var.tags
}
```

### **Step 4: Enterprise Security Implementation (3 minutes)**

**modules/security/zero-trust/main.tf**
```hcl
# Zero Trust Security Module
# Implementing security best practices from IaC 3rd Edition

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Microsoft Defender for Cloud
resource "azurerm_security_center_subscription_pricing" "defender_plans" {
  for_each = toset([
    "VirtualMachines",
    "StorageAccounts", 
    "SqlServers",
    "KeyVaults",
    "AppServices",
    "ContainerRegistry",
    "KubernetesService"
  ])
  
  tier          = "Standard"
  resource_type = each.value
}

# Security Center Auto Provisioning
resource "azurerm_security_center_auto_provisioning" "main" {
  auto_provision = "On"
}

# Network Security with NSG Flow Logs
resource "azurerm_network_watcher_flow_log" "nsg_flow_logs" {
  for_each = var.network_security_group_ids
  
  network_watcher_name      = var.network_watcher_name
  resource_group_name       = var.network_watcher_rg
  network_security_group_id = each.value
  storage_account_id       = azurerm_storage_account.security_logs.id
  enabled                  = true
  
  retention_policy {
    enabled = true
    days    = 90
  }
  
  traffic_analytics {
    enabled               = true
    workspace_id         = var.log_analytics_workspace_id
    workspace_region     = var.location
    workspace_resource_id = var.log_analytics_workspace_id
    interval_in_minutes  = 10
  }
  
  tags = var.tags
}

# Security storage account for logs
resource "azurerm_storage_account" "security_logs" {
  name                     = "saseclogs${var.environment}${random_string.suffix.result}"
  resource_group_name      = var.resource_group_name
  location                = var.location
  account_tier            = "Standard"
  account_replication_type = "GRS"
  
  # Security configurations
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  enable_https_traffic_only       = true
  
  # Network restrictions
  network_rules {
    default_action = "Deny"
    bypass        = ["AzureServices"]
    
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
  
  # Blob properties for security
  blob_properties {
    delete_retention_policy {
      days = 365
    }
    
    versioning_enabled = true
    change_feed_enabled = true
    
    container_delete_retention_policy {
      days = 365
    }
  }
  
  tags = var.tags
}

# Key Vault with advanced security
resource "azurerm_key_vault" "security" {
  name                = "kv-security-${var.environment}-${random_string.suffix.result}"
  location           = var.location
  resource_group_name = var.resource_group_name
  tenant_id          = data.azurerm_client_config.current.tenant_id
  
  sku_name = "premium"  # HSM backed
  
  # Security features
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = false
  enable_rbac_authorization      = true
  purge_protection_enabled       = true
  soft_delete_retention_days     = 90
  
  # Network restrictions
  network_acls {
    bypass                     = "AzureServices"
    default_action            = "Deny"
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
  
  tags = var.tags
}

# Azure Policy for security compliance
resource "azurerm_policy_set_definition" "security_baseline" {
  name         = "security-baseline-${var.environment}"
  policy_type  = "Custom"
  display_name = "Security Baseline for ${title(var.environment)}"
  description  = "Comprehensive security baseline policies"
  
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    reference_id        = "require-secure-transfer-storage"
  }
  
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"
    reference_id        = "require-latest-tls-version"
  }
  
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c"
    reference_id        = "restrict-storage-public-access"
  }
}

# Assign security policy
resource "azurerm_policy_assignment" "security_baseline" {
  name                 = "security-baseline-${var.environment}"
  scope               = var.scope
  policy_definition_id = azurerm_policy_set_definition.security_baseline.id
  
  identity {
    type = "SystemAssigned"
  }
  
  location = var.location
}

# Data sources
data "azurerm_client_config" "current" {}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}
```

---

## Advanced Pattern Benefits

### **1. Microstack Architecture**
✅ **Independent Deployability**: Deploy components separately
✅ **Team Autonomy**: Clear ownership boundaries
✅ **Technology Flexibility**: Use best tool for each stack
✅ **Risk Isolation**: Limit blast radius of changes

### **2. GitOps Integration**
✅ **Declarative Management**: Git as single source of truth
✅ **Automated Synchronization**: Continuous reconciliation
✅ **Audit Trail**: Complete change history
✅ **Rollback Capability**: Easy revert to previous states

### **3. Cost Optimization**
✅ **Proactive Monitoring**: Prevent cost overruns
✅ **Automated Optimization**: Right-size resources automatically
✅ **Budget Controls**: Enforce spending limits
✅ **Anomaly Detection**: Catch unexpected cost increases

### **4. Zero Trust Security**
✅ **Never Trust, Always Verify**: Assume breach mentality
✅ **Least Privilege Access**: Minimal required permissions
✅ **Continuous Monitoring**: Real-time threat detection
✅ **Policy Enforcement**: Automated compliance checking

---

## Workshop Summary

This comprehensive workshop has demonstrated Infrastructure as Code best practices following the principles from **Infrastructure as Code, 3rd Edition** by Kief Morris:

1. **Stack Pattern**: Organized, composable infrastructure stacks
2. **Environment Pattern**: Consistent multi-environment deployment
3. **Immutable Infrastructure**: Replace-don't-modify approach
4. **Pipeline Pattern**: Automated testing and delivery
5. **Advanced Patterns**: Enterprise-scale architecture patterns

These patterns provide the foundation for scalable, reliable, and maintainable infrastructure in enterprise environments.
