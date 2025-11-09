#!/bin/bash
# Script to capture npm publish API requests

echo "=== Capturing npm publish API requests ==="
echo ""
echo "Method 1: Using npm verbose logging (already enabled in .npmrc)"
echo "Run: npm publish --tag alpha"
echo ""
echo "Method 2: Using NODE_DEBUG to see HTTP requests"
echo "Run: NODE_DEBUG=http,https npm publish --tag alpha"
echo ""
echo "Method 3: Using mitmproxy (interactive HTTP proxy)"
echo "  Step 1: brew install mitmproxy"
echo "  Step 2: mitmproxy -p 8080"
echo "  Step 3: In another terminal:"
echo "    export HTTP_PROXY=http://127.0.0.1:8080"
echo "    export HTTPS_PROXY=http://127.0.0.1:8080"
echo "    npm publish --tag alpha"
echo ""
echo "Method 4: Check npm debug logs"
echo "  Latest log: cat \$(ls -t ~/.npm/_logs/*.log | head -1)"
echo ""
echo "=== Running with NODE_DEBUG (shows HTTP requests) ==="
echo ""

# Run with NODE_DEBUG to show HTTP requests
NODE_DEBUG=http,https npm publish --tag alpha 2>&1 | grep -E "(http|PUT|GET|POST|Request|Response)" | head -30

