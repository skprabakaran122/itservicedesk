import { drizzle } from "drizzle-orm/node-postgres";
import pkg from "pg";
const { Pool } = pkg;
import * as schema from "@shared/schema";
if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL must be set. Did you forget to provision a database?");
}

export const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('neon.tech') ? { rejectUnauthorized: false } : false,
  min: 1, // Minimal connections to reduce timeouts
  max: 5, // Lower max to avoid overwhelming remote database
  idleTimeoutMillis: 60000, // Longer idle timeout for stability
  connectionTimeoutMillis: 15000, // Extended timeout for remote connections
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
  // Additional retry configuration
  query_timeout: 30000,
  statement_timeout: 30000,
});

export const db = drizzle(pool, { schema });
