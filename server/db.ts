import { drizzle } from "drizzle-orm/node-postgres";
import pkg from "pg";
const { Pool } = pkg;
import * as schema from "@shared/schema";
if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL must be set. Did you forget to provision a database?");
}

export const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: false, // No SSL needed for local PostgreSQL
  min: 2, // Adequate for local database
  max: 10, // Can handle more connections locally
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000, // Shorter timeout for local connections
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
});

export const db = drizzle(pool, { schema });
