# Module 4: Infrastructure Automation with Ansible
## Duration: 25 minutes (10 min theory + 15 min hands-on)

---

## Theory Section (10 minutes)

### Configuration Management and Infrastructure Automation

#### **1. Why Ansible for Infrastructure Automation?**
**"Automate the configuration and deployment of applications on infrastructure"**

**Key Benefits:**
- **Agentless**: No software to install on target systems
- **Idempotent**: Safe to run multiple times
- **Declarative**: Describe desired state, not steps
- **Human Readable**: YAML-based playbooks
- **Extensible**: Thousands of modules available

**Infrastructure as Code Stack:**
```
┌─────────────────────────────────────┐
│           Applications              │  ← Ansible manages this layer
├─────────────────────────────────────┤
│        Operating System             │  ← Ansible configures this
├─────────────────────────────────────┤
│    Virtual Machine Infrastructure   │  ← Terraform provisions this
├─────────────────────────────────────┤
│         Cloud Platform              │  ← Azure provides this
└─────────────────────────────────────┘
```

#### **2. Ansible Core Concepts**

**Inventory**: Defines which servers to manage
```yaml
[webservers]
web1 ansible_host=10.0.1.4 ansible_user=azureuser
web2 ansible_host=10.0.1.5 ansible_user=azureuser

[webservers:vars]
ansible_ssh_private_key_file=~/.ssh/terraform-demo/id_rsa
```

**Playbooks**: Define automation tasks
```yaml
- name: Install and configure NGINX
  hosts: webservers
  become: yes
  tasks:
    - name: Install NGINX
      apt:
        name: nginx
        state: present
```

**Modules**: Reusable automation units
- `apt`: Package management
- `service`: Service management  
- `template`: File templating
- `user`: User management

#### **3. Best Practices for Production**

**Security:**
- Use SSH keys, never passwords
- Run tasks with least privilege
- Encrypt sensitive data with Ansible Vault
- Validate SSL certificates

**Reliability:**
- Write idempotent playbooks
- Use handlers for service restarts
- Implement proper error handling
- Test playbooks in staging first

**Maintainability:**
- Use roles for complex configurations
- Keep playbooks DRY (Don't Repeat Yourself)
- Version control all automation code
- Document playbook purposes and variables

#### **4. Integration with Terraform**

**Dynamic Inventory**: Automatically discover Terraform-created resources
```bash
# Generate inventory from Terraform outputs
terraform output -json | jq -r '.vm_connection.value.public_ip'
```

**Workflow Integration:**
1. **Terraform**: Provision infrastructure
2. **Wait**: Allow VM to boot completely
3. **Ansible**: Configure applications and services
4. **Validate**: Test the complete stack

---

## Hands-on Demo Section (15 minutes)

### **Step 1: Install Ansible (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/`

```bash
cd ~/tfworkshop

# Install Ansible using pip (recommended method)
python3 -m pip install --user ansible

# Verify installation
ansible --version

# Install community collections for better modules
ansible-galaxy collection install community.general

echo "✅ Ansible installed successfully!"
echo "📋 Version: $(ansible --version | head -1)"
```

### **Step 2: Create Ansible Directory Structure (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/`

```bash
# Create Ansible directory structure following best practices
mkdir -p ansible/{playbooks,roles,inventory,group_vars,host_vars}
cd ansible

# Create directory structure
tree . || ls -la

echo "📁 Ansible directory structure created:"
echo "   playbooks/  - Automation playbooks"
echo "   roles/      - Reusable automation roles" 
echo "   inventory/  - Server inventory files"
echo "   group_vars/ - Group-specific variables"
echo "   host_vars/  - Host-specific variables"
```

### **Step 3: Generate Dynamic Inventory (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/ansible/`

Create a script to dynamically generate inventory from Terraform:

```bash
# Create dynamic inventory script
cat << 'EOF' > inventory/terraform_inventory.py
#!/usr/bin/env python3

import json
import subprocess
import sys
import os

def get_terraform_output():
    """Get Terraform outputs from the dev environment"""
    try:
        # Change to terraform directory
        tf_dir = "../environments/dev"
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=tf_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting Terraform output: {e}", file=sys.stderr)
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing Terraform JSON: {e}", file=sys.stderr)
        return {}

def generate_inventory():
    """Generate Ansible inventory from Terraform outputs"""
    tf_outputs = get_terraform_output()
    
    if not tf_outputs:
        return {"_meta": {"hostvars": {}}}
    
    inventory = {
        "webservers": {
            "hosts": [],
            "vars": {
                "ansible_user": "azureuser",
                "ansible_ssh_private_key_file": "~/.ssh/terraform-demo/id_rsa",
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
            }
        },
        "_meta": {
            "hostvars": {}
        }
    }
    
    # Extract VM connection info
    if "vm_connection" in tf_outputs:
        vm_conn = tf_outputs["vm_connection"]["value"]
        vm_name = vm_conn.get("vm_name", "unknown")
        public_ip = vm_conn.get("public_ip", "")
        private_ip = vm_conn.get("private_ip", "")
        
        if public_ip:
            inventory["webservers"]["hosts"].append(vm_name)
            inventory["_meta"]["hostvars"][vm_name] = {
                "ansible_host": public_ip,
                "private_ip": private_ip,
                "vm_name": vm_name
            }
    
    return inventory

if __name__ == "__main__":
    inventory = generate_inventory()
    print(json.dumps(inventory, indent=2))
EOF

# Make script executable
chmod +x inventory/terraform_inventory.py

# Test the inventory script
echo "🔍 Testing dynamic inventory:"
python3 inventory/terraform_inventory.py

echo "✅ Dynamic inventory script created and tested!"
```

### **Step 4: Create NGINX Installation Playbook (4 minutes)**

📁 **Working Directory**: `~/tfworkshop/ansible/`

```bash
# Create main NGINX installation and configuration playbook
cat << 'EOF' > playbooks/nginx_setup.yml
---
- name: Install and Configure NGINX Web Server
  hosts: webservers
  become: yes
  gather_facts: yes
  
  vars:
    nginx_port: 80
    nginx_user: www-data
    site_name: "Terraform + Ansible Demo"
    
  pre_tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      tags: [packages]
    
    - name: Wait for automatic system updates to complete
      shell: while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done
      tags: [packages]

  tasks:
    - name: Install NGINX
      apt:
        name: nginx
        state: present
      tags: [packages, nginx]
      notify: start nginx

    - name: Install additional packages
      apt:
        name:
          - curl
          - htop
          - tree
        state: present
      tags: [packages]

    - name: Create custom web directory
      file:
        path: /var/www/demo
        state: directory
        owner: "{{ nginx_user }}"
        group: "{{ nginx_user }}"
        mode: '0755'
      tags: [nginx, config]

    - name: Generate custom index.html
      template:
        src: ../templates/index.html.j2
        dest: /var/www/demo/index.html
        owner: "{{ nginx_user }}"
        group: "{{ nginx_user }}"
        mode: '0644'
      tags: [nginx, config]
      notify: reload nginx

    - name: Create NGINX site configuration
      template:
        src: ../templates/nginx_site.conf.j2
        dest: /etc/nginx/sites-available/demo
        backup: yes
      tags: [nginx, config]
      notify: reload nginx

    - name: Enable the site
      file:
        src: /etc/nginx/sites-available/demo
        dest: /etc/nginx/sites-enabled/demo
        state: link
      tags: [nginx, config]
      notify: reload nginx

    - name: Disable default NGINX site
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent
      tags: [nginx, config]
      notify: reload nginx

    - name: Ensure NGINX is started and enabled
      systemd:
        name: nginx
        state: started
        enabled: yes
      tags: [nginx, service]

    - name: Configure firewall for HTTP
      ufw:
        rule: allow
        port: "{{ nginx_port }}"
        proto: tcp
      tags: [security, firewall]

  handlers:
    - name: start nginx
      systemd:
        name: nginx
        state: started

    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded

    - name: restart nginx
      systemd:
        name: nginx
        state: restarted

  post_tasks:
    - name: Verify NGINX is responding
      uri:
        url: "http://{{ ansible_host }}/"
        method: GET
        status_code: 200
      delegate_to: localhost
      tags: [verification]

    - name: Display success message
      debug:
        msg:
          - "✅ NGINX installation completed successfully!"
          - "🌐 Website URL: http://{{ ansible_host }}/"
          - "🖥️  Server: {{ inventory_hostname }}"
          - "📊 OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
      tags: [verification]
EOF

echo "✅ NGINX playbook created!"
```

### **Step 5: Create Jinja2 Templates (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/ansible/`

```bash
# Create templates directory
mkdir -p templates

# Create HTML template
cat << 'EOF' > templates/index.html.j2
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ site_name }}</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
        }
        h1 { color: #ffd700; text-align: center; margin-bottom: 30px; }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .info-card {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 10px;
            border-left: 4px solid #ffd700;
        }
        .info-card h3 { margin-top: 0; color: #ffd700; }
        .status { 
            text-align: center; 
            font-size: 1.2em; 
            color: #90EE90; 
            font-weight: bold;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 {{ site_name }}</h1>
        
        <div class="status">
            ✅ Infrastructure Successfully Deployed & Configured!
        </div>

        <div class="info-grid">
            <div class="info-card">
                <h3>🖥️ Server Information</h3>
                <p><strong>Hostname:</strong> {{ ansible_hostname }}</p>
                <p><strong>OS:</strong> {{ ansible_distribution }} {{ ansible_distribution_version }}</p>
                <p><strong>Architecture:</strong> {{ ansible_architecture }}</p>
                <p><strong>Kernel:</strong> {{ ansible_kernel }}</p>
            </div>

            <div class="info-card">
                <h3>🌐 Network Information</h3>
                <p><strong>Public IP:</strong> {{ ansible_host }}</p>
                <p><strong>Private IP:</strong> {{ private_ip | default('N/A') }}</p>
                <p><strong>VM Name:</strong> {{ vm_name | default(inventory_hostname) }}</p>
            </div>

            <div class="info-card">
                <h3>🔧 Infrastructure Stack</h3>
                <p><strong>Cloud:</strong> Microsoft Azure</p>
                <p><strong>Region:</strong> Australia East</p>
                <p><strong>Provisioning:</strong> Terraform</p>
                <p><strong>Configuration:</strong> Ansible</p>
            </div>

            <div class="info-card">
                <h3>📊 System Resources</h3>
                <p><strong>CPU Cores:</strong> {{ ansible_processor_vcpus }}</p>
                <p><strong>Memory:</strong> {{ (ansible_memtotal_mb/1024)|round(1) }} GB</p>
                <p><strong>Disk Space:</strong> {{ (ansible_devices.sda.size | replace('GB','') | float) | round(1) }} GB</p>
            </div>
        </div>

        <div class="info-card">
            <h3>🎯 Deployment Details</h3>
            <p><strong>Deployed:</strong> {{ ansible_date_time.iso8601 }}</p>
            <p><strong>Timezone:</strong> {{ ansible_date_time.tz }}</p>
            <p><strong>Web Server:</strong> NGINX {{ ansible_local.nginx.version | default('Latest') }}</p>
            <p><strong>Configuration Method:</strong> Infrastructure as Code</p>
        </div>

        <div class="footer">
            <p>🏗️ Terraform Workshop - Module 4: Ansible Configuration Management</p>
            <p>Demonstrating enterprise-grade Infrastructure as Code practices</p>
        </div>
    </div>
</body>
</html>
EOF

# Create NGINX site configuration template
cat << 'EOF' > templates/nginx_site.conf.j2
server {
    listen {{ nginx_port }};
    listen [::]:{{ nginx_port }};
    
    server_name {{ ansible_host }} {{ ansible_hostname }};
    
    root /var/www/demo;
    index index.html index.htm;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval';" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Security: deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Logging
    access_log /var/log/nginx/demo_access.log;
    error_log /var/log/nginx/demo_error.log;
}
EOF

echo "✅ Jinja2 templates created!"
echo "📄 Templates created:"
echo "   - index.html.j2 (Dynamic HTML page)"
echo "   - nginx_site.conf.j2 (NGINX configuration)"
```

### **Step 6: Deploy NGINX with Ansible (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/ansible/`

```bash
# Ensure Terraform infrastructure is deployed first
echo "🔍 Checking Terraform infrastructure..."
cd ../environments/dev
terraform output vm_connection

# Return to Ansible directory
cd ../../ansible

# Run the NGINX installation playbook
echo "🚀 Deploying NGINX with Ansible..."
ansible-playbook \
  -i inventory/terraform_inventory.py \
  playbooks/nginx_setup.yml \
  --timeout=300

echo "✅ NGINX deployment completed!"
echo "🌐 Your website should now be accessible at:"
python3 inventory/terraform_inventory.py | jq -r '.webservers.hosts[0]' | xargs -I {} echo "   http://$(cd ../environments/dev && terraform output -json vm_connection | jq -r '.value.public_ip')/"
```

### **Step 7: Verification and Testing (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/ansible/`

```bash
# Test the deployment with various checks
echo "🧪 Running verification tests..."

# Get the VM IP for testing
VM_IP=$(cd ../environments/dev && terraform output -json vm_connection | jq -r '.value.public_ip')

# Test HTTP connectivity
echo "1. Testing HTTP connectivity..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$VM_IP/

# Check response content
echo -e "\n2. Checking response content..."
curl -s http://$VM_IP/ | grep -o "<title>[^<]*</title>"

# Test NGINX configuration
echo -e "\n3. Testing NGINX configuration on server..."
ansible webservers \
  -i inventory/terraform_inventory.py \
  -m shell \
  -a "sudo nginx -t" \
  --timeout=30

# Check service status
echo -e "\n4. Checking NGINX service status..."
ansible webservers \
  -i inventory/terraform_inventory.py \
  -m shell \
  -a "sudo systemctl is-active nginx" \
  --timeout=30

# Display final status
echo -e "\n✅ Verification completed!"
echo "🌐 Website URL: http://$VM_IP/"
echo "🔧 Infrastructure: Terraform + Ansible"
echo "📊 Status: Production Ready"
```

---

## Key Takeaways & Best Practices

### **What We Accomplished**
✅ **Dynamic Inventory**: Automatically discovered Terraform-created VMs  
✅ **Idempotent Deployment**: Safe to run multiple times  
✅ **Template-Based Configuration**: Flexible, reusable configurations  
✅ **Security Hardening**: Proper file permissions and security headers  
✅ **Error Handling**: Robust error handling and verification  
✅ **Enterprise Patterns**: Production-ready Ansible structure  

### **Production Considerations**

**Security:**
- Use Ansible Vault for sensitive data
- Implement proper RBAC for Ansible execution
- Use jump hosts for private networks
- Encrypt all communications

**Scalability:**
- Use Ansible roles for complex configurations
- Implement parallel execution strategies
- Use dynamic inventories for cloud environments
- Consider Ansible Tower/AWX for enterprise deployments

**Monitoring:**
- Integrate with monitoring systems (Prometheus, Grafana)
- Implement log aggregation (ELK stack)
- Set up alerting for configuration drift
- Use Ansible callbacks for deployment tracking

### **Next Steps**
In Module 5, we'll implement CI/CD pipelines to automate the entire Terraform + Ansible workflow using GitHub Actions, including automated testing, security scanning, and multi-environment deployments.

---

## Troubleshooting Guide

### **Common Issues & Solutions**

**Issue**: SSH connection failures
```bash
# Solution: Check SSH key permissions and connectivity
chmod 600 ~/.ssh/terraform-demo/id_rsa
ansible webservers -i inventory/terraform_inventory.py -m ping
```

**Issue**: Ansible inventory empty
```bash
# Solution: Verify Terraform outputs exist
cd ../environments/dev && terraform output
```

**Issue**: NGINX fails to start
```bash
# Solution: Check NGINX configuration syntax
ansible webservers -i inventory/terraform_inventory.py -m shell -a "sudo nginx -t"
```

**Issue**: Permission denied errors
```bash
# Solution: Ensure proper sudo configuration
ansible webservers -i inventory/terraform_inventory.py -m shell -a "sudo whoami" --become
```
