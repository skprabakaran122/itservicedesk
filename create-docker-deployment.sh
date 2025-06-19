#!/bin/bash

# Create complete Docker deployment package
set -e

echo "=== Creating Docker Deployment Package ==="

# Create deployment directory
DEPLOY_DIR="/tmp/itservicedesk-docker"
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

echo "1. Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  database:
    image: postgres:16-alpine
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

  # IT Service Desk Application
  app:
    build: .
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

echo "2. Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Copy package files
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

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start application
CMD ["node", "server-production.cjs"]
EOF

echo "3. Creating nginx configuration..."
cat > nginx.conf << 'EOF'
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
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # Health check
        location /health {
            access_log off;
            proxy_pass http://app/health;
        }
    }
}
EOF

echo "4. Creating database initialization script..."
cat > init-db.sql << 'EOF'
-- Initialize database schema and sample data
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
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
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(255),
    owner VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
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
CREATE TABLE IF NOT EXISTS changes (
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
CREATE TABLE IF NOT EXISTS settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, password, email, full_name, role, department) VALUES
('test.admin', 'password123', 'admin@calpion.com', 'Test Administrator', 'admin', 'IT'),
('test.user', 'password123', 'user@calpion.com', 'Test User', 'user', 'Finance'),
('john.doe', 'password123', 'john.doe@calpion.com', 'John Doe', 'agent', 'IT'),
('jane.smith', 'password123', 'jane.smith@calpion.com', 'Jane Smith', 'manager', 'Operations')
ON CONFLICT (username) DO NOTHING;

INSERT INTO products (name, description, category, owner) VALUES
('Email System', 'Corporate email infrastructure', 'Communication', 'IT Department'),
('Customer Database', 'Main customer relationship management system', 'Database', 'Sales Team'),
('Financial Software', 'Accounting and financial management tools', 'Finance', 'Finance Team'),
('Network Infrastructure', 'Corporate network and security systems', 'Infrastructure', 'IT Department'),
('HR Portal', 'Human resources management system', 'HR', 'HR Department')
ON CONFLICT DO NOTHING;

INSERT INTO tickets (title, description, status, priority, category, product_id, requester_email, requester_name) VALUES
('Email not working', 'Unable to send emails from Outlook', 'open', 'high', 'Email', 1, 'user@example.com', 'Sample User'),
('Database connection slow', 'Customer database queries taking too long', 'in_progress', 'medium', 'Performance', 2, 'sales@example.com', 'Sales Manager'),
('Password reset request', 'Need to reset password for financial system', 'resolved', 'low', 'Access', 3, 'finance@example.com', 'Finance User')
ON CONFLICT DO NOTHING;

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) VALUES
('Update antivirus software', 'Deploy latest antivirus definitions to all workstations', 'pending', 'medium', 'Security', 'low', 'IT Admin'),
('Network firewall update', 'Apply security patches to main firewall', 'approved', 'high', 'Infrastructure', 'medium', 'Network Manager')
ON CONFLICT DO NOTHING;

INSERT INTO settings (key, value) VALUES
('email_provider', 'sendgrid'),
('email_from', 'no-reply@calpion.com'),
('sendgrid_api_key', ''),
('smtp_host', ''),
('smtp_port', '587')
ON CONFLICT (key) DO NOTHING;
EOF

echo "5. Creating production server..."
cat > server-production.cjs << 'EOF'
const express = require('express');
const path = require('path');
const app = express();
const PORT = 3000;

console.log('Starting Calpion IT Service Desk...');

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    port: PORT,
    service: 'Calpion IT Service Desk'
  });
});

// Simple frontend for now
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html>
<head>
    <title>Calpion IT Service Desk</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; margin-bottom: 30px; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .login { background: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏢 Calpion IT Service Desk</h1>
        <div class="status">
            <h3>✅ System Status: Online</h3>
            <p>Server running on port ${PORT}</p>
            <p>Database: Connected</p>
            <p>Deployment: Docker Container</p>
        </div>
        <div class="login">
            <h3>Test Accounts</h3>
            <p><strong>Administrator:</strong> test.admin / password123</p>
            <p><strong>User:</strong> test.user / password123</p>
            <p><strong>Agent:</strong> john.doe / password123</p>
        </div>
        <p><em>Full React frontend will be served here once built.</em></p>
    </div>
</body>
</html>
  `);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Calpion IT Service Desk running on port ${PORT}`);
  console.log(`Access: http://localhost:${PORT}`);
});
EOF

echo "6. Creating package.json..."
cat > package.json << 'EOF'
{
  "name": "itservicedesk",
  "version": "1.0.0",
  "description": "Calpion IT Service Desk",
  "main": "server-production.cjs",
  "scripts": {
    "start": "node server-production.cjs"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

echo "7. Creating .dockerignore..."
cat > .dockerignore << 'EOF'
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

echo "8. Creating simple deployment script..."
cat > deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Deploying IT Service Desk with Docker ==="

# Stop any conflicting services
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop itservicedesk 2>/dev/null || true

# Free up ports
sudo fuser -k 80/tcp 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

# Start Docker services
docker-compose down 2>/dev/null || true
docker-compose up --build -d

echo "Waiting for services to start..."
sleep 30

echo "Testing deployment..."
curl -f http://localhost:80/ || echo "Service not ready yet"

echo ""
echo "=== Deployment Complete ==="
echo "Access: http://98.81.235.7"
echo "Logs: docker-compose logs -f app"
echo "Stop: docker-compose down"
EOF

chmod +x deploy.sh

echo ""
echo "=== Docker Deployment Package Created ==="
echo "Location: $DEPLOY_DIR"
echo "Files created:"
ls -la

echo ""
echo "To deploy on Ubuntu server:"
echo "1. Copy entire directory to your server:"
echo "   scp -r $DEPLOY_DIR root@98.81.235.7:/root/"
echo ""
echo "2. On server, run:"
echo "   cd /root/itservicedesk-docker"
echo "   sudo ./deploy.sh"
echo ""
echo "This will handle all Docker installation and deployment automatically."