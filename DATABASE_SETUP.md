# Database Configuration Setup

This document explains how to configure and switch between different database environments for your Cal.com development setup.

## Current Configuration

Your `.env` file is now configured with:

### 🔧 **Local Development (Default)**
- **Database**: Local PostgreSQL running in Docker
- **Connection**: `postgresql://postgres:postgres@localhost:5432/postgres`
- **Status**: ✅ **ACTIVE** (currently using this)

### 🌐 **Production (Supabase)**
- **Database**: Supabase PostgreSQL
- **Connection**: Supabase production database
- **Status**: ⏸️ **COMMENTED OUT** (available for switching)

## Quick Commands

### Check Current Configuration
```bash
./switch-db.sh status
```

### Switch to Local Development
```bash
./switch-db.sh local
```

### Switch to Production
```bash
./switch-db.sh production
```

## Manual Configuration

If you prefer to manually edit the `.env` file, here are the key sections:

### Local Development (Default)
```bash
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/postgres"
DATABASE_DIRECT_URL="postgresql://postgres:postgres@localhost:5432/postgres"
```

### Production (Supabase)
```bash
# Uncomment these lines to use production database
# DATABASE_URL="postgres://postgres:wDr2hsgyDlUKYkyK@db.tgumvrfncwmnflyytazv.supabase.co:6543/postgres?sslmode=no-verify&pgbouncer=true"
# DATABASE_DIRECT_URL="postgres://postgres:wDr2hsgyDlUKYkyK@db.tgumvrfncwmnflyytazv.supabase.co:5432/postgres?sslmode=no-verify"
```

## Workflow

1. **For Local Development**: Use `./switch-db.sh local`
2. **For Production Testing**: Use `./switch-db.sh production`
3. **After Switching**: Run `yarn dx` to restart the development server

## Backup Files

The script automatically creates backups when switching configurations:
- Format: `.env.backup.YYYYMMDD_HHMMSS`
- Example: `.env.backup.20250802_150901`

## Troubleshooting

### If the script doesn't work:
1. Check that the script is executable: `chmod +x switch-db.sh`
2. Verify the `.env` file exists in the project root
3. Check the current status: `./switch-db.sh status`

### If database connection fails:
1. Ensure Docker is running
2. Check if PostgreSQL container is up: `docker ps`
3. Restart the database: `yarn dx` (this will restart the database)

## Benefits

✅ **Easy Switching**: Toggle between local and production with one command  
✅ **Automatic Backups**: Your configurations are safely backed up  
✅ **Clear Documentation**: Each configuration is clearly labeled  
✅ **Development Safety**: Default is local development to prevent accidental production changes  
✅ **Flexible**: Easy to add more database configurations in the future 