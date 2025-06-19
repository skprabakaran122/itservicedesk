#!/bin/bash

# Deploy the REAL IT Service Desk application with Docker
set -e

echo "=== Deploying Real IT Service Desk Application ==="

cd /opt/itservicedesk

# Stop existing containers
sudo docker compose down --remove-orphans 2>/dev/null || true

# Copy the actual application files from the Replit project
echo "1. Setting up real application files..."

# We need to copy these key directories and files:
# - client/ (React frontend)
# - server/ (Express backend)
# - shared/ (Shared schemas)
# - package.json (with all real dependencies)
# - dist/ (built frontend, if available)

# Create proper Dockerfile for the real application
sudo tee Dockerfile > /dev/null << 'EOF'
# Multi-stage build for the real IT Service Desk
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for building)
RUN npm install

# Copy source code
COPY . .

# Build the frontend
RUN npm run build

# Production stage
FROM node:20-alpine AS production

WORKDIR /app

# Install only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server
COPY --from=builder /app/shared ./shared

# Install additional tools for health checks
RUN apk add --no-cache wget curl

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001

# Create logs directory and set permissions
RUN mkdir -p logs uploads && \
    chown -R appuser:nodejs /app

USER appuser

EXPOSE 3000

# Health check for the real application
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the real TypeScript server
CMD ["npx", "tsx", "server/index.ts"]
EOF

# Create docker-compose.yml for the real application
sudo tee docker-compose.yml > /dev/null << 'EOF'
services:
  database:
    image: postgres:16-alpine
    container_name: itservice_db
    environment:
      POSTGRES_DB: servicedesk
      POSTGRES_USER: servicedesk
      POSTGRES_PASSWORD: servicedesk123
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-real-db.sql:/docker-entrypoint-initdb.d/init-real-db.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U servicedesk -d servicedesk"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

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
      - app_uploads:/app/uploads
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: itservice_nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx-real.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      app:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:
  app_logs:
  app_uploads:
EOF

# Create nginx config for the real application
sudo tee nginx-real.conf > /dev/null << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    upstream app {
        server app:3000;
    }

    server {
        listen 80;
        server_name _;
        
        # Increase client body size for file uploads
        client_max_body_size 50M;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # API routes
        location /api/ {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            
            # Timeouts for API calls
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # File uploads
        location /uploads/ {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Health check
        location /health {
            access_log off;
            proxy_pass http://app/health;
        }

        # Frontend application (React SPA)
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
            
            # Handle client-side routing
            try_files $uri $uri/ @fallback;
        }

        # Fallback for client-side routing
        location @fallback {
            proxy_pass http://app;
        }
    }
}
EOF

# Create database schema for the real application using Drizzle schema
sudo tee init-real-db.sql > /dev/null << 'EOF'
-- Real IT Service Desk Database Schema
-- Based on the actual Drizzle schema from shared/schema.ts

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (matches Drizzle schema)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('admin', 'agent', 'user', 'manager')),
    department VARCHAR(255),
    business_unit VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table (matches Drizzle schema)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(255),
    owner VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tickets table (matches Drizzle schema)
CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'pending_approval', 'approved')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
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
    approval_token VARCHAR(255),
    sla_target TIMESTAMP,
    response_time INTERVAL,
    resolution_time INTERVAL
);

-- Changes table (matches Drizzle schema) 
CREATE TABLE changes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'scheduled', 'in_progress', 'completed', 'cancelled')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    category VARCHAR(255),
    risk_level VARCHAR(50) DEFAULT 'low' CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
    requested_by VARCHAR(255),
    approved_by VARCHAR(255),
    scheduled_date TIMESTAMP,
    implementation_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Attachments table (for file uploads)
CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    file_size INTEGER,
    mime_type VARCHAR(255),
    ticket_id INTEGER REFERENCES tickets(id),
    change_id INTEGER REFERENCES changes(id),
    uploaded_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Settings table (for email configuration)
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ticket history table
CREATE TABLE ticket_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER REFERENCES tickets(id),
    action VARCHAR(255) NOT NULL,
    details TEXT,
    user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Change history table
CREATE TABLE change_history (
    id SERIAL PRIMARY KEY,
    change_id INTEGER REFERENCES changes(id),
    action VARCHAR(255) NOT NULL,
    details TEXT,
    user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert real sample data that matches your application
INSERT INTO users (username, password, email, full_name, role, department) VALUES
('test.admin', 'password123', 'admin@calpion.com', 'Test Administrator', 'admin', 'IT'),
('test.user', 'password123', 'user@calpion.com', 'Test User', 'user', 'Finance'),
('john.doe', 'password123', 'john.doe@calpion.com', 'John Doe', 'agent', 'IT'),
('jane.smith', 'password123', 'jane.smith@calpion.com', 'Jane Smith', 'manager', 'Operations'),
('admin', 'password123', 'admin@calpion.com', 'System Administrator', 'admin', 'IT');

INSERT INTO products (name, description, category, owner) VALUES
('Email System', 'Corporate email infrastructure and services', 'Communication', 'IT Department'),
('Customer Database', 'Main customer relationship management system', 'Database', 'Sales Team'),
('Financial Software', 'Accounting and financial management tools', 'Finance', 'Finance Team'),
('Network Infrastructure', 'Corporate network and security systems', 'Infrastructure', 'IT Department'),
('HR Portal', 'Human resources management system', 'HR', 'HR Department'),
('Olympus Platform', 'Main business application platform', 'Platform', 'Development Team');

INSERT INTO tickets (title, description, status, priority, category, product_id, requester_email, requester_name) VALUES
('Email server down', 'Corporate email server is not responding', 'open', 'high', 'Incident', 1, 'user@calpion.com', 'Office User'),
('Database performance issue', 'Customer database queries running very slowly', 'in_progress', 'medium', 'Performance', 2, 'sales@calpion.com', 'Sales Manager'),
('Password reset needed', 'User cannot access financial system', 'resolved', 'low', 'Access', 3, 'finance@calpion.com', 'Finance User'),
('Network connectivity', 'WiFi dropping connections frequently', 'open', 'medium', 'Network', 4, 'support@calpion.com', 'Support Team'),
('Olympus Login Issue', 'Cannot login to Olympus platform', 'open', 'high', 'Access', 6, 'dev@calpion.com', 'Developer');

INSERT INTO changes (title, description, status, priority, category, risk_level, requested_by) VALUES
('Antivirus software update', 'Deploy latest antivirus definitions to all workstations', 'pending', 'medium', 'Security', 'low', 'IT Security Team'),
('Network firewall upgrade', 'Apply critical security patches to main firewall', 'approved', 'high', 'Infrastructure', 'medium', 'Network Administrator'),
('Email server maintenance', 'Scheduled maintenance window for email server cluster', 'scheduled', 'high', 'Maintenance', 'high', 'IT Operations'),
('Database backup procedure', 'Implement new automated backup strategy', 'pending', 'medium', 'System', 'low', 'Database Administrator');

INSERT INTO settings (key, value) VALUES
('email_provider', 'sendgrid'),
('email_from', 'no-reply@calpion.com'),
('sendgrid_api_key', ''),
('smtp_host', ''),
('smtp_port', '587'),
('smtp_user', ''),
('smtp_pass', ''),
('sla_response_low', '24'),
('sla_response_medium', '8'),
('sla_response_high', '4'),
('sla_response_critical', '1');
EOF

echo ""
echo "2. To complete the deployment, we need to copy your actual application files."
echo "   Please run these commands to copy files from your Replit project:"
echo ""
echo "   # Copy application source code"
echo "   scp -r ./client/ root@98.81.235.7:/opt/itservicedesk/"
echo "   scp -r ./server/ root@98.81.235.7:/opt/itservicedesk/"
echo "   scp -r ./shared/ root@98.81.235.7:/opt/itservicedesk/"
echo "   scp ./package*.json root@98.81.235.7:/opt/itservicedesk/"
echo "   scp ./tsconfig.json root@98.81.235.7:/opt/itservicedesk/"
echo "   scp ./tailwind.config.ts root@98.81.235.7:/opt/itservicedesk/"
echo "   scp ./postcss.config.js root@98.81.235.7:/opt/itservicedesk/"
echo "   scp ./vite.config.ts root@98.81.235.7:/opt/itservicedesk/"
echo "   scp ./drizzle.config.ts root@98.81.235.7:/opt/itservicedesk/"
echo ""
echo "   # Then build and start the real application:"
echo "   cd /opt/itservicedesk"
echo "   sudo docker compose up --build -d"
echo ""
echo "This will deploy your ACTUAL IT Service Desk with:"
echo "- React frontend with all components and styling"
echo "- Express backend with all API endpoints"
echo "- Drizzle ORM with PostgreSQL"
echo "- File upload capabilities"
echo "- Email notifications"
echo "- Complete ticket and change management"
echo "- User authentication and role management"