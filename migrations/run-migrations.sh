#!/bin/bash

# Database Migration Runner for IT Service Desk
# This script applies all pending migrations to the PostgreSQL database

set -e

echo "Starting database migration process..."

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL environment variable is not set"
    echo "Please set DATABASE_URL to your PostgreSQL connection string"
    exit 1
fi

# Extract database connection details from DATABASE_URL
DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
DB_USER=$(echo $DATABASE_URL | sed -n 's/.*\/\/\([^:]*\):.*/\1/p')

echo "Database: $DB_NAME on $DB_HOST:$DB_PORT"

# Create migrations table if it doesn't exist
psql "$DATABASE_URL" -c "
CREATE TABLE IF NOT EXISTS migrations (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

echo "Created migrations tracking table..."

# Function to apply a migration
apply_migration() {
    local migration_file=$1
    local filename=$(basename "$migration_file")
    
    # Check if migration has already been applied
    local applied=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM migrations WHERE filename = '$filename';" | xargs)
    
    if [ "$applied" -eq "0" ]; then
        echo "Applying migration: $filename"
        psql "$DATABASE_URL" -f "$migration_file"
        psql "$DATABASE_URL" -c "INSERT INTO migrations (filename) VALUES ('$filename');"
        echo "✓ Applied: $filename"
    else
        echo "⚠ Skipped: $filename (already applied)"
    fi
}

# Apply migrations in order
for migration in migrations/*.sql; do
    if [ -f "$migration" ]; then
        apply_migration "$migration"
    fi
done

echo "Database migration completed successfully!"
echo "Current schema version: $(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM migrations;" | xargs) migrations applied"