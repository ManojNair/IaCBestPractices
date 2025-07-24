# Workshop Prerequisites and Setup Guide
## Required Tools and Preparation for Enterprise IaC Workshop

---

## 🛠️ Required Software Installation

### **1. Azure CLI**
```bash
# macOS (using Homebrew)
brew install azure-cli

# Verify installation
az --version
az login
```

### **2. Terraform**
```bash
# macOS (using Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform --version
```

### **3. Ansible**
```bash
# Install using pip
pip3 install ansible

# Verify installation
ansible --version
```

### **4. Additional Tools**
```bash
# Git (if not already installed)
brew install git

# jq for JSON processing
brew install jq

# VS Code (recommended)
brew install --cask visual-studio-code
```

---

## 🔑 Azure Account Setup

### **1. Azure Subscription**
- Active Azure subscription with Contributor access
- Verify access: `az account show`

### **2. Service Principal Creation**
```bash
# Create service principal for Terraform
az ad sp create-for-rbac --name "terraform-workshop" \
  --role="Contributor" \
  --scopes="/subscriptions/$(az account show --query id -o tsv)"

# Note down the output - you'll need these values:
# - appId (client_id)
# - password (client_secret)
# - tenant (tenant_id)
```

### **3. Azure Storage for Terraform State**
```bash
# Create resource group for Terraform state
az group create --name "rg-terraform-state" --location "Australia East"

# Create storage account
az storage account create \
  --name "sttfworkshop$(date +%s)" \
  --resource-group "rg-terraform-state" \
  --location "Australia East" \
  --sku "Standard_LRS"

# Create container
az storage container create \
  --name "tfstate" \
  --account-name "<storage-account-name>"
```

---

## 🔐 SSH Key Setup

### **Generate SSH Key Pair**
```bash
# Create SSH directory
mkdir -p ~/.ssh/terraform-workshop

# Generate SSH key pair
ssh-keygen -t ed25519 -C "terraform-workshop" -f ~/.ssh/terraform-workshop/id_ed25519

# Set proper permissions
chmod 700 ~/.ssh/terraform-workshop
chmod 600 ~/.ssh/terraform-workshop/id_ed25519
chmod 644 ~/.ssh/terraform-workshop/id_ed25519.pub

# Display public key (save this for later)
cat ~/.ssh/terraform-workshop/id_ed25519.pub
```

---

## 📁 GitHub Repository Setup

### **1. Create Repository**
```bash
# Create new repository on GitHub
# Clone the repository locally
git clone https://github.com/<your-username>/terraform-enterprise-workshop.git
cd terraform-enterprise-workshop
```

### **2. Configure GitHub Secrets**
Go to your repository Settings → Secrets and variables → Actions, and add:

**Repository Secrets:**
```
AZURE_CLIENT_ID=<your-service-principal-app-id>
AZURE_CLIENT_SECRET=<your-service-principal-password>
AZURE_SUBSCRIPTION_ID=<your-azure-subscription-id>
AZURE_TENANT_ID=<your-azure-tenant-id>
SSH_PRIVATE_KEY=<content-of-private-key-file>
SSH_PUBLIC_KEY=<content-of-public-key-file>
```

### **3. Environment Setup**
- Create environments: `development`, `staging`, `production`
- Configure protection rules for production environment
- Add required reviewers for production deployments

---

## 🧪 Pre-Workshop Verification

### **Test Azure Access**
```bash
# Test Azure CLI login
az login
az account show

# Test service principal
az login --service-principal \
  --username "<client-id>" \
  --password "<client-secret>" \
  --tenant "<tenant-id>"
```

### **Test Terraform**
```bash
# Create test directory
mkdir terraform-test && cd terraform-test

# Create simple test file
cat > main.tf << 'EOF'
terraform {
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

data "azurerm_client_config" "current" {}

output "current_user" {
  value = data.azurerm_client_config.current
}
EOF

# Test Terraform initialization
terraform init
terraform plan

# Clean up
cd .. && rm -rf terraform-test
```

### **Test Ansible**
```bash
# Test Ansible installation
ansible localhost -m ping

# Test Azure modules
ansible localhost -m azure.azcollection.azure_rm_resourcegroup_info
```

---

## 📋 Workshop Materials Checklist

### **Before the Workshop**
- [ ] Azure CLI installed and configured
- [ ] Terraform installed (version >= 1.0)
- [ ] Ansible installed (version >= 2.15)
- [ ] SSH key pair generated
- [ ] Azure service principal created
- [ ] GitHub repository set up with secrets
- [ ] VS Code with Terraform and Ansible extensions

### **During the Workshop**
- [ ] Access to GitHub repository
- [ ] Azure subscription access
- [ ] SSH keys available
- [ ] Note-taking tools ready

### **Workshop Environment Variables**
Create a `.env` file for quick reference (DO NOT COMMIT):
```bash
export ARM_CLIENT_ID="<your-client-id>"
export ARM_CLIENT_SECRET="<your-client-secret>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
export ARM_TENANT_ID="<your-tenant-id>"
export SSH_KEY_PATH="~/.ssh/terraform-workshop/id_ed25519"
```

---

## 🚨 Troubleshooting Common Issues

### **Azure CLI Login Issues**
```bash
# Clear Azure CLI cache
az account clear
az login --use-device-code

# For corporate environments with conditional access
az login --allow-no-subscriptions
```

### **Terraform Provider Issues**
```bash
# Clear Terraform cache
rm -rf .terraform
rm .terraform.lock.hcl
terraform init -upgrade
```

### **SSH Connection Issues**
```bash
# Test SSH key
ssh-add ~/.ssh/terraform-workshop/id_ed25519
ssh-add -l

# Debug SSH connection
ssh -v -i ~/.ssh/terraform-workshop/id_ed25519 user@host
```

### **Ansible Connection Issues**
```bash
# Test Ansible connection
ansible all -i inventory -m ping -v

# Check Ansible configuration
ansible-config dump
```

---

## 📞 Getting Help

### **Workshop Support**
- Slack channel: `#terraform-workshop`
- Email: `devops-team@company.com`
- GitHub Issues: Repository issues tab

### **Technical Resources**
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Ansible Azure Collection](https://docs.ansible.com/ansible/latest/collections/azure/azcollection/)

---

**You're now ready for the Enterprise IaC Workshop! 🚀**
