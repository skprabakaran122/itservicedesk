-- Migration: Create approval routing system
-- Date: 2025-06-25
-- Description: Create comprehensive approval routing and change approvals tables

-- Create approval_routing table
CREATE TABLE IF NOT EXISTS approval_routing (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    group_id INTEGER REFERENCES groups(id),
    risk_level VARCHAR(50) NOT NULL CHECK (risk_level IN ('low', 'medium', 'high')),
    approver_ids TEXT[] NOT NULL, -- Array of user IDs who can approve
    approval_level INTEGER NOT NULL DEFAULT 1,
    require_all_approvals VARCHAR(10) NOT NULL DEFAULT 'false' CHECK (require_all_approvals IN ('true', 'false')),
    is_active VARCHAR(10) NOT NULL DEFAULT 'true' CHECK (is_active IN ('true', 'false')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create change_approvals table for tracking individual approvals
CREATE TABLE IF NOT EXISTS change_approvals (
    id SERIAL PRIMARY KEY,
    change_id INTEGER NOT NULL REFERENCES changes(id) ON DELETE CASCADE,
    approver_id INTEGER NOT NULL REFERENCES users(id),
    approval_level INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_at TIMESTAMP,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(change_id, approver_id, approval_level)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_approval_routing_group_risk ON approval_routing(group_id, risk_level);
CREATE INDEX IF NOT EXISTS idx_approval_routing_product_risk ON approval_routing(product_id, risk_level);
CREATE INDEX IF NOT EXISTS idx_change_approvals_change_id ON change_approvals(change_id);
CREATE INDEX IF NOT EXISTS idx_change_approvals_approver_id ON change_approvals(approver_id);
CREATE INDEX IF NOT EXISTS idx_change_approvals_status ON change_approvals(status);

-- Insert default approval routing configurations
INSERT INTO approval_routing (group_id, risk_level, approver_ids, approval_level, require_all_approvals, is_active)
VALUES 
    (4, 'medium', ARRAY['1','3','5'], 1, 'false', 'true'),
    (4, 'high', ARRAY['1','3','5'], 1, 'true', 'true'),
    (1, 'medium', ARRAY['3','5'], 1, 'true', 'true')
ON CONFLICT DO NOTHING;