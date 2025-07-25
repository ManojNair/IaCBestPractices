#!/bin/bash

# Terraform Validation Script
# This script validates Terraform code without requiring cloud credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 Starting Terraform validation..."
echo "Repository root: $REPO_ROOT"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "ERROR" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo "ℹ️  $message"
    fi
}

# Function to validate Terraform format
validate_format() {
    print_status "INFO" "Checking Terraform formatting..."
    
    cd "$REPO_ROOT"
    
    # Check if all files are properly formatted
    if terraform fmt -recursive -check .; then
        print_status "SUCCESS" "All Terraform files are properly formatted"
        return 0
    else
        print_status "ERROR" "Some Terraform files are not properly formatted"
        echo "Run 'terraform fmt -recursive' to fix formatting issues"
        return 1
    fi
}

# Function to validate Terraform syntax
validate_syntax() {
    print_status "INFO" "Validating Terraform syntax..."
    
    local validation_errors=0
    
    # Find all directories with .tf files
    while IFS= read -r -d '' dir; do
        print_status "INFO" "Validating directory: $dir"
        
        cd "$dir"
        
        # Initialize without backend to avoid authentication issues
        if terraform init -backend=false > /dev/null 2>&1; then
            if terraform validate; then
                print_status "SUCCESS" "Validation passed for $dir"
            else
                print_status "ERROR" "Validation failed for $dir"
                ((validation_errors++))
            fi
        else
            print_status "WARNING" "Could not initialize $dir (may be normal for modules)"
        fi
        
        cd - > /dev/null
    done < <(find "$REPO_ROOT" -name "*.tf" -exec dirname {} \; | sort -u | grep -v ".terraform" | tr '\n' '\0')
    
    if [ $validation_errors -eq 0 ]; then
        print_status "SUCCESS" "All Terraform configurations are syntactically valid"
        return 0
    else
        print_status "ERROR" "Found $validation_errors directories with validation errors"
        return 1
    fi
}

# Function to run tflint
run_tflint() {
    print_status "INFO" "Running tflint..."
    
    cd "$REPO_ROOT"
    
    # Create basic tflint config if it doesn't exist
    if [ ! -f ".tflint.hcl" ]; then
        cat > .tflint.hcl << 'EOF'
config {
  module = true
  force = false
  disabled_by_default = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format = "snake_case"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
EOF
    fi
    
    # Run tflint on each directory with .tf files
    local lint_errors=0
    
    while IFS= read -r -d '' dir; do
        print_status "INFO" "Linting directory: $dir"
        
        cd "$dir"
        
        if tflint --init > /dev/null 2>&1; then
            if tflint; then
                print_status "SUCCESS" "Linting passed for $dir"
            else
                print_status "ERROR" "Linting issues found in $dir"
                ((lint_errors++))
            fi
        else
            print_status "WARNING" "Could not initialize tflint for $dir"
        fi
        
        cd - > /dev/null
    done < <(find "$REPO_ROOT" -name "*.tf" -exec dirname {} \; | sort -u | grep -v ".terraform" | tr '\n' '\0')
    
    if [ $lint_errors -eq 0 ]; then
        print_status "SUCCESS" "All directories passed linting"
        return 0
    else
        print_status "ERROR" "Found linting issues in $lint_errors directories"
        return 1
    fi
}

# Function to check for security issues
check_security() {
    print_status "INFO" "Checking for basic security issues..."
    
    cd "$REPO_ROOT"
    
    local security_issues=0
    
    # Check for hardcoded secrets or sensitive data
    if grep -r -i --include="*.tf" --include="*.tfvars" "password\|secret\|key" . | grep -v "ssh_public_key" | grep -v "key.*=" | grep -v "#"; then
        print_status "WARNING" "Found potential hardcoded sensitive data"
        ((security_issues++))
    fi
    
    # Check for overly permissive CIDR blocks
    if grep -r -i --include="*.tf" "0.0.0.0/0" .; then
        print_status "WARNING" "Found overly permissive CIDR blocks (0.0.0.0/0)"
        ((security_issues++))
    fi
    
    if [ $security_issues -eq 0 ]; then
        print_status "SUCCESS" "No obvious security issues found"
        return 0
    else
        print_status "WARNING" "Found $security_issues potential security issues"
        return 0  # Don't fail the overall validation for warnings
    fi
}

# Main validation function
main() {
    local exit_code=0
    
    echo "🚀 Terraform Code Validation"
    echo "============================="
    
    # Run all validation steps
    if ! validate_format; then
        exit_code=1
    fi
    
    echo ""
    
    if ! validate_syntax; then
        exit_code=1
    fi
    
    echo ""
    
    if ! run_tflint; then
        exit_code=1
    fi
    
    echo ""
    
    check_security
    
    echo ""
    echo "============================="
    if [ $exit_code -eq 0 ]; then
        print_status "SUCCESS" "All validations passed! 🎉"
    else
        print_status "ERROR" "Some validations failed. Please fix the issues above."
    fi
    
    exit $exit_code
}

# Run main function
main "$@"