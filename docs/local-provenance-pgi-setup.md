# Local npm Provenance with PGI (Public Good Infrastructure)

## Overview

To make `npm publish --provenance` work locally, you need to provide npm with OIDC tokens and environment variables that it expects from CI/CD environments. Using Sigstore's Public Good Infrastructure (PGI), we can generate these tokens locally.

## Prerequisites

1. **Git repository** (already set up ✓)
2. **Node.js and npm** (already installed ✓)
3. **Sigstore CLI** or similar tools for OIDC token generation

## Method 1: Using Sigstore CLI with PGI

### Step 1: Install Sigstore CLI

```bash
npm install -g @sigstore/cli
# Or use npx
npx @sigstore/cli --version
```

### Step 2: Generate OIDC Token

Sigstore's PGI provides OIDC tokens through their Fulcio service. You can use the Sigstore CLI to obtain tokens:

```bash
# This will open a browser for OIDC authentication
sigstore attest --type slsaprovenance \
  --predicate build-predicate.json \
  --certificate-identity "your-email@example.com" \
  --certificate-oidc-issuer "https://oauth2.sigstore.dev/auth"
```

### Step 3: Set Environment Variables

npm looks for specific environment variables to detect CI/CD providers. You can set these locally:

```bash
# For GitHub Actions (npm recognizes this)
export GITHUB_ACTIONS=true
export GITHUB_REPOSITORY="your-username/your-repo"
export GITHUB_REF="refs/heads/main"
export GITHUB_SHA=$(git rev-parse HEAD)
export GITHUB_WORKFLOW="local-build"
export GITHUB_RUN_ID="local-$(date +%s)"

# OIDC token (if you can obtain one)
export ACTIONS_ID_TOKEN_REQUEST_URL="https://api.github.com/..."
export ACTIONS_ID_TOKEN_REQUEST_TOKEN="your-token"
```

**Note:** This approach has limitations because npm verifies the OIDC token against the actual CI/CD provider.

## Method 2: Using GitHub CLI for OIDC Token

If you have GitHub CLI installed and authenticated:

```bash
# Install GitHub CLI if not already installed
brew install gh  # macOS
# or: https://cli.github.com/

# Authenticate
gh auth login

# Get OIDC token (this requires GitHub Actions setup)
# This is complex and may not work for local development
```

## Method 3: Mock CI/CD Environment (Limited Success)

You can try to mock a CI/CD environment, but npm may still reject it due to token verification:

```bash
# Set environment variables to mimic GitHub Actions
export CI=true
export GITHUB_ACTIONS=true
export GITHUB_REPOSITORY="local/local"
export GITHUB_REF="refs/heads/main"
export GITHUB_SHA=$(git rev-parse HEAD)
export GITHUB_WORKFLOW="local"
export GITHUB_RUN_ID="1"

# Try to publish
npm publish --provenance --tag alpha
```

**Warning:** This likely won't work because npm verifies OIDC tokens against GitHub's servers.

## Method 4: Use Sigstore's PGI Directly (Advanced)

### Using @sigstore/sign

```bash
npm install -g @sigstore/sign
```

Create a script to generate provenance using Sigstore's PGI:

```javascript
// generate-provenance.js
const { sign } = require('@sigstore/sign');
const fs = require('fs');

async function generateProvenance() {
  // This is a simplified example
  // Real implementation requires proper OIDC flow
  const payload = {
    // Your provenance data
  };
  
  // Sign using Sigstore PGI
  const bundle = await sign(payload, {
    oidcIssuer: 'https://oauth2.sigstore.dev/auth',
    oidcClientID: 'sigstore',
    oidcClientSecret: process.env.SIGSTORE_CLIENT_SECRET,
  });
  
  fs.writeFileSync('attestation.json', JSON.stringify(bundle, null, 2));
}

generateProvenance();
```

## Method 5: Use act (GitHub Actions locally) - Most Promising

`act` runs GitHub Actions workflows locally:

```bash
# Install act
brew install act  # macOS
# or: https://github.com/nektos/act

# Create a GitHub Actions workflow
mkdir -p .github/workflows
```

Create `.github/workflows/publish.yml`:

```yaml
name: Publish Package

on:
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/'
      
      - run: npm ci
      - run: npm publish --provenance --tag alpha
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

Then run locally:

```bash
act workflow_dispatch
```

**Note:** `act` may have limitations with OIDC tokens, but it's the closest to real CI/CD.

## Recommended Approach

**For local development, the most practical solution is:**

1. **Don't use `--provenance` locally** - Use it only in CI/CD
2. **Use `npm publish` without provenance** for local testing
3. **Set up CI/CD** (GitHub Actions, GitLab CI) for provenance-enabled publishes

## Alternative: Pre-commit Hook

Create a script that warns if you try to publish with provenance locally:

```bash
#!/bin/bash
# .git/hooks/pre-publish

if [[ "$*" == *"--provenance"* ]] && [[ -z "$GITHUB_ACTIONS" ]] && [[ -z "$GITLAB_CI" ]]; then
  echo "⚠️  Warning: --provenance flag detected but not in CI/CD environment"
  echo "   Provenance will not work locally. Use 'npm publish' without --provenance"
  exit 1
fi
```

## References

- [Sigstore PGI Documentation](https://docs.sigstore.dev/)
- [npm Provenance Documentation](https://docs.npmjs.com/generating-provenance-statements)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [act - Run GitHub Actions locally](https://github.com/nektos/act)

