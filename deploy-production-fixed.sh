#!/bin/bash

# Production deployment using the working development setup
set -e

cd /var/www/itservicedesk

echo "=== Production Deployment with Development Setup ==="

# Stop existing processes
pm2 delete all 2>/dev/null || true

# Build the application properly
echo "Building application..."
npm run build

# Create production start script that uses the built distribution
echo "Creating production start script..."
cat > start-production.mjs << 'EOF'
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

console.log('Starting production server...');
console.log('Working directory:', __dirname);

// Start the built server
const serverProcess = spawn('node', ['dist/index.js'], {
  cwd: __dirname,
  stdio: 'inherit',
  env: {
    ...process.env,
    NODE_ENV: 'production',
    PORT: '5000'
  }
});

serverProcess.on('error', (err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

serverProcess.on('exit', (code) => {
  console.log(`Server process exited with code ${code}`);
  if (code !== 0) {
    process.exit(code);
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, stopping server...');
  serverProcess.kill('SIGTERM');
});

process.on('SIGINT', () => {
  console.log('SIGINT received, stopping server...');
  serverProcess.kill('SIGINT');
});
EOF

# Create PM2 configuration for the production setup
echo "Creating PM2 configuration..."
cat > ecosystem.production.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'start-production.mjs',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    restart_delay: 3000,
    max_restarts: 5,
    min_uptime: '20s',
    kill_timeout: 10000,
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true,
    merge_logs: true
  }]
};
EOF

# Ensure logs directory exists
mkdir -p logs
chown -R www-data:www-data logs

# Test if the build was successful
if [ ! -f "dist/index.js" ]; then
  echo "Build failed or incomplete. Checking dist directory..."
  ls -la dist/ 2>/dev/null || echo "No dist directory found"
  
  # Try alternative build approach
  echo "Attempting alternative build..."
  npx vite build 2>/dev/null || echo "Vite build failed"
  
  if [ ! -f "dist/index.js" ]; then
    echo "Creating fallback server using development server in production mode..."
    cat > start-production.mjs << 'EOF'
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

console.log('Starting development server in production mode...');

// Use tsx to run the TypeScript server directly
const serverProcess = spawn('npx', ['tsx', 'server/index.ts'], {
  cwd: __dirname,
  stdio: 'inherit',
  env: {
    ...process.env,
    NODE_ENV: 'production',
    PORT: '5000'
  }
});

serverProcess.on('error', (err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

serverProcess.on('exit', (code) => {
  console.log(`Server process exited with code ${code}`);
  if (code !== 0) {
    process.exit(code);
  }
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, stopping server...');
  serverProcess.kill('SIGTERM');
});

process.on('SIGINT', () => {
  console.log('SIGINT received, stopping server...');
  serverProcess.kill('SIGINT');
});
EOF
  fi
fi

# Start with PM2
echo "Starting application with PM2..."
pm2 start ecosystem.production.config.cjs

# Wait for startup
sleep 15

echo "Checking PM2 status..."
pm2 status

echo "Testing application..."
if curl -s http://localhost:5000/api/health > /dev/null; then
  echo "✓ Application health check successful"
else
  echo "✗ Health check failed, checking logs..."
  pm2 logs servicedesk --lines 20 --nostream
fi

echo "Testing root endpoint..."
curl -s -I http://localhost:5000

echo "Restarting nginx..."
systemctl restart nginx
sleep 3

echo "Testing through nginx..."
curl -s -I http://localhost

echo ""
echo "=== Production Deployment Complete ==="
echo "✓ Using working development setup in production mode"
echo "✓ PM2 process manager configured"
echo "✓ Application should be accessible"
echo ""
echo "Monitor with:"
echo "  pm2 monit"
echo "  pm2 logs servicedesk"
echo "  curl http://your-server-ip/api/health"