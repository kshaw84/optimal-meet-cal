-- Performance Optimization Script for Supabase
-- This script addresses the slow queries identified in the performance analysis

-- =============================================================================
-- 1. OPTIMIZE SYSTEM CATALOG QUERIES (Supabase Dashboard)
-- =============================================================================

-- Create indexes on frequently accessed system catalog columns
-- These will help Supabase dashboard queries run faster

-- Index on pg_class for table/view lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pg_class_relkind_nspname 
ON pg_class(relkind, relnamespace) 
WHERE relkind IN ('r', 'v', 'm', 'f', 'p');

-- Index on pg_namespace for schema filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pg_namespace_nspname 
ON pg_namespace(nspname);

-- Index on pg_proc for function metadata
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pg_proc_prokind_pronamespace 
ON pg_proc(prokind, pronamespace);

-- Index on pg_attribute for column information
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pg_attribute_attrelid_attnum 
ON pg_attribute(attrelid, attnum) 
WHERE NOT attisdropped;

-- Index on pg_constraint for constraint information
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pg_constraint_contype_conrelid 
ON pg_constraint(contype, conrelid);

-- =============================================================================
-- 2. OPTIMIZE APPLICATION-SPECIFIC QUERIES
-- =============================================================================

-- Cache timezone names in a materialized view to avoid repeated pg_timezone_names calls
CREATE MATERIALIZED VIEW IF NOT EXISTS cached_timezone_names AS
SELECT name FROM pg_timezone_names;

-- Create index on the materialized view
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cached_timezone_names_name 
ON cached_timezone_names(name);

-- Create a function to refresh the timezone cache (run periodically)
CREATE OR REPLACE FUNCTION refresh_timezone_cache()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY cached_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 3. OPTIMIZE BOOKING-RELATED QUERIES
-- =============================================================================

-- Add composite indexes for common booking queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_booking_user_status_starttime 
ON "Booking"("userId", "status", "startTime");

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_booking_eventtype_status_starttime 
ON "Booking"("eventTypeId", "status", "startTime");

-- Add index for booking date range queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_booking_starttime_endtime_status 
ON "Booking"("startTime", "endTime", "status");

-- =============================================================================
-- 4. OPTIMIZE ROUTING FORM RESPONSES
-- =============================================================================

-- Add indexes for routing form response queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_routing_form_response_formid_createdat 
ON "RoutingFormResponseDenormalized"("formId", "createdAt");

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_routing_form_response_bookinguid 
ON "RoutingFormResponseDenormalized"("bookingUid") 
WHERE "bookingUid" IS NOT NULL;

-- =============================================================================
-- 5. OPTIMIZE USER AND TEAM QUERIES
-- =============================================================================

-- Add composite indexes for user queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_organization_role 
ON "users"("organizationId", "role");

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email_verified 
ON "users"("email", "emailVerified");

-- =============================================================================
-- 6. OPTIMIZE EVENT TYPE QUERIES
-- =============================================================================

-- Add indexes for event type queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_eventtype_userid_slug_active 
ON "EventType"("userId", "slug") 
WHERE "hidden" = false;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_eventtype_teamid_slug_active 
ON "EventType"("teamId", "slug") 
WHERE "hidden" = false;

-- =============================================================================
-- 7. OPTIMIZE CREDENTIAL QUERIES
-- =============================================================================

-- Add indexes for credential queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_credential_userid_type_invalid 
ON "Credential"("userId", "type", "invalid");

-- =============================================================================
-- 8. ANALYZE TABLES FOR BETTER QUERY PLANNING
-- =============================================================================

-- Analyze all tables to update statistics for better query planning
ANALYZE "Booking";
ANALYZE "EventType";
ANALYZE "users";
ANALYZE "Credential";
ANALYZE "RoutingFormResponseDenormalized";
ANALYZE "App_RoutingForms_FormResponse";

-- =============================================================================
-- 9. CREATE PERFORMANCE MONITORING VIEWS
-- =============================================================================

-- Create a view to monitor slow queries
CREATE OR REPLACE VIEW slow_queries_monitor AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    shared_blks_written,
    shared_blks_dirtied,
    temp_blks_read,
    temp_blks_written,
    blk_read_time,
    blk_write_time
FROM pg_stat_statements 
WHERE mean_time > 1000  -- Queries taking more than 1 second on average
ORDER BY mean_time DESC;

-- Create a view to monitor index usage
CREATE OR REPLACE VIEW index_usage_monitor AS
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;

-- =============================================================================
-- 10. SET UP AUTOMATIC MAINTENANCE
-- =============================================================================

-- Create a function for regular maintenance
CREATE OR REPLACE FUNCTION perform_maintenance()
RETURNS void AS $$
BEGIN
    -- Refresh timezone cache
    PERFORM refresh_timezone_cache();
    
    -- Analyze tables
    ANALYZE;
    
    -- Log maintenance completion
    RAISE NOTICE 'Maintenance completed at %', now();
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 11. OPTIMIZE JSON OPERATIONS
-- =============================================================================

-- Create indexes on JSONB columns that are frequently queried
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_booking_metadata_gin 
ON "Booking" USING GIN ("metadata");

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_eventtype_locations_gin 
ON "EventType" USING GIN ("locations");

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_credential_key_gin 
ON "Credential" USING GIN ("key");

-- =============================================================================
-- 12. SET UP CONNECTION POOLING OPTIMIZATIONS
-- =============================================================================

-- Set optimal PostgreSQL parameters for your workload
-- Note: These may need to be adjusted based on your Supabase plan

-- Increase work_mem for complex queries
-- ALTER SYSTEM SET work_mem = '256MB';  -- Adjust based on your plan

-- Increase shared_buffers for better caching
-- ALTER SYSTEM SET shared_buffers = '256MB';  -- Adjust based on your plan

-- Optimize for read-heavy workload
-- ALTER SYSTEM SET effective_cache_size = '1GB';  -- Adjust based on your plan

-- =============================================================================
-- 13. CREATE QUERY OPTIMIZATION FUNCTIONS
-- =============================================================================

-- Function to get optimized timezone list
CREATE OR REPLACE FUNCTION get_timezone_names()
RETURNS TABLE(name text) AS $$
BEGIN
    RETURN QUERY SELECT t.name FROM cached_timezone_names t;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get booking statistics with optimized queries
CREATE OR REPLACE FUNCTION get_booking_stats(
    p_user_id integer DEFAULT NULL,
    p_start_date timestamp DEFAULT NULL,
    p_end_date timestamp DEFAULT NULL
)
RETURNS TABLE(
    total_bookings bigint,
    accepted_bookings bigint,
    cancelled_bookings bigint,
    pending_bookings bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::bigint as total_bookings,
        COUNT(*) FILTER (WHERE "status" = 'accepted')::bigint as accepted_bookings,
        COUNT(*) FILTER (WHERE "status" = 'cancelled')::bigint as cancelled_bookings,
        COUNT(*) FILTER (WHERE "status" = 'pending')::bigint as pending_bookings
    FROM "Booking" b
    WHERE (p_user_id IS NULL OR b."userId" = p_user_id)
      AND (p_start_date IS NULL OR b."startTime" >= p_start_date)
      AND (p_end_date IS NULL OR b."startTime" <= p_end_date);
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- 14. MONITORING AND ALERTS
-- =============================================================================

-- Create a function to check for performance issues
CREATE OR REPLACE FUNCTION check_performance_issues()
RETURNS TABLE(
    issue_type text,
    description text,
    severity text
) AS $$
BEGIN
    -- Check for slow queries
    RETURN QUERY
    SELECT 
        'slow_query'::text as issue_type,
        'Query taking more than 5 seconds on average'::text as description,
        'high'::text as severity
    FROM pg_stat_statements 
    WHERE mean_time > 5000
    LIMIT 1;
    
    -- Check for unused indexes
    RETURN QUERY
    SELECT 
        'unused_index'::text as issue_type,
        'Index ' || indexname || ' on ' || tablename || ' has no scans'::text as description,
        'medium'::text as severity
    FROM pg_stat_user_indexes 
    WHERE idx_scan = 0
    LIMIT 5;
    
    -- Check for table bloat
    RETURN QUERY
    SELECT 
        'table_bloat'::text as issue_type,
        'Table ' || tablename || ' may have bloat'::text as description,
        'medium'::text as severity
    FROM pg_stat_user_tables 
    WHERE n_dead_tup > n_live_tup * 0.1
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 15. FINAL OPTIMIZATIONS
-- =============================================================================

-- Vacuum analyze to clean up and update statistics
VACUUM ANALYZE;

-- Grant necessary permissions
GRANT SELECT ON slow_queries_monitor TO authenticated;
GRANT SELECT ON index_usage_monitor TO authenticated;
GRANT EXECUTE ON FUNCTION get_timezone_names() TO authenticated;
GRANT EXECUTE ON FUNCTION get_booking_stats(integer, timestamp, timestamp) TO authenticated;
GRANT EXECUTE ON FUNCTION check_performance_issues() TO authenticated;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'Performance optimization script completed successfully at %', now();
    RAISE NOTICE 'Monitor performance using: SELECT * FROM slow_queries_monitor;';
    RAISE NOTICE 'Check for issues using: SELECT * FROM check_performance_issues();';
END $$;
