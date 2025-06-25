-- Migration: Add change management fields
-- Date: 2025-06-25
-- Description: Add assigned_group field to changes table and enhance approval system

-- Add assigned_group column to changes table
ALTER TABLE changes 
ADD COLUMN IF NOT EXISTS assigned_group VARCHAR(255);

-- Add approval_token column for email-based approvals
ALTER TABLE changes 
ADD COLUMN IF NOT EXISTS approval_token VARCHAR(255);

-- Add overdue notification tracking
ALTER TABLE changes 
ADD COLUMN IF NOT EXISTS overdue_notification_sent TIMESTAMP;

-- Add is_overdue flag for performance
ALTER TABLE changes 
ADD COLUMN IF NOT EXISTS is_overdue BOOLEAN DEFAULT FALSE;

-- Update existing changes to have default values
UPDATE changes 
SET assigned_group = 'ASM - Anodyne Pay' 
WHERE assigned_group IS NULL;

-- Create index for better performance on assigned_group queries
CREATE INDEX IF NOT EXISTS idx_changes_assigned_group ON changes(assigned_group);

-- Create index for approval_token lookups
CREATE INDEX IF NOT EXISTS idx_changes_approval_token ON changes(approval_token);