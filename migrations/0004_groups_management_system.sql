-- Migration: Create groups management system
-- Date: 2025-06-25
-- Description: Create groups table for organizational structure and ticket assignment

-- Create groups table
CREATE TABLE IF NOT EXISTS groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    members TEXT[] DEFAULT '{}', -- Array of user IDs
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add assigned_group column to tickets table
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS assigned_group VARCHAR(255);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_groups_name ON groups(name);
CREATE INDEX IF NOT EXISTS idx_groups_active ON groups(is_active);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_group ON tickets(assigned_group);

-- Insert default support groups
INSERT INTO groups (name, description, members, is_active)
VALUES 
    ('ASM - Anodyne Pay', 'Application Support and Maintenance team for Anodyne Pay system', ARRAY['3','5'], TRUE),
    ('ASM - Olympus', 'Application Support and Maintenance team for Olympus platform', ARRAY['1','3'], TRUE),
    ('ASM - RPA', 'Application Support and Maintenance team for RPA solutions', ARRAY['3','5'], TRUE),
    ('Infrastructure', 'Infrastructure and network support team', ARRAY['1','5'], TRUE)
ON CONFLICT (name) DO NOTHING;

-- Update existing tickets to have default group assignments
UPDATE tickets 
SET assigned_group = 'ASM - Anodyne Pay' 
WHERE assigned_group IS NULL;