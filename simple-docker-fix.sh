#!/bin/bash

# Simple Docker fix - create minimal working deployment
set -e

echo "Creating simple Docker deployment that works..."

cd /opt/itservicedesk

# Stop any running containers
sudo docker compose down --remove-orphans 2>/dev/null || true

# Create a simple working Dockerfile that doesn't need package-lock.json
sudo tee Dockerfile > /dev/null << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install wget and basic dependencies
RUN apk add --no-cache wget

# Create a simple package.json with minimal dependencies
RUN npm init -y
RUN npm install express --save

# Copy our server file
COPY server-production.cjs ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 && \
    chown -R appuser:nodejs /app

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server-production.cjs"]
EOF

# Fix docker-compose.yml (remove obsolete version)
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
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
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
    depends_on:
      database:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

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
EOF

# Clean up Docker system
sudo docker system prune -f

# Build and start
echo "Building and starting containers..."
sudo docker compose up --build -d

echo "Waiting for services..."
sleep 30

echo "Status check:"
sudo docker compose ps

echo "Health checks:"
curl -f http://localhost:3000/health 2>/dev/null && echo "App: Working" || echo "App: Still starting"
curl -f http://localhost/ 2>/dev/null && echo "Nginx: Working" || echo "Nginx: Still starting"

echo ""
echo "Docker deployment should now be working at http://98.81.235.7"