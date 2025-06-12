#!/bin/bash

# Complete Firewall and AWS Security Group Fix
echo "=== Complete Network Access Fix ==="

# 1. Fix UFW firewall
echo "Step 1: Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 22/tcp
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "UFW Status:"
sudo ufw status verbose

# 2. Check iptables (sometimes conflicts with UFW)
echo "Step 2: Checking iptables..."
sudo iptables -L INPUT -n | grep 5000 || echo "No iptables rule for port 5000"

# 3. Verify application is bound to all interfaces
echo "Step 3: Checking application binding..."
netstat -tlnp | grep :5000
ss -tlnp | grep :5000

# 4. Test local connectivity
echo "Step 4: Testing local connectivity..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 && echo " - Local HTTP works" || echo " - Local HTTP failed"
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000 && echo " - Localhost HTTP works" || echo " - Localhost HTTP failed"

# 5. Check if systemd-resolved is blocking
echo "Step 5: Checking systemd-resolved..."
sudo systemctl status systemd-resolved --no-pager -l

# 6. Restart application to ensure proper binding
echo "Step 6: Restarting application..."
pm2 restart servicedesk
sleep 3
pm2 status servicedesk

# 7. Final connectivity test
echo "Step 7: Final tests..."
netstat -tlnp | grep :5000

echo ""
echo "=== Network Configuration Complete ==="
echo ""
echo "If you're using AWS EC2, ensure Security Group allows:"
echo "  - Type: Custom TCP"
echo "  - Port: 5000" 
echo "  - Source: 0.0.0.0/0 (Anywhere)"
echo ""
echo "If you're using a VPS, contact your provider to ensure:"
echo "  - Port 5000 is not blocked by provider firewall"
echo "  - No DDoS protection blocking the port"
echo ""
echo "Application should now be accessible at: http://54.160.177.174:5000"