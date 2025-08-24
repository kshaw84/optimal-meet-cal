#!/bin/bash

# Performance Optimization Implementation Script
# This script implements database performance optimizations for both local and production

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check database connection
check_db_connection() {
    local db_url=$1
    print_status "Checking database connection..."
    
    if command_exists psql; then
        if psql "$db_url" -c "SELECT 1;" >/dev/null 2>&1; then
            print_success "Database connection successful"
            return 0
        else
            print_error "Database connection failed"
            return 1
        fi
    else
        print_warning "psql not found, skipping connection test"
        return 0
    fi
}

# Function to run SQL script
run_sql_script() {
    local script_path=$1
    local db_url=$2
    local script_name=$(basename "$script_path")
    
    print_status "Running $script_name..."
    
    if command_exists psql; then
        if psql "$db_url" -f "$script_path"; then
            print_success "$script_name completed successfully"
        else
            print_error "$script_name failed"
            return 1
        fi
    else
        print_warning "psql not found, please run $script_name manually in your database"
        echo "Script content:"
        echo "=================="
        cat "$script_path"
        echo "=================="
    fi
}

# Function to setup local environment
setup_local() {
    print_status "Setting up local environment..."
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        print_error ".env file not found. Please create one with your database URLs."
        return 1
    fi
    
    # Load environment variables safely
    if [ -f ".env" ]; then
        # Load only simple key=value pairs, skip complex values
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            if [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]]; then
                continue
            fi
            
            # Only export simple variables (no spaces, special chars)
            if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && [[ $value =~ ^[A-Za-z0-9_/:@.-]*$ ]]; then
                export "$key=$value"
            fi
        done < .env
    fi
    
    # Check for required environment variables
    if [ -z "$DATABASE_URL" ]; then
        print_error "DATABASE_URL not found in .env file"
        print_status "Please ensure your .env file contains: DATABASE_URL=your_database_url"
        return 1
    fi
    
    print_success "Local environment configured"
}

# Function to setup production environment
setup_production() {
    print_status "Setting up production environment..."
    
    # Check for Supabase CLI
    if command_exists supabase; then
        print_success "Supabase CLI found"
    else
        print_warning "Supabase CLI not found. Please install it for production deployment."
        echo "Install with: npm install -g supabase"
    fi
    
    print_success "Production environment configured"
}

# Function to implement optimizations
implement_optimizations() {
    local environment=$1
    local db_url=$2
    
    print_status "Implementing performance optimizations for $environment..."
    
    # Check database connection
    if ! check_db_connection "$db_url"; then
        print_error "Cannot connect to database. Please check your connection string."
        return 1
    fi
    
    # Run optimization script
    if [ -f "scripts/performance-optimization.sql" ]; then
        run_sql_script "scripts/performance-optimization.sql" "$db_url"
    else
        print_error "performance-optimization.sql not found"
        return 1
    fi
    
    # Run monitoring script
    if [ -f "scripts/monitor-performance.sql" ]; then
        print_status "Running performance monitoring..."
        run_sql_script "scripts/monitor-performance.sql" "$db_url"
    fi
    
    print_success "Performance optimizations implemented for $environment"
}

# Function to create monitoring dashboard
create_monitoring_dashboard() {
    print_status "Creating monitoring dashboard..."
    
    # Create monitoring directory
    mkdir -p monitoring
    
    # Create monitoring dashboard HTML
    cat > monitoring/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Performance Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .good { border-left: 4px solid #4CAF50; }
        .warning { border-left: 4px solid #FF9800; }
        .error { border-left: 4px solid #F44336; }
        .refresh-btn { background: #2196F3; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        .refresh-btn:hover { background: #1976D2; }
    </style>
</head>
<body>
    <h1>Database Performance Dashboard</h1>
    <button class="refresh-btn" onclick="refreshData()">Refresh Data</button>
    <div id="metrics"></div>
    
    <script>
        async function refreshData() {
            try {
                const response = await fetch('/api/performance-metrics');
                const data = await response.json();
                displayMetrics(data);
            } catch (error) {
                console.error('Error fetching metrics:', error);
            }
        }
        
        function displayMetrics(data) {
            const container = document.getElementById('metrics');
            container.innerHTML = '';
            
            data.forEach(metric => {
                const div = document.createElement('div');
                div.className = `metric ${getStatusClass(metric.value)}`;
                div.innerHTML = `
                    <h3>${metric.name}</h3>
                    <p><strong>Value:</strong> ${metric.value}</p>
                    <p><strong>Status:</strong> ${metric.status}</p>
                `;
                container.appendChild(div);
            });
        }
        
        function getStatusClass(value) {
            if (value.includes('good') || value.includes('95%')) return 'good';
            if (value.includes('warning') || value.includes('80%')) return 'warning';
            return 'error';
        }
        
        // Initial load
        refreshData();
        
        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);
    </script>
</body>
</html>
EOF
    
    print_success "Monitoring dashboard created at monitoring/dashboard.html"
}

# Function to create API endpoint for monitoring
create_monitoring_api() {
    print_status "Creating monitoring API endpoint..."
    
    # Create API directory
    mkdir -p apps/api/monitoring
    
    # Create performance metrics endpoint
    cat > apps/api/monitoring/performance-metrics.ts << 'EOF'
import { NextApiRequest, NextApiResponse } from 'next';
import { prisma } from '@calcom/prisma';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    if (req.method !== 'GET') {
        return res.status(405).json({ message: 'Method not allowed' });
    }

    try {
        // Get performance metrics
        const metrics = await getPerformanceMetrics();
        res.status(200).json(metrics);
    } catch (error) {
        console.error('Error fetching performance metrics:', error);
        res.status(500).json({ message: 'Internal server error' });
    }
}

async function getPerformanceMetrics() {
    const metrics = [];

    try {
        // Cache hit ratio
        const cacheHitRatio = await prisma.$queryRaw`
            SELECT ROUND(
                (sum(heap_blks_hit)::float / (sum(heap_blks_hit) + sum(heap_blks_read))::float) * 100, 
                2
            ) as ratio
            FROM pg_statio_user_tables
        `;
        
        const ratio = cacheHitRatio[0]?.ratio || 0;
        metrics.push({
            name: 'Cache Hit Ratio',
            value: `${ratio}%`,
            status: ratio > 95 ? 'good' : ratio > 80 ? 'warning' : 'error'
        });

        // Slow queries count
        const slowQueries = await prisma.$queryRaw`
            SELECT COUNT(*) as count
            FROM pg_stat_statements 
            WHERE mean_time > 1000
        `;
        
        const slowCount = slowQueries[0]?.count || 0;
        metrics.push({
            name: 'Slow Queries (>1s)',
            value: slowCount.toString(),
            status: slowCount === 0 ? 'good' : slowCount < 5 ? 'warning' : 'error'
        });

        // Active connections
        const activeConnections = await prisma.$queryRaw`
            SELECT COUNT(*) as count
            FROM pg_stat_activity 
            WHERE state = 'active'
        `;
        
        const activeCount = activeConnections[0]?.count || 0;
        metrics.push({
            name: 'Active Connections',
            value: activeCount.toString(),
            status: activeCount < 50 ? 'good' : activeCount < 100 ? 'warning' : 'error'
        });

        // Database size
        const dbSize = await prisma.$queryRaw`
            SELECT pg_size_pretty(pg_database_size(current_database())) as size
        `;
        
        metrics.push({
            name: 'Database Size',
            value: dbSize[0]?.size || 'Unknown',
            status: 'info'
        });

    } catch (error) {
        console.error('Error getting metrics:', error);
        metrics.push({
            name: 'Error',
            value: 'Failed to fetch metrics',
            status: 'error'
        });
    }

    return metrics;
}
EOF
    
    print_success "Monitoring API endpoint created"
}

# Function to create cron job for maintenance
create_maintenance_cron() {
    print_status "Creating maintenance cron job..."
    
    # Create maintenance script
    cat > scripts/maintenance-cron.sh << 'EOF'
#!/bin/bash

# Database Maintenance Cron Job
# Run this script daily to maintain database performance

set -e

# Load environment variables
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "DATABASE_URL not set. Exiting."
    exit 1
fi

echo "$(date): Starting database maintenance..."

# Run maintenance function
psql "$DATABASE_URL" -c "SELECT perform_maintenance();"

# Refresh timezone cache
psql "$DATABASE_URL" -c "SELECT refresh_timezone_cache();"

# Analyze tables
psql "$DATABASE_URL" -c "ANALYZE;"

echo "$(date): Database maintenance completed."
EOF
    
    # Make script executable
    chmod +x scripts/maintenance-cron.sh
    
    print_success "Maintenance cron job created at scripts/maintenance-cron.sh"
    print_warning "Add this to your crontab: 0 2 * * * /path/to/your/project/scripts/maintenance-cron.sh"
}

# Function to create Docker setup for local development
create_docker_setup() {
    print_status "Creating Docker setup for local development..."
    
    # Create docker-compose file for local development
    cat > docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: cal_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/performance-optimization.sql:/docker-entrypoint-initdb.d/01-performance-optimization.sql
    command: postgres -c shared_preload_libraries=pg_stat_statements

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  monitoring:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  postgres_data:
  grafana_data:
EOF
    
    print_success "Docker setup created for local development"
    print_status "Run with: docker-compose -f docker-compose.dev.yml up -d"
}

# Function to create GitHub Actions for monitoring
create_github_actions() {
    print_status "Creating GitHub Actions for monitoring..."
    
    # Create .github directory
    mkdir -p .github/workflows
    
    # Create monitoring workflow
    cat > .github/workflows/performance-monitoring.yml << 'EOF'
name: Performance Monitoring

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:  # Manual trigger

jobs:
  monitor-performance:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'yarn'
    
    - name: Install dependencies
      run: yarn install --frozen-lockfile
    
    - name: Run performance monitoring
      env:
        DATABASE_URL: ${{ secrets.DATABASE_URL }}
      run: |
        yarn workspace @calcom/prisma db-push
        psql "$DATABASE_URL" -f scripts/monitor-performance.sql > performance-report.txt
    
    - name: Upload performance report
      uses: actions/upload-artifact@v3
      with:
        name: performance-report
        path: performance-report.txt
    
    - name: Alert on performance issues
      if: failure()
      run: |
        echo "Performance issues detected. Check the uploaded report."
        # Add your alerting logic here (Slack, email, etc.)
EOF
    
    print_success "GitHub Actions workflow created"
}

# Main execution function
main() {
    echo "=========================================="
    echo "Database Performance Optimization Setup"
    echo "=========================================="
    
    # Parse command line arguments
    local environment=""
    local db_url=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local)
                environment="local"
                shift
                ;;
            --production)
                environment="production"
                shift
                ;;
            --db-url)
                db_url="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--local|--production] [--db-url URL]"
                echo ""
                echo "Options:"
                echo "  --local       Setup for local development"
                echo "  --production  Setup for production"
                echo "  --db-url URL  Database URL to use"
                echo "  --help        Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Default to local if no environment specified
    if [ -z "$environment" ]; then
        environment="local"
    fi
    
    print_status "Setting up for $environment environment"
    
    # Setup environment
    if [ "$environment" = "local" ]; then
        setup_local
        if [ -z "$db_url" ]; then
            # Try to get from .env file
            if [ -f ".env" ]; then
                db_url=$(grep "^DATABASE_URL=" .env | cut -d'=' -f2- | tr -d '"')
            fi
            if [ -z "$db_url" ]; then
                print_error "Database URL not provided and not found in .env file"
                exit 1
            fi
        fi
    else
        setup_production
        if [ -z "$db_url" ]; then
            print_error "Database URL required for production setup"
            exit 1
        fi
    fi
    
    # Implement optimizations
    implement_optimizations "$environment" "$db_url"
    
    # Create monitoring tools
    create_monitoring_dashboard
    create_monitoring_api
    create_maintenance_cron
    
    if [ "$environment" = "local" ]; then
        create_docker_setup
    fi
    
    create_github_actions
    
    print_success "Performance optimization setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Start your application"
    echo "2. Open monitoring/dashboard.html to view performance metrics"
    echo "3. Set up the maintenance cron job"
    echo "4. Monitor performance improvements"
}

# Run main function with all arguments
main "$@"
