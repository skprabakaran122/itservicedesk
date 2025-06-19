#!/bin/bash

# Build the actual IT Service Desk frontend from existing React source
set -e

echo "=== Building Frontend from Existing Source ==="

cd /var/www/itservicedesk

echo "1. Checking Node.js and npm versions..."
node --version
npm --version

echo "2. Installing all dependencies..."
npm install

echo "3. Checking if vite.config.ts exists..."
if [ -f "vite.config.ts" ]; then
    echo "✓ Vite config found"
    cat vite.config.ts
else
    echo "Creating vite.config.ts..."
    cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './client/src'),
      '@shared': path.resolve(__dirname, './shared'),
      '@assets': path.resolve(__dirname, './client/src/assets'),
    },
  },
  root: './client',
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    rollupOptions: {
      input: './client/index.html'
    }
  },
  server: {
    proxy: {
      '/api': 'http://localhost:5000'
    }
  }
})
EOF
fi

echo "4. Checking package.json for build script..."
if ! grep -q '"build"' package.json; then
    echo "Adding build script to package.json..."
    npm pkg set scripts.build="vite build"
fi

echo "5. Building the React frontend..."
npm run build

echo "6. Verifying build output..."
if [ -d "dist" ]; then
    echo "✓ Build successful"
    ls -la dist/
    echo "Build contents:"
    find dist -type f -name "*.html" -o -name "*.js" -o -name "*.css" | head -10
else
    echo "✗ Build failed, trying alternative approach..."
    
    # Try building with vite directly
    npx vite build --config vite.config.ts
    
    if [ -d "dist" ]; then
        echo "✓ Alternative build successful"
    else
        echo "✗ All build attempts failed"
        exit 1
    fi
fi

echo "7. Updating server to serve the built frontend..."
cat > server-production.cjs << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve built React app
const distPath = path.join(__dirname, 'dist');
console.log('Looking for built files in:', distPath);

if (fs.existsSync(distPath)) {
    app.use(express.static(distPath));
    console.log('✓ Serving built React app from dist/');
} else {
    console.log('✗ dist/ not found, serving from client/');
    app.use(express.static(path.join(__dirname, 'client')));
}

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        frontend: fs.existsSync(distPath) ? 'Built React App' : 'Development Mode',
        distExists: fs.existsSync(distPath),
        distContents: fs.existsSync(distPath) ? fs.readdirSync(distPath) : 'N/A'
    });
});

// API routes would connect to your actual backend/database
app.get('/api/*', (req, res) => {
    res.status(404).json({ message: 'API endpoint not implemented in production server' });
});

// Serve React app for all other routes (SPA routing)
app.get('*', (req, res) => {
    const indexPath = path.join(distPath, 'index.html');
    
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).send(`
            <h1>IT Service Desk</h1>
            <p>Frontend build not found at: ${indexPath}</p>
            <p>Please run the build process.</p>
            <p>Available files: ${fs.existsSync(distPath) ? fs.readdirSync(distPath).join(', ') : 'dist directory missing'}</p>
        `);
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`IT Service Desk running on port ${PORT}`);
    console.log(`Dist path: ${distPath}`);
    console.log(`Dist exists: ${fs.existsSync(distPath)}`);
    if (fs.existsSync(distPath)) {
        console.log(`Dist contents: ${fs.readdirSync(distPath).join(', ')}`);
    }
});
EOF

echo "8. Restarting service..."
systemctl restart itservicedesk
sleep 5

echo "9. Testing the application..."
systemctl status itservicedesk --no-pager | head -10

echo "10. Checking health endpoint..."
curl -s http://localhost:5000/health | head -20

echo ""
echo "=== Frontend Build Complete ==="
echo "Your actual IT Service Desk React app should now be running at: http://98.81.235.7"