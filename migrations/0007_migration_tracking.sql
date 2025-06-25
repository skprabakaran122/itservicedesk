-- Migration: Create migration tracking system
-- Date: 2025-06-25
-- Description: Create table to track applied migrations for deployment consistency

-- Create migrations table to track applied migrations
CREATE TABLE IF NOT EXISTS migrations (
    id SERIAL PRIMARY KEY,
    migration_name VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Insert migration history for tracking
INSERT INTO migrations (migration_name, description, applied_at)
VALUES 
    ('0001_add_sub_product_to_tickets', 'Initial sub-product field addition to tickets table', '2025-06-23 10:00:00'),
    ('0002_add_change_management_fields', 'Add assigned_group and approval fields to changes table', '2025-06-25 08:00:00'),
    ('0003_approval_routing_system', 'Create approval routing and change approvals tables', '2025-06-25 08:15:00'),
    ('0004_groups_management_system', 'Create groups table and assigned_group for tickets', '2025-06-25 08:30:00'),
    ('0005_email_configuration_system', 'Create settings table for email configuration', '2025-06-25 08:45:00'),
    ('0006_categories_and_products_enhancement', 'Add sub_product to tickets and enhance categories', '2025-06-25 09:00:00'),
    ('0007_migration_tracking', 'Create migration tracking system', '2025-06-25 09:15:00')
ON CONFLICT (migration_name) DO NOTHING;

-- Create index for migration lookups
CREATE INDEX IF NOT EXISTS idx_migrations_name ON migrations(migration_name);
CREATE INDEX IF NOT EXISTS idx_migrations_applied_at ON migrations(applied_at);