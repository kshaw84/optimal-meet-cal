import type { OnModuleDestroy } from "@nestjs/common";
import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { DeduplicateJoinsPlugin, Kysely, ParseJSONResultsPlugin, PostgresDialect } from "kysely";
import { Pool } from "pg";

import type { DB } from "@calcom/kysely/types";

@Injectable()
export class KyselyReadService implements OnModuleDestroy {
  private logger = new Logger("KyselyReadService");

  public kysely: Kysely<DB>;

  constructor(readonly configService: ConfigService) {
    const dbUrl = configService.get("db.readUrl", { infer: true });

    // Configure SSL settings based on environment
    let sslConfig: any = false;

    if (process.env.SUPABASE_SSL_CERT) {
      // Use certificate from environment variable (preferred for Vercel)
      sslConfig = {
        rejectUnauthorized: true,
        ca: process.env.SUPABASE_SSL_CERT,
      };
      this.logger.log("🔒 Using Supabase SSL certificate from environment variable (read)");
    } else {
      try {
        // Try to use Supabase SSL certificate file as fallback
        const certPath = join(process.cwd(), "certificates", "prod-ca-2021.crt");
        const cert = readFileSync(certPath, "utf8");

        sslConfig = {
          rejectUnauthorized: true,
          ca: cert,
        };
        this.logger.log("🔒 Using Supabase SSL certificate file for secure database connection (read)");
      } catch (error) {
        // If certificate not available, fall back to previous logic
        if (process.env.PGSSLMODE === "no-verify") {
          // Fall back to no-verify mode
          sslConfig = { rejectUnauthorized: false };
          this.logger.warn("⚠️ Using SSL with certificate verification disabled (read)");
        } else if (process.env.NODE_ENV === "production") {
          // Production with default SSL
          sslConfig = { rejectUnauthorized: true };
          this.logger.log("🔒 Using production SSL with default certificate verification (read)");
        }
      }
    }

    const pool = new Pool({
      connectionString: dbUrl,
      ssl: sslConfig,
    });

    // 3. Create the Dialect, passing the configured pool instance
    const dialect = new PostgresDialect({
      pool: pool, // Use the pool instance created above
    });
    this.kysely = new Kysely<DB>({
      dialect,
      plugins: [new ParseJSONResultsPlugin(), new DeduplicateJoinsPlugin()],
    });
  }

  async onModuleDestroy() {
    try {
      await this.kysely.destroy();
    } catch (error) {
      this.logger.error(error);
    }
  }
}
