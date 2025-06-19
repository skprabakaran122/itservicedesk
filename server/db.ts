import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

// Environment-specific database configuration
let pool: Pool;

if (process.env.DATABASE_URL) {
  // Replit development environment
  pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false }
  });
} else {
  // Ubuntu production environment
  pool = new Pool({
    host: 'localhost',
    database: 'servicedesk',
    user: 'postgres',
    port: 5432
  });
}

export { pool };
export const db = drizzle(pool, { schema });
