// Infrastructure testing with Terratest
// Following IaC 3rd Edition testing principles

package test

import (
    "fmt"
    "net"
    "testing"
    "time"

    "github.com/gruntwork-io/terratest/modules/random"
    "github.com/gruntwork-io/terratest/modules/retry"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVMModule(t *testing.T) {
    t.Parallel()

    // Define Terraform options
    terraformOptions := &terraform.Options{
        // Path to the Terraform code
        TerraformDir: "../environments/dev",
        
        // Use default values from locals block in main.tf
        // No variables needed since the configuration uses locals
        
        // Retry options for flaky tests
        RetryableTerraformErrors: map[string]string{
            ".*timeout.*": "Terraform timed out",
        },
        MaxRetries:         3,
        TimeBetweenRetries: 5 * time.Second,
    }

    // Clean up resources after testing
    defer terraform.Destroy(t, terraformOptions)
    
    // Deploy infrastructure first
    terraform.InitAndApply(t, terraformOptions)

    // Test 1: Validate Terraform configuration
    t.Run("TerraformValidate", func(t *testing.T) {
        terraform.InitAndValidate(t, terraformOptions)
    })

    // Test 2: Verify minimal changes (timestamp and IP may change)
    t.Run("TerraformPlan", func(t *testing.T) {
        terraform.Init(t, terraformOptions)
        planStruct := terraform.InitAndPlan(t, terraformOptions)
        
        // The infrastructure may show some changes due to:
        // 1. timestamp() function in CreatedDate tag
        // 2. Current IP detection for SSH access
        resourceCount := terraform.GetResourceCount(t, planStruct)
        
        // Should not plan to create or destroy any resources
        assert.Equal(t, 0, resourceCount.Add, "Should not plan to create any new resources")
        assert.Equal(t, 0, resourceCount.Destroy, "Should not plan to destroy any resources")
        
        // May have changes due to dynamic values (timestamp, current IP) - this is acceptable
        t.Logf("Terraform plan summary: Add=%d, Change=%d, Destroy=%d", 
                resourceCount.Add, resourceCount.Change, resourceCount.Destroy)
        
        if resourceCount.Change > 0 {
            t.Logf("✓ Changes detected likely due to timestamp() or current IP detection - this is expected")
        } else {
            t.Logf("✓ No changes detected - infrastructure state is stable")
        }
    })

    // The following tests run after terraform.InitAndApply(t, terraformOptions)
    // Ensure Azure credentials are configured: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID

    // Test 3: Verify outputs exist
    t.Run("OutputsExist", func(t *testing.T) {
        vmConnection := terraform.OutputMap(t, terraformOptions, "vm_connection")
        assert.NotEmpty(t, vmConnection["vm_name"])
        assert.NotEmpty(t, vmConnection["public_ip"])
        assert.NotEmpty(t, vmConnection["private_ip"])
    })

    // Test 4: Verify VM name output
    t.Run("VMOutput", func(t *testing.T) {
        vmConnection := terraform.OutputMap(t, terraformOptions, "vm_connection")
        vmName := vmConnection["vm_name"]
        
        // Verify VM name is not empty and follows naming convention
        assert.NotEmpty(t, vmName, "VM name should not be empty")
        assert.Contains(t, vmName, "vm", "VM name should contain 'vm'")
        assert.Contains(t, vmName, "webserver", "VM name should contain workload name 'webserver'")
    })

    // Test 5: Verify network security group name output
    t.Run("NetworkSecurityGroupOutput", func(t *testing.T) {
        resourceDetails := terraform.OutputMap(t, terraformOptions, "resource_details")
        nsgName := resourceDetails["nsg_name"]
        
        // Verify NSG name is not empty
        assert.NotEmpty(t, nsgName, "Network Security Group name should not be empty")
        assert.Contains(t, nsgName, "nsg", "NSG name should contain 'nsg'")
    })

    // Test 6: Verify SSH connectivity
    t.Run("SSHConnectivity", func(t *testing.T) {
        vmConnection := terraform.OutputMap(t, terraformOptions, "vm_connection")
        publicIP := vmConnection["public_ip"]
        
        if publicIP != "" {
            // Test SSH port is open
            retry.DoWithRetry(t, "SSH connectivity test", 10, 30*time.Second, func() (string, error) {
                conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:22", publicIP), 10*time.Second)
                if err != nil {
                    return "", err
                }
                defer conn.Close()
                return "SSH port is open", nil
            })
        }
    })

    // Test 7: Verify web server functionality
    t.Run("WebServerHealth", func(t *testing.T) {
        vmConnection := terraform.OutputMap(t, terraformOptions, "vm_connection")
        publicIP := vmConnection["public_ip"]
        
        if publicIP != "" {
            // Test HTTP connectivity
            retry.DoWithRetry(t, "Web server health check", 10, 30*time.Second, func() (string, error) {
                conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:80", publicIP), 10*time.Second)
                if err != nil {
                    return "", fmt.Errorf("HTTP port not accessible: %v", err)
                }
                defer conn.Close()
                return "Web server is responding", nil
            })
        }
    })

    // Test 8: Verify resource group output
    t.Run("ResourceGroupOutput", func(t *testing.T) {
        resourceDetails := terraform.OutputMap(t, terraformOptions, "resource_details")
        resourceGroupName := resourceDetails["resource_group"]
        
        // Verify resource group name is not empty and follows naming convention
        assert.NotEmpty(t, resourceGroupName, "Resource group name should not be empty")
        assert.Contains(t, resourceGroupName, "rg", "Resource group name should contain 'rg'")
        
        // Verify other resource details
        assert.NotEmpty(t, resourceDetails["vnet_name"], "VNet name should not be empty")
        assert.NotEmpty(t, resourceDetails["subnet_name"], "Subnet name should not be empty")
    })
}

// Integration test for the complete environment
func TestCompleteEnvironment(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../environments/dev",
        // Use default values from locals block in main.tf
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Test complete infrastructure stack
    t.Run("InfrastructureStack", func(t *testing.T) {
        // Verify all components are created
        resourceDetails := terraform.OutputMap(t, terraformOptions, "resource_details")
        
        assert.NotEmpty(t, resourceDetails["resource_group"])
        assert.NotEmpty(t, resourceDetails["vnet_name"])
        assert.NotEmpty(t, resourceDetails["subnet_name"])
        assert.NotEmpty(t, resourceDetails["nsg_name"])
        
        vmConnection := terraform.OutputMap(t, terraformOptions, "vm_connection")
        assert.NotEmpty(t, vmConnection["vm_name"])
        assert.NotEmpty(t, vmConnection["public_ip"])
    })
}

// Unit test for NSG module specifically
func TestNSGModule(t *testing.T) {
    t.Parallel()

    uniqueID := random.UniqueId()
    
    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/networking/nsg",
        Vars: map[string]interface{}{
            "name_prefix":         fmt.Sprintf("test-%s", uniqueID),
            "environment":         "unittest",
            "location":           "Australia East",
            "resource_group_name": fmt.Sprintf("rg-test-%s", uniqueID),
            "allowed_ssh_ips":    []string{"10.0.0.0/8"},
            "allow_http":         true,
            "allow_https":        true,
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    
    // This would require pre-created resource group
    // terraform.InitAndApply(t, terraformOptions)

    // Test NSG configuration validation
    terraform.InitAndValidate(t, terraformOptions)
    
    // Verify planned resources
    planStruct := terraform.InitAndPlan(t, terraformOptions)
    resourceCount := terraform.GetResourceCount(t, planStruct)
    assert.Equal(t, 1, resourceCount.Add) // Should create 1 NSG
}
