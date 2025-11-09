# npm publish API Requests

## Overview
When you run `npm publish`, npm makes several HTTP requests to the registry. Here's what happens:

## API Requests During `npm publish`

### 1. **GET /{package-name}** - Check if package exists
```
GET https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest
Headers:
  Authorization: Basic <base64-encoded-credentials>
  Accept: application/json
```

**Purpose**: Fetches package metadata to check:
- If the package exists
- What versions are already published
- Package permissions

**Response**: JSON with package metadata including all published versions

**This is where immutability is checked!** The registry compares the version you're trying to publish against existing versions.

---

### 2. **PUT /{package-name}/-/{package-name}-{version}.tgz** - Upload tarball
```
PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest/-/npmtest-1.0.3-alpha.1.tgz
Headers:
  Authorization: Basic <base64-encoded-credentials>
  Content-Type: application/octet-stream
  Content-Length: <tarball-size>
Body: <binary tarball data>
```

**Purpose**: Uploads the actual package tarball (compressed .tar.gz file)

**This is the actual publish operation!**

---

### 3. **PUT /{package-name}** - Update package metadata
```
PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest
Headers:
  Authorization: Basic <base64-encoded-credentials>
  Content-Type: application/json
Body: {
  "name": "npmtest",
  "versions": {
    "1.0.3-alpha.1": { ... package.json content ... }
  },
  "dist-tags": {
    "alpha": "1.0.3-alpha.1",
    "latest": "1.0.2"  // or previous latest
  },
  "time": { ... },
  "users": { ... }
}
```

**Purpose**: Updates the package metadata with:
- New version information
- Distribution tags (latest, alpha, beta, etc.)
- Timestamps
- User information

---

## Complete Flow

```
1. npm publish
   ↓
2. Read package.json
   ↓
3. Create tarball (.tgz file)
   ↓
4. GET /npmtest  ← Check existing versions (immutability check happens here)
   ↓
5. PUT /npmtest/-/npmtest-1.0.3-alpha.1.tgz  ← Upload tarball
   ↓
6. PUT /npmtest  ← Update package metadata
   ↓
7. Done!
```

## How to Capture Actual API Requests

### Method 1: Use npm's verbose logging (already enabled)
Your `.npmrc` has `loglevel=verbose`, which shows HTTP requests.

### Method 2: Use HTTP proxy (mitmproxy, Charles, etc.)
```bash
# Install mitmproxy
brew install mitmproxy

# Run proxy
mitmproxy -p 8080

# In another terminal, configure npm to use proxy
export HTTP_PROXY=http://127.0.0.1:8080
export HTTPS_PROXY=http://127.0.0.1:8080

# Run npm publish
npm publish --tag alpha
```

### Method 3: Use Node.js debug mode
```bash
NODE_DEBUG=http,https npm publish --tag alpha
```

### Method 4: Use curl to see exact requests
You can manually replicate what npm does:
```bash
# 1. Check package
curl -u <username>:<password> \
  https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest

# 2. Upload tarball (if you create one first)
npm pack  # Creates npmtest-1.0.3-alpha.1.tgz
curl -u <username>:<password> \
  -X PUT \
  -H "Content-Type: application/octet-stream" \
  --data-binary @npmtest-1.0.3-alpha.1.tgz \
  https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest/-/npmtest-1.0.3-alpha.1.tgz
```

## Where Immutability is Enforced

The immutability check happens in **Step 1** (GET request):
- Registry checks if version `1.0.3-alpha.1` already exists
- If it exists, registry returns 403/400 error
- npm CLI receives the error and displays: "You cannot publish over the previously published versions"

The actual enforcement is **server-side** in JFrog Artifactory, not in npm CLI.

## Registry-Specific Endpoints

Different registries use slightly different endpoints:

### npmjs.com (public npm)
- `GET https://registry.npmjs.org/{package-name}`
- `PUT https://registry.npmjs.org/{package-name}/-/{package-name}-{version}.tgz`

### JFrog Artifactory (your registry)
- `GET https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/{package-name}`
- `PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/{package-name}/-/{package-name}-{version}.tgz`

### GitHub Packages
- `GET https://npm.pkg.github.com/@scope/{package-name}`
- `PUT https://npm.pkg.github.com/@scope/{package-name}/-/{package-name}-{version}.tgz`

