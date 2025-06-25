import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

// Environment-specific database configuration
let pool: Pool;

if (process.env.DATABASE_URL) {
  // Parse DATABASE_URL for Docker, Replit, RDS, or external environments
  const isLocalDB = process.env.DATABASE_URL.includes('localhost') || 
                   process.env.DATABASE_URL.includes('@database:') ||
                   process.env.NODE_ENV === 'development';
  
  pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: isLocalDB ? false : { 
      rejectUnauthorized: false,
      // AWS RDS requires SSL in production
      sslmode: process.env.DB_SSL_MODE || 'require'
    },
    // RDS-specific connection settings
    connectionTimeoutMillis: 30000,
    idleTimeoutMillis: 30000,
    max: 20, // Maximum pool size for RDS
    min: 2   // Minimum pool size to keep connections warm
  });
} else {
  // Fallback configuration for direct deployment or RDS with individual parameters
  const isRDS = process.env.DB_HOST?.includes('.rds.amazonaws.com');
  
  pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'servicedesk',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    port: parseInt(process.env.DB_PORT || '5432'),
    ssl: isRDS ? {
      rejectUnauthorized: false,
      sslmode: 'require'
    } : false,
    // RDS-optimized connection settings
    connectionTimeoutMillis: isRDS ? 30000 : 5000,
    idleTimeoutMillis: isRDS ? 30000 : 10000,
    max: isRDS ? 20 : 10,
    min: isRDS ? 2 : 1
  });
}

export { pool };
export const db = drizzle(pool, { schema });
