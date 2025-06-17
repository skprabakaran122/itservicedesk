# Manual HTTPS Deployment Steps

## Upload Files to Server

1. **Download the update package**:
   - Download `https-update.tar.gz` from this project

2. **Upload to your server**:
   ```bash
   # From your local machine with the PPK key:
   scp -i service-desk.ppk https-update.tar.gz ubuntu@54.160.177.174:/home/ubuntu/servicedesk/
   ```

3. **Connect to server and extract**:
   ```bash
   ssh -i service-desk.ppk ubuntu@54.160.177.174
   cd /home/ubuntu/servicedesk
   tar -xzf https-update.tar.gz
   rm https-update.tar.gz
   ```

## Setup HTTPS on Server

4. **Install dependencies**:
   ```bash
   npm install
   ```

5. **Generate SSL certificates**:
   ```bash
   mkdir -p ssl
   openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes \
       -subj "/C=US/ST=State/L=City/O=Calpion/OU=IT/CN=54.160.177.174"
   chmod 600 ssl/key.pem
   chmod 644 ssl/cert.pem
   ```

6. **Update firewall**:
   ```bash
   sudo ufw allow 5001/tcp
   ```

7. **Push database changes**:
   ```bash
   npm run db:push
   ```

8. **Restart application**:
   ```bash
   pm2 restart calpion-service-desk
   pm2 status
   ```

## Access Your HTTPS Application

- **HTTPS**: https://54.160.177.174:5001
- **HTTP**: http://54.160.177.174:5000 (redirects to HTTPS)

## Verify HTTPS is Working

```bash
# Check server logs
pm2 logs calpion-service-desk --lines 10

# Test HTTPS endpoint
curl -k https://54.160.177.174:5001

# Test HTTP redirect
curl -I http://54.160.177.174:5000
```

Your IT Service Desk will now have full HTTPS encryption with automatic HTTP redirection.