# Database Migration Guide

## Quick Start

### Run All Migrations
```bash
npm run db:migrate
# or directly: node migrations/run_migrations.cjs
```

### Check Migration Status
```bash
npm run db:status
```

### Development vs Production

**Development (Replit)**
```bash
# Option 1: Use Drizzle (recommended for schema changes)
npm run db:push

# Option 2: Use migration files (recommended for data changes)
npm run db:migrate
```

**Production Deployment**
```bash
export DATABASE_URL="postgresql://user:password@host:port/database"
node migrations/run_migrations.cjs
```

## Migration Files Created

### 0001_add_sub_product_to_tickets.sql
- Adds `sub_product` column to tickets table
- Enables product-category relationships

### 0002_add_change_management_fields.sql  
- Adds `assigned_group` field to changes table
- Adds `approval_token` for email-based approvals
- Adds overdue tracking fields (`overdue_notification_sent`, `is_overdue`)
- Creates performance indexes

### 0003_approval_routing_system.sql
- Creates `approval_routing` table for workflow configuration
- Creates `change_approvals` table for individual approval tracking
- Supports multi-level approvals with "require all" vs "any one" logic
- Includes default approval routing configurations

### 0004_groups_management_system.sql
- Creates `groups` table for organizational structure
- Adds `assigned_group` to tickets table
- Inserts default support groups (ASM - Anodyne Pay, ASM - Olympus, etc.)
- Enables group-based access control

### 0005_email_configuration_system.sql
- Creates `settings` table for dynamic configuration
- Stores email provider settings (SendGrid, SMTP)
- Enables runtime configuration changes

### 0006_categories_and_products_enhancement.sql
- Creates `categories` table linked to products
- Adds `owner` field to products table
- Inserts default categories for existing products
- Enhances product-category relationships

### 0007_migration_tracking.sql
- Creates `migrations` table for tracking applied migrations
- Records migration history with timestamps
- Prevents duplicate migration application

## Migration Safety Features

- **Transaction Safety**: Each migration runs in a transaction with rollback on failure
- **Idempotent**: All migrations use `IF NOT EXISTS` clauses
- **Order Enforcement**: Migrations apply in numerical sequence
- **Duplicate Prevention**: Already applied migrations are automatically skipped
- **Status Tracking**: Complete audit trail of all applied migrations

## Production Checklist

1. **Backup Database**: Always backup before running migrations
2. **Test Staging**: Run migrations on staging environment first  
3. **Verify Dependencies**: Ensure all required tables/columns exist
4. **Check Permissions**: Database user needs CREATE/ALTER privileges
5. **Monitor Application**: Verify all features work after migration

## Troubleshooting

**Migration Failed**
```bash
# Check what went wrong
node migrations/run_migrations.js

# Remove failed migration record to retry
psql $DATABASE_URL -c "DELETE FROM migrations WHERE migration_name = 'failed_migration_name';"
```

**Check Database Structure**  
```bash
psql $DATABASE_URL -c "\d table_name"
```

**Verify Migration Status**
```bash
psql $DATABASE_URL -c "SELECT * FROM migrations ORDER BY applied_at;"
```