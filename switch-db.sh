#!/bin/bash

# Database Configuration Switcher for Cal.com
# Usage: ./switch-db.sh [local|production]

set -e

ENV_FILE=".env"
BACKUP_FILE=".env.backup.$(date +%Y%m%d_%H%M%S)"

# Function to backup current .env
backup_env() {
    echo "Creating backup: $BACKUP_FILE"
    cp "$ENV_FILE" "$BACKUP_FILE"
}

# Function to switch to local database
switch_to_local() {
    echo "Switching to LOCAL database configuration..."
    
    # Create backup
    backup_env
    
    # Update DATABASE_URL and DATABASE_DIRECT_URL to local
    sed -i '' 's|^DATABASE_URL=.*|DATABASE_URL="postgresql://postgres:postgres@localhost:5432/postgres"|' "$ENV_FILE"
    sed -i '' 's|^DATABASE_DIRECT_URL=.*|DATABASE_DIRECT_URL="postgresql://postgres:postgres@localhost:5432/postgres"|' "$ENV_FILE"
    
    echo "✅ Switched to LOCAL database configuration"
    echo "📊 Database: Local PostgreSQL (Docker)"
    echo "🔗 Connection: postgresql://postgres:postgres@localhost:5432/postgres"
}

# Function to switch to production database
switch_to_production() {
    echo "Switching to PRODUCTION database configuration..."
    
    # Create backup
    backup_env
    
    # Update DATABASE_URL and DATABASE_DIRECT_URL to production
    sed -i '' 's|^DATABASE_URL=.*|DATABASE_URL="postgres://postgres:wDr2hsgyDlUKYkyK@db.tgumvrfncwmnflyytazv.supabase.co:6543/postgres?sslmode=no-verify&pgbouncer=true"|' "$ENV_FILE"
    sed -i '' 's|^DATABASE_DIRECT_URL=.*|DATABASE_DIRECT_URL="postgres://postgres:wDr2hsgyDlUKYkyK@db.tgumvrfncwmnflyytazv.supabase.co:5432/postgres?sslmode=no-verify"|' "$ENV_FILE"
    
    echo "✅ Switched to PRODUCTION database configuration"
    echo "📊 Database: Supabase Production"
    echo "🔗 Connection: Supabase PostgreSQL"
}

# Function to show current configuration
show_current() {
    echo "Current database configuration:"
    echo "================================"
    grep "^DATABASE_URL=" "$ENV_FILE" || echo "DATABASE_URL not found"
    grep "^DATABASE_DIRECT_URL=" "$ENV_FILE" || echo "DATABASE_DIRECT_URL not found"
    echo ""
}

# Function to show usage
show_usage() {
    echo "Database Configuration Switcher"
    echo "================================"
    echo ""
    echo "Usage: $0 [local|production|status]"
    echo ""
    echo "Commands:"
    echo "  local      - Switch to local PostgreSQL (Docker)"
    echo "  production - Switch to Supabase production database"
    echo "  status     - Show current database configuration"
    echo ""
    echo "Examples:"
    echo "  $0 local      # Switch to local development"
    echo "  $0 production # Switch to production database"
    echo "  $0 status     # Show current configuration"
    echo ""
}

# Main script logic
case "${1:-}" in
    "local")
        switch_to_local
        ;;
    "production")
        switch_to_production
        ;;
    "status")
        show_current
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

echo ""
echo "💡 Tip: Run 'yarn dx' to restart the development server with the new configuration" 