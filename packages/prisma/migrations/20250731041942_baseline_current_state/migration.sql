-- Migration: Baseline Current State
-- This migration reflects the actual current state of the database after security fixes were applied in Supabase
-- Based on drift detection analysis

-- =============================================================================
-- ADDED TABLES
-- =============================================================================

-- omDemoRequests table was added (not part of security fixes, but part of current state)

-- =============================================================================
-- SECURITY FIXES APPLIED IN SUPABASE
-- =============================================================================

-- The following duplicate indexes were removed as part of security fixes:

-- ApiKey table
-- Removed duplicate unique index on (id) - keeping primary key only

-- App table  
-- Removed duplicate unique index on (slug) - keeping primary key only

-- AssignmentReason table
-- Removed duplicate unique index on (id) - keeping primary key only

-- BookingDenormalized table
-- Removed duplicate unique index on (id) - keeping primary key only

-- CalendarCache table
-- Removed duplicate unique index on (credentialId, key) - keeping primary key only

-- Feature table
-- Removed duplicate unique index on (slug) - keeping primary key only

-- OAuthClient table
-- Removed duplicate unique index on (clientId) - keeping primary key only

-- PlatformBilling table
-- Removed duplicate unique index on (id) - keeping primary key only

-- Task table
-- Removed duplicate unique index on (id) - keeping primary key only

-- Watchlist table
-- Removed duplicate unique index on (id) - keeping primary key only

-- Webhook table
-- Removed duplicate unique index on (id) - keeping primary key only

-- =============================================================================
-- PERFORMANCE IMPROVEMENTS APPLIED IN SUPABASE
-- =============================================================================

-- The following indexes were added for performance:

-- Booking table
-- Added index on (startTime)
-- Added index on (status, startTime)

-- Credential table
-- Added index on (type)
-- Added index on (userId)

-- EventType table
-- Added index on (slug)
-- Added index on (userId, slug)

-- users table
-- Added index on (email)
-- Added index on (organizationId)
-- Added index on (role)

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================
-- This migration documents the current state of the database after:
-- 1. Security fixes were applied in Supabase SQL editor
-- 2. Performance improvements were made
-- 3. New tables were added

-- Future migrations should maintain these security and performance improvements 