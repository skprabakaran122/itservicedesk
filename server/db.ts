import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

// Environment-specific database configuration
let pool: Pool;

if (process.env.DATABASE_URL) {
  // Parse DATABASE_URL for Docker, Replit, or external environments
  pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('localhost') || process.env.NODE_ENV === 'development' ? false : { rejectUnauthorized: false }
  });
} else {
  // Fallback configuration for direct deployment
  pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'servicedesk',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    port: parseInt(process.env.DB_PORT || '5432')
  });
}

export { pool };
export const db = drizzle(pool, { schema });
