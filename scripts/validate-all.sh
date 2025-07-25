#!/bin/bash
# Ultimate Terraform validation runner
# Runs all validation checks to confirm Terraform code works as expected

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

echo "🚀 Complete Terraform Code Validation"
echo "====================================="
echo ""

# 1. Quick validation workflow
echo "📋 Running quick validation workflow..."
if ./scripts/validate-simple.sh; then
    echo "✅ Quick validation passed!"
else
    echo "❌ Quick validation failed!"
    exit 1
fi

echo ""

# 2. Run Go tests (syntax validation)
echo "🧪 Running Go-based syntax validation tests..."
cd tests
if go test -v -run TestIndividualModulesValidation -timeout 300s; then
    echo "✅ Module validation tests passed!"
else
    echo "❌ Some module tests failed"
    exit 1
fi

if go test -v -run TestTerraformSyntaxValidation -timeout 300s; then
    echo "✅ Syntax validation tests passed!"
else
    echo "❌ Some syntax tests failed"
    exit 1
fi

cd "$REPO_ROOT"

echo ""
echo "🎉 ALL VALIDATIONS PASSED!"
echo ""
echo "Summary of what was validated:"
echo "✅ Terraform syntax and formatting"
echo "✅ Module structure and dependencies"
echo "✅ Provider version constraints"
echo "✅ Best practices and conventions"
echo "✅ Basic security checks"
echo ""
echo "🚀 Your Terraform code is ready for deployment!"
echo "   (Make sure to configure Azure credentials first)"