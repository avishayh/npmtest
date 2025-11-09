# How to See Detailed npm API Requests to JFrog Artifactory

## Quick Methods

### Method 1: Enable Verbose Logging in GitHub Actions

Add to your workflow step:
```yaml
- name: Publish
  run: npm publish --provenance --access public --tag alpha
  env:
    NPM_CONFIG_LOGLEVEL: verbose
    # or
    NPM_CONFIG_LOGLEVEL: silly  # Most verbose
```

This will show HTTP requests in the GitHub Actions logs.

### Method 2: Check npm Debug Logs

The error message tells you where the log is:
```
A complete log of this run can be found in: /home/runner/.npm/_logs/2025-11-09T13_34_01_820Z-debug-0.log
```

To download this log from GitHub Actions:
1. Go to the failed workflow run
2. Click on the failed step
3. Scroll to the bottom
4. Download the log file

### Method 3: Use NODE_DEBUG

Add to workflow:
```yaml
- name: Publish
  run: npm publish --provenance --access public --tag alpha
  env:
    NODE_DEBUG: http,https
```

**Warning:** This will expose authentication tokens in logs! Only use for debugging.

### Method 4: Add Custom Logging Step

Add this before the publish step:
```yaml
- name: Enable request logging
  run: |
    export NPM_CONFIG_LOGLEVEL=verbose
    export NODE_DEBUG=http,https
    echo "Verbose logging enabled"
```

## What You'll See

With verbose logging, you'll see output like:

```
npm http fetch GET 200 https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest 752ms
npm http fetch PUT 200 https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest/-/npmtest-1.0.5-alpha.9.tgz 1177ms
npm http fetch PUT 400 https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest 583ms
```

The last line shows the 400 error on the metadata PUT request.

## Understanding the Requests

1. **GET /npmtest** - Checks existing versions (200 OK)
2. **PUT /npmtest/-/npmtest-1.0.5-alpha.9.tgz** - Uploads tarball (200 OK)
3. **PUT /npmtest** - Updates metadata with attestations (400 Bad Request) ← FAILS HERE

## Manual API Testing

You can manually test what npm sends:

```bash
# 1. Get current package metadata
curl -u username:password \
  https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest

# 2. Try to update with attestations (will fail)
curl -u username:password \
  -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "name": "npmtest",
    "versions": {...},
    "attestations": {
      "provenance": {...}
    }
  }' \
  https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest
```

This will show you the exact error JFrog returns.

