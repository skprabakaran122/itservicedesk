import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from "@shared/schema";

// Development environment configuration for Ubuntu compatibility
const isDevelopment = process.env.NODE_ENV === 'development';

let pool: Pool;

if (isDevelopment) {
  // Local PostgreSQL configuration matching Ubuntu production
  pool = new Pool({
    host: 'localhost',
    database: 'servicedesk',
    user: 'postgres',
    // No password for trust authentication like production
    port: 5432
  });
} else {
  // Production configuration
  if (!process.env.DATABASE_URL) {
    throw new Error(
      "DATABASE_URL must be set. Did you forget to provision a database?",
    );
  }
  pool = new Pool({ connectionString: process.env.DATABASE_URL });
}

export { pool };
export const db = drizzle(pool, { schema });
