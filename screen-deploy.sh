#!/bin/bash

echo "IT Service Desk - Screen Deployment"
echo "==================================="

# Install screen if not present
if ! command -v screen >/dev/null 2>&1; then
    echo "Installing screen..."
    sudo apt update -y
    sudo apt install -y screen
fi

# Check if deploy.sh exists
if [ ! -f "deploy.sh" ]; then
    echo "Error: deploy.sh not found"
    exit 1
fi

chmod +x deploy.sh

echo "Starting deployment in screen session..."
echo ""
echo "Session name: servicedesk-deploy"
echo ""
echo "Commands to reconnect after PuTTY disconnection:"
echo "  screen -r servicedesk-deploy    # Reconnect to session"
echo "  screen -list                    # List all sessions"
echo ""
echo "Press Ctrl+A then D to detach (keep running)"
echo "Press Ctrl+C to stop deployment"
echo ""

# Start deployment in named screen session
screen -S servicedesk-deploy sudo ./deploy.sh