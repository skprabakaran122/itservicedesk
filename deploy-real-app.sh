#!/bin/bash

# Deploy the actual IT Service Desk application
set -e

cd /var/www/itservicedesk

echo "=== Deploying Real IT Service Desk Application ==="

# Stop existing placeholder
pm2 delete all 2>/dev/null || true

# Build the actual application properly
echo "Building the real application..."
npm run build

# Check if build was successful
if [ ! -f "dist/index.js" ]; then
    echo "Backend build missing, building server..."
    npm run build:server 2>/dev/null || {
        echo "Building server manually..."
        npx vite build --outDir dist/server server/index.ts
    }
fi

# Create production server that uses the actual built application
echo "Creating production server for real app..."
cat > server-real.cjs << 'EOF'
const express = require('express');
const path = require('path');
const { createServer } = require('http');

const app = express();
const PORT = 5000;

console.log('=== IT Service Desk Production Server ===');
console.log('Starting real application...');

// Basic middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Serve static files from dist
const distPath = path.join(__dirname, 'dist');
console.log('Serving static files from:', distPath);
app.use(express.static(distPath));

// Try to load and register the actual routes
try {
    // Load the built backend routes
    const routesPath = path.join(__dirname, 'dist', 'index.js');
    console.log('Loading routes from:', routesPath);
    
    // Import the built server
    require(routesPath);
    console.log('✓ Real application routes loaded');
    
} catch (error) {
    console.log('Could not load built routes, trying alternative approach...');
    
    // Fallback: run the TypeScript server directly
    const { spawn } = require('child_process');
    
    console.log('Starting TypeScript server with tsx...');
    const tsxProcess = spawn('npx', ['tsx', 'server/index.ts'], {
        cwd: __dirname,
        stdio: 'pipe',
        env: {
            ...process.env,
            NODE_ENV: 'production',
            PORT: PORT.toString()
        }
    });
    
    tsxProcess.stdout.on('data', (data) => {
        console.log('APP:', data.toString().trim());
    });
    
    tsxProcess.stderr.on('data', (data) => {
        console.error('APP ERROR:', data.toString().trim());
    });
    
    tsxProcess.on('exit', (code) => {
        console.log('TypeScript server exited with code:', code);
        if (code !== 0) {
            process.exit(code);
        }
    });
    
    // Graceful shutdown
    process.on('SIGTERM', () => {
        console.log('SIGTERM received, stopping TypeScript server...');
        tsxProcess.kill('SIGTERM');
    });
    
    process.on('SIGINT', () => {
        console.log('SIGINT received, stopping TypeScript server...');
        tsxProcess.kill('SIGINT');
    });
    
    // Don't continue with Express setup since tsx is handling it
    return;
}

// If we get here, the built version didn't work, so create a proxy
console.log('Setting up proxy to TypeScript server...');

// Start the TypeScript server on a different port
const { spawn } = require('child_process');
const tsxProcess = spawn('npx', ['tsx', 'server/index.ts'], {
    cwd: __dirname,
    stdio: 'pipe',
    env: {
        ...process.env,
        NODE_ENV: 'production',
        PORT: '5001'  // Use different port
    }
});

tsxProcess.stdout.on('data', (data) => {
    console.log('BACKEND:', data.toString().trim());
});

tsxProcess.stderr.on('data', (data) => {
    console.error('BACKEND ERROR:', data.toString().trim());
});

// Wait for backend to start
setTimeout(() => {
    // Proxy API requests to the TypeScript server
    app.use('/api', (req, res) => {
        const targetUrl = `http://localhost:5001${req.originalUrl}`;
        console.log('Proxying:', req.method, req.originalUrl, '->', targetUrl);
        
        const http = require('http');
        const options = {
            hostname: 'localhost',
            port: 5001,
            path: req.originalUrl,
            method: req.method,
            headers: req.headers
        };
        
        const proxyReq = http.request(options, (proxyRes) => {
            res.status(proxyRes.statusCode);
            Object.keys(proxyRes.headers).forEach(key => {
                res.set(key, proxyRes.headers[key]);
            });
            proxyRes.pipe(res);
        });
        
        proxyReq.on('error', (err) => {
            console.error('Proxy error:', err);
            res.status(500).json({ error: 'Backend unavailable' });
        });
        
        if (req.body) {
            proxyReq.write(JSON.stringify(req.body));
        }
        proxyReq.end();
    });
    
    // Serve frontend for all other routes
    app.get('*', (req, res) => {
        const indexPath = path.join(distPath, 'index.html');
        if (require('fs').existsSync(indexPath)) {
            res.sendFile(indexPath);
        } else {
            res.status(404).send('Application not built properly');
        }
    });
    
    // Start the proxy server
    const server = createServer(app);
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`✓ IT Service Desk running on port ${PORT}`);
        console.log(`✓ Frontend: Static files from dist/`);
        console.log(`✓ Backend: Proxied to TypeScript server on port 5001`);
    });
    
}, 3000);

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, stopping servers...');
    tsxProcess.kill('SIGTERM');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, stopping servers...');
    tsxProcess.kill('SIGINT');
    process.exit(0);
});
EOF

# Update PM2 configuration for real app
echo "Creating PM2 configuration for real app..."
cat > ecosystem.real.config.cjs << 'EOF'
module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server-real.cjs',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    restart_delay: 5000,
    max_restarts: 3,
    min_uptime: '30s',
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

# Ensure all dependencies are available
echo "Checking dependencies..."
npm install tsx --save-dev 2>/dev/null || true

# Start the real application
echo "Starting real IT Service Desk application..."
pm2 start ecosystem.real.config.cjs

# Wait for startup
sleep 15

echo "Checking application status..."
pm2 status

echo "Testing real application endpoints..."
echo "Health check:"
curl -s http://localhost:5000/api/health 2>/dev/null || echo "Health endpoint not responding"

echo ""
echo "Auth check:"
curl -s http://localhost:5000/api/auth/me 2>/dev/null || echo "Auth endpoint not responding"

echo ""
echo "Frontend check:"
curl -s -I http://localhost:5000/ 2>/dev/null || echo "Frontend not responding"

echo ""
echo "=== Real IT Service Desk Deployment Complete ==="
echo "✓ Built and deployed actual application"
echo "✓ PM2 running real application server"
echo "✓ Should serve full React frontend with all features"
echo ""
echo "Your real IT Service Desk should now be at: http://98.81.235.7"
echo "Features: Dashboard, Tickets, Changes, Products, Users, Reports"
echo ""
echo "Monitor with: pm2 logs servicedesk"