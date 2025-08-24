-- System Catalog Optimization Script for Supabase
-- These indexes help Supabase dashboard queries run faster
-- Modified for Supabase SQL Editor (no CONCURRENTLY)

-- Note: These may require superuser privileges in Supabase
-- If you get permission errors, these optimizations are for Supabase dashboard only

-- Index on pg_class for table/view lookups
CREATE INDEX IF NOT EXISTS idx_pg_class_relkind_nspname 
ON pg_class(relkind, relnamespace) 
WHERE relkind IN ('r', 'v', 'm', 'f', 'p');

-- Index on pg_namespace for schema filtering
CREATE INDEX IF NOT EXISTS idx_pg_namespace_nspname 
ON pg_namespace(nspname);

-- Index on pg_proc for function metadata
CREATE INDEX IF NOT EXISTS idx_pg_proc_prokind_pronamespace 
ON pg_proc(prokind, pronamespace);

-- Index on pg_attribute for column information
CREATE INDEX IF NOT EXISTS idx_pg_attribute_attrelid_attnum 
ON pg_attribute(attrelid, attnum) 
WHERE NOT attisdropped;

-- Index on pg_constraint for constraint information
CREATE INDEX IF NOT EXISTS idx_pg_constraint_contype_conrelid 
ON pg_constraint(contype, conrelid);
