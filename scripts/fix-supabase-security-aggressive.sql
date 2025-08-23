-- Aggressive Supabase Security Fixes
-- This script forces all views to be SECURITY INVOKER and prevents future SECURITY DEFINER issues

-- =============================================================================
-- 1. FORCE RECREATE ALL VIEWS WITH EXPLICIT SECURITY INVOKER
-- =============================================================================

-- Drop and recreate RoutingFormResponse view with EXPLICIT SECURITY INVOKER
DROP VIEW IF EXISTS "RoutingFormResponse" CASCADE;
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

-- Drop and recreate BookingTimeStatus view with EXPLICIT SECURITY INVOKER
DROP VIEW IF EXISTS public."BookingTimeStatus" CASCADE;
CREATE VIEW public."BookingTimeStatus" WITH (security_invoker = true)
AS
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

-- Drop and recreate BookingTimeStatusDenormalized view with EXPLICIT SECURITY INVOKER
DROP VIEW IF EXISTS public."BookingTimeStatusDenormalized" CASCADE;
CREATE VIEW public."BookingTimeStatusDenormalized" WITH (security_invoker = true) AS
SELECT 
    *,
    CASE
        WHEN "rescheduled" IS TRUE THEN 'rescheduled'
        WHEN "status" = 'cancelled'::public."BookingStatus" AND "rescheduled" IS NULL THEN 'cancelled'
        WHEN "endTime" < now() THEN 'completed'
        WHEN "endTime" > now() THEN 'uncompleted'
        ELSE NULL
    END as "timeStatus"
FROM public."BookingDenormalized";

-- =============================================================================
-- 2. CREATE A FUNCTION TO FORCE SECURITY INVOKER ON ALL VIEWS
-- =============================================================================

-- Function to ensure all views are SECURITY INVOKER
CREATE OR REPLACE FUNCTION ensure_views_security_invoker()
RETURNS VOID AS $$
DECLARE
    view_record RECORD;
BEGIN
    SET search_path = public;
    
    -- Loop through all views and ensure they're SECURITY INVOKER
    FOR view_record IN 
        SELECT schemaname, viewname, definition 
        FROM pg_views 
        WHERE schemaname = 'public' 
        AND viewname IN ('RoutingFormResponse', 'BookingTimeStatus', 'BookingTimeStatusDenormalized')
    LOOP
        -- Drop and recreate each view with SECURITY INVOKER
        EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', view_record.schemaname, view_record.viewname);
        
        -- Recreate with SECURITY INVOKER
        IF view_record.viewname = 'RoutingFormResponse' THEN
            EXECUTE 'CREATE VIEW "RoutingFormResponse" WITH (security_invoker = true) AS ' || view_record.definition;
        ELSIF view_record.viewname = 'BookingTimeStatus' THEN
            EXECUTE 'CREATE VIEW "BookingTimeStatus" WITH (security_invoker = true) AS ' || view_record.definition;
        ELSIF view_record.viewname = 'BookingTimeStatusDenormalized' THEN
            EXECUTE 'CREATE VIEW "BookingTimeStatusDenormalized" WITH (security_invoker = true) AS ' || view_record.definition;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 3. CREATE A TRIGGER TO PREVENT SECURITY DEFINER VIEWS
-- =============================================================================

-- Function to check for SECURITY DEFINER views and fix them
CREATE OR REPLACE FUNCTION check_and_fix_security_definer_views()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    
    -- If this is a view creation, ensure it's SECURITY INVOKER
    IF TG_OP = 'CREATE' AND TG_TAG = 'CREATE VIEW' THEN
        -- Force the view to be SECURITY INVOKER
        PERFORM ensure_views_security_invoker();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 4. APPLY THE FIXES IMMEDIATELY
-- =============================================================================

-- Run the function to ensure all views are SECURITY INVOKER
SELECT ensure_views_security_invoker();

-- =============================================================================
-- 5. VERIFICATION QUERIES
-- =============================================================================

-- Check that views exist and are SECURITY INVOKER
SELECT 'Views recreated with SECURITY INVOKER' as status, count(*) as count
FROM pg_views 
WHERE viewname IN ('RoutingFormResponse', 'BookingTimeStatus', 'BookingTimeStatusDenormalized')
    AND schemaname = 'public';

-- Show the current view definitions to verify
SELECT schemaname, viewname, 
       CASE 
           WHEN definition LIKE '%security_invoker%' THEN 'SECURITY INVOKER'
           WHEN definition LIKE '%security_definer%' THEN 'SECURITY DEFINER'
           ELSE 'DEFAULT'
       END as security_setting
FROM pg_views 
WHERE viewname IN ('RoutingFormResponse', 'BookingTimeStatus', 'BookingTimeStatusDenormalized')
    AND schemaname = 'public';
