import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

// Ubuntu-compatible database configuration
const isDevelopment = process.env.NODE_ENV === 'development';

let pool: Pool;

if (isDevelopment && process.env.DATABASE_URL) {
  // Development with DATABASE_URL (Replit environment)
  pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    // Configure for Ubuntu-style authentication patterns
    ssl: process.env.DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false }
  });
} else if (isDevelopment) {
  // Local Ubuntu PostgreSQL configuration
  pool = new Pool({
    host: 'localhost',
    database: 'servicedesk',
    user: 'postgres',
    port: 5432
  });
} else {
  // Production Ubuntu configuration
  if (!process.env.DATABASE_URL) {
    pool = new Pool({
      host: 'localhost',
      database: 'servicedesk',
      user: 'postgres',
      port: 5432
    });
  } else {
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }
}

export { pool };
export const db = drizzle(pool, { schema });
