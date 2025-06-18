#!/bin/bash

echo "Fixing User Authentication - Creating Valid User"
echo "=============================================="

cd /var/www/itservicedesk

# Stop the application to avoid conflicts
sudo -u ubuntu pm2 stop servicedesk

# Set PostgreSQL password
export PGPASSWORD=servicedesk123

echo "Current users in database:"
psql -h localhost -U servicedesk -d servicedesk -c "SELECT id, username, email, role FROM users;"

echo ""
echo "Dropping existing john.doe user and recreating with correct password..."

# Remove existing user
psql -h localhost -U servicedesk -d servicedesk -c "DELETE FROM users WHERE username = 'john.doe';"

# Create user with correct bcrypt hash for 'password123'
# This is the bcrypt hash for 'password123' with salt rounds 10
psql -h localhost -U servicedesk -d servicedesk -c "
INSERT INTO users (username, email, password, role, first_name, last_name, department, phone, is_active, created_at, updated_at) 
VALUES (
  'john.doe', 
  'john.doe@calpion.com', 
  '\$2b\$10\$e0MYzXyjpJS7Pd2ALDLNPeaP5Bz4pQH1JOq9lEJP4s.2LdJSJ4n4q',
  'admin',
  'John',
  'Doe', 
  'IT', 
  '555-0123',
  true,
  NOW(),
  NOW()
);"

# Also create a test user with a simpler password 'test123'
psql -h localhost -U servicedesk -d servicedesk -c "
INSERT INTO users (username, email, password, role, first_name, last_name, department, phone, is_active, created_at, updated_at) 
VALUES (
  'testuser', 
  'test@calpion.com', 
  '\$2b\$10\$nOUIs5kJ7naTuTFkBy1veuK0kSCbYAX/g.DXDikAsua/KFQO5OW6O',
  'user',
  'Test',
  'User', 
  'Support', 
  '555-0124',
  true,
  NOW(),
  NOW()
);"

echo ""
echo "Updated users in database:"
psql -h localhost -U servicedesk -d servicedesk -c "SELECT id, username, email, role, first_name, last_name FROM users;"

# Restart the application
sudo -u ubuntu pm2 start servicedesk

sleep 5

echo ""
echo "Testing login with updated credentials..."

# Test with john.doe / password123
echo "Testing john.doe login..."
curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' \
  -w "Response Code: %{http_code}\n"

echo ""
echo "Testing testuser login..."
curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}' \
  -w "Response Code: %{http_code}\n"

echo ""
echo "Application status:"
sudo -u ubuntu pm2 status

echo ""
echo "Updated login credentials:"
echo "========================================="
echo "Administrator Account:"
echo "Username: john.doe"
echo "Password: password123"
echo ""
echo "Test User Account:"
echo "Username: testuser" 
echo "Password: test123"
echo ""
echo "Access your IT Service Desk at: https://98.81.235.7"