#!/bin/bash

echo "IT Service Desk - Persistent Deployment Script"
echo "=============================================="
echo "This script runs in background to prevent connection issues"

# Create a log file with timestamp
LOG_FILE="deployment-$(date +%Y%m%d-%H%M%S).log"

# Function to run deployment in background with logging
run_deployment() {
    echo "Starting deployment in background..."
    echo "Log file: $LOG_FILE"
    echo "You can safely disconnect - deployment will continue"
    echo ""
    
    # Run deployment in background with full logging
    nohup sudo ./deploy.sh > "$LOG_FILE" 2>&1 &
    
    # Get the process ID
    DEPLOY_PID=$!
    echo "Deployment process ID: $DEPLOY_PID"
    
    # Wait a moment to check if process started
    sleep 3
    
    if kill -0 $DEPLOY_PID 2>/dev/null; then
        echo "✓ Deployment started successfully"
        echo ""
        echo "Commands to monitor progress:"
        echo "  tail -f $LOG_FILE                 # Follow deployment log"
        echo "  ps aux | grep deploy.sh           # Check if still running"
        echo "  sudo kill $DEPLOY_PID             # Stop deployment if needed"
        echo ""
        echo "The deployment will take 5-10 minutes to complete."
        echo "You can disconnect safely - the process will continue."
    else
        echo "✗ Failed to start deployment process"
        exit 1
    fi
}

# Check if deploy.sh exists
if [ ! -f "deploy.sh" ]; then
    echo "Error: deploy.sh not found in current directory"
    exit 1
fi

# Make deploy.sh executable
chmod +x deploy.sh

# Run the deployment
run_deployment

echo ""
echo "Deployment started in background."
echo "You can now monitor with: tail -f $LOG_FILE"