-- Migration: Enhance categories and products system
-- Date: 2025-06-25
-- Description: Add sub-product support and enhance product-category relationships

-- Add sub_product column to tickets table
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS sub_product VARCHAR(255);

-- Add owner column to products table for user assignment
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS owner VARCHAR(255);

-- Create categories table for better organization
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_categories_product_id ON categories(product_id);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active);
CREATE INDEX IF NOT EXISTS idx_tickets_sub_product ON tickets(sub_product);

-- Insert default categories for existing products
INSERT INTO categories (name, description, product_id, is_active)
VALUES 
    ('AR Workflow Management', 'Accounts Receivable workflow and process management', 2, TRUE),
    ('Payment Processing', 'Payment gateway and transaction processing', 2, TRUE),
    ('User Management', 'User accounts and access control', 2, TRUE),
    ('System Integration', 'Third-party system integrations', 2, TRUE),
    ('Reporting', 'Business intelligence and reporting features', 2, TRUE)
ON CONFLICT DO NOTHING;

-- Update products with default owners
UPDATE products 
SET owner = 'system' 
WHERE owner IS NULL;