# Module 3: Immutable Infrastructure with VM Deployment (IaC 3rd Edition)
## Duration: 25 minutes (8 min theory + 17 min hands-on demo)

---

## Theory Section (8 minutes)

### Immutable Infrastructure - The Foundation of Reliable Systems

#### **1. Immutable Infrastructure Principles**
**"Replace, don't modify running infrastructure"**

From IaC 3rd Edition, Immutable Infrastructure means:
- **No In-Place Updates**: Never modify running infrastructure directly
- **Disposable Components**: Infrastructure can be easily recreated
- **Predictable Deployments**: Consistent results through replacement
- **Drift Prevention**: Eliminate configuration drift by design
- **Rollback Capability**: Easy rollback to previous known-good state

**Traditional (Mutable) vs Immutable Approach:**
```
❌ Mutable: Create VM → Update packages → Configure services → Patch
✅ Immutable: Create VM image → Deploy VM → Replace entire VM for updates
```

#### **2. Infrastructure Lifecycle Management**
**"Infrastructure has a defined lifecycle: create, use, replace, destroy"**

**Lifecycle Stages:**
1. **Creation**: Infrastructure provisioned from definition
2. **Active Use**: Infrastructure serves its purpose unchanged  
3. **Replacement**: New infrastructure created, old infrastructure destroyed
4. **Destruction**: Old infrastructure cleanly removed

**Benefits of Immutable Lifecycle:**
- **Consistency**: Each deployment is identical
- **Reliability**: No accumulated configuration drift
- **Testing**: Same process in all environments
- **Speed**: Parallel deployment of new infrastructure
- **Safety**: Old infrastructure remains until new is validated

#### **3. Blue-Green Deployment Pattern**
**"Maintain two identical production environments, switching between them"**

```
Blue Environment (Active)     Green Environment (Standby)
├── Load Balancer ────────────> VMs v1.0
├── Database                   └── Ready for v2.0
└── Storage

Deployment Process:
1. Deploy v2.0 to Green environment
2. Test Green environment thoroughly  
3. Switch traffic from Blue to Green
4. Keep Blue as rollback option
5. Eventually destroy old Blue environment
```

**Implementation with Terraform:**
```hcl
locals {
  # Current deployment slot (blue or green)
  current_slot = var.deployment_slot
  next_slot    = var.deployment_slot == "blue" ? "green" : "blue"
}

# Blue environment resources
resource "azurerm_linux_virtual_machine" "blue" {
  count = var.deployment_slot == "blue" ? var.vm_count : 0
  name  = "vm-${var.workload}-blue-${format("%03d", count.index + 1)}"
  # ...
}

# Green environment resources  
resource "azurerm_linux_virtual_machine" "green" {
  count = var.deployment_slot == "green" ? var.vm_count : 0
  name  = "vm-${var.workload}-green-${format("%03d", count.index + 1)}"
  # ...
}
```

#### **4. Custom Image Pipeline**
**"Bake infrastructure and application configuration into immutable images"**

**Image Creation Process:**
1. **Base Image**: Start with hardened OS image
2. **Security Hardening**: Apply security baselines
3. **Application Installation**: Install and configure applications
4. **Validation**: Test image functionality
5. **Image Storage**: Store in container registry or image gallery
6. **Deployment**: Deploy VMs from custom image

**Packer Integration Example:**
```json
{
  "builders": [
    {
      "type": "azure-arm",
      "subscription_id": "{{user `subscription_id`}}",
      "managed_image_name": "ubuntu-hardened-{{timestamp}}",
      "managed_image_resource_group_name": "rg-images",
      
      "os_type": "Linux",
      "image_publisher": "Canonical",
      "image_offer": "0001-com-ubuntu-server-jammy",
      "image_sku": "22_04-lts-gen2"
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "scripts": [
        "scripts/security-hardening.sh",
        "scripts/install-applications.sh",
        "scripts/configure-monitoring.sh"
      ]
    }
  ]
}
```

#### **5. Infrastructure Health Checks and Validation**
**"Validate infrastructure health before switching traffic"**

**Health Check Categories:**
1. **Resource Health**: All resources created successfully
2. **Network Connectivity**: Services can communicate
3. **Application Health**: Applications respond correctly
4. **Security Posture**: Security controls are active
5. **Performance Baseline**: Meets performance requirements

```hcl
# Health check resources
resource "azurerm_application_gateway" "main" {
  # ...
  
  backend_http_settings {
    name     = "backend-http-settings"
    port     = 80
    protocol = "Http"
    
    # Health probe configuration
    probe_name = "health-probe"
  }
  
  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }
}
```

#### **6. Security Hardening in Immutable Images**
**"Security controls should be baked into the infrastructure"**

**Security Hardening Layers:**
1. **OS Hardening**: CIS benchmarks, kernel hardening
2. **Network Security**: Firewalls, intrusion detection
3. **Access Controls**: SSH configuration, user management
4. **Monitoring**: Security logging, audit trails
5. **Compliance**: Regulatory requirements automated

---

## Hands-on Demo Section (17 minutes)

### **Step 1: Custom VM Image with Packer (4 minutes)**

First, let's create a hardened VM image using Packer:

**packer/ubuntu-hardened.pkr.hcl**
```hcl
# Packer configuration for hardened Ubuntu image
# Implements immutable infrastructure principle

packer {
  required_plugins {
    azure = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

# Variables for image configuration
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "resource_group" {
  type        = string
  description = "Resource group for image building"
  default     = "rg-packer-images"
}

variable "image_name" {
  type        = string
  description = "Name for the custom image"
  default     = "ubuntu-hardened"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

# Azure ARM builder
source "azure-arm" "ubuntu" {
  # Authentication
  subscription_id = var.subscription_id
  
  # Image configuration
  managed_image_name                = "${var.image_name}-${var.environment}-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  managed_image_resource_group_name = var.resource_group
  
  # Base image
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  image_version   = "latest"
  
  # Build VM configuration
  vm_size = "Standard_B2s"
  location = "East US 2"
  
  # Build metadata
  azure_tags = {
    Environment = var.environment
    ImageType   = "hardened-ubuntu"
    BuildDate   = formatdate("YYYY-MM-DD", timestamp())
    ManagedBy   = "packer"
    Purpose     = "immutable-infrastructure"
  }
}

# Build configuration
build {
  name = "ubuntu-hardened"
  sources = ["source.azure-arm.ubuntu"]
  
  # Update system packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y unattended-upgrades",
    ]
  }
  
  # Security hardening script
  provisioner "shell" {
    script = "scripts/security-hardening.sh"
  }
  
  # Install monitoring agent
  provisioner "shell" {
    script = "scripts/install-monitoring.sh"
  }
  
  # Install web server
  provisioner "shell" {
    script = "scripts/install-nginx.sh"
  }
  
  # Final cleanup and preparation
  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
  }
}
```

**packer/scripts/security-hardening.sh**
```bash
#!/bin/bash
# Security hardening script for Ubuntu VM
# Following CIS Ubuntu Linux 22.04 LTS Benchmark

set -e

echo "Starting security hardening process..."

# 1. Configure automatic security updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# 2. Configure SSH hardening
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cat > /etc/ssh/sshd_config << EOF
# SSH Configuration - Security Hardened
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security settings
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Connection settings
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# 3. Configure firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https

# 4. Install and configure fail2ban
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl start fail2ban

# 5. Configure log rotation
cat > /etc/logrotate.d/rsyslog << EOF
/var/log/syslog
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
    rotate 4
    weekly
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF

# 6. Set file permissions
chmod 640 /etc/shadow
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/ssh/sshd_config

echo "Security hardening completed successfully!"
```

### **Step 2: Blue-Green Deployment Infrastructure (5 minutes)**

**blue-green-deployment/main.tf**
```hcl
# Blue-Green Deployment Implementation
# Following Immutable Infrastructure principles from IaC 3rd Edition

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variables for blue-green deployment
variable "deployment_slot" {
  description = "Current deployment slot (blue or green)"
  type        = string
  
  validation {
    condition     = contains(["blue", "green"], var.deployment_slot)
    error_message = "Deployment slot must be either 'blue' or 'green'."
  }
}

variable "vm_count" {
  description = "Number of VMs to deploy"
  type        = number
  default     = 2
}

variable "custom_image_id" {
  description = "ID of the custom VM image"
  type        = string
}

variable "workload" {
  description = "Workload name"
  type        = string
  default     = "webapp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Local values for deployment logic
locals {
  # Current and next deployment slots
  current_slot = var.deployment_slot
  next_slot    = var.deployment_slot == "blue" ? "green" : "blue"
  
  # Naming convention
  name_prefix = "${var.workload}-${var.environment}"
  
  # Common tags
  common_tags = {
    Environment     = var.environment
    Workload        = var.workload
    DeploymentModel = "blue-green"
    ManagedBy       = "terraform"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-bluegreen-001"
  location = "East US 2"
  
  tags = local.common_tags
}

# Application Gateway for traffic routing
resource "azurerm_application_gateway" "main" {
  name                = "agw-${local.name_prefix}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.gateway.id
  }

  frontend_port {
    name = "frontend-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  # Backend pool for blue environment
  backend_address_pool {
    name = "backend-pool-blue"
  }

  # Backend pool for green environment
  backend_address_pool {
    name = "backend-pool-green"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    
    # Health probe
    probe_name = "health-probe"
  }

  # Health probe configuration
  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    
    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "frontend-port"
    protocol                       = "Http"
  }

  # Request routing rule - points to active slot
  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool-${local.current_slot}"
    backend_http_settings_name = "backend-http-settings"
  }

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}-001"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Subnet for Application Gateway
resource "azurerm_subnet" "gateway" {
  name                 = "snet-gateway"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for Blue environment
resource "azurerm_subnet" "blue" {
  name                 = "snet-blue"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Subnet for Green environment
resource "azurerm_subnet" "green" {
  name                 = "snet-green"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "gateway" {
  name                = "pip-gateway-${local.name_prefix}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# Blue Environment VMs
resource "azurerm_linux_virtual_machine" "blue" {
  count = var.deployment_slot == "blue" ? var.vm_count : 0
  
  name                = "vm-${local.name_prefix}-blue-${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.blue[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/terraform-demo/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Use custom hardened image
  source_image_id = var.custom_image_id

  tags = merge(local.common_tags, {
    Slot    = "blue"
    Purpose = "immutable-vm"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Green Environment VMs
resource "azurerm_linux_virtual_machine" "green" {
  count = var.deployment_slot == "green" ? var.vm_count : 0
  
  name                = "vm-${local.name_prefix}-green-${format("%03d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.green[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/terraform-demo/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Use custom hardened image
  source_image_id = var.custom_image_id

  tags = merge(local.common_tags, {
    Slot    = "green"
    Purpose = "immutable-vm"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Network Interfaces for Blue VMs
resource "azurerm_network_interface" "blue" {
  count = var.deployment_slot == "blue" ? var.vm_count : var.vm_count  # Always create for backend pool
  
  name                = "nic-${local.name_prefix}-blue-${format("%03d", count.index + 1)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.blue.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(local.common_tags, {
    Slot = "blue"
  })
}

# Network Interfaces for Green VMs
resource "azurerm_network_interface" "green" {
  count = var.deployment_slot == "green" ? var.vm_count : var.vm_count  # Always create for backend pool
  
  name                = "nic-${local.name_prefix}-green-${format("%03d", count.index + 1)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.green.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(local.common_tags, {
    Slot = "green"
  })
}

# Backend pool associations - Blue
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "blue" {
  count = length(azurerm_network_interface.blue)
  
  network_interface_id    = azurerm_network_interface.blue[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = tolist(azurerm_application_gateway.main.backend_address_pool)[0].id
}

# Backend pool associations - Green
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "green" {
  count = length(azurerm_network_interface.green)
  
  network_interface_id    = azurerm_network_interface.green[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = tolist(azurerm_application_gateway.main.backend_address_pool)[1].id
}
```

### **Step 3: Health Check and Validation Scripts (4 minutes)**

📁 **Working Directory**: `~/tfworkshop/scripts/`

```bash
# Create health check and validation scripts
mkdir -p ~/tfworkshop/scripts
cd ~/tfworkshop/scripts

# Create comprehensive health check script
cat << 'EOF' > health-check.sh
#!/bin/bash
# Health check script for blue-green deployment validation
# Implements health validation from IaC 3rd Edition

set -e

ENVIRONMENT=\${1:-"dev"}
DEPLOYMENT_SLOT=\${2:-"blue"}
HEALTH_ENDPOINT=\${3:-"http://localhost/health"}
MAX_ATTEMPTS=\${4:-30}
SLEEP_INTERVAL=\${5:-10}

echo "Starting health check validation for \${DEPLOYMENT_SLOT} environment..."
echo "Health endpoint: \${HEALTH_ENDPOINT}"
echo "Max attempts: \${MAX_ATTEMPTS}, Interval: \${SLEEP_INTERVAL}s"

# Function to check application health
check_health() {
    local endpoint=\$1
    local response_code=\$(curl -s -o /dev/null -w "%{http_code}" "\${endpoint}" || echo "000")
    
    if [ "\${response_code}" = "200" ]; then
        return 0
    else
        echo "Health check failed with response code: \${response_code}"
        return 1
    fi
}

# Function to validate infrastructure resources
validate_infrastructure() {
    echo "Validating infrastructure components..."
    
    # Check if VMs are running
    local vm_count=\$(az vm list \
        --resource-group "rg-webapp-\${ENVIRONMENT}-bluegreen-001" \
        --query "[?contains(name, '\${DEPLOYMENT_SLOT}') && powerState=='VM running'] | length(@)" \
        --output tsv)
    
    if [ "\${vm_count}" -gt 0 ]; then
        echo "✅ \${vm_count} VMs are running in \${DEPLOYMENT_SLOT} slot"
    else
        echo "❌ No running VMs found in \${DEPLOYMENT_SLOT} slot"
        return 1
    fi
    
    # Check Application Gateway health
    local agw_status=\$(az network application-gateway show \
        --resource-group "rg-webapp-\${ENVIRONMENT}-bluegreen-001" \
        --name "agw-webapp-\${ENVIRONMENT}-001" \
        --query "provisioningState" \
        --output tsv)
    
    if [ "\${agw_status}" = "Succeeded" ]; then
        echo "✅ Application Gateway is healthy"
    else
        echo "❌ Application Gateway status: \${agw_status}"
        return 1
    fi
}

# Main health check logic
main() {
    echo "🔍 Starting comprehensive health validation..."
    
    # Validate infrastructure first
    if ! validate_infrastructure; then
        echo "❌ Infrastructure validation failed"
        exit 1
    fi
    
    # Perform application health checks
    local attempt=1
    while [ \${attempt} -le \${MAX_ATTEMPTS} ]; do
        echo "Health check attempt \${attempt}/\${MAX_ATTEMPTS}..."
        
        if check_health "\${HEALTH_ENDPOINT}"; then
            echo "✅ Health check passed! \${DEPLOYMENT_SLOT} deployment is healthy"
            exit 0
        fi
        
        if [ \${attempt} -lt \${MAX_ATTEMPTS} ]; then
            echo "⏳ Waiting \${SLEEP_INTERVAL}s before retry..."
            sleep \${SLEEP_INTERVAL}
        fi
        
        ((attempt++))
    done
    
    echo "❌ Health check failed after \${MAX_ATTEMPTS} attempts"
    exit 1
}

# Execute main function
main "\$@"
EOF

# Make script executable
chmod +x health-check.sh
```
        return 1
    fi
    
    return 0
}

# Function to perform performance baseline check
performance_check() {
    echo "Performing performance baseline check..."
    
    # Use Apache Bench for basic performance testing
    local response_time=$(curl -s -w "%{time_total}" -o /dev/null "${HEALTH_ENDPOINT}")
    local threshold="2.0"  # 2 seconds threshold
    
    if (( $(echo "${response_time} < ${threshold}" | bc -l) )); then
        echo "✅ Response time: ${response_time}s (threshold: ${threshold}s)"
        return 0
    else
        echo "❌ Response time: ${response_time}s exceeds threshold: ${threshold}s"
        return 1
    fi
}

# Function to check security posture
security_check() {
    echo "Validating security posture..."
    
    # Check if HTTPS redirect is working (if configured)
    local http_response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/health" || echo "000")
    
    # Check for security headers
    local security_headers=$(curl -s -I "${HEALTH_ENDPOINT}" | grep -E "(X-Frame-Options|X-XSS-Protection|X-Content-Type-Options)" | wc -l)
    
    if [ "${security_headers}" -ge 2 ]; then
        echo "✅ Security headers are present"
    else
        echo "⚠️  Some security headers may be missing"
    fi
    
    return 0
}

# Main health check loop
main() {
    echo "=== Infrastructure Validation ==="
    if ! validate_infrastructure; then
        echo "❌ Infrastructure validation failed"
        exit 1
    fi
    
    echo ""
    echo "=== Application Health Check ==="
    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        echo "Attempt ${attempt}/${MAX_ATTEMPTS}: Checking application health..."
        
        if check_health "${HEALTH_ENDPOINT}"; then
            echo "✅ Application health check passed"
            break
        fi
        
        if [ ${attempt} -eq ${MAX_ATTEMPTS} ]; then
            echo "❌ Application health check failed after ${MAX_ATTEMPTS} attempts"
            exit 1
        fi
        
        echo "Waiting ${SLEEP_INTERVAL} seconds before next attempt..."
        sleep ${SLEEP_INTERVAL}
    done
    
    echo ""
    echo "=== Performance Validation ==="
    if ! performance_check; then
        echo "❌ Performance validation failed"
        exit 1
    fi
    
    echo ""
    echo "=== Security Validation ==="
    security_check
    
    echo ""
    echo "🎉 All health checks passed for ${DEPLOYMENT_SLOT} environment!"
    
    # Output deployment information
    echo ""
    echo "=== Deployment Information ==="
    echo "Environment: ${ENVIRONMENT}"
    echo "Active Slot: ${DEPLOYMENT_SLOT}"
    echo "Health Endpoint: ${HEALTH_ENDPOINT}"
    echo "Validation Time: $(date)"
}

# Run main function
main "$@"
```

### **Step 4: Deployment Switching Script (4 minutes)**

**scripts/switch-deployment.sh**
```bash
#!/bin/bash
# Blue-Green deployment switching script
# Implements safe traffic switching from IaC 3rd Edition

set -e

ENVIRONMENT=${1:-"dev"}
TARGET_SLOT=${2:-"green"}
TERRAFORM_DIR=${3:-"./blue-green-deployment"}

echo "Starting blue-green deployment switch to ${TARGET_SLOT}..."

# Function to get current deployment slot
get_current_slot() {
    cd "${TERRAFORM_DIR}"
    terraform output -raw current_deployment_slot 2>/dev/null || echo "blue"
}

# Function to validate target environment
validate_target_environment() {
    local slot=$1
    echo "Validating ${slot} environment..."
    
    # Run health checks on target environment
    if ! ./scripts/health-check.sh "${ENVIRONMENT}" "${slot}"; then
        echo "❌ Health check failed for ${slot} environment"
        return 1
    fi
    
    echo "✅ ${slot} environment validation passed"
    return 0
}

# Function to switch traffic
switch_traffic() {
    local new_slot=$1
    echo "Switching traffic to ${new_slot} environment..."
    
    cd "${TERRAFORM_DIR}"
    
    # Update Terraform variables
    cat > switch.tfvars << EOF
deployment_slot = "${new_slot}"
EOF
    
    # Plan the switch
    echo "Planning traffic switch..."
    terraform plan -var-file="switch.tfvars" -out="switch.tfplan"
    
    # Apply the switch
    echo "Applying traffic switch..."
    terraform apply "switch.tfplan"
    
    # Verify switch was successful
    local applied_slot=$(terraform output -raw current_deployment_slot)
    if [ "${applied_slot}" = "${new_slot}" ]; then
        echo "✅ Traffic successfully switched to ${new_slot}"
        return 0
    else
        echo "❌ Traffic switch verification failed"
        return 1
    fi
}

# Function to perform post-switch validation
post_switch_validation() {
    local slot=$1
    echo "Performing post-switch validation..."
    
    # Wait for traffic to stabilize
    echo "Waiting for traffic to stabilize..."
    sleep 30
    
    # Run health checks on the new active environment
    if ! ./scripts/health-check.sh "${ENVIRONMENT}" "${slot}"; then
        echo "❌ Post-switch validation failed"
        return 1
    fi
    
    # Monitor for any errors in logs
    echo "Monitoring application logs for errors..."
    # (Add log monitoring logic here)
    
    echo "✅ Post-switch validation passed"
    return 0
}

# Function to rollback if needed  
rollback() {
    local current_slot=$1
    local previous_slot=$([ "${current_slot}" = "blue" ] && echo "green" || echo "blue")
    
    echo "⚠️  Rolling back to ${previous_slot} environment..."
    
    if switch_traffic "${previous_slot}"; then
        echo "✅ Rollback to ${previous_slot} completed successfully"
    else
        echo "❌ Rollback failed - manual intervention required!"
        exit 1
    fi
}

# Main deployment switching logic
main() {
    local current_slot=$(get_current_slot)
    
    echo "Current deployment slot: ${current_slot}"
    echo "Target deployment slot: ${TARGET_SLOT}"
    
    if [ "${current_slot}" = "${TARGET_SLOT}" ]; then
        echo "Target slot is already active. No switch needed."
        exit 0
    fi
    
    # Step 1: Validate target environment
    if ! validate_target_environment "${TARGET_SLOT}"; then
        echo "❌ Target environment validation failed. Aborting switch."
        exit 1
    fi
    
    # Step 2: Switch traffic
    if ! switch_traffic "${TARGET_SLOT}"; then
        echo "❌ Traffic switch failed. Aborting."
        exit 1
    fi
    
    # Step 3: Post-switch validation
    if ! post_switch_validation "${TARGET_SLOT}"; then
        echo "❌ Post-switch validation failed. Initiating rollback..."
        rollback "${TARGET_SLOT}"
        exit 1
    fi
    
    echo ""
    echo "🎉 Blue-Green deployment switch completed successfully!"
    echo "Active environment: ${TARGET_SLOT}"
    echo "Previous environment: ${current_slot} (available for rollback)"
    
    # Output next steps
    echo ""
    echo "Next steps:"
    echo "1. Monitor the application for any issues"
    echo "2. Run additional tests if needed"
    echo "3. When confident, destroy the old environment:"
    echo "   terraform destroy -target=azurerm_linux_virtual_machine.${current_slot}"
}

# Trap for cleanup on exit
trap 'echo "Deployment switch interrupted"' INT TERM

# Run main function
main "$@"
```

### **Key Immutable Infrastructure Benefits Demonstrated**
✅ **No In-Place Updates**: VMs are replaced, never modified
✅ **Blue-Green Deployment**: Zero-downtime deployments with easy rollback
✅ **Custom Image Pipeline**: Hardened, consistent VM images
✅ **Health Validation**: Comprehensive health checks before traffic switch
✅ **Automated Rollback**: Safe rollback capability if issues detected
✅ **Infrastructure as Code**: Entire process managed through code

---

## Immutable Infrastructure Advantages

1. **Reliability**: Consistent deployments eliminate configuration drift
2. **Speed**: Parallel deployment reduces downtime
3. **Safety**: Easy rollback to previous known-good state
4. **Testing**: Same deployment process in all environments
5. **Compliance**: Immutable audit trail of all changes
6. **Scalability**: Easy to scale up/down by replacing instances

---

## Next Steps
In Module 4, we'll implement the Pipeline Pattern to automate the entire immutable infrastructure deployment process with comprehensive testing and validation.

### **Step 1: SSH Key Generation (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/`

```bash
# Create SSH key directory for secure access
mkdir -p ~/.ssh/terraform-demo
cd ~/tfworkshop

# Generate SSH key pair with RSA encryption
ssh-keygen -t rsa -b 4096 -C "terraform-demo-\$(date +%Y%m%d)" -f ~/.ssh/terraform-demo/id_rsa -N ""

# Set proper permissions
chmod 700 ~/.ssh/terraform-demo
chmod 600 ~/.ssh/terraform-demo/id_rsa
chmod 644 ~/.ssh/terraform-demo/id_rsa.pub

# Display public key for verification
echo "🔑 Generated SSH Public Key:"
cat ~/.ssh/terraform-demo/id_rsa.pub

echo ""
echo "✅ SSH keys generated successfully!"
echo "📁 Private key: ~/.ssh/terraform-demo/id_rsa"
echo "📁 Public key: ~/.ssh/terraform-demo/id_rsa.pub"
```

### **Step 2: Network Security Module (4 minutes)**

📁 **Working Directory**: `~/tfworkshop/modules/networking/nsg/`

```bash
# Create network security module
mkdir -p ~/tfworkshop/modules/networking/nsg
cd ~/tfworkshop/modules/networking/nsg

# Create main NSG configuration
cat << 'EOF' > main.tf
# Network Security Group for Ubuntu VM
resource "azurerm_network_security_group" "main" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # SSH Access Rule - Restricted to specific IPs
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
  }

  # HTTP Access Rule (if web server)
  dynamic "security_rule" {
    for_each = var.allow_http ? [1] : []
    content {
      name                       = "HTTP"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # HTTPS Access Rule (if web server)
  dynamic "security_rule" {
    for_each = var.allow_https ? [1] : []
    content {
      name                       = "HTTPS"
      priority                   = 1003
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # Deny all other inbound traffic
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

  tags = var.tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  count = var.associate_with_subnet ? 1 : 0
  
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.main.id
}

locals {
  nsg_name = "nsg-\${var.name_prefix}-\${var.environment}-001"
}
EOF

# Create variables for the NSG module
cat << 'EOF' > variables.tf
variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed for SSH access"
  type        = list(string)
  default     = []  # Should be provided - restrict access for security!
}

variable "allow_http" {
  description = "Allow HTTP traffic"
  type        = bool
  default     = false
}

variable "allow_https" {
  description = "Allow HTTPS traffic"
  type        = bool
  default     = false
}

variable "associate_with_subnet" {
  description = "Associate NSG with subnet"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for association"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
EOF

# Create outputs
cat << 'EOF' > outputs.tf
output "nsg_id" {
  description = "Network Security Group ID"
  value       = azurerm_network_security_group.main.id
}

output "nsg_name" {
  description = "Network Security Group name"
  value       = azurerm_network_security_group.main.name
}
EOF

echo "✅ Network Security Group module created!"
echo "📁 Files created:"
echo "   - main.tf (NSG with security rules)"
echo "   - variables.tf (configuration variables)"
echo "   - outputs.tf (NSG ID and name outputs)"
```

### **Step 3: Virtual Machine Module (4 minutes)**

📁 **Working Directory**: `~/tfworkshop/modules/compute/vm/`

```bash
# Create VM module for immutable infrastructure
mkdir -p ~/tfworkshop/modules/compute/vm
cd ~/tfworkshop/modules/compute/vm

# Create main VM configuration
cat << 'EOF' > main.tf
# Ubuntu Virtual Machine Module
# Implements immutable infrastructure principles

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = local.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.main[0].id : null
  }

  tags = local.all_tags
}

# Public IP (conditional)
resource "azurerm_public_ip" "main" {
  count = var.enable_public_ip ? 1 : 0
  
  name                = local.pip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.all_tags
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = local.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Security settings
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  # Custom data for cloud-init
  custom_data = var.custom_data != null ? base64encode(var.custom_data) : null

  tags = local.all_tags

  lifecycle {
    create_before_destroy = true  # Immutable infrastructure principle
  }
}

# Locals for naming and tagging
locals {
  vm_name  = "vm-\${var.workload}-\${var.environment}-\${var.location_short}-\${format("%03d", var.instance)}"
  nic_name = "nic-\${var.workload}-\${var.environment}-\${var.location_short}-\${format("%03d", var.instance)}"
  pip_name = "pip-\${var.workload}-\${var.environment}-\${var.location_short}-\${format("%03d", var.instance)}"
  
  all_tags = merge(
    var.common_tags,
    {
      Module    = "compute/vm"
      Component = "virtual-machine"
      Instance  = var.instance
      VMSize    = var.vm_size
    }
  )
}
EOF

# Create VM variables
cat << 'EOF' > variables.tf
variable "workload" {
  description = "Workload name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "location_short" {
  description = "Short Azure region code"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for VM placement"
  type        = string
}

variable "instance" {
  description = "Instance number"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "Virtual machine size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "enable_public_ip" {
  description = "Enable public IP"
  type        = bool
  default     = false
}

variable "os_disk_type" {
  description = "OS disk storage type"
  type        = string
  default     = "Premium_LRS"
}

variable "vm_image" {
  description = "VM image configuration"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "custom_data" {
  description = "Custom data for cloud-init"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
EOF

# Create VM outputs
cat << 'EOF' > outputs.tf
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
EOF

echo "✅ Virtual Machine module created!"
echo "📁 Module supports:"
echo "   - Immutable infrastructure (create_before_destroy)"
echo "   - Conditional public IP"
echo "   - Custom cloud-init data"
echo "   - Comprehensive tagging"

### **Step 4: VNet Module (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/modules/networking/vnet/`

```bash
# Create VNet module for network infrastructure
mkdir -p ~/tfworkshop/modules/networking/vnet
cd ~/tfworkshop/modules/networking/vnet

# Create VNet configuration
cat << 'EOF' > main.tf
# Virtual Network Module
# Provides isolated network environment for VMs

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.all_tags
}

# VM Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = local.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  count = var.nsg_id != null ? 1 : 0
  
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = var.nsg_id
}

# Locals for naming and tagging
locals {
  vnet_name   = "vnet-\${var.workload}-\${var.environment}-\${var.location_short}-\${format("%03d", var.instance)}"
  subnet_name = "snet-\${var.workload}-\${var.environment}-\${var.location_short}-\${format("%03d", var.instance)}"
  
  all_tags = merge(
    var.common_tags,
    {
      Module    = "networking/vnet"
      Component = "virtual-network"
      Purpose   = "vm-hosting"
    }
  )
}
EOF

# Create VNet variables
cat << 'EOF' > variables.tf
variable "workload" {
  description = "Workload name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "location_short" {
  description = "Short Azure region code"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "instance" {
  description = "Instance number"
  type        = number
  default     = 1
}

variable "vnet_cidr" {
  description = "Virtual network CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "nsg_id" {
  description = "Network Security Group ID to associate"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
EOF

# Create VNet outputs
cat << 'EOF' > outputs.tf
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
EOF

echo "✅ Virtual Network module created!"
echo "📁 Module provides:"
echo "   - Isolated virtual network"
echo "   - VM subnet with configurable CIDR"
echo "   - Optional NSG association"
echo "   - Comprehensive outputs"
```

### **Step 5: Environment Configuration (5 minutes)**

📁 **Working Directory**: `~/tfworkshop/environments/dev/`

```bash
# Create development environment configuration
mkdir -p ~/tfworkshop/environments/dev
cd ~/tfworkshop/environments/dev

# Create main environment configuration
cat << 'EOF' > main.tf
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

  # Remote state backend (update with your storage account)
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-dev"
    storage_account_name = "sttfstatedev001"
    container_name       = "tfstate"
    key                  = "dev/ubuntu-vm.tfstate"
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

# Get current public IP for SSH access
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
  current_ip = "\${chomp(data.http.current_ip.response_body)}/32"
  
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
  name     = "rg-\${local.workload}-\${local.environment}-\${local.location_short}-001"
  location = local.location
  tags     = local.common_tags
}

# Network Security Group Module
module "nsg" {
  source = "../../modules/networking/nsg"
  
  workload            = local.workload
  environment         = local.environment
  location            = local.location
  location_short      = local.location_short
  instance            = 1
  resource_group_name = azurerm_resource_group.main.name
  
  allowed_ssh_ips = [local.current_ip]
  allow_http      = true
  allow_https     = true
  
  common_tags = local.common_tags
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
  nsg_id      = module.nsg.nsg_id
  
  common_tags = local.common_tags
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
      <p>Environment: \${local.environment}</p>
      <p>VM Name: \${local.workload}-vm</p>
      <p>Deployed: \${formatdate("YYYY-MM-DD HH:mm:ss", timestamp())}</p>
    </body>
    </html>
    HTML
  EOT
  
  common_tags = local.common_tags
}
EOF

# Create environment outputs
cat << 'EOF' > outputs.tf
# VM Connection Information
output "vm_connection" {
  description = "VM connection details"
  value = {
    vm_name     = module.ubuntu_vm.vm_name
    public_ip   = module.ubuntu_vm.public_ip
    private_ip  = module.ubuntu_vm.private_ip
    ssh_command = "ssh azureuser@\${module.ubuntu_vm.public_ip}"
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
    vm_link = "https://portal.azure.com/#@/resource\${module.ubuntu_vm.vm_id}/overview"
    rg_link = "https://portal.azure.com/#@/resource/subscriptions/\${data.azurerm_client_config.current.subscription_id}/resourceGroups/\${azurerm_resource_group.main.name}/overview"
  }
}
EOF

# Create terraform.tfvars for customization
cat << 'EOF' > terraform.tfvars
# Development Environment Variables
# Customize these values for your deployment

# Uncomment and modify as needed:
# vm_size = "Standard_B1s"  # Smaller size for cost savings
# location = "West US 2"    # Different region
# workload = "myapp"        # Custom workload name
EOF

echo "✅ Development environment configured!"
echo "📁 Environment includes:"
echo "   - Complete infrastructure as code"
echo "   - Secure SSH access (current IP only)"
echo "   - Web server auto-configuration"
echo "   - Comprehensive outputs and portal links"
```

### **Step 6: Deploy Infrastructure (5 minutes)**

📁 **Working Directory**: `~/tfworkshop/environments/dev/`

```bash
# Initialize Terraform
terraform init

echo "📋 Terraform initialization complete!"
echo "🔍 Planning deployment..."

# Plan deployment (values are configured in locals block)
# Note: No need for -var flags since workload and environment are defined in locals
terraform plan -out=tfplan

echo "📊 Review the plan above carefully!"
echo "✅ If everything looks good, apply with:"
echo "   terraform apply tfplan"

# Apply the configuration (uncomment when ready)
# terraform apply tfplan

echo "🎯 Post-deployment verification:"
echo "1. Check outputs: terraform output"
echo "2. Test SSH: ssh azureuser@\$(terraform output -raw vm_connection | jq -r '.public_ip')"
echo "3. Test web server: curl http://\$(terraform output -raw vm_connection | jq -r '.public_ip')"
echo "4. Monitor in Azure Portal using the provided links"
```

## **🎯 Workshop Summary**

### **What We've Built**

✅ **Modular Infrastructure**: Reusable Terraform modules for NSG, VNet, and VM  
✅ **Security Hardening**: SSH-only access from your current IP  
✅ **Immutable Infrastructure**: VM replacement instead of modification  
✅ **Environment Patterns**: Structured dev/staging/prod approach  
✅ **Enterprise Tagging**: Comprehensive resource organization  

### **Key Learning Outcomes**

🔧 **Module Design**: Created production-ready Terraform modules  
🛡️ **Security Best Practices**: Implemented least-privilege access  
📊 **State Management**: Configured remote backend storage  
🚀 **Deployment Automation**: Streamlined infrastructure provisioning  

### **Next Steps**

1. **Scale Up**: Deploy to staging and production environments
2. **Add Monitoring**: Integrate Azure Monitor and Log Analytics
3. **Implement CI/CD**: Automate deployments with GitHub Actions
4. **Add Load Balancing**: Scale to multiple VM instances

---

**🎉 Module 3 Complete!** You've successfully implemented VM deployment with immutable infrastructure patterns.

Now let's deploy our Ubuntu VM with SSH key authentication:

```bash
# Navigate to the dev environment
cd environments/dev

# Initialize Terraform
terraform init

# Validate the configuration
terraform validate

# Plan the deployment
terraform plan -out=tfplan

# Review the plan and apply
terraform apply tfplan

# Display outputs
terraform output
```

**Expected Output:**
```bash
vm_connection = {
  "private_ip" = "10.0.1.4"
  "public_ip" = "20.62.146.123"
  "ssh_command" = "ssh azureuser@20.62.146.123"
  "vm_name" = "vm-webserver-dev-eus2-001"
}

resource_details = {
  "nsg_name" = "nsg-webserver-dev-eus2-001"
  "resource_group" = "rg-webserver-dev-eus2-001"
  "subnet_name" = "snet-webserver-dev-eus2-001"
  "vnet_name" = "vnet-webserver-dev-eus2-001"
}
```

### **Step 6: Verification and Testing (2 minutes)**

Test the SSH connection and verify the deployment:

```bash
# Test SSH connection
ssh -i ~/.ssh/terraform-demo/id_rsa azureuser@$(terraform output -json vm_connection | jq -r '.public_ip')

# Once connected to the VM, verify the system
ubuntu@vm-webserver-dev-aue-001:~$ lsb_release -a
ubuntu@vm-webserver-dev-aue-001:~$ df -h
ubuntu@vm-webserver-dev-aue-001:~$ sudo systemctl status ssh
ubuntu@vm-webserver-dev-aue-001:~$ exit
```

### **Security Verification Commands**
```bash
# Verify NSG rules
az network nsg rule list --resource-group $(terraform output -json resource_details | jq -r '.resource_group') --nsg-name $(terraform output -json resource_details | jq -r '.nsg_name') --output table

# Check VM status
az vm show --resource-group $(terraform output -json resource_details | jq -r '.resource_group') --name $(terraform output -json vm_connection | jq -r '.vm_name') --show-details --output table
```

### **Key Takeaways**
✅ **Secure SSH access** with key-based authentication
✅ **Network security** with properly configured NSG rules
✅ **Modular deployment** using reusable modules
✅ **Enterprise naming** following Azure CAF standards
✅ **Proper resource organization** with appropriate tagging
✅ **Automated security** with current IP detection

---

## Security Best Practices Implemented

1. **SSH Key Authentication**: Disabled password authentication
2. **Network Isolation**: VM deployed in private subnet with NSG
3. **Minimal Access**: SSH restricted to current public IP only
4. **Resource Tagging**: Complete tagging for governance and cost management
5. **Standard Naming**: Consistent naming convention across all resources
6. **Monitoring Ready**: VM configured for Azure Monitor integration

---

## Next Steps
In Module 4, we'll configure this Ubuntu VM using Ansible for application deployment and system hardening, demonstrating configuration management best practices.
