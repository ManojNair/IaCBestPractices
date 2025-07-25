// Enhanced Terraform validation tests
// These tests validate Terraform code without requiring cloud credentials

package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTerraformValidationWithoutCredentials(t *testing.T) {
    t.Parallel()

    // Test the dev environment with local backend
    t.Run("DevEnvironmentValidation", func(t *testing.T) {
        terraformOptions := &terraform.Options{
            TerraformDir: "../environments/dev",
            
            // Use local backend to avoid authentication issues
            BackendConfig: map[string]interface{}{
                "path": "/tmp/terraform-test-dev.tfstate",
            },
            
            // Variables to pass to Terraform for testing
            Vars: map[string]interface{}{
                // Override the file path that doesn't exist
                "ssh_public_key_override": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... test@example.com",
            },
        }

        // Initialize and validate without applying
        _, err := terraform.InitE(t, terraformOptions)
        if err != nil {
            t.Logf("Init failed (expected for backend config): %v", err)
            // Continue with basic validation using init -backend=false
            terraformOptions.BackendConfig = nil
            terraform.RunTerraformCommand(t, terraformOptions, "init", "-backend=false")
        }
        
        // This will validate the syntax without checking remote state
        terraform.Validate(t, terraformOptions)
    })
}

func TestIndividualModulesValidation(t *testing.T) {
    t.Parallel()

    modules := []struct {
        name        string
        path        string
        vars        map[string]interface{}
        description string
    }{
        {
            name: "VNetModule",
            path: "../modules/networking/vnet",
            vars: map[string]interface{}{
                "workload":            "test",
                "environment":         "test",
                "location":           "Australia East",
                "location_short":     "aue",
                "instance":           1,
                "resource_group_name": "rg-test",
                "vnet_cidr":          "10.0.0.0/16",
                "subnet_cidr":        "10.0.1.0/24",
                "common_tags":        map[string]string{"Environment": "test"},
            },
            description: "Virtual Network module should validate correctly",
        },
        {
            name: "NSGModule",
            path: "../modules/networking/nsg",
            vars: map[string]interface{}{
                "name_prefix":         "test",
                "environment":         "test",
                "location":           "Australia East",
                "resource_group_name": "rg-test",
                "allowed_ssh_ips":    []string{"10.0.0.0/8"},
                "allow_http":         true,
                "allow_https":        true,
                "tags":               map[string]string{"Environment": "test"},
            },
            description: "Network Security Group module should validate correctly",
        },
        {
            name: "VMModule",
            path: "../modules/compute/vm",
            vars: map[string]interface{}{
                "workload":            "test",
                "environment":         "test",
                "location":           "Australia East",
                "location_short":     "aue",
                "instance":           1,
                "resource_group_name": "rg-test",
                "subnet_id":          "/subscriptions/test/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/test",
                "admin_username":     "testuser",
                "ssh_public_key":     "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... test@example.com",
                "enable_public_ip":   true,
                "vm_size":            "Standard_B2s",
                "os_disk_type":       "Premium_LRS",
                "common_tags":        map[string]string{"Environment": "test"},
            },
            description: "Virtual Machine module should validate correctly",
        },
    }

    for _, module := range modules {
        module := module // Capture range variable
        t.Run(module.name, func(t *testing.T) {
            t.Parallel()

            terraformOptions := &terraform.Options{
                TerraformDir: module.path,
                Vars:         module.vars,
            }

            // Initialize and validate the module (syntax only)
            terraform.Init(t, terraformOptions)
            
            // For syntax validation, we just need to run validate without vars
            terraform.RunTerraformCommand(t, &terraform.Options{TerraformDir: module.path}, "validate")
            
            t.Logf("✅ %s", module.description)
        })
    }
}

func TestTerraformPlanGeneration(t *testing.T) {
    t.Parallel()

    // Test plan generation for modules that can be planned independently
    modules := []struct {
        name string
        path string
        vars map[string]interface{}
    }{
        {
            name: "VNetModulePlan",
            path: "../modules/networking/vnet",
            vars: map[string]interface{}{
                "workload":            "test",
                "environment":         "test", 
                "location":           "Australia East",
                "location_short":     "aue",
                "instance":           1,
                "resource_group_name": "rg-test",
                "vnet_cidr":          "10.0.0.0/16",
                "subnet_cidr":        "10.0.1.0/24",
                "common_tags":        map[string]string{"Environment": "test"},
            },
        },
    }

    for _, module := range modules {
        module := module
        t.Run(module.name, func(t *testing.T) {
            t.Parallel()

            terraformOptions := &terraform.Options{
                TerraformDir: module.path,
                Vars:         module.vars,
            }

            // Initialize, plan and verify
            terraform.Init(t, terraformOptions)
            planStruct := terraform.InitAndPlan(t, terraformOptions)
            
            // Verify that resources will be created
            resourceCount := terraform.GetResourceCount(t, planStruct)
            assert.Greater(t, resourceCount.Add, 0, "Should plan to create at least one resource")
            
            t.Logf("✅ Plan generated successfully with %d resources to add", resourceCount.Add)
        })
    }
}

func TestTerraformSyntaxValidation(t *testing.T) {
    t.Parallel()

    // Test syntax validation for all directories with .tf files
    directories := []string{
        "../environments/shared",
        "../environments/staging", 
        "../modules/networking/vnet",
        "../modules/networking/nsg",
        "../modules/compute/vm",
        "../stacks/foundation",
    }

    for _, dir := range directories {
        dir := dir
        t.Run("SyntaxValidation-"+dir, func(t *testing.T) {
            t.Parallel()

            terraformOptions := &terraform.Options{
                TerraformDir: dir,
            }

            // Initialize without backend and validate syntax
            terraform.RunTerraformCommand(t, terraformOptions, "init", "-backend=false")
            terraform.Validate(t, terraformOptions)
            
            t.Logf("✅ Syntax validation passed for %s", dir)
        })
    }
}