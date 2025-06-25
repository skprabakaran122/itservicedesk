-- Migration: Create email configuration system
-- Date: 2025-06-25
-- Description: Create settings table for email configuration and system settings

-- Create settings table for dynamic configuration
CREATE TABLE IF NOT EXISTS settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL UNIQUE,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for fast key lookups
CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);

-- Insert default email configuration settings
INSERT INTO settings (key, value, description)
VALUES 
    ('email_provider', 'sendgrid', 'Email service provider (sendgrid or smtp)'),
    ('email_sendgrid_api_key', '', 'SendGrid API Key for email notifications'),
    ('email_from_address', 'no-reply@calpion.com', 'From email address for notifications'),
    ('email_smtp_host', '', 'SMTP server hostname'),
    ('email_smtp_port', '587', 'SMTP server port'),
    ('email_smtp_user', '', 'SMTP username'),
    ('email_smtp_pass', '', 'SMTP password')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = CURRENT_TIMESTAMP;