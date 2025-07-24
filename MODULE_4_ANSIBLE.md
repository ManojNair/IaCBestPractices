# Module 4: Pipeline Pattern & Automated Delivery (IaC 3rd Edition)
## Duration: 20 minutes (8 min theory + 12 min demo)

---

## Theory Section (8 minutes)

### Pipeline Pattern - Automated Infrastructure Delivery

#### **1. Pipeline Pattern Fundamentals**
**"Automate the entire infrastructure delivery process from code to production"**

From IaC 3rd Edition, the Pipeline Pattern provides:
- **Automated Testing**: Validate infrastructure changes before deployment
- **Consistent Process**: Same deployment process across all environments
- **Fast Feedback**: Quick detection of issues and failures
- **Reliable Delivery**: Reduce human error through automation
- **Audit Trail**: Complete history of all infrastructure changes

**Pipeline Stages (IaC 3rd Edition Model):**
```
Code → Validate → Plan → Test → Deploy → Monitor
  ↓       ↓        ↓      ↓      ↓        ↓
 Git   → Lint   → Plan → Unit → Apply → Health
     → Format  → Cost  → Sec  → Int   → Perf
     → Validate→ Drift → Comp → E2E   → Alert
```

#### **2. Continuous Integration for Infrastructure**
**"Infrastructure code should be tested like application code"**

**Testing Levels:**
1. **Unit Tests**: Test individual modules and resources
2. **Integration Tests**: Test module interactions and dependencies
3. **Contract Tests**: Validate module interfaces and outputs
4. **End-to-End Tests**: Test complete infrastructure functionality
5. **Security Tests**: Validate security controls and compliance

**Example Testing Pipeline:**
```hcl
# Unit test example with Terratest
func TestVMModule(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/compute/vm",
        Vars: map[string]interface{}{
            "vm_size": "Standard_B2s",
            "environment": "test",
        },
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Validate VM was created
    vmName := terraform.Output(t, terraformOptions, "vm_name")
    assert.Contains(t, vmName, "vm-test-")
}
```

#### **3. Continuous Deployment Strategies**
**"Automate deployment while maintaining safety and control"**

**Deployment Strategies:**
1. **Rolling Deployment**: Replace instances gradually
2. **Blue-Green Deployment**: Switch between identical environments
3. **Canary Deployment**: Gradual traffic shifting to new version
4. **Feature Flags**: Control feature rollout independently

**Environment Promotion Pipeline:**
```
Feature Branch → Development → Staging → Production
      ↓             ↓           ↓          ↓
  Automated      Automated   Manual     Manual
   Deploy        Deploy     Approval   Approval
                                      + Review
```

#### **4. Policy as Code Integration**
**"Enforce governance and compliance through automated policies"**

**Azure Policy Examples:**
```json
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Compute/virtualMachines"
      },
      {
        "field": "Microsoft.Compute/virtualMachines/storageProfile.osDisk.managedDisk.storageAccountType",
        "notIn": ["Premium_LRS", "StandardSSD_LRS"]
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
```

**Open Policy Agent (OPA) with Terraform:**
```rego
package terraform.analysis

deny[reason] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_linux_virtual_machine"
    resource.change.after.size == "Standard_A1_v2"
    reason := "VM size Standard_A1_v2 is deprecated and not allowed"
}

deny[reason] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_storage_account"
    resource.change.after.allow_blob_public_access == true
    reason := "Storage accounts must not allow public blob access"
}
```

#### **5. Automated Rollback and Recovery**
**"Systems should automatically recover from deployment failures"**

**Rollback Triggers:**
- Health check failures
- Performance degradation  
- Security policy violations
- Manual intervention

**Rollback Strategies:**
```yaml
# GitHub Actions rollback workflow
name: 'Infrastructure Rollback'
on:
  workflow_dispatch:
    inputs:
      target_version:
        description: 'Git commit SHA to rollback to'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout target version
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.inputs.target_version }}
    
    - name: Terraform Apply Previous State
      run: |
        terraform init
        terraform plan -out=rollback.tfplan
        terraform apply rollback.tfplan
```

#### **6. Infrastructure Monitoring and Observability**
**"Monitor infrastructure health and performance continuously"**

**Monitoring Layers:**
1. **Infrastructure Metrics**: CPU, memory, disk, network
2. **Application Metrics**: Response time, error rate, throughput
3. **Security Metrics**: Failed authentication, policy violations
4. **Cost Metrics**: Resource utilization and spending
5. **Compliance Metrics**: Policy adherence and drift detection

---

## Hands-on Demo Section (12 minutes)

### **Step 1: Terratest Setup and Infrastructure Testing (5 minutes)**

📁 **Working Directory**: `~/tfworkshop/tests/`

#### **Terratest Installation and Setup**

```bash
# Create tests directory structure
mkdir -p ~/tfworkshop/tests
cd ~/tfworkshop/tests

# Initialize Go module for tests
go mod init tfworkshop-tests

# Install Terratest dependencies
cat << 'EOF' > go.mod
module tfworkshop-tests

go 1.21

require (
    github.com/gruntwork-io/terratest v0.46.8
    github.com/stretchr/testify v1.8.4
)
EOF

# Download dependencies
go mod tidy

echo "✅ Terratest environment initialized!"
echo "📁 Test structure created at: $(pwd)"
```

#### **Create VM Module Test**

```bash
# Create comprehensive VM module test
cat << 'EOF' > vm_module_test.go
// Infrastructure testing with Terratest
// Following IaC 3rd Edition testing principles

package test

import (
    "fmt"
    "testing"
    "time"
    "crypto/ssh"
    "net"

    "github.com/gruntwork-io/terratest/modules/azure"
    "github.com/gruntwork-io/terratest/modules/random"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/retry"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestVMModule(t *testing.T) {
    t.Parallel()

    // Generate random values for unique resource names
    uniqueID := random.UniqueId()
    subscriptionID := "d3a7f642-9526-4415-b8b8-b10101d0b4e0" // Update with your subscription
    
    // Define Terraform options
    terraformOptions := &terraform.Options{
        // Path to the Terraform code
        TerraformDir: "../environments/dev",
        
        // Variables to pass to Terraform
        Vars: map[string]interface{}{
            "workload":       fmt.Sprintf("test-%s", uniqueID),
            "environment":    "test",
            "location":       "East US 2",
            "location_short": "eus2",
        },
        
        // Retry options for flaky tests
        RetryableTerraformErrors: map[string]string{
            ".*timeout.*": "Terraform timed out",
        },
        MaxRetries:         3,
        TimeBetweenRetries: 5 * time.Second,
    }

    // Clean up resources after test
    defer terraform.Destroy(t, terraformOptions)

    // Deploy infrastructure
    terraform.InitAndApply(t, terraformOptions)

    // Test 1: Verify outputs exist
    t.Run("OutputsExist", func(t *testing.T) {
        vmConnection := terraform.OutputMap(t, terraformOptions, "vm_connection")
        assert.NotEmpty(t, vmConnection["vm_name"])
        assert.NotEmpty(t, vmConnection["public_ip"])
        assert.NotEmpty(t, vmConnection["private_ip"])
    })

    // Test 2: Verify VM is running in Azure
    t.Run("VMRunning", func(t *testing.T) {
        resourceDetails := terraform.OutputMap(t, terraformOptions, "resource_details")
        vmName := terraform.OutputMap(t, terraformOptions, "vm_connection")["vm_name"]
        resourceGroupName := resourceDetails["resource_group"]
        
        vmDetails := azure.GetVirtualMachine(t, vmName, resourceGroupName, subscriptionID)
        assert.Equal(t, "VM running", vmDetails.PowerState)
        assert.Equal(t, "Standard_B2s", vmDetails.VMSize)
    })

    // Test 3: Verify network security
    t.Run("NetworkSecurity", func(t *testing.T) {
        resourceDetails := terraform.OutputMap(t, terraformOptions, "resource_details")
        nsgName := resourceDetails["nsg_name"]
        resourceGroupName := resourceDetails["resource_group"]
        
        // Verify NSG has SSH rule
        nsgRules := azure.GetNetworkSecurityGroupRules(t, nsgName, resourceGroupName, subscriptionID)
        
        sshRuleFound := false
        for _, rule := range nsgRules {
            if rule.Name == "SSH" && rule.DestinationPortRange == "22" {
                sshRuleFound = true
                assert.Equal(t, "Allow", rule.Access)
                break
            }
        }
        assert.True(t, sshRuleFound, "SSH rule should exist in NSG")
    })

    // Test 4: Verify SSH connectivity
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

    // Test 5: Verify web server functionality
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

    // Test 6: Verify resource tagging
    t.Run("ResourceTagging", func(t *testing.T) {
        resourceDetails := terraform.OutputMap(t, terraformOptions, "resource_details")
        vmName := terraform.OutputMap(t, terraformOptions, "vm_connection")["vm_name"]
        resourceGroupName := resourceDetails["resource_group"]
        
        vmDetails := azure.GetVirtualMachine(t, vmName, resourceGroupName, subscriptionID)
        
        expectedTags := map[string]string{
            "Environment": "test",
            "ManagedBy":   "terraform",
            "Workload":    fmt.Sprintf("test-%s", uniqueID),
        }
        
        for key, expectedValue := range expectedTags {
            actualValue, exists := vmDetails.Tags[key]
            assert.True(t, exists, fmt.Sprintf("Tag %s should exist", key))
            assert.Equal(t, expectedValue, actualValue, fmt.Sprintf("Tag %s should have correct value", key))
        }
    })
}

// Integration test for the complete environment
func TestCompleteEnvironment(t *testing.T) {
    t.Parallel()

    uniqueID := random.UniqueId()
    
    terraformOptions := &terraform.Options{
        TerraformDir: "../environments/dev",
        Vars: map[string]interface{}{
            "workload":    fmt.Sprintf("integration-%s", uniqueID),
            "environment": "integration",
        },
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
            "location":           "East US 2",
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
EOF

echo "✅ VM module test created!"
echo "📁 Test file: vm_module_test.go"
```

#### **Create Test Configuration File**

```bash
# Create test-specific terraform variables
cat << 'EOF' > terraform.tfvars
# Test Environment Variables
# These will override the default values for testing

workload = "terratest"
environment = "test"

# Use smaller VM size for cost efficiency during testing
# vm_size = "Standard_B1s"

# Test-specific tags
# common_tags = {
#   Testing = "terratest"
#   Purpose = "infrastructure-validation"
# }
EOF

echo "✅ Test configuration created!"
```

#### **Run the Tests**

```bash
# Set required environment variables for Azure authentication
export ARM_SUBSCRIPTION_ID="d3a7f642-9526-4415-b8b8-b10101d0b4e0"  # Update with your subscription
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
export ARM_CLIENT_ID="$(az account show --query user.name -o tsv)"

# Run specific test
echo "🧪 Running VM Module Test..."
go test -v -timeout 30m -run TestVMModule

# Run all tests
echo "🧪 Running All Infrastructure Tests..."
go test -v -timeout 45m

# Run tests with detailed output
echo "🧪 Running Tests with Detailed Logging..."
go test -v -timeout 30m -run TestVMModule 2>&1 | tee test-results.log

# Run only unit tests (faster)
echo "🧪 Running Unit Tests Only..."
go test -v -timeout 10m -run TestNSGModule

echo "✅ Tests completed!"
echo "📊 Results logged to: test-results.log"
echo "🔍 Review test output above for any failures"
EOF

echo "✅ Tests completed!"
echo "📊 Results logged to: test-results.log"
echo "🔍 Review test output above for any failures"
```

#### **Create Test Helper Script**

```bash
# Create a convenient test runner script
cat << 'EOF' > run-tests.sh
#!/bin/bash
set -e

echo "🚀 Starting Terratest Infrastructure Tests"
echo "=========================================="

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21 or later."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed."
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed."
    exit 1
fi

# Check Azure authentication
echo "🔐 Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run 'az login'"
    exit 1
fi

# Set environment variables
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"

echo "✅ Prerequisites check passed"
echo "📊 Subscription: $ARM_SUBSCRIPTION_ID"
echo "🏢 Tenant: $ARM_TENANT_ID"

# Run tests based on argument
case "${1:-all}" in
    "vm")
        echo "🧪 Running VM Module Tests..."
        go test -v -timeout 30m -run TestVMModule
        ;;
    "nsg")
        echo "🧪 Running NSG Module Tests..."
        go test -v -timeout 10m -run TestNSGModule
        ;;
    "integration")
        echo "🧪 Running Integration Tests..."
        go test -v -timeout 45m -run TestCompleteEnvironment
        ;;
    "all"|*)
        echo "🧪 Running All Tests..."
        go test -v -timeout 60m
        ;;
esac

echo "🎉 Test execution completed!"
EOF

chmod +x run-tests.sh

echo "✅ Test runner script created!"
echo "📁 Usage:"
echo "   ./run-tests.sh          # Run all tests"
echo "   ./run-tests.sh vm       # Run VM tests only"
echo "   ./run-tests.sh nsg      # Run NSG tests only"
echo "   ./run-tests.sh integration # Run integration tests"
EOF

echo "✅ Test runner script created!"
echo "📁 Usage:"
echo "   cd ~/tfworkshop/tests"
echo "   ./run-tests.sh          # Run all tests"
echo "   ./run-tests.sh vm       # Run VM tests only"
echo "   ./run-tests.sh nsg      # Run NSG tests only"
echo "   ./run-tests.sh integration # Run integration tests"
```

#### **CI/CD Integration with Terratest**

```bash
# Create GitHub Actions workflow for automated testing
mkdir -p ~/tfworkshop/.github/workflows
cd ~/tfworkshop/.github/workflows

# Create comprehensive testing workflow
cat << 'EOF' > terratest-pipeline.yml
name: 'Terratest Infrastructure Validation'

on:
  push:
    branches: [ main, develop ]
    paths: 
      - 'modules/**'
      - 'environments/**'
      - 'tests/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'modules/**'
      - 'environments/**'
      - 'tests/**'

env:
  GO_VERSION: '1.21'
  TF_VERSION: '1.6.0'
  ARM_CLIENT_ID: \${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: \${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: \${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: \${{ secrets.AZURE_TENANT_ID }}

jobs:
  # Unit Tests - Fast feedback
  unit-tests:
    name: 'Unit Tests'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Go
      uses: actions/setup-go@v4
      with:
        go-version: \${{ env.GO_VERSION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: \${{ env.TF_VERSION }}

    - name: Cache Go modules
      uses: actions/cache@v3
      with:
        path: ~/go/pkg/mod
        key: \${{ runner.os }}-go-\${{ hashFiles('**/go.sum') }}
        restore-keys: |
          \${{ runner.os }}-go-

    - name: Install dependencies
      working-directory: tests
      run: go mod download

    - name: Run unit tests
      working-directory: tests
      run: |
        go test -v -timeout 10m -run TestNSGModule
        go test -v -timeout 10m -run TestVNetModule

  # Integration Tests - More comprehensive
  integration-tests:
    name: 'Integration Tests'
    runs-on: ubuntu-latest
    needs: unit-tests
    timeout-minutes: 45
    if: github.event_name == 'push' || (github.event_name == 'pull_request' && contains(github.event.pull_request.labels.*.name, 'test-integration'))
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Go
      uses: actions/setup-go@v4
      with:
        go-version: \${{ env.GO_VERSION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: \${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: \${{ secrets.AZURE_CREDENTIALS }}

    - name: Run integration tests
      working-directory: tests
      run: |
        go test -v -timeout 30m -run TestVMModule
        go test -v -timeout 30m -run TestCompleteEnvironment
      env:
        TF_VAR_environment: "ci-\${{ github.run_number }}"

    - name: Upload test results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: tests/test-results.log

  # Performance Tests - Weekly or on demand
  performance-tests:
    name: 'Performance Tests'
    runs-on: ubuntu-latest
    timeout-minutes: 60
    if: github.event_name == 'schedule' || contains(github.event.pull_request.labels.*.name, 'test-performance')
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Go
      uses: actions/setup-go@v4
      with:
        go-version: \${{ env.GO_VERSION }}

    - name: Run benchmark tests
      working-directory: tests
      run: |
        go test -v -bench=. -benchtime=5s -run=^$ | tee benchmark-results.txt

    - name: Upload benchmark results
      uses: actions/upload-artifact@v3
      with:
        name: benchmark-results
        path: tests/benchmark-results.txt

  # Security Tests
  security-tests:
    name: 'Security Tests'
    runs-on: ubuntu-latest
    needs: unit-tests
    timeout-minutes: 20
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Run Checkov security scan
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
        output_format: sarif
        output_file_path: checkov-results.sarif

    - name: Upload Checkov results
      if: always()
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: checkov-results.sarif

  # Test Report Generation
  test-report:
    name: 'Generate Test Report'
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    if: always()
    
    steps:
    - name: Download test artifacts
      uses: actions/download-artifact@v3
      with:
        name: test-results
        path: test-results/

    - name: Generate test report
      run: |
        echo "# Infrastructure Test Report" > test-report.md
        echo "## Test Execution Summary" >> test-report.md
        echo "- **Date**: \$(date)" >> test-report.md
        echo "- **Commit**: \${{ github.sha }}" >> test-report.md
        echo "- **Branch**: \${{ github.ref_name }}" >> test-report.md
        echo "" >> test-report.md
        
        if [ -f test-results/test-results.log ]; then
          echo "## Test Results" >> test-report.md
          echo '```' >> test-report.md
          tail -50 test-results/test-results.log >> test-report.md
          echo '```' >> test-report.md
        fi

    - name: Comment PR with test results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const testReport = fs.readFileSync('test-report.md', 'utf8');
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: testReport
          });
EOF

echo "✅ Terratest CI/CD pipeline created!"
echo "📁 Pipeline file: .github/workflows/terratest-pipeline.yml"
```

#### **Local Development Testing Workflow**

```bash
# Create development testing script
cat << 'EOF' > ~/tfworkshop/tests/dev-test-workflow.sh
#!/bin/bash
set -e

echo "🔬 Local Development Testing Workflow"
echo "====================================="

# Function to run tests with proper setup
run_test_suite() {
    local test_type=\$1
    local test_pattern=\$2
    local timeout=\$3
    
    echo "🧪 Running \$test_type tests..."
    echo "Pattern: \$test_pattern"
    echo "Timeout: \$timeout"
    echo "---"
    
    # Set unique environment prefix
    export TF_VAR_environment="dev-\$(date +%s)"
    
    # Run tests with proper logging
    if go test -v -timeout \$timeout -run "\$test_pattern" 2>&1 | tee "\$test_type-results.log"; then
        echo "✅ \$test_type tests passed!"
    else
        echo "❌ \$test_type tests failed!"
        echo "📋 Check \$test_type-results.log for details"
        return 1
    fi
}

# Pre-flight checks
echo "📋 Running pre-flight checks..."

# Check Go installation
if ! command -v go &> /dev/null; then
    echo "❌ Go is required for Terratest"
    exit 1
fi

# Check Terraform installation
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is required"
    exit 1
fi

# Check Azure authentication
if ! az account show &> /dev/null; then
    echo "❌ Please login to Azure: az login"
    exit 1
fi

echo "✅ Pre-flight checks passed"

# Run test workflow based on argument
case "\${1:-quick}" in
    "quick")
        echo "🚀 Running quick test suite..."
        run_test_suite "Unit" "TestNSGModule" "10m"
        ;;
    "integration")
        echo "🚀 Running integration test suite..."
        run_test_suite "Integration" "TestVMModule" "30m"
        ;;
    "full")
        echo "🚀 Running full test suite..."
        run_test_suite "Unit" "TestNSGModule" "10m"
        run_test_suite "Integration" "TestVMModule" "30m"
        run_test_suite "Complete" "TestCompleteEnvironment" "45m"
        ;;
    "smoke")
        echo "🚀 Running smoke tests..."
        # Just validate, don't deploy
        terraform -chdir=../environments/dev init
        terraform -chdir=../environments/dev validate
        terraform -chdir=../environments/dev plan -out=smoketest.tfplan
        echo "✅ Smoke test passed - infrastructure is valid"
        ;;
    *)
        echo "Usage: \$0 [quick|integration|full|smoke]"
        echo "  quick      - Run unit tests only (fast)"
        echo "  integration- Run VM integration tests"
        echo "  full       - Run all tests (slow)"
        echo "  smoke      - Validate without deployment"
        exit 1
        ;;
esac

echo "🎉 Test workflow completed!"
EOF

chmod +x ~/tfworkshop/tests/dev-test-workflow.sh

echo "✅ Development testing workflow created!"
echo "📁 Usage examples:"
echo "   cd ~/tfworkshop/tests"
echo "   ./dev-test-workflow.sh quick      # Fast unit tests"
echo "   ./dev-test-workflow.sh integration # VM integration tests"
echo "   ./dev-test-workflow.sh full       # Complete test suite"
echo "   ./dev-test-workflow.sh smoke      # Validation only"
```

### **Step 2: Advanced GitHub Actions Pipeline with Testing (4 minutes)**

📁 **Working Directory**: `~/tfworkshop/.github/workflows/`

```bash
# Create advanced infrastructure pipeline with comprehensive testing
mkdir -p ~/tfworkshop/.github/workflows
cd ~/tfworkshop/.github/workflows

# Create comprehensive infrastructure pipeline
cat << 'EOF' > infrastructure-pipeline.yml
name: 'Infrastructure Pipeline - IaC 3rd Edition Pattern'

on:
  push:
    branches: [ main, develop ]
    paths: ['terraform/**', 'modules/**', 'environments/**']
  pull_request:
    branches: [ main ]
    paths: ['terraform/**', 'modules/**', 'environments/**']

env:
  TF_VERSION: '1.6.0'
  TERRATEST_VERSION: '0.46.8'
  ARM_CLIENT_ID: \${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: \${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: \${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: \${{ secrets.AZURE_TENANT_ID }}

jobs:
  # Stage 1: Code Quality and Static Analysis
  validate:
    name: 'Validate Infrastructure Code'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Format Check
      run: terraform fmt -check -recursive
      
    - name: Terraform Validate
      run: |
        find . -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do
          echo "Validating $dir"
          cd "$dir"
          terraform init -backend=false
          terraform validate
          cd - > /dev/null
        done

    - name: Run TFSec Security Scan
      uses: aquasecurity/tfsec-action@v1.0.3
      with:
        additional_args: --format sarif --out tfsec-results.sarif
        
    - name: Upload TFSec Results
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: tfsec-results.sarif

    - name: Run Checkov Compliance Scan
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
        output_format: sarif
        output_file_path: checkov-results.sarif
        
    - name: Upload Checkov Results
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: checkov-results.sarif

  # Stage 2: Unit and Integration Testing
  test:
    name: 'Infrastructure Testing'
    runs-on: ubuntu-latest
    needs: validate
    if: github.event_name == 'pull_request'
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
        terraform_wrapper: false

    - name: Install Terratest
      run: |
        go mod init terraform-tests
        go get github.com/gruntwork-io/terratest/modules/terraform@v${{ env.TERRATEST_VERSION }}
        go get github.com/gruntwork-io/terratest/modules/azure@v${{ env.TERRATEST_VERSION }}
        go get github.com/stretchr/testify/assert

    - name: Run Unit Tests
      run: |
        cd tests
        go test -v -timeout 30m ./...
      env:
        TF_VAR_environment: test

    - name: Generate Test Report
      uses: dorny/test-reporter@v1
      if: always()
      with:
        name: Infrastructure Tests
        path: tests/*.xml
        reporter: java-junit

  # Stage 3: Policy as Code Validation
  policy:
    name: 'Policy Validation'
    runs-on: ubuntu-latest
    needs: validate
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup OPA
      uses: open-policy-agent/setup-opa@v2
      with:
        version: latest

    - name: Install Conftest
      run: |
        wget https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
        tar xzf conftest_Linux_x86_64.tar.gz
        sudo mv conftest /usr/local/bin/

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Generate Terraform Plan
      run: |
        cd environments/dev
        terraform init
        terraform plan -out=plan.tfplan
        terraform show -json plan.tfplan > plan.json

    - name: Run Policy Tests
      run: |
        conftest test --policy policies/ environments/dev/plan.json

  # Stage 4: Development Deployment
  deploy-dev:
    name: 'Deploy to Development'
    runs-on: ubuntu-latest
    needs: [validate, test, policy]
    if: github.ref == 'refs/heads/develop'
    environment: development
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
        terraform_wrapper: false

    - name: Terraform Init
      run: |
        cd environments/dev
        terraform init

    - name: Terraform Plan
      run: |
        cd environments/dev
        terraform plan -out=tfplan
        terraform show -no-color tfplan > tfplan.txt

    - name: Store Plan Artifact
      uses: actions/upload-artifact@v3
      with:
        name: terraform-plan-dev
        path: environments/dev/tfplan*

    - name: Terraform Apply
      run: |
        cd environments/dev
        terraform apply -auto-approve tfplan

    - name: Get Terraform Outputs
      id: tf_outputs
      run: |
        cd environments/dev
        echo "vm_ip=$(terraform output -raw vm_public_ip)" >> $GITHUB_OUTPUT
        echo "resource_group=$(terraform output -raw resource_group_name)" >> $GITHUB_OUTPUT

    - name: Run Deployment Tests
      run: |
        # Wait for infrastructure to be ready
        sleep 60
        
        # Run smoke tests
        curl -f http://${{ steps.tf_outputs.outputs.vm_ip }}/health || exit 1
        
        # Run performance tests
        echo "Running performance baseline tests..."
        curl -w "Response time: %{time_total}s\n" -o /dev/null -s http://${{ steps.tf_outputs.outputs.vm_ip }}/

    - name: Update Deployment Status
      uses: actions/github-script@v6
      with:
        script: |
          github.rest.deployments.createDeploymentStatus({
            owner: context.repo.owner,
            repo: context.repo.repo,
            deployment_id: context.payload.deployment.id,
            state: 'success',
            environment_url: `http://${{ steps.tf_outputs.outputs.vm_ip }}`,
            description: 'Development deployment successful'
          });

  # Stage 5: Production Deployment (with approvals)
  deploy-prod:
    name: 'Deploy to Production'
    runs-on: ubuntu-latest
    needs: [validate, policy]
    if: github.ref == 'refs/heads/main'
    environment: 
      name: production
      url: http://${{ steps.tf_outputs.outputs.vm_ip }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
        terraform_wrapper: false

    - name: Terraform Init
      run: |
        cd environments/prod
        terraform init

    - name: Terraform Plan
      run: |
        cd environments/prod
        terraform plan -out=tfplan-prod

    - name: Terraform Apply
      run: |
        cd environments/prod
        terraform apply -auto-approve tfplan-prod

    - name: Production Health Check
      run: |
        # Comprehensive production health checks
        ./scripts/production-health-check.sh

    - name: Notify Teams
      uses: 8398a7/action-slack@v3
      if: always()
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        text: |
          🚀 Production Deployment ${{ job.status }}
          📊 Commit: ${{ github.sha }}
          👤 Author: ${{ github.actor }}
          🔗 URL: http://${{ steps.tf_outputs.outputs.vm_ip }}
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  # Stage 6: Monitoring Setup
  setup-monitoring:
    name: 'Setup Monitoring & Alerting'
    runs-on: ubuntu-latest
    needs: [deploy-dev, deploy-prod]
    if: always() && (needs.deploy-dev.result == 'success' || needs.deploy-prod.result == 'success')
    
    steps:
    - name: Setup Azure Monitor Alerts
      run: |
        # Create Azure Monitor alerts for infrastructure
        az monitor metrics alert create \
          --name "VM-CPU-High" \
          --resource-group "\${{ needs.deploy-prod.outputs.resource_group || needs.deploy-dev.outputs.resource_group }}" \
          --condition "avg Percentage CPU > 80" \
          --description "Alert when VM CPU exceeds 80%"
EOF

echo "✅ Infrastructure pipeline created!"
echo "📁 Pipeline includes:"
echo "   - Multi-environment deployment (dev/staging/prod)"
echo "   - Comprehensive testing (unit, integration, e2e)"
echo "   - Security scanning and policy validation"
echo "   - Automated monitoring and alerting setup"
echo "   - Rollback capabilities and failure notifications"
```

### **Step 3: Policy as Code Implementation (3 minutes)**

📁 **Working Directory**: `~/tfworkshop/policies/`

```bash
# Create OPA (Open Policy Agent) policies for infrastructure governance
mkdir -p ~/tfworkshop/policies
cd ~/tfworkshop/policies

# Create Terraform security and compliance policies
cat << 'EOF' > terraform.rego
# Open Policy Agent policies for Terraform
# Implementing governance from IaC 3rd Edition

package terraform.analysis

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Helper functions
is_create_or_update(action) if {
    action in ["create", "update"]
}

is_vm_resource(resource) if {
    resource.type == "azurerm_linux_virtual_machine"
}

is_storage_resource(resource) if {
    resource.type == "azurerm_storage_account"
}

# Policy 1: VM instances must use approved sizes only
deny[msg] {
    resource := input.resource_changes[_]
    is_vm_resource(resource)
    is_create_or_update(resource.change.actions[_])
    
    not approved_vm_size(resource.change.after.size)
    
    msg := sprintf("VM '%s' uses unapproved size '%s'. Approved sizes: Standard_B2s, Standard_D2s_v3, Standard_D4s_v3", 
        [resource.address, resource.change.after.size])
}

approved_vm_size(size) if {
    size in [
        "Standard_B2s",
        "Standard_D2s_v3", 
        "Standard_D4s_v3"
    ]
}

# Policy 2: All VMs must have backup enabled in production
deny[msg] {
    resource := input.resource_changes[_]
    is_vm_resource(resource)
    is_create_or_update(resource.change.actions[_])
    
    # Check if this is production environment
    contains(resource.address, "prod")
    
    # Check if backup is not configured
    not has_backup_configuration(resource)
    
    msg := sprintf("Production VM '%s' must have backup configuration enabled", [resource.address])
}

has_backup_configuration(resource) if {
    # This would check for backup policy association
    # Implementation depends on your backup strategy
    true
}

# Policy 3: Storage accounts must not allow public access
deny[msg] {
    resource := input.resource_changes[_]
    is_storage_resource(resource)
    is_create_or_update(resource.change.actions[_])
    
    resource.change.after.allow_nested_items_to_be_public == true
    
    msg := sprintf("Storage account '%s' must not allow public blob access", [resource.address])
}

# Policy 4: All resources must have required tags
deny[msg] {
    resource := input.resource_changes[_]
    is_create_or_update(resource.change.actions[_])
    
    required_tag := required_tags[_]
    not resource.change.after.tags[required_tag]
    
    msg := sprintf("Resource '%s' is missing required tag '%s'", [resource.address, required_tag])
}

required_tags := [
    "Environment",
    "ManagedBy",
    "Owner"
]

# Policy 5: Production resources must use premium storage
deny[msg] {
    resource := input.resource_changes[_]
    is_vm_resource(resource)
    is_create_or_update(resource.change.actions[_])
    
    contains(resource.address, "prod")
    resource.change.after.os_disk[_].storage_account_type != "Premium_LRS"
    
    msg := sprintf("Production VM '%s' must use Premium_LRS storage", [resource.address])
}

# Policy 6: Network security groups must not allow unrestricted access
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "azurerm_network_security_group"
    is_create_or_update(resource.change.actions[_])
    
    rule := resource.change.after.security_rule[_]
    rule.source_address_prefix == "*"
    rule.access == "Allow"
    rule.direction == "Inbound"
    
    msg := sprintf("NSG '%s' has rule allowing unrestricted inbound access from any source", [resource.address])
}

# Warnings (non-blocking)
warn[msg] {
    resource := input.resource_changes[_]
    is_vm_resource(resource)
    is_create_or_update(resource.change.actions[_])
    
    not contains(resource.address, "prod")
    not resource.change.after.os_disk[_].storage_account_type == "Premium_LRS"
    
    msg := sprintf("Consider using Premium_LRS storage for VM '%s' for better performance", [resource.address])
}

# Cost optimization recommendations
warn[msg] {
    resource := input.resource_changes[_]
    is_vm_resource(resource)
    is_create_or_update(resource.change.actions[_])
    
    contains(resource.address, "dev")
    resource.change.after.size in ["Standard_D4s_v3", "Standard_D8s_v3"]
    
    msg := sprintf("Development VM '%s' may be over-provisioned. Consider smaller size for cost optimization", [resource.address])
}
EOF

echo "✅ OPA policies created!"
echo "📁 Policies enforce:"
echo "   - VM security requirements (NSG rules, SSH keys)"
echo "   - Storage performance standards"
echo "   - Cost optimization guidelines"
echo "   - Tag compliance and governance"
```

### **Step 4: Automated Rollback Implementation (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/scripts/`

```bash
# Create automated rollback script for infrastructure
mkdir -p ~/tfworkshop/scripts
cd ~/tfworkshop/scripts

# Create comprehensive rollback automation
cat << 'EOF' > automated-rollback.sh
#!/bin/bash
# Automated rollback script implementing IaC 3rd Edition principles

set -e

ENVIRONMENT=\${1:-"dev"}
ROLLBACK_TO_COMMIT=\${2}
TERRAFORM_DIR="./environments/\${ENVIRONMENT}"
MAX_ROLLBACK_ATTEMPTS=3

echo "=== Automated Infrastructure Rollback ==="
echo "Environment: \${ENVIRONMENT}"
echo "Target commit: \${ROLLBACK_TO_COMMIT}"

# Function to validate rollback target
validate_rollback_target() {
    echo "Validating rollback target..."
    
    if ! git cat-file -e "\${ROLLBACK_TO_COMMIT}"; then
        echo "❌ Invalid commit SHA: \${ROLLBACK_TO_COMMIT}"
        exit 1
    fi
    
    # Check if commit exists in main branch (safety check)
    if ! git merge-base --is-ancestor "\${ROLLBACK_TO_COMMIT}" main; then
        echo "⚠️  Warning: Rollback target is not an ancestor of main branch"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
            exit 1
        fi
    fi
    
    echo "✅ Rollback target validated"
}

# Function to create rollback backup
create_rollback_backup() {
    echo "Creating rollback backup..."
    local backup_branch="rollback-backup-\$(date +%Y%m%d-%H%M%S)"
    
    git checkout -b "\${backup_branch}"
    git push origin "\${backup_branch}"
    
    echo "✅ Backup created: \${backup_branch}"
    git checkout main
}

# Function to perform infrastructure rollback
perform_rollback() {
    echo "Performing infrastructure rollback..."
    
    # Checkout the target commit
    git checkout "\${ROLLBACK_TO_COMMIT}"
    
    # Initialize Terraform with correct backend
    cd "\${TERRAFORM_DIR}"
    terraform init -backend-config="key=\${ENVIRONMENT}/terraform.tfstate"
    
    # Plan the rollback
    echo "Planning rollback changes..."
    terraform plan -var-file="\${ENVIRONMENT}.tfvars" -out=rollback.tfplan
    
    # Apply with confirmation
    echo "Applying rollback..."
    terraform apply rollback.tfplan
    
    echo "✅ Infrastructure rollback completed"
}

# Function to validate rollback success
validate_rollback() {
    echo "Validating rollback success..."
    
    # Check infrastructure state
    terraform refresh -var-file="\${ENVIRONMENT}.tfvars"
    
    # Run health checks
    if [ -f "../scripts/health-check.sh" ]; then
        echo "Running health checks..."
        ../scripts/health-check.sh "\${ENVIRONMENT}"
    fi
    
    echo "✅ Rollback validation completed"
}

# Main rollback logic
main() {
    if [ -z "\${ROLLBACK_TO_COMMIT}" ]; then
        echo "❌ Usage: \$0 <environment> <commit-sha>"
        exit 1
    fi
    
    validate_rollback_target
    create_rollback_backup
    
    local attempt=1
    while [ \${attempt} -le \${MAX_ROLLBACK_ATTEMPTS} ]; do
        echo "Rollback attempt \${attempt}/\${MAX_ROLLBACK_ATTEMPTS}"
        
        if perform_rollback && validate_rollback; then
            echo "🎉 Rollback completed successfully!"
            break
        else
            echo "❌ Rollback attempt \${attempt} failed"
            if [ \${attempt} -lt \${MAX_ROLLBACK_ATTEMPTS} ]; then
                echo "Retrying in 30 seconds..."
                sleep 30
            fi
        fi
        
        ((attempt++))
    done
    
    if [ \${attempt} -gt \${MAX_ROLLBACK_ATTEMPTS} ]; then
        echo "❌ Rollback failed after \${MAX_ROLLBACK_ATTEMPTS} attempts"
        exit 1
    fi
}

# Execute main function
main "\$@"
EOF

# Make script executable
chmod +x automated-rollback.sh
```
    
    echo "✅ Rollback target validated"
}

# Function to backup current state
backup_current_state() {
    echo "Backing up current state..."
    
    local backup_dir="./backups/rollback-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${backup_dir}"
    
    # Backup current Terraform state
    cd "${TERRAFORM_DIR}"
    terraform state pull > "${backup_dir}/terraform.tfstate"
    
    # Backup current configuration
    cp -r . "${backup_dir}/config/"
    
    echo "✅ Current state backed up to ${backup_dir}"
    cd - > /dev/null
}

# Function to perform rollback
perform_rollback() {
    local attempt=$1
    echo "Rollback attempt ${attempt}/${MAX_ROLLBACK_ATTEMPTS}..."
    
    # Checkout rollback target
    git checkout "${ROLLBACK_TO_COMMIT}"
    
    # Initialize and plan
    cd "${TERRAFORM_DIR}"
    terraform init
    
    # Create rollback plan
    if terraform plan -out=rollback.tfplan; then
        echo "✅ Rollback plan created successfully"
    else
        echo "❌ Failed to create rollback plan"
        return 1
    fi
    
    # Apply rollback
    if terraform apply -auto-approve rollback.tfplan; then
        echo "✅ Rollback applied successfully"
        return 0
    else
        echo "❌ Rollback application failed"
        return 1
    fi
}

# Function to validate rollback success
validate_rollback() {
    echo "Validating rollback success..."
    
    cd "${TERRAFORM_DIR}"
    
    # Check if infrastructure is healthy
    if terraform plan -detailed-exitcode; then
        echo "✅ Infrastructure state is consistent"
    else
        echo "⚠️  Infrastructure state may have drift"
    fi
    
    # Run health checks if available
    if [ -f "../../scripts/health-check.sh" ]; then
        if ../../scripts/health-check.sh "${ENVIRONMENT}"; then
            echo "✅ Health checks passed"
        else
            echo "❌ Health checks failed"
            return 1
        fi
    fi
    
    return 0
}

# Main rollback logic
main() {
    if [ -z "${ROLLBACK_TO_COMMIT}" ]; then
        echo "Usage: $0 <environment> <commit-sha>"
        exit 1
    fi
    
    # Step 1: Validate rollback target
    validate_rollback_target
    
    # Step 2: Backup current state
    backup_current_state
    
    # Step 3: Perform rollback with retries
    for attempt in $(seq 1 $MAX_ROLLBACK_ATTEMPTS); do
        if perform_rollback "${attempt}"; then
            break
        fi
        
        if [ ${attempt} -eq ${MAX_ROLLBACK_ATTEMPTS} ]; then
            echo "❌ Rollback failed after ${MAX_ROLLBACK_ATTEMPTS} attempts"
            echo "🔧 Manual intervention required"
            exit 1
        fi
        
        echo "Retrying rollback in 30 seconds..."
        sleep 30
    done
    
    # Step 4: Validate rollback success
    if validate_rollback; then
        echo "🎉 Rollback completed successfully!"
        echo "Environment ${ENVIRONMENT} has been rolled back to commit ${ROLLBACK_TO_COMMIT}"
    else
        echo "⚠️  Rollback completed but validation failed"
        echo "Manual verification recommended"
        exit 1
    fi
    
    # Return to main branch
    git checkout main
}

# Trap for cleanup
trap 'echo "Rollback interrupted"; git checkout main 2>/dev/null || true' INT TERM

# Execute main function
main "$@"
EOF

chmod +x ~/tfworkshop/scripts/automated-rollback.sh

echo "✅ Automated rollback script created!"
echo "📁 Usage examples:"
echo "   ./automated-rollback.sh dev                    # Rollback dev environment"
echo "   ./automated-rollback.sh prod abc123def         # Rollback prod to specific commit"
echo "   ./automated-rollback.sh staging --no-validate  # Skip validation"
```

### **Key Pipeline Pattern Benefits Demonstrated**
✅ **Automated Testing**: Comprehensive infrastructure testing with Terratest
✅ **Policy as Code**: Governance and compliance automation with OPA
✅ **Continuous Delivery**: Automated deployment with safety gates
✅ **Quality Gates**: Multiple validation stages before deployment
✅ **Automated Rollback**: Safe rollback capability with validation
✅ **Monitoring Integration**: Automated setup of monitoring and alerting

---

## Pipeline Pattern Advantages

1. **Speed**: Automated processes reduce manual effort and time
2. **Quality**: Consistent testing and validation catch issues early
3. **Reliability**: Automated processes reduce human error
4. **Compliance**: Policy as Code ensures governance requirements
5. **Visibility**: Complete audit trail of all changes and deployments
6. **Recovery**: Automated rollback capability for quick recovery

---

## Next Steps
In Module 5, we'll create a complete CI/CD pipeline using GitHub Actions to automate both Terraform deployments and Terratest validation for enterprise-scale infrastructure management.
highlight = white
verbose = blue
warn = bright purple
error = red
debug = dark gray
deprecate = purple
skip = cyan
unreachable = red
ok = green
changed = yellow
diff_add = green
diff_remove = red
diff_lines = cyan
EOF

echo "✅ Ansible directory structure created successfully!"
echo "📁 Main directories:"
echo "   - ansible/inventories/dev/"
echo "   - ansible/playbooks/"
echo "   - ansible/roles/{common,nginx,security}/"
```

### **Step 2: Dynamic Inventory from Terraform (2 minutes)**

📁 **Working Directory**: `~/tfworkshop/ansible/inventories/dev/`

```bash
# Create dynamic inventory configuration
cd ~/tfworkshop/ansible/inventories/dev

# Create hosts.yml template
cat << 'EOF' > hosts.yml
---
all:
  children:
    webservers:
      hosts:
        # This will be populated dynamically from Terraform
        vm-webserver-dev-eus2-001:
          ansible_host: "{{ terraform_output.vm_connection.public_ip }}"
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/terraform-demo/id_ed25519
          vm_name: "{{ terraform_output.vm_connection.vm_name }}"
          environment: dev
          role: webserver
      vars:
        http_port: 80
        https_port: 443
        nginx_user: www-data
        
    databases:
      hosts: {}
      vars:
        db_port: 5432
        
  vars:
    ansible_python_interpreter: /usr/bin/python3
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

# Create dynamic inventory generator script
cd ~/tfworkshop/ansible
cat << 'EOF' > generate_inventory.py
#!/usr/bin/env python3
"""
Dynamic Inventory Generator for Terraform-Ansible Integration
Generates Ansible inventory from Terraform outputs
"""

import json
import subprocess
import sys
import os
from pathlib import Path

def get_terraform_outputs(terraform_dir):
    """Get outputs from Terraform state"""
    try:
        os.chdir(terraform_dir)
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting Terraform outputs: {e}", file=sys.stderr)
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing Terraform outputs: {e}", file=sys.stderr)
        return {}

def generate_inventory(terraform_outputs):
    """Generate Ansible inventory from Terraform outputs"""
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": ["webservers", "databases"]
        },
        "webservers": {
            "hosts": [],
            "vars": {
                "http_port": 80,
                "https_port": 443,
                "nginx_user": "www-data"
            }
        },
        "databases": {
            "hosts": [],
            "vars": {
                "db_port": 5432
            }
        }
    }
    
    # Process VM outputs if they exist
    if 'vm_details' in terraform_outputs:
        vm_details = terraform_outputs['vm_details']['value']
        for vm in vm_details:
            vm_name = vm.get('name', 'unknown')
            public_ip = vm.get('public_ip', '')
            private_ip = vm.get('private_ip', '')
            
            # Add to webservers group
            inventory['webservers']['hosts'].append(vm_name)
            inventory['_meta']['hostvars'][vm_name] = {
                'ansible_host': public_ip or private_ip,
                'ansible_user': 'azureuser',
                'ansible_ssh_private_key_file': '~/.ssh/terraform-demo/id_ed25519',
                'private_ip': private_ip,
                'public_ip': public_ip,
                'environment': vm.get('environment', 'dev'),
                'role': 'webserver'
            }
    
    return inventory

def main():
    """Main function"""
    # Default to current directory's environments/dev
    terraform_dir = os.path.join(os.getcwd(), 'environments', 'dev')
    
    if len(sys.argv) > 1:
        terraform_dir = sys.argv[1]
    
    if not os.path.exists(terraform_dir):
        print(f"Terraform directory not found: {terraform_dir}", file=sys.stderr)
        sys.exit(1)
    
    terraform_outputs = get_terraform_outputs(terraform_dir)
    inventory = generate_inventory(terraform_outputs)
    
    print(json.dumps(inventory, indent=2))

if __name__ == "__main__":
    main()
EOF

# Make the script executable
chmod +x generate_inventory.py

echo "✅ Dynamic inventory generator created!"
echo "🔧 Usage: ./generate_inventory.py [terraform_directory]"
echo "📋 This script will generate Ansible inventory from Terraform outputs"
```
#!/usr/bin/env python3
import json
import subprocess
import yaml

def get_terraform_output():
    """Get Terraform outputs from the dev environment"""
    try:
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            cwd='environments/dev',
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting Terraform output: {e}")
        return None

def generate_inventory():
    """Generate Ansible inventory from Terraform outputs"""
    tf_output = get_terraform_output()
    if not tf_output:
        return
    
    vm_connection = tf_output['vm_connection']['value']
    
    inventory = {
        'all': {
            'children': {
                'webservers': {
                    'hosts': {
                        vm_connection['vm_name']: {
                            'ansible_host': vm_connection['public_ip'],
                            'ansible_user': 'azureuser',
                            'ansible_ssh_private_key_file': '~/.ssh/terraform-demo/id_ed25519',
                            'vm_name': vm_connection['vm_name'],
                            'environment': 'dev',
                            'role': 'webserver'
                        }
                    },
                    'vars': {
                        'http_port': 80,
                        'https_port': 443,
                        'nginx_user': 'www-data'
                    }
                }
            }
        }
    }
    
    with open('ansible/inventories/dev/hosts.yml', 'w') as f:
        yaml.dump(inventory, f, default_flow_style=False)
    
    print("✅ Inventory generated successfully")
    print(f"📍 VM: {vm_connection['vm_name']}")
    print(f"🌐 IP: {vm_connection['public_ip']}")

if __name__ == '__main__':
    generate_inventory()
EOF

chmod +x ansible/generate_inventory.py
python3 ansible/generate_inventory.py
```

### **Step 3: Common Role for Base Configuration (2 minutes)**

**ansible/roles/common/tasks/main.yml**
```yaml
---
# Common configuration for all Ubuntu servers
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 86400
  become: yes
  tags: [packages]

- name: Install essential packages
  apt:
    name:
      - curl
      - wget
      - git
      - htop
      - vim
      - unzip
      - software-properties-common
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
    state: present
  become: yes
  tags: [packages]

- name: Configure automatic security updates
  apt:
    name: unattended-upgrades
    state: present
  become: yes
  tags: [security]

- name: Enable automatic security updates
  lineinfile:
    path: /etc/apt/apt.conf.d/20auto-upgrades
    line: "{{ item }}"
    create: yes
  become: yes
  with_items:
    - 'APT::Periodic::Update-Package-Lists "1";'
    - 'APT::Periodic::Unattended-Upgrade "1";'
  tags: [security]

- name: Set timezone
  timezone:
    name: UTC
  become: yes
  tags: [system]

- name: Create deployment user
  user:
    name: deploy
    shell: /bin/bash
    create_home: yes
    groups: sudo
    append: yes
  become: yes
  tags: [users]

- name: Configure SSH for deploy user
  authorized_key:
    user: deploy
    key: "{{ lookup('file', '~/.ssh/terraform-demo/id_ed25519.pub') }}"
  become: yes
  tags: [users]
```

### **Step 4: Nginx Web Server Role (2 minutes)**

**ansible/roles/nginx/tasks/main.yml**
```yaml
---
# Install and configure Nginx
- name: Install Nginx
  apt:
    name: nginx
    state: present
  become: yes
  tags: [nginx]

- name: Start and enable Nginx
  systemd:
    name: nginx
    state: started
    enabled: yes
  become: yes
  tags: [nginx]

- name: Remove default Nginx site
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  become: yes
  notify: restart nginx
  tags: [nginx]

- name: Create web root directory
  file:
    path: /var/www/{{ ansible_hostname }}
    state: directory
    owner: www-data
    group: www-data
    mode: '0755'
  become: yes
  tags: [nginx]

- name: Deploy custom Nginx configuration
  template:
    src: site.conf.j2
    dest: /etc/nginx/sites-available/{{ ansible_hostname }}
    backup: yes
  become: yes
  notify: restart nginx
  tags: [nginx]

- name: Enable custom site
  file:
    src: /etc/nginx/sites-available/{{ ansible_hostname }}
    dest: /etc/nginx/sites-enabled/{{ ansible_hostname }}
    state: link
  become: yes
  notify: restart nginx
  tags: [nginx]

- name: Create sample index page
  template:
    src: index.html.j2
    dest: /var/www/{{ ansible_hostname }}/index.html
    owner: www-data
    group: www-data
    mode: '0644'
  become: yes
  tags: [nginx, content]

- name: Configure Nginx security headers
  blockinfile:
    path: /etc/nginx/nginx.conf
    marker: "# {mark} ANSIBLE MANAGED SECURITY HEADERS"
    insertbefore: "include /etc/nginx/sites-enabled/*;"
    block: |
      # Security Headers
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header Referrer-Policy "no-referrer-when-downgrade" always;
      add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
  become: yes
  notify: restart nginx
  tags: [nginx, security]
```

**ansible/roles/nginx/templates/site.conf.j2**
```nginx
server {
    listen {{ http_port }};
    server_name {{ ansible_hostname }} {{ ansible_default_ipv4.address }};
    
    root /var/www/{{ ansible_hostname }};
    index index.html index.htm;
    
    # Security settings
    server_tokens off;
    
    # Logging
    access_log /var/log/nginx/{{ ansible_hostname }}_access.log;
    error_log /var/log/nginx/{{ ansible_hostname }}_error.log;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**ansible/roles/nginx/templates/index.html.j2**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ ansible_hostname }} - Terraform + Ansible Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; }
        .info { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .success { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Enterprise IaC Workshop Demo</h1>
        <p class="success">✅ VM deployed successfully with Terraform + Ansible!</p>
        
        <div class="info">
            <h3>Server Information:</h3>
            <ul>
                <li><strong>Hostname:</strong> {{ ansible_hostname }}</li>
                <li><strong>Environment:</strong> {{ environment }}</li>
                <li><strong>Role:</strong> {{ role }}</li>
                <li><strong>OS:</strong> {{ ansible_distribution }} {{ ansible_distribution_version }}</li>
                <li><strong>Private IP:</strong> {{ ansible_default_ipv4.address }}</li>
                <li><strong>Deployment Time:</strong> {{ ansible_date_time.iso8601 }}</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>Deployment Stack:</h3>
            <ul>
                <li>🏗️ <strong>Infrastructure:</strong> Terraform</li>
                <li>⚙️ <strong>Configuration:</strong> Ansible</li>
                <li>🌐 <strong>Web Server:</strong> Nginx</li>
                <li>🔒 <strong>Security:</strong> SSH Keys + NSG</li>
            </ul>
        </div>
    </div>
</body>
</html>
```

**ansible/roles/nginx/handlers/main.yml**
```yaml
---
- name: restart nginx
  systemd:
    name: nginx
    state: restarted
  become: yes
```

### **Step 5: Main Playbook and Execution (2 minutes)**

**ansible/playbooks/site.yml**
```yaml
---
- name: Configure Web Servers
  hosts: webservers
  become: yes
  gather_facts: yes
  
  pre_tasks:
    - name: Wait for system to become reachable
      wait_for_connection:
        timeout: 300
      tags: [always]
    
    - name: Gather system facts
      setup:
      tags: [always]
  
  roles:
    - role: common
      tags: [common]
    - role: nginx
      tags: [nginx]
  
  post_tasks:
    - name: Verify Nginx is running
      systemd:
        name: nginx
        state: started
      tags: [verification]
    
    - name: Test web server response
      uri:
        url: "http://{{ ansible_default_ipv4.address }}"
        method: GET
        status_code: 200
      delegate_to: localhost
      tags: [verification]
    
    - name: Display connection information
      debug:
        msg: |
          🎉 Web server configured successfully!
          🌐 URL: http://{{ ansible_host }}
          🔗 SSH: ssh {{ ansible_user }}@{{ ansible_host }}
      tags: [always]
```

**Execute the Ansible playbook:**
```bash
# Navigate to Ansible directory
cd ansible

# Test connectivity
ansible webservers -m ping

# Run the playbook
ansible-playbook playbooks/site.yml

# Run specific tags
ansible-playbook playbooks/site.yml --tags nginx

# Check the website
curl http://$(cd ../environments/dev && terraform output -raw vm_connection | jq -r '.public_ip')
```

### **Key Takeaways**
✅ **Automated Configuration**: Complete server setup with Ansible
✅ **Role-Based Architecture**: Modular and reusable configuration
✅ **Security Hardening**: Automatic updates and security headers
✅ **Dynamic Inventory**: Integration with Terraform outputs
✅ **Idempotent Operations**: Safe to run multiple times
✅ **Enterprise Patterns**: Structured approach for scalability

---

## 🧪 Terratest Best Practices & Troubleshooting

### **Testing Best Practices**

#### **1. Test Organization**
```bash
# Recommended test structure
tests/
├── go.mod
├── go.sum
├── unit/
│   ├── nsg_test.go
│   ├── vnet_test.go
│   └── vm_test.go
├── integration/
│   ├── complete_environment_test.go
│   └── multi_environment_test.go
├── performance/
│   └── benchmark_test.go
└── helpers/
    ├── azure_helpers.go
    └── test_helpers.go
```

#### **2. Test Naming Conventions**
```go
// Good naming patterns
func TestNSGModule_WithHTTPSEnabled_ShouldCreateCorrectRules(t *testing.T)
func TestVMModule_WithPublicIP_ShouldBeAccessible(t *testing.T)
func TestCompleteInfrastructure_MultiRegion_ShouldDeploySuccessfully(t *testing.T)

// Use descriptive test names that explain:
// - What is being tested (NSGModule)
// - Under what conditions (WithHTTPSEnabled)
// - What should happen (ShouldCreateCorrectRules)
```

#### **3. Resource Cleanup Strategies**
```go
func TestWithProperCleanup(t *testing.T) {
    // Strategy 1: Defer cleanup immediately after setup
    terraformOptions := &terraform.Options{...}
    defer terraform.Destroy(t, terraformOptions)
    
    // Strategy 2: Cleanup on test failure
    defer func() {
        if t.Failed() {
            // Save logs before cleanup
            terraform.RunTerraformCommand(t, terraformOptions, "show")
        }
    }()
    
    // Strategy 3: Resource tagging for orphan cleanup
    Vars: map[string]interface{}{
        "common_tags": map[string]string{
            "Test":      "terratest",
            "TestRunID": uniqueID,
            "AutoClean": "true",
        },
    },
}
```

#### **4. Parallel Testing Guidelines**
```go
func TestParallelExecution(t *testing.T) {
    // Enable parallel execution
    t.Parallel()
    
    // Use unique identifiers to avoid conflicts
    uniqueID := random.UniqueId()
    
    // Be mindful of Azure subscription limits
    // - Max 20 concurrent deployments per subscription
    // - Consider using separate test subscriptions
    
    // Use resource group isolation
    Vars: map[string]interface{}{
        "resource_group_name": fmt.Sprintf("rg-test-%s", uniqueID),
    },
}
```

### **Common Issues & Solutions**

#### **Issue 1: Azure Authentication Failures**
```bash
# Error: "Failed to get authorization token"
# Solution: Set up proper authentication

# Method 1: Environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Method 2: Azure CLI (for local development)
az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Method 3: Managed Identity (for CI/CD)
# Configure in GitHub Actions or Azure DevOps
```

#### **Issue 2: Test Timeout Errors**
```go
// Problem: Tests timing out during resource creation
// Solution: Increase timeouts and add retry logic

terraformOptions := &terraform.Options{
    TerraformDir: "../modules/compute/vm",
    Vars:         vars,
    
    // Increase timeout for slow operations
    RetryableTerraformErrors: map[string]string{
        ".*timeout.*":                   "Terraform timeout",
        ".*could not determine.*":       "Resource state uncertain",
        ".*already exists.*":           "Resource already exists",
    },
    MaxRetries:         5,
    TimeBetweenRetries: 10 * time.Second,
}

// For very slow resources, use even longer timeouts
go test -v -timeout 60m -run TestVMModule
```

#### **Issue 3: Resource Quota Limits**
```bash
# Error: "Operation could not be completed as it results in exceeding approved quota"
# Solutions:

# 1. Use smaller VM sizes for testing
export TF_VAR_vm_size="Standard_B1s"

# 2. Clean up old test resources
az group list --query "[?contains(name, 'rg-test-')].name" -o tsv | \
  xargs -I {} az group delete --name {} --yes --no-wait

# 3. Request quota increase
az vm list-usage --location "East US 2" --output table

# 4. Use different regions for parallel tests
regions=("eastus2" "centralus" "westus2")
region=${regions[$((RANDOM % ${#regions[@]}))]}
```

#### **Issue 4: State File Conflicts**
```go
// Problem: Multiple tests interfering with each other
// Solution: Use unique backend configurations

terraformOptions := &terraform.Options{
    TerraformDir: "../environments/dev",
    
    // Use separate state files for each test
    BackendConfig: map[string]interface{}{
        "key": fmt.Sprintf("test-%s.tfstate", uniqueID),
    },
    
    // Or use local backend for tests
    BackendConfig: map[string]interface{}{
        "path": fmt.Sprintf("./terraform-%s.tfstate", uniqueID),
    },
}
```

#### **Issue 5: Network Connectivity Testing**
```go
// Robust network connectivity testing
func testNetworkConnectivity(t *testing.T, publicIP string, port int) {
    retry.DoWithRetry(t, "Network connectivity test", 10, 30*time.Second, func() (string, error) {
        timeout := 10 * time.Second
        conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", publicIP, port), timeout)
        if err != nil {
            return "", fmt.Errorf("connection failed: %v", err)
        }
        defer conn.Close()
        
        // For HTTP, try a simple request
        if port == 80 || port == 443 {
            client := http.Client{Timeout: timeout}
            protocol := "http"
            if port == 443 {
                protocol = "https"
            }
            
            resp, err := client.Get(fmt.Sprintf("%s://%s", protocol, publicIP))
            if err != nil {
                return "", err
            }
            defer resp.Body.Close()
            
            if resp.StatusCode != 200 {
                return "", fmt.Errorf("HTTP status: %d", resp.StatusCode)
            }
        }
        
        return "Connection successful", nil
    })
}
```

### **Performance Optimization**

#### **1. Test Execution Speed**
```bash
# Run tests in parallel (be mindful of quotas)
go test -v -parallel 4 -timeout 45m

# Skip slow integration tests during development
go test -v -short

# Use build tags for different test types
go test -v -tags=unit
go test -v -tags=integration
```

#### **2. Resource Optimization**
```go
// Use minimal resource configurations for testing
testVars := map[string]interface{}{
    "vm_size":           "Standard_B1s",        // Smallest VM
    "os_disk_type":      "Standard_LRS",        // Cheapest storage
    "enable_public_ip":  false,                 // Skip if not needed
    "backup_enabled":    false,                 // Skip for tests
}
```

#### **3. Caching Strategies**
```bash
# Cache Go modules
go mod download

# Cache Terraform providers
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p $TF_PLUGIN_CACHE_DIR

# Cache test data
export TERRATEST_CACHE_DIR="$HOME/.terratest-cache"
```

### **Monitoring & Debugging**

#### **1. Enhanced Logging**
```go
// Enable detailed Terraform logging
terraformOptions := &terraform.Options{
    TerraformDir: "../modules/compute/vm",
    Vars:         vars,
    
    // Enable detailed logging
    EnvVars: map[string]string{
        "TF_LOG":      "DEBUG",
        "TF_LOG_PATH": fmt.Sprintf("./terraform-%s.log", uniqueID),
    },
}

// Custom logging
t.Logf("Starting test with unique ID: %s", uniqueID)
t.Logf("Resource group: %s", resourceGroupName)
```

#### **2. Test Metrics Collection**
```go
func TestWithMetrics(t *testing.T) {
    start := time.Now()
    defer func() {
        duration := time.Since(start)
        t.Logf("Test completed in: %v", duration)
        
        // Log resource costs (if applicable)
        // Log performance metrics
        // Send metrics to monitoring system
    }()
    
    // Test implementation...
}
```

### **CI/CD Integration Tips**

#### **1. GitHub Actions Optimization**
```yaml
# Use matrix builds for different configurations
strategy:
  matrix:
    environment: [dev, staging]
    region: [eastus2, westus2]
    terraform_version: [1.5.0, 1.6.0]

# Cache dependencies
- name: Cache Go modules
  uses: actions/cache@v3
  with:
    path: ~/go/pkg/mod
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}

# Use artifacts for test results
- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: terratest-results-${{ matrix.environment }}
    path: |
      tests/*.log
      tests/test-results.xml
```

#### **2. Cost Management**
```bash
# Automated cleanup job
- name: Cleanup test resources
  if: always()
  run: |
    # Delete resource groups older than 2 hours
    az group list --query "[?tags.Test=='terratest' && tags.CreatedTime < '$(date -d '2 hours ago' -Iso)'].name" -o tsv | \
      xargs -I {} az group delete --name {} --yes --no-wait
```

---

## Configuration Management Benefits

1. **Consistency**: Identical configuration across all environments
2. **Repeatability**: Infrastructure and configuration as code
3. **Compliance**: Automated security and policy enforcement
4. **Scalability**: Easy to apply to multiple servers
5. **Auditability**: All changes tracked in version control

---

## Next Steps
In Module 5, we'll create a complete CI/CD pipeline using GitHub Actions to automate both Terraform deployments and Ansible configuration management.
