-- Performance Monitoring Script
-- Run this script to monitor database performance and identify issues

-- =============================================================================
-- 1. SLOW QUERY ANALYSIS
-- =============================================================================

-- Top 10 slowest queries by average execution time
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    stddev_time,
    min_time,
    max_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    shared_blks_written,
    temp_blks_read,
    temp_blks_written,
    blk_read_time,
    blk_write_time
FROM pg_stat_statements 
WHERE mean_time > 1000  -- Queries taking more than 1 second on average
ORDER BY mean_time DESC
LIMIT 10;

-- =============================================================================
-- 2. INDEX USAGE ANALYSIS
-- =============================================================================

-- Most used indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    idx_blks_read,
    idx_blks_hit
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC
LIMIT 20;

-- Unused indexes (potential candidates for removal)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes 
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 10;

-- =============================================================================
-- 3. TABLE PERFORMANCE ANALYSIS
-- =============================================================================

-- Table statistics and bloat analysis
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    CASE 
        WHEN n_live_tup > 0 THEN 
            ROUND((n_dead_tup::float / n_live_tup::float) * 100, 2)
        ELSE 0 
    END as bloat_percentage,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables 
ORDER BY n_dead_tup DESC
LIMIT 20;

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
    query
FROM pg_stat_activity 
WHERE state = 'active' 
  AND query_start < now() - interval '5 minutes'
ORDER BY query_start;

-- =============================================================================
-- 5. CACHE HIT RATIO ANALYSIS
-- =============================================================================

-- Overall cache hit ratio
SELECT 
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 as cache_hit_ratio
FROM pg_statio_user_tables;

-- Cache hit ratio by table
SELECT 
    schemaname,
    tablename,
    heap_blks_hit,
    heap_blks_read,
    CASE 
        WHEN (heap_blks_hit + heap_blks_read) > 0 THEN
            ROUND((heap_blks_hit::float / (heap_blks_hit + heap_blks_read)::float) * 100, 2)
        ELSE 0 
    END as cache_hit_ratio
FROM pg_statio_user_tables 
WHERE (heap_blks_hit + heap_blks_read) > 0
ORDER BY cache_hit_ratio ASC
LIMIT 20;

-- =============================================================================
-- 6. LOCK ANALYSIS
-- =============================================================================

-- Current locks
SELECT 
    l.pid,
    l.mode,
    l.granted,
    a.usename,
    a.application_name,
    a.query_start,
    a.state,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted
ORDER BY a.query_start;

-- =============================================================================
-- 7. WAL (Write-Ahead Log) ANALYSIS
-- =============================================================================

-- WAL statistics
SELECT 
    wal_records,
    wal_fpi,
    wal_bytes,
    wal_buffers_full,
    wal_write,
    wal_sync,
    wal_write_time,
    wal_sync_time
FROM pg_stat_wal;

-- =============================================================================
-- 8. BUFFER ANALYSIS
-- =============================================================================

-- Buffer usage
SELECT 
    schemaname,
    tablename,
    heap_blks_read,
    heap_blks_hit,
    idx_blks_read,
    idx_blks_hit,
    toast_blks_read,
    toast_blks_hit,
    tidx_blks_read,
    tidx_blks_hit
FROM pg_statio_user_tables 
ORDER BY (heap_blks_read + idx_blks_read) DESC
LIMIT 20;

-- =============================================================================
-- 9. FUNCTION PERFORMANCE
-- =============================================================================

-- Function call statistics
SELECT 
    schemaname,
    funcname,
    calls,
    total_time,
    mean_time,
    stddev_time
FROM pg_stat_user_functions 
WHERE calls > 0
ORDER BY total_time DESC
LIMIT 20;

-- =============================================================================
-- 10. SYSTEM RESOURCE USAGE
-- =============================================================================

-- Database size
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
WHERE datname = current_database();

-- Schema sizes
SELECT 
    schema_name,
    pg_size_pretty(sum(table_size)::bigint) as schema_size,
    sum(table_size)::bigint as schema_size_bytes
FROM (
    SELECT 
        schemaname as schema_name,
        pg_total_relation_size(schemaname||'.'||tablename) as table_size
    FROM pg_tables
    WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
) t
GROUP BY schema_name
ORDER BY schema_size_bytes DESC;

-- =============================================================================
-- 11. PERFORMANCE RECOMMENDATIONS
-- =============================================================================

-- Generate performance recommendations
WITH recommendations AS (
    -- Tables with high bloat
    SELECT 
        'high_bloat' as issue_type,
        'Table ' || schemaname || '.' || tablename || ' has ' || 
        ROUND((n_dead_tup::float / n_live_tup::float) * 100, 2) || '% bloat' as description,
        'high' as severity
    FROM pg_stat_user_tables 
    WHERE n_live_tup > 0 AND (n_dead_tup::float / n_live_tup::float) > 0.1
    
    UNION ALL
    
    -- Tables without recent analyze
    SELECT 
        'stale_statistics' as issue_type,
        'Table ' || schemaname || '.' || tablename || ' has stale statistics' as description,
        'medium' as severity
    FROM pg_stat_user_tables 
    WHERE last_analyze IS NULL OR last_analyze < now() - interval '7 days'
    
    UNION ALL
    
    -- Large unused indexes
    SELECT 
        'unused_index' as issue_type,
        'Large unused index: ' || indexname || ' on ' || tablename || 
        ' (' || pg_size_pretty(pg_relation_size(indexrelid)) || ')' as description,
        'medium' as severity
    FROM pg_stat_user_indexes 
    WHERE idx_scan = 0 AND pg_relation_size(indexrelid) > 1024*1024  -- > 1MB
    
    UNION ALL
    
    -- Slow queries
    SELECT 
        'slow_query' as issue_type,
        'Query taking ' || ROUND(mean_time/1000, 2) || 's on average' as description,
        'high' as severity
    FROM pg_stat_statements 
    WHERE mean_time > 5000  -- > 5 seconds
    LIMIT 5
)
SELECT 
    issue_type,
    description,
    severity,
    COUNT(*) as count
FROM recommendations
GROUP BY issue_type, description, severity
ORDER BY 
    CASE severity 
        WHEN 'high' THEN 1 
        WHEN 'medium' THEN 2 
        WHEN 'low' THEN 3 
    END,
    count DESC;

-- =============================================================================
-- 12. QUERY PATTERN ANALYSIS
-- =============================================================================

-- Most common query patterns
SELECT 
    CASE 
        WHEN query LIKE 'SELECT%' THEN 'SELECT'
        WHEN query LIKE 'INSERT%' THEN 'INSERT'
        WHEN query LIKE 'UPDATE%' THEN 'UPDATE'
        WHEN query LIKE 'DELETE%' THEN 'DELETE'
        ELSE 'OTHER'
    END as query_type,
    COUNT(*) as count,
    AVG(mean_time) as avg_time,
    SUM(total_time) as total_time
FROM pg_stat_statements 
GROUP BY query_type
ORDER BY total_time DESC;

-- =============================================================================
-- 13. TIME-BASED ANALYSIS
-- =============================================================================

-- Queries by time of day (if you have query_start tracking)
-- Note: This requires additional setup to track query timing

-- =============================================================================
-- 14. SUMMARY REPORT
-- =============================================================================

-- Performance summary
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
-- 15. CLEANUP RECOMMENDATIONS
-- =============================================================================

-- Tables that might benefit from VACUUM
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables 
WHERE n_dead_tup > n_live_tup * 0.05  -- More than 5% dead tuples
ORDER BY n_dead_tup DESC
LIMIT 10;
