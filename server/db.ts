import { drizzle } from "drizzle-orm/node-postgres";
import pkg from "pg";
const { Pool } = pkg;
import * as schema from "@shared/schema";
if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL must be set. Did you forget to provision a database?");
}

export const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: false,
  min: 5, // Minimum connections in pool (increased)
  max: 20, // Maximum connections in pool
  idleTimeoutMillis: 300000, // Keep idle connections for 5 minutes
  connectionTimeoutMillis: 2000, // Timeout for new connections
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
});

export const db = drizzle(pool, { schema });
