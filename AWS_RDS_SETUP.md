# AWS RDS Setup Guide

## RDS Instance Creation

### 1. Create PostgreSQL RDS Instance

```bash
# Via AWS CLI
aws rds create-db-instance \
    --db-instance-identifier itservice-prod \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 16.1 \
    --master-username admin \
    --master-user-password YourSecurePassword123 \
    --allocated-storage 20 \
    --storage-type gp2 \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --db-subnet-group-name default \
    --backup-retention-period 7 \
    --storage-encrypted \
    --multi-az false \
    --publicly-accessible true \
    --db-name itservicedesk
```

### 2. Security Group Configuration

```bash
# Create security group for RDS
aws ec2 create-security-group \
    --group-name itservice-rds-sg \
    --description "Security group for IT Service Desk RDS"

# Allow PostgreSQL access from application
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 5432 \
    --source-group sg-yyyyyyyyy  # Application security group
```

## Environment Configuration

### 1. Get RDS Endpoint
```bash
aws rds describe-db-instances \
    --db-instance-identifier itservice-prod \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

### 2. Update Environment Variables
```bash
# Copy RDS configuration template
cp .env.rds.example .env.rds

# Update with actual values
DATABASE_URL=postgresql://admin:YourSecurePassword123@itservice-prod.cluster-xyz.us-east-1.rds.amazonaws.com:5432/itservicedesk?sslmode=require
DB_HOST=itservice-prod.cluster-xyz.us-east-1.rds.amazonaws.com
DB_NAME=itservicedesk
DB_USER=admin
DB_PASSWORD=YourSecurePassword123
```

## Database Initialization

### 1. Run Initial Migrations
```bash
# Start application container with RDS connection
docker-compose -f docker-compose.rds.yml --env-file .env.rds up -d --build

# Check if migrations ran successfully
docker logs itservice_app_rds

# Run migrations manually if needed
docker exec itservice_app_rds node migrations/run_migrations.cjs
```

### 2. Verify Database Connection
```bash
# Test connection from container
docker exec itservice_app_rds node -e "
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
pool.query('SELECT version()').then(res => {
  console.log('PostgreSQL version:', res.rows[0].version);
  pool.end();
}).catch(err => console.error('Connection failed:', err));
"
```

## Performance Optimization

### 1. Connection Pooling
```javascript
// Already configured in server/db.ts
{
  max: 20,              // Maximum connections for RDS
  min: 2,               // Keep connections warm
  connectionTimeoutMillis: 30000,
  idleTimeoutMillis: 30000
}
```

### 2. RDS Parameter Group
```bash
# Create custom parameter group
aws rds create-db-parameter-group \
    --db-parameter-group-name itservice-pg16 \
    --db-parameter-group-family postgres16 \
    --description "Custom parameters for IT Service Desk"

# Optimize for application workload
aws rds modify-db-parameter-group \
    --db-parameter-group-name itservice-pg16 \
    --parameters "ParameterName=shared_preload_libraries,ParameterValue=pg_stat_statements,ApplyMethod=pending-reboot"
```

## Monitoring and Maintenance

### 1. CloudWatch Monitoring
```bash
# Enable enhanced monitoring
aws rds modify-db-instance \
    --db-instance-identifier itservice-prod \
    --monitoring-interval 60 \
    --monitoring-role-arn arn:aws:iam::account:role/rds-monitoring-role
```

### 2. Automated Backups
```bash
# Configure backup window
aws rds modify-db-instance \
    --db-instance-identifier itservice-prod \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "sun:04:00-sun:05:00"
```

### 3. Database Maintenance
```bash
# Create manual snapshot
aws rds create-db-snapshot \
    --db-instance-identifier itservice-prod \
    --db-snapshot-identifier itservice-manual-snapshot-$(date +%Y%m%d)

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier itservice-restored \
    --db-snapshot-identifier itservice-manual-snapshot-20250625
```

## Security Best Practices

### 1. Encryption
- **At Rest**: Storage encryption enabled during creation
- **In Transit**: SSL required (sslmode=require in connection string)
- **Credentials**: Use AWS Secrets Manager for production

### 2. Network Security
```bash
# Restrict access to specific IP ranges
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 5432 \
    --cidr 10.0.0.0/16  # VPC CIDR only
```

### 3. Database Users
```sql
-- Connect to RDS and create application user
CREATE USER app_user WITH PASSWORD 'SecureAppPassword123';
GRANT CONNECT ON DATABASE itservicedesk TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;
```

## Troubleshooting

### Connection Issues
```bash
# Test connectivity from EC2/container
telnet your-rds-endpoint.region.rds.amazonaws.com 5432

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Verify RDS status
aws rds describe-db-instances --db-instance-identifier itservice-prod
```

### Performance Issues
```sql
-- Check active connections
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- Monitor query performance
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;
```

### Backup and Recovery
```bash
# List available snapshots
aws rds describe-db-snapshots \
    --db-instance-identifier itservice-prod

# Point-in-time recovery
aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier itservice-prod \
    --target-db-instance-identifier itservice-recovered \
    --restore-time 2025-06-25T10:00:00.000Z
```