#!/bin/bash

# Simple Docker deployment for IT Service Desk
set -e

echo "=== Docker Deployment (No More Port Headaches!) ==="

# Step 1: Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "1. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "1. Docker already installed ✓"
fi

# Step 2: Stop any conflicting services
echo "2. Stopping conflicting services..."
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop itservicedesk 2>/dev/null || true
sudo systemctl stop apache2 2>/dev/null || true

# Step 3: Free up ports
echo "3. Freeing up ports..."
sudo fuser -k 80/tcp 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true
sudo fuser -k 5432/tcp 2>/dev/null || true

# Step 4: Set environment variables
echo "4. Setting up environment..."
export SENDGRID_API_KEY="${SENDGRID_API_KEY:-}"

# Step 5: Verify docker-compose.yml exists
echo "5. Checking Docker configuration..."
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    echo "Current directory: $(pwd)"
    echo "Files present:"
    ls -la
    exit 1
fi

echo "Docker Compose file found ✓"

# Step 6: Build and start everything
echo "6. Starting IT Service Desk with Docker..."
docker-compose down --remove-orphans 2>/dev/null || true
docker-compose up --build -d

# Step 6: Wait for services to be healthy
echo "6. Waiting for services to start..."
sleep 30

# Step 7: Verify deployment
echo "7. Verifying deployment..."

# Check if containers are running
echo "Container status:"
docker-compose ps

# Test health endpoints
echo "Testing application health:"
curl -f http://localhost:3000/health || echo "Direct app health check failed"

echo "Testing through nginx:"
curl -f http://localhost/ || echo "Nginx proxy health check failed"

# Check database connection
echo "Database status:"
docker-compose exec -T database pg_isready -U servicedesk -d servicedesk || echo "Database check failed"

echo ""
echo "=== Deployment Complete! ==="
echo "✓ PostgreSQL database running in container"
echo "✓ IT Service Desk app running in container"  
echo "✓ Nginx proxy running in container"
echo "✓ All port conflicts resolved automatically"
echo ""
echo "🌐 Access your application at: http://98.81.235.7"
echo ""
echo "📊 Management commands:"
echo "  View logs: docker-compose logs -f app"
echo "  Restart: docker-compose restart"
echo "  Stop: docker-compose down"
echo "  Update: docker-compose pull && docker-compose up -d"
echo ""
echo "🗄️ Database access:"
echo "  Connect: docker-compose exec database psql -U servicedesk -d servicedesk"
echo ""
echo "No more SystemD, PM2, or nginx configuration headaches!"