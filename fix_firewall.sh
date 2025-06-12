#!/bin/bash

# Fix Firewall and Network Access
echo "Fixing firewall configuration for external access..."

# Check current firewall status
echo "Current UFW status:"
sudo ufw status

# Reset and configure firewall properly
echo "Configuring firewall rules..."
sudo ufw --force reset
sudo ufw allow OpenSSH
sudo ufw allow 22/tcp
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "New firewall status:"
sudo ufw status verbose

# Check if application is running on correct interface
echo "Checking application binding..."
netstat -tlnp | grep :5000

# Check PM2 process
echo "PM2 status:"
pm2 status

# Check application logs
echo "Recent application logs:"
pm2 logs servicedesk --lines 5

# Test local connectivity
echo "Testing local connectivity..."
curl -I http://localhost:5000 || echo "Local connection failed"

# Check AWS security group (if applicable)
echo "If this is an AWS instance, ensure Security Group allows:"
echo "- Port 5000 (Custom TCP) from 0.0.0.0/0"
echo "- Port 22 (SSH) from your IP"
echo "- Port 80 (HTTP) from 0.0.0.0/0 (if using Nginx)"

echo "Firewall configuration complete."