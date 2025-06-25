#!/bin/bash

# Docker initialization script for IT Service Desk
# Runs database migrations and starts the application

set -e

echo "🐳 Starting IT Service Desk in Docker..."

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
until node -e "
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
pool.query('SELECT 1').then(() => {
  console.log('✅ Database connected');
  pool.end();
  process.exit(0);
}).catch(err => {
  console.log('❌ Database not ready:', err.message);
  process.exit(1);
});
"; do
  echo "⏳ Database not ready, waiting 5 seconds..."
  sleep 5
done

# Run database migrations
echo "📦 Running database migrations..."
node migrations/run_migrations.cjs || {
  echo "❌ Migration failed, but continuing..."
}

# Start the application
echo "🚀 Starting application..."
exec tsx server/index.ts