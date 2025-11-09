#!/bin/bash
# Helper script to run GitHub Actions workflow locally with act
# Usage: ./act-publish.sh [tag] [version_bump]

set -e

TAG="${1:-alpha}"
VERSION_BUMP="${2:-prerelease}"

echo "=== Running GitHub Actions workflow locally with act ==="
echo "Tag: $TAG"
echo "Version bump: $VERSION_BUMP"
echo ""

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo "❌ Error: act is not installed"
    echo "Install with: brew install act"
    exit 1
fi

# Check if .secrets file exists
if [ ! -f .secrets ]; then
    echo "⚠️  Warning: .secrets file not found"
    echo "Creating .secrets template..."
    cat > .secrets << EOF
# Add your secrets here
# NPM_TOKEN=your-npm-token-here
EOF
    echo "Please add your NPM_TOKEN to .secrets file"
    echo ""
fi

# Check if NPM_TOKEN is set in environment or .secrets
if [ -z "$NPM_TOKEN" ] && ! grep -q "NPM_TOKEN=" .secrets 2>/dev/null; then
    echo "⚠️  Warning: NPM_TOKEN not found"
    echo "Set it in .secrets file or as environment variable"
    echo ""
fi

echo "Running workflow..."
echo ""

# Read NPM_TOKEN from .secrets if not in environment
if [ -z "$NPM_TOKEN" ] && [ -f .secrets ]; then
  NPM_TOKEN=$(grep "^NPM_TOKEN=" .secrets | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  export NPM_TOKEN
fi

# Run act with workflow_dispatch event
act workflow_dispatch \
  --input "tag=$TAG" \
  --input "version_bump=$VERSION_BUMP" \
  --secret-file .secrets \
  --env NPM_TOKEN="${NPM_TOKEN}" \
  -W .github/workflows/publish.yml \
  --container-architecture linux/amd64 \
  --platform ubuntu-latest=catthehacker/ubuntu:act-latest

echo ""
echo "=== Done ==="

