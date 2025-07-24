# Terraform Enterprise Project Structure
# This directory contains the complete enterprise-grade Terraform implementation

## Directory Structure
```
terraform-enterprise/
├── modules/
│   ├── compute/
│   │   └── vm/
│   └── networking/
│       ├── vnet/
│       └── nsg/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── shared/
│   ├── backend/
│   └── variables/
└── ansible/
    ├── inventories/
    ├── playbooks/
    └── roles/
```

## Usage Instructions

### 1. Setup Remote State Backend
```bash
cd shared/backend
terraform init
terraform plan
terraform apply
```

### 2. Deploy Development Environment
```bash
cd environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Configure with Ansible
```bash
cd ../../ansible
python3 generate_inventory.py
ansible-playbook playbooks/site.yml
```

## Prerequisites
- Terraform >= 1.0
- Azure CLI
- Ansible >= 2.15
- SSH key pair generated

## Security Notes
- Never commit terraform.tfvars files
- Use Azure Key Vault for sensitive data
- Follow least privilege access principles
- Enable state file encryption
