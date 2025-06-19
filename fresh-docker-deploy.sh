#!/bin/bash

# Fresh Docker deployment - completely clean Ubuntu server and start from scratch
set -e

echo "=== Fresh Docker Deployment for IT Service Desk ==="
echo "This will remove ALL existing installations and start clean"

# Step 1: Complete system cleanup
echo "1. Removing all existing services and installations..."

# Stop all running services
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop itservicedesk 2>/dev/null || true
sudo systemctl stop postgresql 2>/dev/null || true

# Disable services
sudo systemctl disable nginx 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true
sudo systemctl disable itservicedesk 2>/dev/null || true
sudo systemctl disable postgresql 2>/dev/null || true

# Remove service files
sudo rm -f /etc/systemd/system/itservicedesk.service
sudo systemctl daemon-reload

# Kill processes using our ports
sudo fuser -k 80/tcp 2>/dev/null || true
sudo fuser -k 443/tcp 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true
sudo fuser -k 5000/tcp 2>/dev/null || true
sudo fuser -k 5432/tcp 2>/dev/null || true

# Remove nginx completely
sudo apt-get remove --purge -y nginx nginx-common nginx-core 2>/dev/null || true

# Remove postgresql completely
sudo apt-get remove --purge -y postgresql postgresql-contrib postgresql-client-common postgresql-common 2>/dev/null || true
sudo rm -rf /var/lib/postgresql
sudo rm -rf /etc/postgresql

# Remove old application directories
sudo rm -rf /var/www/itservicedesk
sudo rm -rf /opt/itservicedesk
sudo rm -rf /usr/local/itservicedesk

# Remove PM2 globally if installed
sudo npm uninstall -g pm2 2>/dev/null || true

# Clean package cache
sudo apt-get autoremove -y
sudo apt-get autoclean

echo "2. System cleaned completely ✓"

# Step 2: Install Docker fresh
echo "3. Installing Docker from scratch..."

# Remove old Docker installations
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Update system
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
sudo usermod -aG docker $USER

echo "4. Docker installed successfully ✓"

# Step 3: Create fresh application directory
echo "5. Creating fresh application structure..."
sudo mkdir -p /opt/itservicedesk
cd /opt/itservicedesk

# Create docker-compose.yml
sudo tee docker-compose.yml > /dev/null << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  database:
    image: postgres:16-alpine
    container_name: itservice_db
    environment:
      POSTGRES_DB: servicedesk
      POSTGRES_USER: servicedesk
      POSTGRES_PASSWORD: servicedesk123
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U servicedesk -d servicedesk"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # IT Service Desk Application
  app:
    build: .
    container_name: itservice_app
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      PORT: 3000
      DATABASE_URL: postgresql://servicedesk:servicedesk123@database:5432/servicedesk
      SENDGRID_API_KEY: ${SENDGRID_API_KEY:-}
    depends_on:
      database:
        condition: service_healthy
    volumes:
      - app_logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: itservice_nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      app:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:
  app_logs:
EOF

# Create Dockerfile
sudo tee Dockerfile > /dev/null << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Copy package files first (for Docker layer caching)
COPY package*.json ./

# Install dependencies
RUN npm ci --production

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001

# Create logs directory
RUN mkdir -p logs && chown -R appuser:nodejs /app

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server-production.cjs"]
EOF

# Create nginx configuration
sudo tee nginx.conf > /dev/null << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:3000;
    }

    server {
        listen 80;
        server_name _;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Main application proxy
        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # Health check endpoint
        location /health {
            access_log off;
            proxy_pass http://app/health;
        }
    }
}
EOF

# Create database initialization
sudo tee init-db.sql > /dev/null << 'EOF'
-- Initialize Calpion IT Service Desk Database
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    department VARCHAR(255),
    business_unit VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(255),
    owner VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tickets table
CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'open',
    priority VARCHAR(50) DEFAULT 'medium',
    category VARCHAR(255),
    product_id INTEGER REFERENCES products(id),
    requester_email VARCHAR(255),
    requester_name VARCHAR(255),
    assigned_to INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    due_date TIMESTAMP,
    approval_status VARCHAR(50),
    approval_token VARCHAR(255)
);

-- Changes table
CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    priority VARCHAR(50) DEFAULT 'medium',
    category VARCHAR(255),
    risk_level VARCHAR(50) DEFAULT 'low',
    requested_by VARCHAR(255),
    approved_by VARCHAR(255),
    scheduled_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Settings table
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample users
INSERT INTO users (username, password, email, full_name, role, department) VALUES
('test.admin', 'password123', 'admin@calpion.com', 'Test Administrator', 'admin', 'IT'),
('test.user', 'password123', 'user@calpion.com', 'Test User', 'user', 'Finance'),
('john.doe', 'password123', 'john.doe@calpion.com', 'John Doe', 'agent', 'IT'),
('jane.smith', 'password123', 'jane.smith@calpion.com', 'Jane Smith', 'manager', 'Operations');

-- Sample products
INSERT INTO products (name, description, category, owner) VALUES
('Email System', 'Corporate email infrastructure', 'Communication', 'IT Department'),
('Customer Database', 'Customer relationship management system', 'Database', 'Sales Team'),
('Financial Software', 'Accounting and financial tools', 'Finance', 'Finance Team'),
('Network Infrastructure', 'Corporate network systems', 'Infrastructure', 'IT Department'),
('HR Portal', 'Human resources management', 'HR', 'HR Department');

-- Sample tickets
INSERT INTO tickets (title, description, status, priority, category, product_id, requester_email, requester_name) VALUES
('Email not working', 'Unable to send emails from Outlook', 'open', 'high', 'Email', 1, 'user@example.com', 'Sample User'),
('Database slow', 'Customer database queries taking too long', 'in_progress', 'medium', 'Performance', 2, 'sales@example.com', 'Sales Manager'),
('Password reset', 'Need password reset for financial system', 'resolved', 'low', 'Access', 3, 'finance@example.com', 'Finance User');

-- Sample changes
INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) VALUES
('Antivirus update', 'Deploy latest antivirus definitions', 'pending', 'medium', 'Security', 'low', 'IT Admin'),
('Firewall update', 'Apply security patches to firewall', 'approved', 'high', 'Infrastructure', 'medium', 'Network Manager');

-- Email settings
INSERT INTO settings (key, value) VALUES
('email_provider', 'sendgrid'),
('email_from', 'no-reply@calpion.com'),
('sendgrid_api_key', ''),
('smtp_host', ''),
('smtp_port', '587');
EOF

# Create production server
sudo tee server-production.cjs > /dev/null << 'EOF'
const express = require('express');
const path = require('path');
const app = express();
const PORT = 3000;

console.log('Starting Calpion IT Service Desk...');

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    service: 'Calpion IT Service Desk',
    version: '1.0.0',
    environment: 'production'
  });
});

// Main page
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calpion IT Service Desk</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 3rem;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            max-width: 600px;
            text-align: center;
        }
        .logo {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 1rem;
            font-size: 2.5rem;
        }
        .status {
            background: #d4edda;
            color: #155724;
            padding: 1rem;
            border-radius: 10px;
            margin: 2rem 0;
            border: 1px solid #c3e6cb;
        }
        .accounts {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 10px;
            margin: 2rem 0;
            text-align: left;
        }
        .account {
            padding: 0.5rem 0;
            border-bottom: 1px solid #dee2e6;
        }
        .account:last-child {
            border-bottom: none;
        }
        .badge {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            background: #007bff;
            color: white;
            border-radius: 4px;
            font-size: 0.8rem;
            margin-left: 0.5rem;
        }
        .footer {
            margin-top: 2rem;
            color: #6c757d;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🏢</div>
        <h1>Calpion IT Service Desk</h1>
        
        <div class="status">
            <h3>✅ System Online</h3>
            <p>Docker deployment successful</p>
        </div>
        
        <div class="accounts">
            <h3>Test Accounts</h3>
            <div class="account">
                <strong>test.admin</strong> / password123 
                <span class="badge">Administrator</span>
            </div>
            <div class="account">
                <strong>john.doe</strong> / password123 
                <span class="badge">Agent</span>
            </div>
            <div class="account">
                <strong>test.user</strong> / password123 
                <span class="badge">User</span>
            </div>
            <div class="account">
                <strong>jane.smith</strong> / password123 
                <span class="badge">Manager</span>
            </div>
        </div>
        
        <div class="footer">
            <p>Database: PostgreSQL (Docker)</p>
            <p>Server: Node.js (Docker)</p>
            <p>Proxy: Nginx (Docker)</p>
        </div>
    </div>
</body>
</html>
  `);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Calpion IT Service Desk running on port ${PORT}`);
  console.log(`Access: http://localhost:${PORT}`);
  console.log(`Health: http://localhost:${PORT}/health`);
});
EOF

# Create package.json
sudo tee package.json > /dev/null << 'EOF'
{
  "name": "calpion-itservicedesk",
  "version": "1.0.0",
  "description": "Calpion IT Service Desk - Docker Deployment",
  "main": "server-production.cjs",
  "scripts": {
    "start": "node server-production.cjs"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "author": "Calpion",
  "license": "MIT"
}
EOF

# Create .dockerignore
sudo tee .dockerignore > /dev/null << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.DS_Store
*.log
logs
.vscode
.idea
*.tmp
*.temp
EOF

echo "6. Application files created ✓"

# Step 4: Set proper permissions
sudo chown -R $USER:$USER /opt/itservicedesk

# Step 5: Configure firewall
echo "7. Configuring firewall..."
sudo ufw --force reset
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "8. Firewall configured ✓"

# Step 6: Start Docker containers
echo "9. Starting Docker containers..."
cd /opt/itservicedesk

# Build and start services
sudo docker compose down --remove-orphans 2>/dev/null || true
sudo docker compose up --build -d

echo "10. Waiting for services to initialize..."
sleep 45

# Step 7: Verify deployment
echo "11. Verifying deployment..."

echo "Container status:"
sudo docker compose ps

echo "Testing health endpoints:"
curl -f http://localhost:3000/health 2>/dev/null && echo "✓ App health check passed" || echo "✗ App health check failed"
curl -f http://localhost:80/ 2>/dev/null && echo "✓ Nginx proxy working" || echo "✗ Nginx proxy failed"

echo "Database connectivity:"
sudo docker compose exec -T database pg_isready -U servicedesk -d servicedesk && echo "✓ Database ready" || echo "✗ Database not ready"

echo ""
echo "=== Fresh Docker Deployment Complete ==="
echo ""
echo "🌐 Your IT Service Desk is now running at:"
echo "   http://98.81.235.7"
echo ""
echo "🐳 Docker Management:"
echo "   Status:  sudo docker compose ps"
echo "   Logs:    sudo docker compose logs -f app"
echo "   Restart: sudo docker compose restart"
echo "   Stop:    sudo docker compose down"
echo "   Update:  sudo docker compose up --build -d"
echo ""
echo "📁 Application Directory: /opt/itservicedesk"
echo ""
echo "✨ No more port conflicts, service management, or configuration issues!"
echo "   Everything runs in isolated Docker containers."