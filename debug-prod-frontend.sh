#!/bin/bash

echo "Debugging production frontend JavaScript..."

# Test the actual JS file that's being served
echo "=== Testing production JavaScript file ==="
JS_CONTENT=$(curl -s https://98.81.235.7/assets/index-Bd_55WME.js -k | head -100)
echo "JavaScript file size and first 100 chars:"
echo "$JS_CONTENT" | wc -c
echo "$JS_CONTENT"

echo -e "\n=== Testing CSS file ==="
CSS_CONTENT=$(curl -s https://98.81.235.7/assets/index-Cf-nQCTa.css -k | head -50)
echo "CSS file first 50 lines:"
echo "$CSS_CONTENT"

echo -e "\n=== Testing direct dashboard access with browser simulation ==="
curl -s https://98.81.235.7/dashboard -k \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" | head -50

echo -e "\n=== Testing if React is loading by checking for root element ==="
PAGE_CONTENT=$(curl -s https://98.81.235.7/ -k)
echo "Looking for React root div:"
echo "$PAGE_CONTENT" | grep -o '<div id="root"[^>]*>'

echo -e "\n=== Checking if build files exist and are accessible ==="
curl -s -I https://98.81.235.7/assets/index-Bd_55WME.js -k | head -3
curl -s -I https://98.81.235.7/assets/index-Cf-nQCTa.css -k | head -3
