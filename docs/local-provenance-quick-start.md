# Quick Start: Local npm Provenance with PGI

## The Challenge

npm's `--provenance` flag requires:
1. **OIDC tokens** from a recognized CI/CD provider (GitHub Actions, GitLab CI, etc.)
2. **Token verification** against the provider's servers
3. **CI/CD environment detection** (environment variables)

This makes local provenance difficult because npm verifies tokens against actual CI/CD providers.

## Practical Solutions

### Solution 1: Use `act` (GitHub Actions Local Runner) - Recommended

`act` runs GitHub Actions workflows locally, which can provide the necessary environment:

```bash
# 1. Install act
brew install act

# 2. Run the workflow locally
act workflow_dispatch

# This will:
# - Set up the GitHub Actions environment
# - Attempt to get OIDC tokens (may require GitHub authentication)
# - Run npm publish --provenance
```

**Note:** OIDC tokens may still require GitHub authentication, but `act` handles the environment setup.

### Solution 2: Use Setup Script (Environment Variables Only)

This sets environment variables but **may still fail** due to OIDC token verification:

```bash
# Run setup script
npm run setup:provenance

# Source the environment variables
source .env.provenance

# Try to publish
npm run publish:alpha:local-provenance
```

**Expected result:** Likely to fail with "provider: null" because OIDC tokens aren't available.

### Solution 3: Use Sigstore CLI with PGI (Advanced)

Generate proper attestations using Sigstore's Public Good Infrastructure:

```bash
# Install Sigstore CLI
npm install -g @sigstore/cli

# Generate provenance attestation
# This requires OIDC authentication through browser
sigstore attest --type slsaprovenance \
  --predicate build-predicate.json \
  --certificate-identity "your-email@example.com" \
  --certificate-oidc-issuer "https://oauth2.sigstore.dev/auth" \
  npmtest-1.0.5-alpha.7.tgz

# Then publish with the file
npm publish --provenance-file ./attestation.json --tag alpha
```

**Note:** This requires creating a proper `build-predicate.json` file with build information.

### Solution 4: Best Practice - Use CI/CD

The most reliable approach:

1. **Local development:** Use `npm publish --tag alpha` (no provenance)
2. **CI/CD:** Use `npm publish --provenance --tag alpha` in GitHub Actions/GitLab CI

This ensures:
- ✅ Provenance works reliably
- ✅ Tokens are properly verified
- ✅ Build environment is verifiable

## Quick Commands

```bash
# Setup local provenance environment
npm run setup:provenance

# Try local provenance (may fail)
npm run publish:alpha:local-provenance

# Regular publish (always works)
npm run publish:alpha

# Use act for local GitHub Actions
act workflow_dispatch
```

## Files Created

1. **`setup-local-provenance.sh`** - Sets up environment variables
2. **`.env.provenance`** - Environment variables file (generated)
3. **`.github/workflows/publish.yml`** - GitHub Actions workflow for CI/CD
4. **`docs/local-provenance-pgi-setup.md`** - Detailed documentation

## Expected Behavior

| Method | Success Rate | Notes |
|--------|--------------|-------|
| `npm publish --provenance` (local) | ❌ Low | Requires OIDC tokens |
| `act workflow_dispatch` | ⚠️ Medium | May work if GitHub auth is set up |
| `npm publish` (no provenance) | ✅ High | Always works |
| CI/CD with `--provenance` | ✅ High | Recommended approach |

## Troubleshooting

### Error: "provider: null"
- **Cause:** npm can't detect a CI/CD provider
- **Solution:** Use `act` or set up actual CI/CD

### Error: "OIDC token verification failed"
- **Cause:** Token can't be verified against provider
- **Solution:** Use actual CI/CD environment or skip provenance locally

### Error: "No dsseEnvelope found"
- **Cause:** Invalid provenance file format
- **Solution:** Use Sigstore CLI to generate proper format

## Recommendation

**For local development:** Don't use `--provenance`. Use regular `npm publish`.

**For production:** Set up CI/CD (GitHub Actions) and use `--provenance` there.

This gives you the best of both worlds:
- Fast local iteration without provenance complexity
- Reliable provenance in production builds

