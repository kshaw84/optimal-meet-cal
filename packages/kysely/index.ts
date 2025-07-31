import { Kysely, ParseJSONResultsPlugin, PostgresDialect, DeduplicateJoinsPlugin } from "kysely";
import { Pool } from "pg";

import type { DB, Booking } from "./types";

export type { DB, Booking };

const connectionString = process.env.DATABASE_URL ?? "postgresql://postgres:@localhost:5450/calendso";

// Configure SSL settings based on environment
const sslConfig =
  process.env.PGSSLMODE === "no-verify"
    ? { rejectUnauthorized: false }
    : process.env.NODE_ENV === "production"
    ? { rejectUnauthorized: true }
    : false;

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
