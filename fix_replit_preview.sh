#!/bin/bash

# Fix Replit preview loading issues

echo "=== Fixing Replit Preview Loading ==="

# Kill any existing processes on port 5000
echo "1. Cleaning up existing processes..."
pkill -f "tsx server/index.ts" 2>/dev/null || true
pkill -f "npm run dev" 2>/dev/null || true
sleep 2

# Clear any cached files that might cause issues
echo "2. Clearing development cache..."
rm -rf node_modules/.vite 2>/dev/null || true
rm -rf .vite 2>/dev/null || true
rm -rf dist 2>/dev/null || true

# Reinstall dependencies to ensure clean state
echo "3. Refreshing dependencies..."
npm ci

# Create a simple health check endpoint test
echo "4. Testing server accessibility..."
npm run dev &
SERVER_PID=$!

# Wait for server to start
sleep 10

# Test if server responds
if curl -s http://localhost:5000/api/health > /dev/null; then
    echo "✓ Server is responding locally"
else
    echo "✗ Server not responding locally"
fi

# Kill test server
kill $SERVER_PID 2>/dev/null || true
sleep 2

echo ""
echo "=== Preview Fix Applied ==="
echo ""
echo "Try these steps:"
echo "1. Click the 'Stop' button in Replit console"
echo "2. Wait 5 seconds"  
echo "3. Click 'Run' again"
echo "4. Open preview in a new tab using:"
echo "   https://83e938a3-9929-4918-9e8c-133675a9935d-00-16gy3jb3aitja.kirk.replit.dev"
echo ""
echo "If preview still doesn't work:"
echo "- Try opening the preview URL directly in a new browser tab"
echo "- Check if your browser is blocking the preview domain"
echo "- Ensure Replit's firewall isn't blocking external access"