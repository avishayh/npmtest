# Using act to Run GitHub Actions Workflow Locally

## What Was Fixed

The workflow has been updated for better `act` compatibility:

1. **Better input handling** - Defaults for tag and version_bump
2. **Fallback mechanism** - If provenance fails, publishes without it
3. **Multiple triggers** - Added `workflow_call` for better act support
4. **Helper scripts** - Easy-to-use scripts for running with act

## Prerequisites

1. **Install act:**
   ```bash
   brew install act
   ```

2. **Set up secrets:**
   ```bash
   cp .secrets.example .secrets
   # Edit .secrets and add your NPM_TOKEN
   ```

## Usage

### Method 1: Using the Helper Script (Easiest)

```bash
# Publish alpha version
npm run publish:alpha:act

# Publish latest version
npm run publish:latest:act

# Or use the script directly with custom parameters
./act-publish.sh alpha prerelease
./act-publish.sh latest patch
```

### Method 2: Using act Directly

```bash
# Basic usage
act workflow_dispatch \
  --input "tag=alpha" \
  --input "version_bump=prerelease" \
  --secret-file .secrets

# With custom workflow
act workflow_dispatch \
  -W .github/workflows/publish.yml \
  --input "tag=beta" \
  --input "version_bump=minor" \
  --secret-file .secrets
```

### Method 3: Using Environment Variables

```bash
export NPM_TOKEN=your-token-here
act workflow_dispatch \
  --input "tag=alpha" \
  --input "version_bump=prerelease" \
  --env NPM_TOKEN="$NPM_TOKEN"
```

## Workflow Features

### Inputs

- `tag` (default: `alpha`) - Distribution tag (alpha, beta, latest)
- `version_bump` (default: `prerelease`) - Version bump type:
  - `prerelease` - Creates alpha.1, alpha.2, etc.
  - `patch` - 1.0.0 → 1.0.1
  - `minor` - 1.0.0 → 1.1.0
  - `major` - 1.0.0 → 2.0.0

### Provenance Handling

The workflow attempts to publish with provenance first. If that fails (common with act due to OIDC token limitations), it automatically falls back to publishing without provenance.

### Steps

1. **Checkout code** - Gets the full git history
2. **Setup Node.js** - Installs Node.js 20
3. **Install dependencies** - Runs `npm ci`
4. **Bump version** - Updates version based on input
5. **Publish with provenance** - Attempts with `--provenance` flag
6. **Fallback publish** - If provenance fails, publishes without it

## Configuration Files

### `.actrc`
Configuration file for act. Currently sets the runner image.

### `.secrets`
Your secrets file (not committed to git). Add your `NPM_TOKEN` here.

Example:
```
NPM_TOKEN=your-npm-token-here
```

### `act-publish.sh`
Helper script that:
- Checks if act is installed
- Validates secrets file
- Runs act with proper inputs
- Handles errors gracefully

## Troubleshooting

### Error: "act: command not found"
```bash
brew install act
```

### Error: "NPM_TOKEN not found"
1. Create `.secrets` file: `cp .secrets.example .secrets`
2. Add your token: `echo "NPM_TOKEN=your-token" >> .secrets`
3. Or set environment variable: `export NPM_TOKEN=your-token`

### Error: "Provenance generation failed"
This is expected with act. The workflow will automatically fall back to publishing without provenance.

### Error: "OIDC token verification failed"
Act may not fully support OIDC tokens. The workflow handles this by falling back to non-provenance publish.

### Workflow doesn't run
Make sure you're using the correct event:
```bash
# For workflow_dispatch
act workflow_dispatch

# For push events
act push
```

## Limitations

1. **OIDC Tokens**: act may not fully support OIDC token generation, so provenance might not work
2. **GitHub API**: Some GitHub Actions features require actual GitHub API access
3. **Secrets**: You need to provide secrets manually (they're not pulled from GitHub)

## Best Practices

1. **Use act for testing** - Test your workflow locally before pushing
2. **Use real CI/CD for production** - For actual provenance, use GitHub Actions
3. **Keep secrets safe** - Never commit `.secrets` file
4. **Test fallback** - The fallback mechanism ensures your package still publishes even if provenance fails

## Example Output

```
=== Running GitHub Actions workflow locally with act ===
Tag: alpha
Version bump: prerelease

✓ act is installed
✓ .secrets file found

Running workflow...

[Publish Package/publish] 🚀  Start image=catthehacker/ubuntu:act-latest
[Publish Package/publish]   🐳  docker pull catthehacker/ubuntu:act-latest
[Publish Package/publish] ⭐  Run actions/checkout@v4
[Publish Package/publish] ⭐  Run actions/setup-node@v4
[Publish Package/publish] ⭐  Run Install dependencies
[Publish Package/publish] ⭐  Run Bump version
[Publish Package/publish] ⭐  Run Publish to npm with provenance
[Publish Package/publish] ⚠️  Provenance failed, publishing without provenance...
[Publish Package/publish] ⭐  Run Fallback publish without provenance

=== Done ===
```

## Next Steps

1. Install act: `brew install act`
2. Set up secrets: `cp .secrets.example .secrets && edit .secrets`
3. Test the workflow: `npm run publish:alpha:act`
4. Check the output and verify the package was published

