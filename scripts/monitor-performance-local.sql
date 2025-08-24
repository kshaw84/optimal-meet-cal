-- Local Performance Monitoring Script
-- Simplified version for local development environments

-- =============================================================================
-- 1. BASIC PERFORMANCE METRICS
-- =============================================================================

-- Cache hit ratio
SELECT 
    'Cache Hit Ratio' as metric,
    ROUND(
        (sum(heap_blks_hit)::float / (sum(heap_blks_hit) + sum(heap_blks_read))::float) * 100, 
        2
    )::text || '%' as value
FROM pg_statio_user_tables;

-- Database size
SELECT 
    'Database Size' as metric,
    pg_size_pretty(pg_database_size(current_database())) as value;

-- Active connections
SELECT 
    'Active Connections' as metric,
    COUNT(*)::text as value
FROM pg_stat_activity 
WHERE state = 'active';

-- =============================================================================
-- 2. TABLE PERFORMANCE
-- =============================================================================

-- Table statistics
SELECT 
    schemaname,
    tablename,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    CASE 
        WHEN n_live_tup > 0 THEN 
            ROUND((n_dead_tup::float / n_live_tup::float) * 100, 2)
        ELSE 0 
    END as bloat_percentage,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables 
ORDER BY n_dead_tup DESC
LIMIT 10;

-- =============================================================================
-- 3. INDEX USAGE
-- =============================================================================

-- Most used indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC
LIMIT 10;

-- Unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes 
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 10;

-- =============================================================================
-- 4. CONNECTION ANALYSIS
-- =============================================================================

-- Active connections by user
SELECT 
    usename,
    application_name,
    client_addr,
    state,
    count(*) as connection_count
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY usename, application_name, client_addr, state
ORDER BY connection_count DESC;

-- Long-running queries
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    LEFT(query, 100) as query_preview
FROM pg_stat_activity 
WHERE state = 'active' 
  AND query_start < now() - interval '5 minutes'
ORDER BY query_start;

-- =============================================================================
-- 5. PERFORMANCE SUMMARY
-- =============================================================================

-- Overall performance summary
SELECT 
    'Database Performance Summary' as metric,
    current_database() as value
UNION ALL
SELECT 
    'Total Tables',
    COUNT(*)::text
FROM pg_stat_user_tables
UNION ALL
SELECT 
    'Total Indexes',
    COUNT(*)::text
FROM pg_stat_user_indexes
UNION ALL
SELECT 
    'Active Connections',
    COUNT(*)::text
FROM pg_stat_activity
WHERE state = 'active'
UNION ALL
SELECT 
    'Cache Hit Ratio',
    ROUND(
        (sum(heap_blks_hit)::float / (sum(heap_blks_hit) + sum(heap_blks_read))::float) * 100, 
        2
    )::text || '%'
FROM pg_statio_user_tables
UNION ALL
SELECT 
    'Database Size',
    pg_size_pretty(pg_database_size(current_database()))
UNION ALL
SELECT 
    'Uptime',
    EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))::integer::text || ' seconds';

-- =============================================================================
-- 6. OPTIMIZATION RECOMMENDATIONS
-- =============================================================================

-- Tables that might benefit from VACUUM
SELECT 
    'Tables needing VACUUM' as recommendation,
    schemaname || '.' || tablename as table_name,
    n_dead_tup as dead_tuples,
    n_live_tup as live_tuples
FROM pg_stat_user_tables 
WHERE n_dead_tup > n_live_tup * 0.05  -- More than 5% dead tuples
ORDER BY n_dead_tup DESC
LIMIT 5;

-- Large unused indexes
SELECT 
    'Large unused indexes' as recommendation,
    schemaname || '.' || tablename || '.' || indexname as index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes 
WHERE idx_scan = 0 AND pg_relation_size(indexrelid) > 1024*1024  -- > 1MB
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 5;

-- =============================================================================
-- 7. CUSTOM FUNCTIONS STATUS
-- =============================================================================

-- Check if our optimization functions exist
SELECT 
    'Optimization Functions' as check_type,
    proname as function_name,
    CASE WHEN proname IS NOT NULL THEN 'Installed' ELSE 'Missing' END as status
FROM pg_proc 
WHERE proname IN ('perform_maintenance', 'refresh_timezone_cache', 'get_timezone_names', 'check_performance_issues')
ORDER BY proname;

-- =============================================================================
-- 8. MATERIALIZED VIEW STATUS
-- =============================================================================

-- Check if our materialized views exist
SELECT 
    'Materialized Views' as check_type,
    matviewname as view_name,
    'Installed' as status
FROM pg_matviews 
WHERE matviewname = 'cached_timezone_names'
UNION ALL
SELECT 
    'Materialized Views' as check_type,
    'cached_timezone_names' as view_name,
    'Missing' as status
WHERE NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE matviewname = 'cached_timezone_names'
);
