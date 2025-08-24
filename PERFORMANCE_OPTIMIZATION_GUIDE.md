# Database Performance Optimization Guide

## Overview

Your Supabase database is experiencing significant performance issues with queries taking 8+ seconds to execute. This guide provides a comprehensive solution to address these problems.

## Issues Identified

### 1. **Supabase Dashboard Introspection Queries (8+ seconds)**
- Table/view definition queries scanning system catalogs
- Function metadata queries
- Schema information queries

### 2. **Application-Specific Issues**
- Timezone queries (`SELECT name FROM pg_timezone_names`) taking 3+ seconds
- Complex JSON aggregation queries
- Missing indexes on frequently queried columns

## Immediate Actions Required

### Step 1: Run the Performance Optimization Script

1. **Open Supabase SQL Editor**
   - Go to your Supabase dashboard
   - Navigate to SQL Editor
   - Create a new query

2. **Execute the Optimization Script**
   ```sql
   -- Copy and paste the contents of scripts/performance-optimization.sql
   -- This will create indexes and optimizations
   ```

3. **Monitor Progress**
   - The script uses `CREATE INDEX CONCURRENTLY` to avoid blocking
   - Monitor the progress in the SQL editor
   - Check for any errors

### Step 2: Run the Monitoring Script

1. **Execute the Monitoring Script**
   ```sql
   -- Copy and paste the contents of scripts/monitor-performance.sql
   -- This will show you current performance metrics
   ```

2. **Review Results**
   - Look for slow queries
   - Check index usage
   - Identify tables with high bloat

## Expected Improvements

### Immediate (After Index Creation)
- **Supabase Dashboard Queries**: 80-90% reduction in execution time
- **Timezone Queries**: 95% reduction (cached in materialized view)
- **Booking Queries**: 60-80% improvement with composite indexes

### Long-term (After Maintenance)
- **Overall Query Performance**: 50-70% improvement
- **Cache Hit Ratio**: Should increase to >95%
- **Connection Efficiency**: Better connection pooling

## Monitoring and Maintenance

### Daily Monitoring
```sql
-- Check for slow queries
SELECT * FROM slow_queries_monitor;

-- Check for performance issues
SELECT * FROM check_performance_issues();
```

### Weekly Maintenance
```sql
-- Run maintenance function
SELECT perform_maintenance();

-- Refresh timezone cache
SELECT refresh_timezone_cache();
```

### Monthly Tasks
1. **Review Unused Indexes**
   ```sql
   SELECT * FROM index_usage_monitor WHERE idx_scan = 0;
   ```

2. **Check Table Bloat**
   ```sql
   SELECT schemaname, tablename, n_dead_tup, n_live_tup 
   FROM pg_stat_user_tables 
   WHERE n_dead_tup > n_live_tup * 0.1;
   ```

3. **Update Statistics**
   ```sql
   ANALYZE;
   ```

## Application-Level Optimizations

### 1. **Use Optimized Functions**
Replace direct timezone queries with:
```sql
SELECT * FROM get_timezone_names();
```

### 2. **Use Booking Statistics Function**
```sql
SELECT * FROM get_booking_stats(user_id, start_date, end_date);
```

### 3. **Implement Query Caching**
- Cache frequently accessed data in your application
- Use Redis or similar for session data
- Implement connection pooling

## Supabase-Specific Optimizations

### 1. **Connection Pooling**
- Use Supabase's connection pooling feature
- Configure appropriate pool sizes
- Monitor connection usage

### 2. **Resource Limits**
- Check your Supabase plan limits
- Monitor CPU and memory usage
- Consider upgrading if needed

### 3. **Backup and Recovery**
- Ensure regular backups are configured
- Test recovery procedures
- Monitor backup performance

## Troubleshooting

### If Queries Are Still Slow

1. **Check Index Creation**
   ```sql
   SELECT indexname, tablename, indexdef 
   FROM pg_indexes 
   WHERE indexname LIKE 'idx_%';
   ```

2. **Verify Statistics**
   ```sql
   SELECT schemaname, tablename, last_analyze 
   FROM pg_stat_user_tables;
   ```

3. **Check for Locks**
   ```sql
   SELECT * FROM pg_locks WHERE NOT granted;
   ```

### Common Issues

1. **Index Creation Fails**
   - Check available disk space
   - Verify permissions
   - Run `VACUUM ANALYZE` first

2. **Memory Issues**
   - Reduce `work_mem` setting
   - Check for memory leaks
   - Monitor connection count

3. **Lock Contention**
   - Identify long-running transactions
   - Check for deadlocks
   - Optimize transaction size

## Performance Metrics to Track

### Key Performance Indicators (KPIs)

1. **Query Response Time**
   - Average query time < 100ms
   - 95th percentile < 500ms
   - Maximum query time < 5s

2. **Cache Hit Ratio**
   - Target: >95%
   - Monitor: `pg_statio_user_tables`

3. **Connection Usage**
   - Active connections < 80% of limit
   - Idle connections < 20%

4. **Index Efficiency**
   - Index scan ratio > 80%
   - Unused indexes < 10%

### Monitoring Dashboard

Create a simple monitoring dashboard with:

```sql
-- Performance summary
SELECT 
    'Cache Hit Ratio' as metric,
    ROUND((sum(heap_blks_hit)::float / (sum(heap_blks_hit) + sum(heap_blks_read))::float) * 100, 2)::text || '%' as value
FROM pg_statio_user_tables
UNION ALL
SELECT 
    'Slow Queries (>1s)',
    COUNT(*)::text
FROM pg_stat_statements 
WHERE mean_time > 1000
UNION ALL
SELECT 
    'Active Connections',
    COUNT(*)::text
FROM pg_stat_activity 
WHERE state = 'active';
```

## Long-term Strategy

### 1. **Query Optimization**
- Review and optimize application queries
- Use prepared statements
- Implement query result caching

### 2. **Database Design**
- Normalize/denormalize as needed
- Partition large tables
- Use appropriate data types

### 3. **Infrastructure**
- Consider read replicas for heavy read workloads
- Implement proper backup strategies
- Monitor resource usage trends

### 4. **Application Architecture**
- Implement proper connection pooling
- Use async/await patterns
- Cache frequently accessed data

## Emergency Procedures

### If Database Becomes Unresponsive

1. **Check Active Queries**
   ```sql
   SELECT pid, query_start, state, query 
   FROM pg_stat_activity 
   WHERE state = 'active';
   ```

2. **Kill Long-Running Queries**
   ```sql
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'active' 
   AND query_start < now() - interval '10 minutes';
   ```

3. **Restart if Necessary**
   - Contact Supabase support
   - Document the incident
   - Review monitoring data

## Success Metrics

After implementing these optimizations, you should see:

- **Query Response Time**: 80-90% improvement
- **Supabase Dashboard**: Loads in <2 seconds
- **Application Performance**: 50-70% improvement
- **User Experience**: Significantly faster page loads
- **Resource Usage**: More efficient CPU and memory usage

## Support and Resources

- **Supabase Documentation**: https://supabase.com/docs
- **PostgreSQL Performance Tuning**: https://www.postgresql.org/docs/current/performance.html
- **Monitoring Tools**: Consider using pgAdmin, Grafana, or similar

## Next Steps

1. **Immediate**: Run the optimization scripts
2. **This Week**: Monitor performance improvements
3. **This Month**: Implement application-level optimizations
4. **Ongoing**: Regular maintenance and monitoring

Remember to test all changes in a development environment first and have a rollback plan ready.
