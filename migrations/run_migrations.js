#!/usr/bin/env node

/**
 * Database Migration Runner
 * Runs all pending SQL migrations in order
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

// Database connection configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://localhost:5432/servicedesk'
});

async function runMigrations() {
  try {
    console.log('🚀 Starting database migrations...');
    
    // Get list of migration files
    const migrationsDir = __dirname;
    const migrationFiles = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql') && file !== 'README.md')
      .sort();
    
    console.log(`📁 Found ${migrationFiles.length} migration files`);
    
    // Create migrations table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        description TEXT
      )
    `);
    
    // Get already applied migrations
    const appliedResult = await pool.query('SELECT migration_name FROM migrations');
    const appliedMigrations = new Set(appliedResult.rows.map(row => row.migration_name));
    
    let appliedCount = 0;
    
    for (const filename of migrationFiles) {
      const migrationName = path.basename(filename, '.sql');
      
      if (appliedMigrations.has(migrationName)) {
        console.log(`⏭️  Skipping already applied migration: ${migrationName}`);
        continue;
      }
      
      console.log(`📦 Applying migration: ${migrationName}`);
      
      try {
        // Read and execute migration file
        const migrationPath = path.join(migrationsDir, filename);
        const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
        
        // Execute migration in a transaction
        await pool.query('BEGIN');
        await pool.query(migrationSQL);
        
        // Record migration as applied
        await pool.query(
          'INSERT INTO migrations (migration_name, description) VALUES ($1, $2)',
          [migrationName, `Applied from ${filename}`]
        );
        
        await pool.query('COMMIT');
        
        console.log(`✅ Successfully applied: ${migrationName}`);
        appliedCount++;
        
      } catch (error) {
        await pool.query('ROLLBACK');
        console.error(`❌ Failed to apply migration ${migrationName}:`, error.message);
        throw error;
      }
    }
    
    if (appliedCount === 0) {
      console.log('✨ All migrations are up to date!');
    } else {
      console.log(`🎉 Successfully applied ${appliedCount} migrations`);
    }
    
    // Show current migration status
    const statusResult = await pool.query(
      'SELECT migration_name, applied_at FROM migrations ORDER BY applied_at DESC LIMIT 5'
    );
    
    console.log('\n📊 Recent migrations:');
    statusResult.rows.forEach(row => {
      console.log(`   ${row.migration_name} - ${row.applied_at.toISOString()}`);
    });
    
  } catch (error) {
    console.error('💥 Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run migrations if called directly
if (require.main === module) {
  runMigrations();
}

module.exports = { runMigrations };