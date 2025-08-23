# Supabase Security Fixes

This document outlines the security issues identified by Supabase linter and the fixes applied to resolve them.

## Issues Identified

### 1. Security Definer Views (ERROR)
**Problem**: Views were defined with `SECURITY DEFINER` property, which means they execute with the permissions of the view creator rather than the querying user.

**Affected Views**:
- `public.RoutingFormResponse`
- `public.BookingTimeStatusDenormalized`
- `public.BookingTimeStatus`

**Fix**: Recreated all views without `SECURITY DEFINER` to ensure they respect Row Level Security (RLS) policies.

### 2. RLS Disabled in Public (ERROR)
**Problem**: The `_prisma_migrations` table was public but didn't have Row Level Security enabled.

**Fix**: 
- Enabled RLS on the `_prisma_migrations` table
- Created a policy that allows only authenticated users to read migration records

### 3. Function Search Path Mutable (WARNING)
**Problem**: Functions didn't have their search path explicitly set, making them vulnerable to search path injection attacks.

**Affected Functions**: 25+ functions including:
- `calculate_booking_status_order`
- `calculate_is_team_booking`
- `refresh_booking_time_status_denormalized`
- `trigger_refresh_routing_form_response_denormalized`
- And many more...

**Fix**: Added `SET search_path = public;` at the beginning of each function to ensure they always use the correct schema.

## Migration Applied

The migration `20250101000000_fix_supabase_security_issues` addresses all these issues:

1. **Drops and recreates views** without `SECURITY DEFINER`
2. **Enables RLS** on the `_prisma_migrations` table with appropriate policies
3. **Updates all functions** to include explicit search path setting

## Security Impact

### Before Fixes
- Views could bypass RLS policies
- Migration table was publicly accessible
- Functions were vulnerable to search path injection

### After Fixes
- Views respect RLS policies and user permissions
- Migration table is protected by RLS
- Functions are protected against search path injection attacks

## Applying the Fixes

To apply these security fixes:

1. **Run the migration**:
   ```bash
   yarn workspace @calcom/prisma db-migrate
   ```

2. **Verify the fixes**:
   - Check that views no longer have `SECURITY DEFINER`
   - Confirm RLS is enabled on `_prisma_migrations`
   - Verify functions have explicit search paths

3. **Test functionality**:
   - Ensure all views still work correctly
   - Verify that RLS policies don't break legitimate access
   - Test that functions execute properly

## Monitoring

After applying these fixes, monitor your Supabase linter to ensure:
- No more security definer view errors
- No more RLS disabled errors
- No more function search path mutable warnings

## Additional Recommendations

1. **Review RLS Policies**: Consider implementing more granular RLS policies for your application tables
2. **Regular Security Audits**: Run Supabase linter regularly to catch new security issues
3. **Function Security**: Always set explicit search paths in new functions
4. **View Security**: Avoid using `SECURITY DEFINER` unless absolutely necessary

## References

- [Supabase Database Linter Documentation](https://supabase.com/docs/guides/database/database-linter)
- [PostgreSQL Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [PostgreSQL Search Path Security](https://www.postgresql.org/docs/current/runtime-config-client.html#GUC-SEARCH-PATH)
