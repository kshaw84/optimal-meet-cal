import type { Prisma } from "@prisma/client";
import { PrismaClient as PrismaClientWithoutExtension } from "@prisma/client";
// Configure SSL settings for database connections
import { readFileSync } from "fs";
import { join } from "path";

import { bookingIdempotencyKeyExtension } from "./extensions/booking-idempotency-key";
import { disallowUndefinedDeleteUpdateManyExtension } from "./extensions/disallow-undefined-delete-update-many";
import { excludeLockedUsersExtension } from "./extensions/exclude-locked-users";
import { excludePendingPaymentsExtension } from "./extensions/exclude-pending-payment-teams";
import { usageTrackingExtention } from "./extensions/usage-tracking";
import { bookingReferenceMiddleware } from "./middleware";

const datasourceUrl = process.env.DATABASE_URL;
const prismaOptions: Prisma.PrismaClientOptions = {
  // Add connection pooling for better performance
  datasources: {
    db: {
      url: datasourceUrl,
    },
  },
  // Optimize for development performance
  log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
};

// Add SSL configuration for Supabase
if (datasourceUrl) {
  try {
    // Try to use Supabase SSL certificate file
    const certPath = join(process.cwd(), "certificates", "prod-ca-2021.crt");
    readFileSync(certPath, "utf8"); // Verify file exists

    // Configure URL with proper SSL settings
    const url = new URL(datasourceUrl);
    url.searchParams.set("sslmode", "require");
    url.searchParams.set("sslcert", "");
    url.searchParams.set("sslkey", "");
    url.searchParams.set("sslrootcert", certPath);
    // Add connection pooling parameters
    url.searchParams.set("pool_timeout", "20");
    url.searchParams.set("connection_limit", "10");

    prismaOptions.datasources = {
      db: {
        url: url.toString(),
      },
    };
    console.log("🔒 Prisma using Supabase SSL certificate for secure database connection");
  } catch (error) {
    // If certificate file not found, fall back to optimized no-verify mode
    if (process.env.PGSSLMODE === "no-verify") {
      const url = new URL(datasourceUrl);
      url.searchParams.set("sslmode", "require");
      // Add connection pooling parameters
      url.searchParams.set("pool_timeout", "20");
      url.searchParams.set("connection_limit", "10");

      prismaOptions.datasources = {
        db: {
          url: url.toString(),
        },
      };
      console.log("⚠️ Prisma using SSL with certificate verification disabled (optimized)");
    }
  }
}

const globalForPrisma = global as unknown as {
  prismaWithoutClientExtensions: PrismaClientWithoutExtension;
  prismaWithClientExtensions: PrismaClientWithExtensions;
};

const loggerLevel = parseInt(process.env.NEXT_PUBLIC_LOGGER_LEVEL ?? "", 10);

if (!isNaN(loggerLevel)) {
  switch (loggerLevel) {
    case 5:
    case 6:
      prismaOptions.log = ["error"];
      break;
    case 4:
      prismaOptions.log = ["warn", "error"];
      break;
    case 3:
      prismaOptions.log = ["info", "error", "warn"];
      break;
    default:
      // For values 0, 1, 2 (or anything else below 3)
      prismaOptions.log = ["error", "warn"]; // Reduced logging for better performance
      break;
  }
}

// Prevents flooding with idle connections
const prismaWithoutClientExtensions =
  globalForPrisma.prismaWithoutClientExtensions || new PrismaClientWithoutExtension(prismaOptions);

export const customPrisma = (options?: Prisma.PrismaClientOptions) =>
  new PrismaClientWithoutExtension({ ...prismaOptions, ...options })
    .$extends(usageTrackingExtention(prismaWithoutClientExtensions))
    .$extends(excludeLockedUsersExtension())
    .$extends(excludePendingPaymentsExtension())
    .$extends(bookingIdempotencyKeyExtension())
    .$extends(disallowUndefinedDeleteUpdateManyExtension());
// .$extends(withAccelerate()); // Temporarily disabled for Supabase compatibility

// If any changed on middleware server restart is required
// TODO: Migrate it to $extends
bookingReferenceMiddleware(prismaWithoutClientExtensions);

// FIXME: Due to some reason, there are types failing in certain places due to the $extends. Fix it and then enable it
// Specifically we get errors like `Type 'string | Date | null | undefined' is not assignable to type 'Exact<string | Date | null | undefined, string | Date | null | undefined>'`
const prismaWithClientExtensions = prismaWithoutClientExtensions
  .$extends(usageTrackingExtention(prismaWithoutClientExtensions))
  .$extends(excludeLockedUsersExtension())
  .$extends(excludePendingPaymentsExtension())
  .$extends(bookingIdempotencyKeyExtension())
  .$extends(disallowUndefinedDeleteUpdateManyExtension());
// .$extends(withAccelerate()); // Temporarily disabled for Supabase compatibility

export const prisma = globalForPrisma.prismaWithClientExtensions || prismaWithClientExtensions;

// This prisma instance is meant to be used only for READ operations.
// If self hosting, feel free to leave INSIGHTS_DATABASE_URL as empty and `readonlyPrisma` will default to `prisma`.
export const readonlyPrisma = process.env.INSIGHTS_DATABASE_URL
  ? customPrisma({
      datasources: { db: { url: process.env.INSIGHTS_DATABASE_URL } },
    })
  : prisma;

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prismaWithoutClientExtensions = prismaWithoutClientExtensions;
  globalForPrisma.prismaWithClientExtensions = prisma;
}

type PrismaClientWithExtensions = typeof prismaWithClientExtensions;
export type PrismaClient = PrismaClientWithExtensions;

type OmitPrismaClient = Omit<
  PrismaClient,
  "$connect" | "$disconnect" | "$on" | "$transaction" | "$use" | "$extends"
>;

// we cant pass tx to functions as types miss match since we have a custom prisma client https://github.com/prisma/prisma/discussions/20924#discussioncomment-10077649
export type PrismaTransaction = OmitPrismaClient;

export default prisma;

export * from "./selects";
