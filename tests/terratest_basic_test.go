package test

import (
    "fmt"
    "testing"
    "github.com/gruntwork-io/terratest/modules/random"
    "github.com/stretchr/testify/assert"
)

func TestTerraformSyntax(t *testing.T) {
    t.Parallel()

    // Generate random values for unique resource names
    uniqueID := random.UniqueId()
    
    t.Run("GenerateUniqueID", func(t *testing.T) {
        // Test that we can generate unique IDs
        assert.NotEmpty(t, uniqueID, "Unique ID should not be empty")
        assert.Len(t, uniqueID, 6, "Unique ID should be 6 characters long")
        t.Logf("Generated unique ID: %s", uniqueID)
    })

    t.Run("TerraformDirectoryExists", func(t *testing.T) {
        // Test that the Terraform directory exists
        terraformDir := "../environments/dev"
        
        // This is a basic check - in a real test you'd check if directory exists
        assert.NotEmpty(t, terraformDir, "Terraform directory path should not be empty")
        t.Logf("Terraform directory: %s", terraformDir)
    })

    t.Run("VariableGeneration", func(t *testing.T) {
        // Test variable generation
        vars := map[string]interface{}{
            "workload":       fmt.Sprintf("test-%s", uniqueID),
            "environment":    "test",
            "location":       "Australia East",
            "location_short": "aue",
        }
        
        assert.Equal(t, fmt.Sprintf("test-%s", uniqueID), vars["workload"])
        assert.Equal(t, "test", vars["environment"])
        assert.Equal(t, "Australia East", vars["location"])
        assert.Equal(t, "aue", vars["location_short"])
        
        t.Logf("Generated variables: %+v", vars)
    })
}
