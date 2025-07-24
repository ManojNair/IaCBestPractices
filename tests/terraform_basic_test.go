// Basic Terraform validation tests
// These tests don't require Azure credentials

package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTerraformValidation(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        // Path to the Terraform code
        TerraformDir: "../environments/dev",
        
        // Variables to pass to Terraform
        Vars: map[string]interface{}{
            "workload":       "test",
            "environment":    "test",
            "location":       "Australia East",
            "location_short": "aue",
        },
    }

    // Test 1: Validate Terraform configuration
    t.Run("TerraformValidate", func(t *testing.T) {
        // This will validate the Terraform configuration without applying
        terraform.InitAndValidate(t, terraformOptions)
    })

    // Test 2: Generate and verify Terraform plan
    t.Run("TerraformPlan", func(t *testing.T) {
        // Initialize and create plan
        terraform.Init(t, terraformOptions)
        planStruct := terraform.InitAndPlan(t, terraformOptions)
        
        // Verify that resources will be created
        resourceCount := terraform.GetResourceCount(t, planStruct)
        assert.Greater(t, resourceCount.Add, 0, "Should plan to create at least one resource")
    })
}

func TestTerraformModuleValidation(t *testing.T) {
    t.Parallel()

    // Test individual modules
    modules := []struct {
        name string
        path string
        vars map[string]interface{}
    }{
        {
            name: "networking/vnet",
            path: "../modules/networking/vnet",
            vars: map[string]interface{}{
                "name_prefix":         "test",
                "environment":         "test",
                "location":           "Australia East",
                "resource_group_name": "rg-test",
                "address_space":      []string{"10.0.0.0/16"},
            },
        },
        {
            name: "networking/nsg",
            path: "../modules/networking/nsg",
            vars: map[string]interface{}{
                "name_prefix":         "test",
                "environment":         "test",
                "location":           "Australia East",
                "resource_group_name": "rg-test",
                "allowed_ssh_ips":    []string{"10.0.0.0/8"},
                "allow_http":         true,
                "allow_https":        true,
            },
        },
    }

    for _, module := range modules {
        module := module // capture range variable
        t.Run(module.name, func(t *testing.T) {
            t.Parallel()

            terraformOptions := &terraform.Options{
                TerraformDir: module.path,
                Vars:         module.vars,
            }

            // Validate the module
            terraform.InitAndValidate(t, terraformOptions)
        })
    }
}
