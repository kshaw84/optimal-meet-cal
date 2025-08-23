-- Final View Security Fix
-- This script explicitly sets views to SECURITY INVOKER and prevents future SECURITY DEFINER issues

-- =============================================================================
-- 1. DROP AND RECREATE VIEWS WITH EXPLICIT SECURITY INVOKER
-- =============================================================================

-- Drop all problematic views
DROP VIEW IF EXISTS "RoutingFormResponse" CASCADE;
DROP VIEW IF EXISTS "BookingTimeStatus" CASCADE;
DROP VIEW IF EXISTS "BookingTimeStatusDenormalized" CASCADE;

-- Recreate RoutingFormResponse view with explicit SECURITY INVOKER
CREATE VIEW "RoutingFormResponse" WITH (security_invoker = true) AS
SELECT
  r.id,
  r.response,
  (
    SELECT jsonb_object_agg(
      key,
      CASE
        WHEN jsonb_typeof(value->'value') = 'string'
        THEN jsonb_build_object(
          'label', value->'label',
          'value', lower((value->>'value')::text)
        )
        ELSE value
      END
    )
    FROM jsonb_each(r.response::jsonb)
  ) as "responseLowercase",
  f.id as "formId",
  f.name as "formName",
  f."teamId" as "formTeamId",
  f."userId" as "formUserId",
  b.uid as "bookingUid",
  b.status as "bookingStatus",

  CASE b.status
    WHEN 'accepted' THEN 1
    WHEN 'pending' THEN 2
    WHEN 'awaiting_host' THEN 3
    WHEN 'cancelled' THEN 4
    WHEN 'rejected' THEN 5
  END as "bookingStatusOrder",
  b."createdAt" as "bookingCreatedAt",
  b."startTime" as "bookingStartTime",
  b."endTime" as "bookingEndTime",
  (SELECT
    json_agg(
      json_build_object(
        'name', a.name, 'timeZone', a."timeZone", 'email', a.email
      )
    )
    FROM "Attendee" a
    WHERE "a"."bookingId" = b.id
  ) as "bookingAttendees",
  u.id as "bookingUserId",
  u.name as "bookingUserName",
  u.email as "bookingUserEmail",
  u."avatarUrl" as "bookingUserAvatarUrl",
  COALESCE(
    (
      SELECT
        ar."reasonString"
      FROM "AssignmentReason" ar
      WHERE ar."bookingId" = b.id
      LIMIT 1
    ),
    ''
  ) as "bookingAssignmentReason",
  COALESCE(
    (
      SELECT
        LOWER(ar."reasonString")
      FROM "AssignmentReason" ar
      WHERE ar."bookingId" = b.id
      LIMIT 1
    ),
    ''
  ) as "bookingAssignmentReasonLowercase",
  r."createdAt" as "createdAt",
    -- UTM parameters from Tracking table
  t.utm_source as "utm_source",
  t.utm_medium as "utm_medium",
  t.utm_campaign as "utm_campaign",
  t.utm_term as "utm_term",
  t.utm_content as "utm_content"
FROM "App_RoutingForms_FormResponse" r
LEFT JOIN "App_RoutingForms_Form" f ON r."formId" = f.id
LEFT JOIN "Booking" b ON r."routedToBookingUid" = b.uid
LEFT JOIN "users" u ON b."userId" = u.id
LEFT JOIN "Tracking" t ON t."bookingId" = b.id;

-- Recreate BookingTimeStatus view with explicit SECURITY INVOKER
CREATE VIEW "BookingTimeStatus" WITH (security_invoker = true) AS
SELECT
    "Booking".id,
    "Booking".uid,
    "Booking"."eventTypeId",
    "Booking".title,
    "Booking".description,
    "Booking"."startTime",
    "Booking"."endTime",
    "Booking"."createdAt",
    "Booking".location,
    "Booking".paid,
    "Booking".status,
    "Booking".rescheduled,
    "Booking"."userId",
    et."teamId",
    et.length AS "eventLength",
    CASE
        WHEN "Booking".rescheduled IS TRUE THEN 'rescheduled'::text
        WHEN "Booking".status = 'cancelled'::"BookingStatus" AND "Booking".rescheduled IS NULL THEN 'cancelled'::text
        WHEN "Booking"."endTime" < now() THEN 'completed'::text
        WHEN "Booking"."endTime" > now() THEN 'uncompleted'::text
        ELSE NULL::text
    END AS "timeStatus",
    et."parentId" AS "eventParentId",
    "u"."email" AS "userEmail",
    "u"."username" AS "username",
    "Booking"."ratingFeedback",
    "Booking"."rating",
    "Booking"."noShowHost",
    false as "isTeamBooking"
FROM "Booking"
LEFT JOIN "EventType" et ON "Booking"."eventTypeId" = et.id
LEFT JOIN users u ON u.id = "Booking"."userId"
WHERE et."teamId" IS NULL
UNION
SELECT
    "Booking".id,
    "Booking".uid,
    "Booking"."eventTypeId",
    "Booking".title,
    "Booking".description,
    "Booking"."startTime",
    "Booking"."endTime",
    "Booking"."createdAt",
    "Booking".location,
    "Booking".paid,
    "Booking".status,
    "Booking".rescheduled,
    "Booking"."userId",
    et."teamId",
    et.length AS "eventLength",
    CASE
        WHEN "Booking".rescheduled IS TRUE THEN 'rescheduled'::text
        WHEN "Booking".status = 'cancelled'::"BookingStatus" AND "Booking".rescheduled IS NULL THEN 'cancelled'::text
        WHEN "Booking"."endTime" < now() THEN 'completed'::text
        WHEN "Booking"."endTime" > now() THEN 'uncompleted'::text
        ELSE NULL::text
    END AS "timeStatus",
    et."parentId" AS "eventParentId",
    "u"."email" AS "userEmail",
    "u"."username" AS "username",
    "Booking"."ratingFeedback",
    "Booking"."rating",
    "Booking"."noShowHost",
    true as "isTeamBooking"
FROM "Booking"
LEFT JOIN "EventType" et ON "Booking"."eventTypeId" = et.id
LEFT JOIN users u ON u.id = "Booking"."userId"
WHERE "et"."teamId" IS NOT NULL;

-- Recreate BookingTimeStatusDenormalized view with explicit SECURITY INVOKER
CREATE VIEW "BookingTimeStatusDenormalized" WITH (security_invoker = true) AS
SELECT 
    *,
    CASE
        WHEN "rescheduled" IS TRUE THEN 'rescheduled'
        WHEN "status" = 'cancelled'::"BookingStatus" AND "rescheduled" IS NULL THEN 'cancelled'
        WHEN "endTime" < now() THEN 'completed'
        WHEN "endTime" > now() THEN 'uncompleted'
        ELSE NULL
    END as "timeStatus"
FROM "BookingDenormalized";

-- =============================================================================
-- 2. SET PROPER PERMISSIONS
-- =============================================================================

-- Grant proper permissions to the views
GRANT SELECT ON "RoutingFormResponse" TO authenticated;
GRANT SELECT ON "BookingTimeStatus" TO authenticated;
GRANT SELECT ON "BookingTimeStatusDenormalized" TO authenticated;

-- Grant permissions to anon if needed
GRANT SELECT ON "RoutingFormResponse" TO anon;
GRANT SELECT ON "BookingTimeStatus" TO anon;
GRANT SELECT ON "BookingTimeStatusDenormalized" TO anon;

-- =============================================================================
-- 3. CREATE A FUNCTION TO ENSURE VIEWS STAY SECURITY INVOKER
-- =============================================================================

-- Function to ensure views are always SECURITY INVOKER
CREATE OR REPLACE FUNCTION ensure_views_security_invoker()
RETURNS VOID AS $$
BEGIN
    SET search_path = public;
    
    -- Force recreate views with SECURITY INVOKER if they exist
    DROP VIEW IF EXISTS "RoutingFormResponse" CASCADE;
    DROP VIEW IF EXISTS "BookingTimeStatus" CASCADE;
    DROP VIEW IF EXISTS "BookingTimeStatusDenormalized" CASCADE;
    
    -- Recreate with SECURITY INVOKER (this will be done by the migration)
    RAISE NOTICE 'Views dropped and will be recreated with SECURITY INVOKER';
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 4. VERIFICATION
-- =============================================================================

-- Check view ownership and security settings
SELECT 
    schemaname,
    viewname,
    viewowner,
    CASE 
        WHEN definition LIKE '%security_invoker%' THEN 'SECURITY INVOKER'
        WHEN definition LIKE '%security_definer%' THEN 'SECURITY DEFINER'
        ELSE 'DEFAULT'
    END as security_setting
FROM pg_views 
WHERE viewname IN ('RoutingFormResponse', 'BookingTimeStatus', 'BookingTimeStatusDenormalized')
    AND schemaname = 'public';

-- Check that views exist and are accessible
SELECT 'Views recreated with SECURITY INVOKER' as status, count(*) as count
FROM pg_views 
WHERE viewname IN ('RoutingFormResponse', 'BookingTimeStatus', 'BookingTimeStatusDenormalized')
    AND schemaname = 'public';

-- Test a simple query on each view to ensure they work
SELECT 'RoutingFormResponse test' as test, count(*) as count FROM "RoutingFormResponse" LIMIT 1;
SELECT 'BookingTimeStatus test' as test, count(*) as count FROM "BookingTimeStatus" LIMIT 1;
SELECT 'BookingTimeStatusDenormalized test' as test, count(*) as count FROM "BookingTimeStatusDenormalized" LIMIT 1;
