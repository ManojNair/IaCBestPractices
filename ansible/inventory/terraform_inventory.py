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
