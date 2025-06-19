#!/bin/bash

# Development PM2 management script
# Eliminates module errors and provides seamless development workflow

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Ensure logs directory exists
mkdir -p logs

case "$1" in
  "start")
    echo "Starting development server with PM2..."
    
    # Stop any existing processes
    pm2 delete servicedesk-dev 2>/dev/null || true
    
    # Start with CommonJS configuration
    pm2 start ecosystem.dev.config.cjs
    
    if [ $? -eq 0 ]; then
      echo "✅ Development server started successfully"
      echo "📊 Run './dev-pm2.sh status' to check status"
      echo "📋 Run './dev-pm2.sh logs' to view logs"
    else
      echo "❌ PM2 start failed, trying direct node execution..."
      NODE_ENV=development DATABASE_URL=$DATABASE_URL node server.js &
      echo $! > .dev-server.pid
      echo "✅ Development server started with direct node"
    fi
    ;;
    
  "stop")
    echo "Stopping development server..."
    pm2 delete ecosystem.dev.config.cjs 2>/dev/null || echo "No PM2 process found"
    
    # Stop direct node process if exists
    if [ -f .dev-server.pid ]; then
      kill $(cat .dev-server.pid) 2>/dev/null || true
      rm .dev-server.pid
      echo "✅ Direct node process stopped"
    fi
    ;;
    
  "restart")
    echo "Restarting development server..."
    ./dev-pm2.sh stop
    sleep 2
    ./dev-pm2.sh start
    ;;
    
  "logs")
    echo "Showing development logs..."
    pm2 logs servicedesk-dev --lines 50
    ;;
    
  "status")
    echo "Development server status:"
    pm2 status | grep -E "(servicedesk-dev|Name)" || echo "No PM2 processes running"
    
    # Check if direct node process is running
    if [ -f .dev-server.pid ]; then
      PID=$(cat .dev-server.pid)
      if ps -p $PID > /dev/null 2>&1; then
        echo "Direct node process running (PID: $PID)"
      else
        echo "Direct node process not running"
        rm .dev-server.pid
      fi
    fi
    ;;
    
  "health")
    echo "Checking application health..."
    response=$(curl -s http://localhost:5000/api/health 2>/dev/null)
    if [ $? -eq 0 ]; then
      echo "✅ Application responding: $response"
    else
      echo "❌ Application not responding on port 5000"
    fi
    ;;
    
  "test-auth")
    echo "Testing authentication..."
    response=$(curl -s -X POST http://localhost:5000/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"admin","password":"password123"}' 2>/dev/null)
    
    if echo "$response" | grep -q "admin"; then
      echo "✅ Authentication working: Admin login successful"
    else
      echo "❌ Authentication failed: $response"
    fi
    ;;
    
  "deploy-test")
    echo "Testing Ubuntu deployment compatibility..."
    echo "Database config: $(node -e "console.log(process.env.DATABASE_URL ? 'Remote' : 'Local')")"
    echo "Node version: $(node --version)"
    echo "PM2 version: $(pm2 --version)"
    
    # Test CommonJS module loading
    echo "Testing CommonJS configuration..."
    node -e "const config = require('./ecosystem.dev.config.cjs'); console.log('✅ CommonJS config loads correctly');" 2>/dev/null || echo "❌ CommonJS config error"
    ;;
    
  *)
    echo "Calpion IT Service Desk - Development PM2 Manager"
    echo ""
    echo "Usage: ./dev-pm2.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start development server with PM2"
    echo "  stop        Stop development server"
    echo "  restart     Restart development server"
    echo "  logs        Show development logs"
    echo "  status      Show server status"
    echo "  health      Check application health"
    echo "  test-auth   Test authentication system"
    echo "  deploy-test Test Ubuntu deployment compatibility"
    echo ""
    echo "Examples:"
    echo "  ./dev-pm2.sh start    # Start development server"
    echo "  ./dev-pm2.sh logs     # View live logs"
    echo "  ./dev-pm2.sh health   # Check if app is responding"
    ;;
esac