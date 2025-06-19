#!/bin/bash

# Fix Docker build issues and redeploy
set -e

echo "=== Fixing Docker Build Issues ==="

cd /opt/itservicedesk

# Stop existing containers
sudo docker compose down

# Fix Dockerfile to use npm install instead of npm ci
sudo tee Dockerfile > /dev/null << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Copy package files
COPY package*.json ./

# Install dependencies using npm install (not ci)
RUN npm install --production

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

# Remove version from docker-compose.yml (it's obsolete)
sudo tee docker-compose.yml > /dev/null << 'EOF'
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

# Clean up any previous failed builds
sudo docker system prune -f

# Rebuild and start
echo "Rebuilding containers..."
sudo docker compose up --build -d

echo "Waiting for services to start..."
sleep 30

# Check status
echo "Container status:"
sudo docker compose ps

echo "Testing health endpoints:"
curl -f http://localhost:3000/health 2>/dev/null && echo "✓ App health check passed" || echo "App still starting..."
curl -f http://localhost:80/ 2>/dev/null && echo "✓ Nginx proxy working" || echo "Nginx still starting..."

echo ""
echo "=== Docker Build Fixed ==="
echo "Access your IT Service Desk at: http://98.81.235.7"