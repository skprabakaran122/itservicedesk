# Calpion IT Service Desk

A production-ready IT Service Desk application designed for comprehensive ticket management, change requests, and automated workflows. Built with modern web technologies and optimized for Ubuntu server deployment.

## Core Features

- **Ticket Management**: Complete lifecycle management with SLA tracking
- **Change Management**: Multi-level approval workflows with email notifications
- **User Management**: Role-based access control with department organization
- **Product Catalog**: IT services and hardware management
- **Email Integration**: SendGrid and SMTP support with professional templates
- **Dashboard Analytics**: Real-time metrics and performance monitoring
- **Approval Routing**: Automated workflows based on risk assessment

## Architecture

- **Frontend**: React 18 with TypeScript, Tailwind CSS, shadcn/ui components
- **Backend**: Node.js with Express, production-ready server architecture
- **Database**: PostgreSQL with Drizzle ORM and comprehensive schema
- **Authentication**: Session-based with secure cookie management
- **Process Management**: PM2 with Ubuntu-optimized configurations
- **Email Service**: Dual provider support (SendGrid/SMTP) with fallback

## Quick Deployment

### Ubuntu Server (Recommended)
```bash
cd /var/www/itservicedesk
sudo bash deploy-ubuntu-compatible.sh
```

### Minimal Clean Build
```bash
cd /var/www/itservicedesk  
sudo bash clean-build.sh
```

## Development Workflow

### PM2 Development Commands
```bash
./dev-pm2.sh start      # Start development server
./dev-pm2.sh logs       # View live logs
./dev-pm2.sh status     # Check server status
./dev-pm2.sh test-auth  # Test authentication
```

### Database Setup
```bash
./init-dev-environment.sh    # Initialize development database
```

## Production Configuration

### Essential Files
- **server.js** - Production Node.js server
- **ecosystem.config.cjs** - PM2 production configuration
- **deploy-ubuntu-compatible.sh** - Complete deployment script
- **DEPLOYMENT.md** - Comprehensive deployment guide

### Default Access
- **admin/password123** - System Administrator
- **support/password123** - Support Technician
- **manager/password123** - IT Manager

### Email Configuration
1. Update SendGrid API key in admin console
2. Whitelist server IP address in SendGrid account
3. Alternative: Configure SMTP in email settings

## System Requirements

- **Server**: Ubuntu 20.04+ with Node.js 20.x
- **Database**: PostgreSQL 12+ with trust authentication
- **Process Manager**: PM2 for production deployment
- **Reverse Proxy**: Nginx for HTTPS and load balancing

## Production Monitoring

```bash
pm2 status                    # Application status
pm2 logs servicedesk          # Application logs
curl /api/health              # Health check endpoint
```

## Security Features

- Session-based authentication with secure cookies
- Input validation and sanitization
- SQL injection prevention via ORM
- Role-based access control
- HTTPS support with SSL certificates
- File upload restrictions and validation

## Support

Access the application health endpoint at `/api/health` for system status.
Review PM2 logs for troubleshooting deployment issues.
Check email configuration via admin console for notification setup.