#!/bin/bash

# Docker initialization script for IT Service Desk
# Runs database migrations and starts the application

set -e

echo "🐳 Starting IT Service Desk in Docker..."

# Wait for database to be ready (works for both local Docker and RDS)
echo "⏳ Waiting for database connection..."
RETRY_COUNT=0
MAX_RETRIES=30

until node -e "
const { Pool } = require('pg');
const isRDS = process.env.DB_HOST && process.env.DB_HOST.includes('.rds.amazonaws.com');
const poolConfig = process.env.DATABASE_URL ? 
  { 
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false }
  } : 
  {
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT || 5432,
    ssl: isRDS ? { rejectUnauthorized: false } : false
  };

const pool = new Pool(poolConfig);
pool.query('SELECT 1').then(() => {
  console.log('✅ Database connected');
  pool.end();
  process.exit(0);
}).catch(err => {
  console.log('❌ Database not ready:', err.message);
  process.exit(1);
});
" || { 
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Failed to connect to database after $MAX_RETRIES attempts"
    echo "Check your RDS configuration and network connectivity"
    exit 1
  fi
  echo "⏳ Database not ready (attempt $RETRY_COUNT/$MAX_RETRIES), waiting 10 seconds..."
  sleep 10
}; do
  :
done

# Run database migrations
echo "📦 Running database migrations..."
node migrations/run_migrations.cjs || {
  echo "❌ Migration failed, but continuing..."
}

# Start the application
echo "🚀 Starting application..."
exec tsx server/index.ts