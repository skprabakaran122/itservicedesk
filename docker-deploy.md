# Docker Deployment Guide

## Quick Start

After making changes to your IT Service Desk application, follow these steps to run it in Docker:

### 1. Build and Run with Docker Compose
```bash
# Build and start all services
docker-compose up --build -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### 2. Access the Application
- **Main Application**: http://localhost:5000
- **Database**: localhost:5432 (if needed for external tools)

### 3. Default Login Credentials
- **Admin**: `john.doe` / `password123`
- **Test Admin**: `test.admin` / `password123`
- **Regular User**: `test.user` / `password123`

## Configuration

### Environment Variables
Edit `docker-compose.yml` to configure:

```yaml
environment:
  NODE_ENV: production
  DATABASE_URL: postgresql://postgres:password123@postgres:5432/servicedesk
  PORT: 5000
  SENDGRID_API_KEY: your_sendgrid_key_here  # Uncomment and add your key
```

### Database
- PostgreSQL runs in a separate container
- Data persists in Docker volume `postgres_data`
- Initial setup runs automatically from `init-db.sql`

### File Uploads
- Uploads directory is mounted as volume
- Files persist between container restarts

## Development Workflow

1. **Make Changes**: Edit your code in Replit
2. **Test Locally**: Use the Replit environment to test
3. **Deploy with Docker**: Run `docker-compose up --build` to deploy

## Production Considerations

### Security
- Change default database password in `docker-compose.yml`
- Configure proper SSL certificates for HTTPS
- Set secure environment variables

### Scaling
- Use Docker Swarm or Kubernetes for production scaling
- Consider separate database server for high availability
- Implement proper backup strategy for PostgreSQL data

### Monitoring
- Health checks are configured for all services
- Use `docker-compose logs` to monitor application logs
- Consider adding monitoring tools like Prometheus/Grafana

## Troubleshooting

### Container Won't Start
```bash
# Check container status
docker-compose ps

# View detailed logs
docker-compose logs app
docker-compose logs postgres
```

### Database Connection Issues
```bash
# Test database connectivity
docker-compose exec postgres psql -U postgres -d servicedesk -c "SELECT 1;"
```

### Reset Everything
```bash
# Remove containers and volumes
docker-compose down -v
docker-compose up --build
```