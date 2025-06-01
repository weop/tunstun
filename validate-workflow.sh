#!/bin/bash
# GitHub Actions Workflow Validation Script

echo "🔍 Validating GitHub Actions Workflow"
echo "====================================="

# Test YAML syntax
echo "📋 Checking YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-appimage.yml'))" 2>/dev/null; then
    echo "✅ YAML syntax is valid"
else
    echo "❌ YAML syntax is invalid"
    exit 1
fi

# Check for common GitHub Actions issues
echo ""
echo "🔧 Checking for common issues..."

# Check for proper variable syntax
if grep -q '\${{ github\.sha:0:8 }}' .github/workflows/build-appimage.yml; then
    echo "❌ Found invalid substring syntax"
    exit 1
else
    echo "✅ No invalid substring syntax found"
fi

# Check for required secrets usage
if grep -q 'GITHUB_TOKEN.*secrets\.GITHUB_TOKEN' .github/workflows/build-appimage.yml; then
    echo "✅ GitHub token properly referenced"
else
    echo "⚠️  GitHub token reference not found"
fi

# Check for proper step referencing
if grep -q 'steps\.create_release\.outputs\.upload_url' .github/workflows/build-appimage.yml; then
    echo "✅ Step output properly referenced"
else
    echo "⚠️  Step output reference not found"
fi

# Check for environment variable usage
if grep -q '\${{ env\.SHORT_SHA }}' .github/workflows/build-appimage.yml; then
    echo "✅ Environment variables properly used"
else
    echo "⚠️  Environment variable usage not found"
fi

echo ""
echo "📁 Checking file structure..."

# Check for required files
required_files=(
    ".github/workflows/build-appimage.yml"
    "build-appimage.sh"
    "pubspec.yaml"
    "assets/icons/icon.png"
    "lib/main.dart"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

echo ""
echo "🎯 Workflow Trigger Analysis..."

# Check triggers
if grep -q "push:" .github/workflows/build-appimage.yml && grep -q "branches.*main" .github/workflows/build-appimage.yml; then
    echo "✅ Main branch push trigger configured"
else
    echo "⚠️  Main branch push trigger not found"
fi

if grep -q "workflow_dispatch:" .github/workflows/build-appimage.yml; then
    echo "✅ Manual dispatch trigger configured"
else
    echo "⚠️  Manual dispatch trigger not found"
fi

echo ""
echo "🚀 Simulation Test..."

# Simulate the environment variables that would be set
export GITHUB_SHA="1234567890abcdef1234567890abcdef12345678"
export GITHUB_REF_NAME="main"
export SHORT_SHA=$(echo $GITHUB_SHA | cut -c1-8)

echo "Simulated GITHUB_SHA: $GITHUB_SHA"
echo "Simulated SHORT_SHA: $SHORT_SHA"
echo "Expected AppImage name: tunstun-${SHORT_SHA}-x86_64.AppImage"

echo ""
echo "✅ GitHub Actions workflow validation complete!"
echo ""
echo "📝 Next steps:"
echo "1. Commit and push to main branch to trigger build"
echo "2. Check the Actions tab in your GitHub repository"
echo "3. Download the AppImage from Artifacts or Releases"
