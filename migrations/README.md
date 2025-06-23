# Database Migrations

This directory contains database migration files for the IT Service Desk system. These migrations document all schema changes made to the PostgreSQL database.

## Migration Files

### 0001_add_sub_product_to_tickets.sql
- **Date**: 2025-06-23
- **Purpose**: Adds sub-product functionality to tickets table
- **Changes**:
  - Adds `sub_product` varchar(100) column to `tickets` table
  - Creates index on `sub_product` for better query performance
  - Fixes data integrity issue by updating product IDs to product names

## Running Migrations

### Development Environment
The system uses Drizzle ORM with `npm run db:push` for schema synchronization. This automatically applies schema changes from `shared/schema.ts` to the database.

### Manual Migration Execution
If you need to run migrations manually:

```sql
-- Connect to your PostgreSQL database and run:
\i migrations/0001_add_sub_product_to_tickets.sql
```

### Production Deployment
For production deployments, ensure migrations are applied in order:

1. Backup your database before applying migrations
2. Apply migrations in numerical order (0001, 0002, etc.)
3. Verify schema changes are applied correctly

## Schema Changes Log

| Migration | Date | Description |
|-----------|------|-------------|
| 0001 | 2025-06-23 | Added sub_product field to tickets table for organizational hierarchy |

## Notes

- All migrations are written to be idempotent where possible
- Index creation uses `IF NOT EXISTS` to prevent errors on re-runs
- Data fixes are included in migrations where necessary for consistency
- Always test migrations in development before applying to production