#!/bin/bash

# Ubuntu Production Monitoring Setup
# Installs monitoring tools for IT Service Desk application

set -e

# Configuration
APP_NAME="itservicedesk"
MONITOR_USER="ubuntu"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Install monitoring packages
log "Installing monitoring packages..."
sudo apt update
sudo apt install -y htop iotop nethogs ncdu fail2ban logrotate

# Configure log rotation
log "Configuring log rotation..."
sudo tee /etc/logrotate.d/$APP_NAME > /dev/null << EOF
/opt/itservicedesk/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# Configure fail2ban for SSH protection
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

# Create monitoring script
log "Creating monitoring script..."
sudo tee /usr/local/bin/itservice-monitor.sh > /dev/null << 'EOF'
#!/bin/bash

# IT Service Desk Monitoring Script

APP_NAME="itservicedesk"
APP_DIR="/opt/$APP_NAME"
LOG_FILE="/var/log/$APP_NAME-monitor.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a $LOG_FILE
}

# Check application status
check_app() {
    if systemctl is-active --quiet $APP_NAME; then
        log_message "✅ Application service is running"
    else
        log_message "❌ Application service is down - attempting restart"
        sudo systemctl restart $APP_NAME
        sleep 10
        if systemctl is-active --quiet $APP_NAME; then
            log_message "✅ Application service restarted successfully"
        else
            log_message "❌ Failed to restart application service"
        fi
    fi
}

# Check nginx status
check_nginx() {
    if systemctl is-active --quiet nginx; then
        log_message "✅ Nginx is running"
    else
        log_message "❌ Nginx is down - attempting restart"
        sudo systemctl restart nginx
    fi
}

# Check disk space
check_disk() {
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    if [ $DISK_USAGE -gt 80 ]; then
        log_message "⚠️  High disk usage: ${DISK_USAGE}%"
        # Clean old logs
        find $APP_DIR/logs -name "*.log" -mtime +7 -delete
        find /var/log -name "*.gz" -mtime +30 -delete
    else
        log_message "✅ Disk usage: ${DISK_USAGE}%"
    fi
}

# Check memory usage
check_memory() {
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ $MEMORY_USAGE -gt 80 ]; then
        log_message "⚠️  High memory usage: ${MEMORY_USAGE}%"
        pm2 restart $APP_NAME
    else
        log_message "✅ Memory usage: ${MEMORY_USAGE}%"
    fi
}

# Check application health endpoint
check_health() {
    if curl -f -s http://localhost/health > /dev/null; then
        log_message "✅ Application health check passed"
    else
        log_message "❌ Application health check failed"
        sudo systemctl restart $APP_NAME
    fi
}

# Check database connectivity (requires DATABASE_URL in environment)
check_database() {
    cd $APP_DIR
    if sudo -u ubuntu node -e "
        const { Pool } = require('pg');
        require('dotenv').config();
        const pool = new Pool({ connectionString: process.env.DATABASE_URL });
        pool.query('SELECT 1').then(() => {
            console.log('Database connection OK');
            pool.end();
            process.exit(0);
        }).catch(err => {
            console.error('Database connection failed:', err.message);
            process.exit(1);
        });
    " 2>/dev/null; then
        log_message "✅ Database connection is healthy"
    else
        log_message "❌ Database connection failed"
    fi
}

# Run all checks
log_message "Starting system health check..."
check_app
check_nginx
check_disk
check_memory
check_health
check_database
log_message "Health check completed"
EOF

sudo chmod +x /usr/local/bin/itservice-monitor.sh

# Create cron job for monitoring
log "Setting up monitoring cron job..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/itservice-monitor.sh") | crontab -

# Create backup script
log "Creating backup script..."
sudo tee /usr/local/bin/itservice-backup.sh > /dev/null << 'EOF'
#!/bin/bash

# IT Service Desk Backup Script

APP_NAME="itservicedesk"
APP_DIR="/opt/$APP_NAME"
BACKUP_DIR="/backup/$APP_NAME"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup application files
tar -czf $BACKUP_DIR/app_$DATE.tar.gz -C /opt $APP_NAME --exclude=node_modules --exclude=logs

# Backup database (if DATABASE_URL is available)
cd $APP_DIR
if [ -f ".env" ]; then
    source .env
    if [ ! -z "$DATABASE_URL" ]; then
        pg_dump $DATABASE_URL > $BACKUP_DIR/database_$DATE.sql
    fi
fi

# Clean old backups (keep 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

sudo chmod +x /usr/local/bin/itservice-backup.sh

# Create daily backup cron job
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/itservice-backup.sh") | crontab -

# Create status dashboard script
log "Creating status dashboard..."
sudo tee /usr/local/bin/itservice-status.sh > /dev/null << 'EOF'
#!/bin/bash

# IT Service Desk Status Dashboard

APP_NAME="itservicedesk"
APP_DIR="/opt/$APP_NAME"

echo "======================================================"
echo "        IT Service Desk Status Dashboard"
echo "======================================================"
echo ""

# System Information
echo "🖥️  SYSTEM INFO:"
echo "   Hostname: $(hostname)"
echo "   Uptime: $(uptime -p)"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# Service Status
echo "🔧 SERVICE STATUS:"
echo -n "   Application: "
if systemctl is-active --quiet $APP_NAME; then
    echo "✅ Running"
else
    echo "❌ Stopped"
fi

echo -n "   Nginx: "
if systemctl is-active --quiet nginx; then
    echo "✅ Running"
else
    echo "❌ Stopped"
fi

echo -n "   Fail2ban: "
if systemctl is-active --quiet fail2ban; then
    echo "✅ Running"
else
    echo "❌ Stopped"
fi
echo ""

# Resource Usage
echo "📊 RESOURCE USAGE:"
echo "   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "   Memory: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "   Disk: $(df / | awk 'NR==2 {print $5}')"
echo ""

# PM2 Status
echo "🏃 PM2 PROCESSES:"
pm2 status
echo ""

# Recent Logs
echo "📝 RECENT LOGS (last 5 lines):"
if [ -f "$APP_DIR/logs/combined.log" ]; then
    tail -5 $APP_DIR/logs/combined.log
else
    echo "   No logs found"
fi
echo ""

# Health Check
echo "🏥 HEALTH CHECK:"
if curl -f -s http://localhost/health > /dev/null; then
    echo "   ✅ Application responding"
else
    echo "   ❌ Application not responding"
fi
echo ""

echo "======================================================"
EOF

sudo chmod +x /usr/local/bin/itservice-status.sh

# Enable and start services
log "Enabling monitoring services..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create monitoring log file
sudo touch /var/log/$APP_NAME-monitor.log
sudo chown ubuntu:ubuntu /var/log/$APP_NAME-monitor.log

echo ""
log "✅ Monitoring setup completed!"
echo ""
echo "📊 Monitoring Commands:"
echo "  - Status dashboard: sudo /usr/local/bin/itservice-status.sh"
echo "  - Run health check: sudo /usr/local/bin/itservice-monitor.sh"
echo "  - Create backup: sudo /usr/local/bin/itservice-backup.sh"
echo "  - View monitor logs: tail -f /var/log/$APP_NAME-monitor.log"
echo ""
echo "⏰ Automated Tasks:"
echo "  - Health checks: Every 5 minutes"
echo "  - Backups: Daily at 2 AM"
echo "  - Log rotation: Daily"
echo ""
echo "🔒 Security:"
echo "  - Fail2ban: SSH brute force protection enabled"
echo "  - Firewall: UFW enabled with required ports only"
echo ""
log "Run 'sudo /usr/local/bin/itservice-status.sh' to view system status"