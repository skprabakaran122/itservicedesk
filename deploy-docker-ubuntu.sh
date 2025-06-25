#!/bin/bash

# Docker on Ubuntu AWS Production Deployment
# Complete setup for IT Service Desk with Docker + RDS

set -e

# Configuration
APP_NAME="itservicedesk"
DOCKER_COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.prod"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Run as ubuntu user with sudo privileges."
fi

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
log "Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Add user to docker group
log "Adding user to docker group..."
sudo usermod -aG docker $USER

# Install Docker Compose
log "Installing Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Enable and start Docker
log "Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Install additional tools
log "Installing additional tools..."
sudo apt install -y nginx certbot python3-certbot-nginx htop fail2ban ufw

# Create application directory
log "Creating application directory..."
sudo mkdir -p /opt/$APP_NAME
sudo chown $USER:$USER /opt/$APP_NAME

# Copy application files
log "Setting up application files..."
cp -r . /opt/$APP_NAME/
cd /opt/$APP_NAME

# Create production environment file
log "Creating production environment configuration..."
cat > $ENV_FILE << EOF
# Production Environment Configuration
NODE_ENV=production
PORT=5000
HOST=0.0.0.0
DOCKER_ENV=true

# RDS Database Configuration
# IMPORTANT: Update these values with your actual RDS details
DATABASE_URL=postgresql://username:password@your-rds-endpoint.region.rds.amazonaws.com:5432/itservicedesk?sslmode=require
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_NAME=itservicedesk
DB_USER=your_db_username
DB_PASSWORD=your_db_password
DB_PORT=5432
DB_SSL_MODE=require

# Application Configuration
APP_PORT=5000
UPLOAD_DIR=/opt/$APP_NAME/uploads
SESSION_SECRET=$(openssl rand -base64 32)

# Email Configuration (Optional)
SENDGRID_API_KEY=your_sendgrid_api_key
EMAIL_FROM=no-reply@yourdomain.com

# AWS Configuration (if needed)
AWS_REGION=us-east-1
EOF

warn "Please edit /opt/$APP_NAME/$ENV_FILE with your actual RDS credentials!"

# Create Docker Compose configuration for Ubuntu production
log "Creating Docker Compose configuration..."
cat > docker-compose.ubuntu.yml << 'EOF'
version: '3.8'

services:
  app:
    build: 
      context: .
      dockerfile: Dockerfile
    container_name: itservice_app
    restart: unless-stopped
    ports:
      - "127.0.0.1:5000:5000"  # Bind to localhost only (nginx proxy)
    environment:
      - NODE_ENV=production
      - PORT=5000
      - HOST=0.0.0.0
      - DOCKER_ENV=true
    env_file:
      - .env.prod
    volumes:
      - ./uploads:/app/uploads:rw
      - ./logs:/app/logs:rw
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

# No database service - using external RDS
EOF

# Create nginx configuration
log "Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; img-src 'self' data: https:; font-src 'self' data: https:;" always;

    # File upload size
    client_max_body_size 10M;

    # Docker container proxy
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }

    # Direct file serving for uploads
    location /uploads {
        alias /opt/itservicedesk/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable nginx site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
sudo nginx -t

# Configure firewall
log "Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'

# Configure fail2ban
log "Configuring fail2ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# Create systemd service for Docker Compose
log "Creating systemd service..."
sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null << EOF
[Unit]
Description=IT Service Desk Docker Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/$APP_NAME
ExecStart=/usr/local/bin/docker-compose -f docker-compose.ubuntu.yml --env-file $ENV_FILE up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.ubuntu.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Create management scripts
log "Creating management scripts..."

# Docker management script
cat > /opt/$APP_NAME/manage.sh << 'EOF'
#!/bin/bash

APP_NAME="itservicedesk"
COMPOSE_FILE="docker-compose.ubuntu.yml"
ENV_FILE=".env.prod"

case "$1" in
    start)
        echo "Starting IT Service Desk..."
        docker-compose -f $COMPOSE_FILE --env-file $ENV_FILE up -d
        ;;
    stop)
        echo "Stopping IT Service Desk..."
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "Restarting IT Service Desk..."
        docker-compose -f $COMPOSE_FILE down
        docker-compose -f $COMPOSE_FILE --env-file $ENV_FILE up -d
        ;;
    rebuild)
        echo "Rebuilding and restarting IT Service Desk..."
        docker-compose -f $COMPOSE_FILE down
        docker-compose -f $COMPOSE_FILE --env-file $ENV_FILE up -d --build
        ;;
    logs)
        docker-compose -f $COMPOSE_FILE logs -f
        ;;
    status)
        docker-compose -f $COMPOSE_FILE ps
        docker stats --no-stream
        ;;
    shell)
        docker-compose -f $COMPOSE_FILE exec app sh
        ;;
    migrate)
        echo "Running database migrations..."
        docker-compose -f $COMPOSE_FILE exec app node migrations/run_migrations.cjs
        ;;
    backup)
        echo "Creating backup..."
        docker-compose -f $COMPOSE_FILE exec app node -e "
        require('dotenv').config();
        const { exec } = require('child_process');
        const date = new Date().toISOString().split('T')[0];
        exec(\`pg_dump \${process.env.DATABASE_URL} > /app/backup-\${date}.sql\`, (err, stdout, stderr) => {
          if (err) console.error(err);
          else console.log('Backup created: backup-' + date + '.sql');
        });
        "
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|rebuild|logs|status|shell|migrate|backup}"
        exit 1
        ;;
esac
EOF

chmod +x /opt/$APP_NAME/manage.sh

# Create monitoring script
cat > /opt/$APP_NAME/monitor.sh << 'EOF'
#!/bin/bash

APP_NAME="itservicedesk"
COMPOSE_FILE="docker-compose.ubuntu.yml"

echo "======================================================"
echo "        IT Service Desk Status Dashboard"
echo "======================================================"
echo ""

# System Information
echo "🖥️  SYSTEM INFO:"
echo "   Hostname: $(hostname)"
echo "   Uptime: $(uptime -p)"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "   Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
echo ""

# Container Status
echo "🐳 CONTAINER STATUS:"
docker-compose -f $COMPOSE_FILE ps
echo ""

# Resource Usage
echo "📊 RESOURCE USAGE:"
echo "   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "   Memory: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "   Disk: $(df / | awk 'NR==2 {print $5}')"
echo ""

# Docker Stats
echo "🏃 CONTAINER STATS:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo ""

# Health Check
echo "🏥 HEALTH CHECK:"
if curl -f -s http://localhost/health > /dev/null; then
    echo "   ✅ Application responding"
else
    echo "   ❌ Application not responding"
fi
echo ""

# Recent Logs
echo "📝 RECENT LOGS:"
docker-compose -f $COMPOSE_FILE logs --tail=5 app
echo ""

echo "======================================================"
EOF

chmod +x /opt/$APP_NAME/monitor.sh

# Enable services
log "Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl enable nginx
sudo systemctl enable fail2ban
sudo systemctl enable $APP_NAME

# Start services
log "Starting services..."
sudo systemctl start nginx
sudo systemctl start fail2ban

# Test Docker installation
log "Testing Docker installation..."
if docker run hello-world > /dev/null 2>&1; then
    info "Docker installation successful"
else
    warn "Docker test failed - you may need to log out and back in"
fi

# Create log directory
mkdir -p /opt/$APP_NAME/logs
mkdir -p /opt/$APP_NAME/uploads

# Set up log rotation
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/$APP_NAME > /dev/null << EOF
/opt/$APP_NAME/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        docker-compose -f /opt/$APP_NAME/docker-compose.ubuntu.yml exec app pm2 reloadLogs || true
    endscript
}
EOF

# Final setup
log "Performing final setup..."
cd /opt/$APP_NAME

# Show completion message
echo ""
log "✅ Docker Ubuntu deployment setup completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Edit /opt/$APP_NAME/$ENV_FILE with your RDS credentials"
echo "2. Start the application: sudo systemctl start $APP_NAME"
echo "3. Check status: /opt/$APP_NAME/monitor.sh"
echo "4. Run migrations: /opt/$APP_NAME/manage.sh migrate"
echo ""
echo "🐳 Docker Management Commands:"
echo "  - Start: /opt/$APP_NAME/manage.sh start"
echo "  - Stop: /opt/$APP_NAME/manage.sh stop"
echo "  - Restart: /opt/$APP_NAME/manage.sh restart"
echo "  - Rebuild: /opt/$APP_NAME/manage.sh rebuild"
echo "  - View logs: /opt/$APP_NAME/manage.sh logs"
echo "  - Status: /opt/$APP_NAME/manage.sh status"
echo "  - Shell access: /opt/$APP_NAME/manage.sh shell"
echo ""
echo "🌐 Application URLs:"
echo "  - HTTP: http://$(curl -s ifconfig.me)"
echo "  - Local: http://localhost"
echo "  - Health: http://localhost/health"
echo ""
echo "🔧 System Services:"
echo "  - Application: sudo systemctl {start|stop|restart} $APP_NAME"
echo "  - Nginx: sudo systemctl {start|stop|restart} nginx"
echo "  - Docker: sudo systemctl {start|stop|restart} docker"
echo ""
warn "Remember to configure your RDS database connection!"
warn "You may need to log out and back in for Docker group membership to take effect"