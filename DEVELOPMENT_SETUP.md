# Development Setup Guide

## Environment Variables to Suppress Warnings

Add these to your `.env` file to suppress the development warnings:

```bash
# Deployment key for signature verification (optional for development)
DEPLOYMENT_KEY=dev_deployment_key

# Rate limiting key (optional for development)  
UNKEY_ROOT_KEY=dev_unkey_root_key

# Prisma SSL settings (for development)
DATABASE_URL="postgresql://username:password@localhost:5432/calcom?sslmode=require"
```

## Package Version Conflicts

The warnings about package version conflicts are due to different versions of dependencies being used across the monorepo. These are generally safe to ignore in development, but can be resolved by:

1. Running `npm install` to ensure all packages are up to date
2. Using `npm dedupe` to remove duplicate packages
3. Updating to consistent versions across the monorepo

## React 19 Compatibility

The React 19 warnings have been suppressed with the compatibility patches in:
- `apps/web/lib/react19-warnings.ts`
- `packages/lib/react19-compatibility.ts`

## Deprecated Page Configurations

The deprecated page configurations in webhook files have been updated to use the new Next.js App Router format. 