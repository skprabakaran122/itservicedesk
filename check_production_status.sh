#!/bin/bash

# Check production server status and accessibility

echo "=== Production Server Status Check ==="

cd /var/www/servicedesk

echo "1. Systemd service status:"
sudo systemctl status servicedesk.service --no-pager -l

echo ""
echo "2. Application process check:"
ps aux | grep tsx | grep -v grep

echo ""
echo "3. Port connectivity test:"
netstat -tlnp | grep :5000 || ss -tlnp | grep :5000

echo ""
echo "4. HTTP response test:"
curl -v http://localhost:5000 2>&1 | head -20

echo ""
echo "5. Recent application logs:"
sudo journalctl -u servicedesk.service --no-pager -n 10

echo ""
echo "6. Server external IP and network:"
curl -s ifconfig.me
echo ""
ip route | grep default

echo ""
echo "7. Firewall status:"
sudo ufw status || echo "UFW not configured"
iptables -L INPUT | grep 5000 || echo "No iptables rules for port 5000"

echo ""
echo "=== Recommendations ==="
echo "If accessible locally but not externally:"
echo "- Check cloud provider security groups"
echo "- Verify firewall allows port 5000"
echo "- Consider setting up Nginx reverse proxy"