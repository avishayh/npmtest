#!/bin/bash
# Setup script for local npm provenance with PGI
# This attempts to configure environment for local provenance generation

set -e

echo "=== Setting up Local npm Provenance with PGI ==="
echo ""

# Check if git repo exists
if [ ! -d .git ]; then
    echo "❌ Error: Not a git repository. Run 'git init' first."
    exit 1
fi

# Get git information
GIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_REF=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
GIT_REPO=$(git config --get remote.origin.url 2>/dev/null || echo "local/local")

echo "Git Information:"
echo "  SHA: $GIT_SHA"
echo "  Ref: $GIT_REF"
echo "  Repo: $GIT_REPO"
echo ""

# Method 1: Try to set GitHub Actions environment variables
echo "Method 1: Setting GitHub Actions environment variables..."
export CI=true
export GITHUB_ACTIONS=true
export GITHUB_REPOSITORY="${GIT_REPO#*:}"  # Remove git@ or https:// prefix
export GITHUB_REF="refs/heads/${GIT_REF}"
export GITHUB_SHA="$GIT_SHA"
export GITHUB_WORKFLOW="local-build"
export GITHUB_RUN_ID="local-$(date +%s)"
export GITHUB_RUN_NUMBER="1"
export GITHUB_ACTOR=$(git config user.name || echo "local-user")

echo "Environment variables set:"
echo "  GITHUB_ACTIONS=$GITHUB_ACTIONS"
echo "  GITHUB_REPOSITORY=$GITHUB_REPOSITORY"
echo "  GITHUB_REF=$GITHUB_REF"
echo "  GITHUB_SHA=$GITHUB_SHA"
echo ""

# Check if Sigstore CLI is available
if command -v sigstore &> /dev/null || command -v @sigstore/cli &> /dev/null; then
    echo "✓ Sigstore CLI found"
    SIGSTORE_AVAILABLE=true
else
    echo "⚠ Sigstore CLI not found. Install with: npm install -g @sigstore/cli"
    SIGSTORE_AVAILABLE=false
fi

# Check if GitHub CLI is available
if command -v gh &> /dev/null; then
    echo "✓ GitHub CLI found"
    GH_AVAILABLE=true
else
    echo "⚠ GitHub CLI not found. Install with: brew install gh"
    GH_AVAILABLE=false
fi

# Check if act is available (for running GitHub Actions locally)
if command -v act &> /dev/null; then
    echo "✓ act (GitHub Actions local runner) found"
    ACT_AVAILABLE=true
else
    echo "⚠ act not found. Install with: brew install act"
    ACT_AVAILABLE=false
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "⚠️  IMPORTANT: npm's automatic provenance generation requires:"
echo "   1. Valid OIDC tokens from a CI/CD provider"
echo "   2. Verification against the provider's servers"
echo ""
echo "Local provenance may still fail because npm verifies tokens."
echo ""
echo "Options:"
echo "  1. Try: npm publish --provenance --tag alpha"
echo "     (May fail with 'provider: null' error)"
echo ""
echo "  2. Use act to run GitHub Actions locally:"
if [ "$ACT_AVAILABLE" = true ]; then
    echo "     act workflow_dispatch"
else
    echo "     First install: brew install act"
    echo "     Then create .github/workflows/publish.yml"
    echo "     Then run: act workflow_dispatch"
fi
echo ""
echo "  3. Best practice: Use provenance only in CI/CD"
echo "     For local: npm publish --tag alpha (without --provenance)"
echo ""

# Create a helper script to export these variables
cat > .env.provenance << EOF
# Local Provenance Environment Variables
# Source this file before running npm publish --provenance
# Usage: source .env.provenance

export CI=true
export GITHUB_ACTIONS=true
export GITHUB_REPOSITORY="${GIT_REPO#*:}"
export GITHUB_REF="refs/heads/${GIT_REF}"
export GITHUB_SHA="$GIT_SHA"
export GITHUB_WORKFLOW="local-build"
export GITHUB_RUN_ID="local-$(date +%s)"
export GITHUB_RUN_NUMBER="1"
export GITHUB_ACTOR=$(git config user.name || echo "local-user")
EOF

echo "✓ Created .env.provenance file"
echo "  Source it with: source .env.provenance"
echo ""

