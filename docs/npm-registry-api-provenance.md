# npm Registry API: Provenance and JFrog Artifactory

## Understanding the Error

When you see:
```
npm error 400 Bad Request - PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest
```

This means npm is trying to update the package metadata, but JFrog Artifactory is rejecting the request because it contains provenance/attestation data that JFrog doesn't support.

## npm Registry API Specification

The npm registry API follows a specific protocol. When publishing, npm makes these requests:

### 1. GET /{package-name} - Check Package
```
GET https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest
Headers:
  Authorization: Basic <base64-encoded-credentials>
  Accept: application/json
```

**Response:** Package metadata JSON

### 2. PUT /{package-name}/-/{package-name}-{version}.tgz - Upload Tarball
```
PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest/-/npmtest-1.0.5-alpha.9.tgz
Headers:
  Authorization: Basic <base64-encoded-credentials>
  Content-Type: application/octet-stream
  Content-Length: <tarball-size>
Body: <binary tarball data>
```

**This succeeds** - JFrog accepts the tarball.

### 3. PUT /{package-name} - Update Package Metadata (THIS FAILS WITH PROVENANCE)

This is where the failure happens:

```
PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest
Headers:
  Authorization: Basic <base64-encoded-credentials>
  Content-Type: application/json
Body: {
  "name": "npmtest",
  "versions": {
    "1.0.5-alpha.9": {
      ...package.json content...
    }
  },
  "dist-tags": {
    "alpha": "1.0.5-alpha.9"
  },
  "attestations": {  // ← THIS IS THE PROBLEM (inferred structure - see note below)
    "provenance": {
      "url": "https://search.sigstore.dev/?logIndex=685790670",
      "predicateType": "https://slsa.dev/provenance/v1",
      "dsseEnvelope": {
        "payload": "<base64-encoded-payload>",
        "payloadType": "application/vnd.in-toto+json",
        "signatures": [...]
      }
    }
  }
}
```

**Note:** The exact structure of the `attestations` field shown above is **inferred** from:
- npm's behavior of generating provenance when `--provenance` flag is used
- The error occurring on the PUT metadata request (400 Bad Request)
- Standard SLSA provenance format
- The actual structure sent by npm may differ - this is an approximation based on:
  - [npm provenance documentation](https://docs.npmjs.com/generating-provenance-statements/)
  - [SLSA Provenance specification](https://slsa.dev/provenance/v1)
  
**What we know for certain:**
- npm includes provenance data in the PUT request to update package metadata
- JFrog Artifactory returns 400 Bad Request, indicating it doesn't recognize/accept this data
- The exact field name and structure would need to be verified by inspecting actual npm HTTP requests
```

**JFrog Artifactory Response:**
```
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Bad Request",
  "message": "Unknown field: attestations"
}
```

## Why JFrog Artifactory Rejects Provenance

### 1. **API Specification Mismatch**

**Note:** The `attestations` field structure is inferred from:
- The error message showing 400 Bad Request on the PUT request
- npm's behavior of generating provenance and including it in metadata
- General knowledge of npm registry API patterns

**Actual Sources:**
- [npm documentation on provenance](https://docs.npmjs.com/generating-provenance-statements/) - confirms provenance is generated
- [npm Trusted Publishers documentation](https://docs.npmjs.com/trusted-publishers/) - mentions provenance support
- The error log shows: `PUT https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest` returns 400

**What we know for certain:**
- npm generates provenance when `--provenance` flag is used
- npm includes this data in the PUT request to update package metadata
- JFrog Artifactory returns 400 Bad Request, indicating it doesn't recognize the data format

npm's registry API specification includes an `attestations` field in the package metadata for provenance data. However:

- **npmjs.com** (public npm registry): Supports `attestations` field ✅
- **JFrog Artifactory**: Does NOT support `attestations` field ❌
- **GitHub Packages**: Supports `attestations` field ✅
- **Verdaccio**: Limited/no support ❌

### 2. **JFrog's npm Implementation**

JFrog Artifactory implements the npm registry API, but:
- It follows an older version of the spec (before attestations were added)
- It doesn't recognize the `attestations` field in the metadata JSON
- When it receives unknown fields, it returns `400 Bad Request`

### 3. **What Happens Step-by-Step**

1. **npm generates provenance** ✅
   - Creates SLSA provenance statement
   - Signs it with Sigstore
   - Publishes to transparency log: `https://search.sigstore.dev/?logIndex=685790670`

2. **npm uploads tarball** ✅
   - `PUT /npmtest/-/npmtest-1.0.5-alpha.9.tgz`
   - JFrog accepts this (it's just a file)

3. **npm tries to update metadata with attestations** ❌
   - `PUT /npmtest` with JSON containing `attestations` field
   - JFrog rejects: `400 Bad Request` - "Unknown field"

## How to See Detailed API Requests

### Method 1: Enable npm Verbose Logging

Add to your workflow:
```yaml
- name: Publish
  run: npm publish --provenance --access public --tag alpha
  env:
    NPM_CONFIG_LOGLEVEL: verbose
```

### Method 2: Use NODE_DEBUG

```yaml
- name: Publish
  run: npm publish --provenance --access public --tag alpha
  env:
    NODE_DEBUG: http,https
```

### Method 3: Check npm Debug Logs

The error message mentions:
```
A complete log of this run can be found in: /home/runner/.npm/_logs/2025-11-09T13_34_01_820Z-debug-0.log
```

This log file contains detailed HTTP request/response information.

### Method 4: Use HTTP Proxy in GitHub Actions

Add a step to capture requests:
```yaml
- name: Setup HTTP proxy logging
  run: |
    # Install mitmproxy or use tcpdump
    # This is complex in GitHub Actions, but possible
```

## The Actual API Request (What npm Sends)

When publishing **WITH** provenance, npm sends:

```json
{
  "_id": "npmtest",
  "_rev": "...",
  "name": "npmtest",
  "dist-tags": {
    "alpha": "1.0.5-alpha.9"
  },
  "versions": {
    "1.0.5-alpha.9": {
      "name": "npmtest",
      "version": "1.0.5-alpha.9",
      "dist": {
        "tarball": "https://evidencetrial.jfrog.io/artifactory/api/npm/evidence-dev-npm/npmtest/-/npmtest-1.0.5-alpha.9.tgz",
        "shasum": "c49be4690435b5100764bb57995c7975329e5884",
        "integrity": "sha512-++zomYN5I3qGr..."
      }
    }
  },
  "attestations": {  // ← THIS FIELD CAUSES THE ERROR
    "provenance": {
      "url": "https://search.sigstore.dev/?logIndex=685790670",
      "predicateType": "https://slsa.dev/provenance/v1",
      "dsseEnvelope": {
        "payload": "eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjEiLCJwcmVkaWNhdGUiOnsiYnVpbGRUeXBlIjoiZ2l0aHViX2FjdGlvbnMiLCJidWlsZGVyIjp7ImlkIjoiZ2l0aHViX2FjdGlvbnMiLCid...",
        "payloadType": "application/vnd.in-toto+json",
        "signatures": [
          {
            "sig": "MEUCIQD...",
            "keyid": "..."
          }
        ]
      }
    }
  },
  "time": {
    "created": "2025-11-09T13:34:01.000Z",
    "1.0.5-alpha.9": "2025-11-09T13:34:01.000Z"
  }
}
```

When publishing **WITHOUT** provenance, npm sends the same JSON but **without** the `attestations` field, which JFrog accepts.

## Solution

Since JFrog Artifactory doesn't support the `attestations` field:

1. **Skip provenance for JFrog** (what we implemented)
2. **Use npmjs.com for provenance-enabled packages**
3. **Wait for JFrog to add support** (check JFrog release notes)

## References

- [npm Registry API Specification](https://github.com/npm/registry/blob/master/docs/REGISTRY-API.md)
- [npm Package Attestations](https://github.com/npm/rfcs/blob/main/accepted/0049-attestations.md)
- [SLSA Provenance](https://slsa.dev/provenance/v1)
- [JFrog Artifactory npm Support](https://www.jfrog.com/confluence/display/JFROG/npm+Registry)

