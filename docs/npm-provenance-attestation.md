# npm Provenance and Attestation Guide

## Overview

**Provenance** provides cryptographic proof of where and how a package was built, following the [SLSA (Supply-chain Levels for Software Artifacts)](https://slsa.dev/) framework. This helps verify package authenticity and build integrity.

## npm Provenance Support

npm supports provenance through the `--provenance` flag when publishing. This generates attestations that prove:
- **Where** the package was built (repository, commit)
- **How** it was built (build system, environment)
- **Who** built it (CI/CD system with verified identity)

## How to Add Provenance to npm publish

### Option 1: Use `--provenance` flag (Automatic)

```bash
npm publish --provenance --tag alpha
```

**How it works:**
- npm automatically generates provenance attestations
- Works best in CI/CD environments (GitHub Actions, GitLab CI)
- Requires environment variables and OIDC tokens in CI
- For local publishing, may require additional setup

### Option 2: Use `--provenance-file` (Manual)

If you have a pre-generated provenance bundle:

```bash
npm publish --provenance-file ./path/to/provenance.json --tag alpha
```

### Option 3: Configure in `.npmrc`

Add to your `.npmrc` file:

```
provenance=true
```

Then all publishes will include provenance:

```bash
npm publish --tag alpha
```

## CI/CD Integration (Recommended)

### GitHub Actions

Provenance works automatically with **Trusted Publishing**:

1. **Enable Trusted Publishing on npmjs.com:**
   - Go to your package settings
   - Add trusted publisher:
     - Organization/User
     - Repository name
     - Workflow filename (e.g., `publish.yml`)
     - Environment name (optional)

2. **GitHub Actions Workflow:**

```yaml
name: Publish Package

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'
      
      - run: npm ci
      - run: npm test
      
      - run: npm publish --provenance
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Key points:**
- `id-token: write` permission enables OIDC token generation
- `--provenance` flag generates attestations automatically
- No long-lived tokens needed (uses short-lived OIDC tokens)

### GitLab CI/CD

```yaml
publish:
  image: node:20
  script:
    - npm ci
    - npm test
    - npm publish --provenance
  only:
    - tags
```

## Local Publishing with Provenance

For local development, provenance generation is more limited:

### Method 1: Use `--provenance` (may not work locally)

```bash
npm publish --provenance --tag alpha
```

**Note:** This typically requires:
- Git repository
- Proper git configuration
- May not work fully outside CI/CD

### Method 2: Generate Attestations Manually

You can use tools like `@actions/attest` or `sigstore` CLI:

```bash
# Install sigstore CLI
npm install -g @sigstore/cli

# Generate provenance attestation
sigstore attest --type slsaprovenance \
  --predicate build-predicate.json \
  --certificate-identity "your-identity" \
  --certificate-oidc-issuer "https://github.com" \
  npmtest-1.0.5-alpha.2.tgz

# Then publish with the provenance file
npm publish --provenance-file ./attestation.json --tag alpha
```

## Is there an `npm attest` command?

**No, npm does not have a standalone `attest` command** (as of npm 11.6.0).

However:

1. **Provenance is built into `npm publish`** - Use `--provenance` flag
2. **Attestations are generated automatically** during publish with `--provenance`
3. **You can use external tools** for manual attestation:
   - `@actions/attest` - GitHub Actions attestation library
   - `sigstore` CLI - Generate and verify attestations
   - `@sigstore/cli` - Sigstore command-line tool

## Checking Provenance

After publishing with provenance, you can verify it:

### On npmjs.com:
- Go to your package page
- Look for "Provenance" badge/indicator
- Click to view attestation details

### Using npm CLI:

```bash
# View package metadata (includes provenance info)
npm view npmtest@1.0.5-alpha.2

# Check if provenance exists
npm view npmtest@1.0.5-alpha.2 dist.attestations
```

## Registry Support

**Important:** Not all registries support provenance:

| Registry | Provenance Support |
|----------|-------------------|
| **npmjs.com** | ✅ Full support |
| **GitHub Packages** | ✅ Full support |
| **JFrog Artifactory** | ⚠️ May have limited support |
| **Verdaccio** | ❌ Limited/no support |
| **Azure Artifacts** | ⚠️ Varies by configuration |

For **JFrog Artifactory** (your current registry), check:
- Artifactory version (7.x+ recommended)
- Repository configuration
- Whether provenance metadata is stored

## Best Practices

1. **Use CI/CD for publishing** - Provenance works best in automated environments
2. **Enable Trusted Publishing** - More secure than long-lived tokens
3. **Always use `--provenance`** in CI/CD workflows
4. **Verify provenance** after publishing
5. **Document your build process** - Helps with provenance generation

## Troubleshooting

### Error: "Automatic provenance generation not supported for provider: null"

**This is the most common error when publishing locally!**

**Cause:**
- You're publishing from your local machine (not CI/CD)
- npm cannot detect a CI/CD provider (GitHub Actions, GitLab CI, etc.)
- No git repository or missing required environment variables

**Solutions:**

**Option 1: Publish without provenance (for local development)**
```bash
# Just publish normally - no provenance needed for local testing
npm run publish:alpha
```

**Option 2: Use provenance only in CI/CD**
- Remove `--provenance` flag from local scripts
- Add `--provenance` only in your CI/CD workflows
- This is the recommended approach

**Option 3: Use `--provenance-file` with manual attestation (NOT RECOMMENDED)**
```bash
# This requires generating a valid Sigstore bundle with DSSE format
# This is extremely complex and not practical for local development
# The bundle must include:
# - DSSE (Dead Simple Signing Envelope) format
# - Proper Sigstore bundle structure
# - Valid signatures and certificates
# - Correct payload structure
# 
# Use tools like @sigstore/cli, but this is still very complex
npm publish --provenance-file ./valid-sigstore-bundle.json --tag alpha
```

**⚠️ Warning:** Generating a valid Sigstore bundle manually is extremely complex and error-prone. The bundle must be in a specific format with proper signatures. This is not recommended for local development.

**Option 4: Initialize git repository**
```bash
git init
git add .
git commit -m "Initial commit"
# Then --provenance might work, but still limited without CI/CD
```

**Best Practice:** Use provenance in CI/CD, not locally. For local publishing, just use:
```bash
npm run publish:alpha  # No provenance flag
```

### Error: "Provenance generation failed"

**Causes:**
- Not in a git repository
- Missing environment variables
- Registry doesn't support provenance
- OIDC token unavailable (local publishing)

**Solutions:**
- Publish from CI/CD instead of locally
- Check registry support
- Use `--provenance-file` with manually generated attestations

### Error: "No dsseEnvelope with payload found in sigstore bundle"

**This error occurs when using `--provenance-file` with an invalid format.**

**Cause:**
- The provenance file is not in the correct Sigstore bundle format
- Missing DSSE (Dead Simple Signing Envelope) structure
- Invalid or missing signatures/certificates
- Incorrect payload structure

**What npm expects:**
The `--provenance-file` must contain a valid **Sigstore bundle** with:
- DSSE envelope format
- Proper bundle structure with `dsseEnvelope` and `payload`
- Valid signatures from Sigstore
- Correct certificate chain
- Properly formatted attestation statement

**Example of what's needed (simplified):**
```json
{
  "dsseEnvelope": {
    "payload": "<base64-encoded-payload>",
    "payloadType": "application/vnd.in-toto+json",
    "signatures": [...]
  },
  "verificationMaterial": {
    "certificate": {...},
    "tlogEntries": [...]
  }
}
```

**Solution:**
- **Don't use `--provenance-file` for local development** - it's too complex
- Use `npm publish` without provenance flags for local testing
- Use `--provenance` (automatic) only in CI/CD environments
- If you must generate manually, use `@sigstore/cli` or similar tools, but expect significant complexity

**Best Practice:** For local development, just use:
```bash
npm run publish:alpha  # No provenance - works perfectly for local testing
```

### Error: "Registry does not support provenance"

**Solution:**
- Check if your registry (JFrog Artifactory) supports provenance
- May need to upgrade Artifactory version
- Consider using npmjs.com or GitHub Packages for provenance-enabled packages

## References

- [npm Trusted Publishing Docs](https://docs.npmjs.com/trusted-publishers)
- [SLSA Framework](https://slsa.dev/)
- [Sigstore](https://www.sigstore.dev/)
- [npm publish documentation](https://docs.npmjs.com/cli/v11/commands/npm-publish)

