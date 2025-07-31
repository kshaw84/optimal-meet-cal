import { readFileSync } from "fs";
import { Kysely, ParseJSONResultsPlugin, PostgresDialect, DeduplicateJoinsPlugin } from "kysely";
import { join } from "path";
import { Pool } from "pg";

import type { DB, Booking } from "./types";

export type { DB, Booking };

const connectionString = process.env.DATABASE_URL ?? "postgresql://postgres:@localhost:5450/calendso";

// Configure SSL settings based on environment
let sslConfig: any = false;

try {
  // Try to use Supabase SSL certificate file
  const certPath = join(process.cwd(), "certificates", "prod-ca-2021.crt");
  const cert = readFileSync(certPath, "utf8");

  sslConfig = {
    rejectUnauthorized: true,
    ca: cert,
  };
  console.log("🔒 Using Supabase SSL certificate for secure database connection");
} catch (error) {
  // If certificate file not found, fall back to previous logic
  if (process.env.SUPABASE_SSL_CERT) {
    // Use certificate from environment variable
    sslConfig = {
      rejectUnauthorized: true,
      ca: process.env.SUPABASE_SSL_CERT,
    };
    console.log("🔒 Using Supabase SSL certificate from environment variable");
  } else if (process.env.PGSSLMODE === "no-verify") {
    // Fall back to no-verify mode
    sslConfig = { rejectUnauthorized: false };
    console.log("⚠️ Using SSL with certificate verification disabled");
  } else if (process.env.NODE_ENV === "production") {
    // Production with default SSL
    sslConfig = { rejectUnauthorized: true };
    console.log("🔒 Using production SSL with default certificate verification");
  }
}

const pool = new Pool({
  connectionString,
  ssl: sslConfig,
});

// 3. Create the Dialect, passing the configured pool instance
const dialect = new PostgresDialect({
  pool: pool, // Use the pool instance created above
});

// 4. Create the Kysely instance as before
const db = new Kysely<DB>({
  dialect,
  plugins: [new ParseJSONResultsPlugin(), new DeduplicateJoinsPlugin()],
});

export default db;
