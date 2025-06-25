# Docker Deployment Guide

## Quick Start

### Development Environment
```bash
# Start all services (database + application)
docker-compose up --build

# Access the application
http://localhost:5000
```

### Production Environment
```bash
# Copy environment configuration
cp .env.example .env.prod

# Edit production settings
nano .env.prod

# Start production services
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

## Docker Configuration Changes

### Database Connection
- **Enhanced**: `server/db.ts` now supports Docker service names (`database:5432`)
- **SSL Handling**: Automatic SSL detection for development vs production
- **Environment Variables**: Fallback configuration for flexible deployment

### Server Configuration
- **Docker Detection**: Automatic environment detection via `DOCKER_ENV` flag
- **Network Binding**: Dynamic host binding (`0.0.0.0` for containers)
- **Health Checks**: `/health` endpoint for container monitoring
- **Logging**: Environment-aware logging (Docker/development/production)

### File Upload Handling
- **Volume Mounting**: Persistent file storage via Docker volumes
- **Directory Configuration**: Dynamic upload paths via `UPLOAD_DIR`
- **Permissions**: Proper file permissions for containerized environments

## Docker Services

### Application Service (`app`)
- **Image**: Multi-stage build with optimized production layer
- **Port**: 5000 (configurable via PORT environment variable)
- **Health Check**: Automated container health monitoring
- **Migrations**: Automatic database migration on startup
- **User**: Non-root user (appuser) for security

### Database Service (`database`)
- **Image**: PostgreSQL 16 Alpine
- **Port**: 5432 (configurable)
- **Data Persistence**: Named volume for data storage
- **Health Check**: PostgreSQL readiness verification

### Nginx Service (`nginx`) - Production Only
- **Reverse Proxy**: Load balancing and SSL termination
- **SSL Support**: Ready for certificate mounting
- **File Upload**: 10MB max upload size
- **Health Checks**: Automatic upstream monitoring

## Environment Variables

### Required Variables
```bash
# Database Configuration
DATABASE_URL=postgresql://postgres:password@database:5432/itservicedesk?sslmode=disable

# Application Configuration
NODE_ENV=production
PORT=5000
HOST=0.0.0.0
DOCKER_ENV=true

# File Storage
UPLOAD_DIR=/app/uploads
```

### Optional Variables
```bash
# Production Database Override
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=itservicedesk
DB_PORT=5432

# Application Settings
APP_PORT=5000
```

## Volume Mounts

### Application Volumes
- `./uploads:/app/uploads` - File upload persistence
- `./logs:/app/logs` - Application logs (production)

### Database Volumes
- `postgres_data:/var/lib/postgresql/data` - Database data persistence
- `./backups:/backups` - Database backup storage (production)

## Docker Commands

### Build and Start
```bash
# Development
docker-compose up --build -d

# Production
docker-compose -f docker-compose.prod.yml up --build -d
```

### Database Operations
```bash
# Run migrations manually
docker exec itservice_app node migrations/run_migrations.cjs

# Database backup
docker exec itservice_db_prod pg_dump -U postgres itservicedesk > backup.sql

# Restore database
docker exec -i itservice_db_prod psql -U postgres itservicedesk < backup.sql
```

### Monitoring
```bash
# View logs
docker-compose logs -f app
docker-compose logs -f database

# Health checks
curl http://localhost:5000/health

# Container status
docker-compose ps
```

### Maintenance
```bash
# Stop services
docker-compose down

# Remove volumes (WARNING: Data loss)
docker-compose down -v

# Update containers
docker-compose pull
docker-compose up --build -d
```

## Troubleshooting

### Common Issues

**Container Connection Issues**
- Check Docker network: `docker network ls`
- Verify service names in DATABASE_URL
- Ensure ports are not conflicting

**Database Connection Failed**
- Wait for database health check to pass
- Verify DATABASE_URL format
- Check database logs: `docker-compose logs database`

**File Upload Issues**
- Verify volume mounts are correct
- Check directory permissions in container
- Ensure UPLOAD_DIR is writable

**Migration Failures**
- Run migrations manually: `docker exec app node migrations/run_migrations.cjs`
- Check database connectivity
- Verify migration file syntax

### Debug Commands
```bash
# Enter application container
docker exec -it itservice_app sh

# Enter database container
docker exec -it itservice_db psql -U postgres itservicedesk

# Check container networking
docker inspect itservice_app | grep NetworkMode
```

## Security Considerations

### Container Security
- Non-root user execution (appuser:1001)
- Read-only file system where possible
- Minimal base image (Alpine Linux)
- Security scanning with health checks

### Network Security
- Container isolation via Docker networks
- No direct database exposure (internal networking)
- Nginx reverse proxy for production
- SSL/TLS termination at proxy level

### Data Security
- Volume encryption for sensitive data
- Secure environment variable handling
- Database password via Docker secrets (production)
- Regular security updates via base image updates