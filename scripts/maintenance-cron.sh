#!/bin/bash

# Database Maintenance Script for Local Development
# Run this script to maintain database performance

set -e

echo "$(date): Starting database maintenance..."

# Database URL for local development
DB_URL="postgresql://postgres:postgres@localhost:5450/postgres"

# Run maintenance function
echo "Running maintenance function..."
psql "$DB_URL" -c "SELECT perform_maintenance();"

# Refresh timezone cache
echo "Refreshing timezone cache..."
psql "$DB_URL" -c "SELECT refresh_timezone_cache();"

# Analyze tables
echo "Analyzing tables..."
psql "$DB_URL" -c "ANALYZE;"

# Check performance
echo "Checking performance..."
psql "$DB_URL" -c "SELECT * FROM check_performance_issues();"

echo "$(date): Database maintenance completed successfully!"
