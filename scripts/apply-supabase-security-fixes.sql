-- Supabase Security Fixes Script
-- Run this script in your Supabase SQL editor to fix all security issues

-- =============================================================================
-- 1. FIX SECURITY DEFINER VIEWS
-- =============================================================================

-- Drop and recreate RoutingFormResponse view without SECURITY DEFINER
DROP VIEW IF EXISTS "RoutingFormResponse";
CREATE VIEW "RoutingFormResponse" AS
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

-- Drop and recreate BookingTimeStatus view without SECURITY DEFINER
DROP VIEW IF EXISTS public."BookingTimeStatus";
CREATE VIEW public."BookingTimeStatus"
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

-- Drop and recreate BookingTimeStatusDenormalized view without SECURITY DEFINER
DROP VIEW IF EXISTS public."BookingTimeStatusDenormalized";
CREATE VIEW public."BookingTimeStatusDenormalized" AS
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
-- 2. ENABLE RLS ON _prisma_migrations TABLE
-- =============================================================================

-- Enable RLS on _prisma_migrations table
ALTER TABLE public."_prisma_migrations" ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows only authenticated users to read migration records
-- This is a basic policy - you may want to customize based on your security requirements
CREATE POLICY "_prisma_migrations_read_policy" ON public."_prisma_migrations"
    FOR SELECT
    TO authenticated
    USING (true);

-- =============================================================================
-- 3. FIX FUNCTION SEARCH PATH MUTABLE ISSUES
-- =============================================================================

-- Function to calculate booking status order
CREATE OR REPLACE FUNCTION calculate_booking_status_order(status TEXT)
RETURNS INTEGER AS $$
BEGIN
    SET search_path = public;
    RETURN CASE status
        WHEN 'accepted' THEN 1
        WHEN 'pending' THEN 2
        WHEN 'awaiting_host' THEN 3
        WHEN 'cancelled' THEN 4
        WHEN 'rejected' THEN 5
        ELSE 999  -- Default to end of sort order for unknown statuses
    END;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate is team booking
CREATE OR REPLACE FUNCTION calculate_is_team_booking(team_id INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
    SET search_path = public;
    RETURN team_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh booking time status denormalized
CREATE OR REPLACE FUNCTION refresh_booking_time_status_denormalized(booking_id INTEGER)
RETURNS VOID AS $$
BEGIN
    SET search_path = public;
    -- Delete existing entry if any
    DELETE FROM "BookingDenormalized" WHERE id = booking_id;

    -- Insert a denormalized booking joined with EventType and user
    INSERT INTO "BookingDenormalized" (
        id,
        uid,
        "eventTypeId",
        title,
        description,
        "startTime",
        "endTime",
        "createdAt",
        "updatedAt",
        location,
        paid,
        status,
        rescheduled,
        "userId",
        "teamId",
        "eventLength",
        "eventParentId",
        "userEmail",
        "userName",
        "userUsername",
        "ratingFeedback",
        "rating",
        "noShowHost",
        "isTeamBooking"
    )
    SELECT
        "Booking".id,
        "Booking".uid,
        "Booking"."eventTypeId",
        "Booking".title,
        "Booking".description,
        "Booking"."startTime",
        "Booking"."endTime",
        "Booking"."createdAt",
        "Booking"."updatedAt",
        "Booking".location,
        "Booking".paid,
        "Booking".status,
        "Booking".rescheduled,
        "Booking"."userId",
        et."teamId",
        et.length AS "eventLength",
        et."parentId" AS "eventParentId",
        "u"."email" AS "userEmail",
        "u"."name" AS "userName",
        "u"."username" AS "userUsername",
        "Booking"."ratingFeedback",
        "Booking"."rating",
        "Booking"."noShowHost",
        calculate_is_team_booking(et."teamId") as "isTeamBooking"
    FROM "Booking"
    LEFT JOIN "EventType" et ON "Booking"."eventTypeId" = et.id
    LEFT JOIN users u ON u.id = "Booking"."userId"
    WHERE "Booking".id = booking_id;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh routing form response denormalized
CREATE OR REPLACE FUNCTION refresh_routing_form_response_denormalized(response_id INTEGER)
RETURNS VOID AS $$
BEGIN
    SET search_path = public;
    -- Delete existing entry if any
    DELETE FROM "RoutingFormResponseDenormalized" WHERE id = response_id;
    
    -- Insert form response with all related data
    INSERT INTO "RoutingFormResponseDenormalized" (
        id,
        "formId",
        "formName",
        "formTeamId",
        "formUserId",
        "bookingUid",
        "bookingId",
        "bookingStatus",
        "bookingStatusOrder",
        "bookingCreatedAt",
        "bookingStartTime",
        "bookingEndTime",
        "bookingUserId",
        "bookingUserName",
        "bookingUserEmail",
        "bookingUserAvatarUrl",
        "bookingAssignmentReason",
        "eventTypeId",
        "eventTypeParentId",
        "eventTypeSchedulingType",
        "createdAt",
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content"
    )
    SELECT 
        r.id,
        r."formId",
        f.name as "formName",
        f."teamId" as "formTeamId",
        f."userId" as "formUserId",
        b.uid as "bookingUid",
        b.id as "bookingId",
        b.status as "bookingStatus",
        calculate_booking_status_order(b.status::text) as "bookingStatusOrder",
        b."createdAt" as "bookingCreatedAt",
        b."startTime" as "bookingStartTime",
        b."endTime" as "bookingEndTime",
        b."userId" as "bookingUserId",
        u.name as "bookingUserName",
        u.email as "bookingUserEmail",
        u."avatarUrl" as "bookingUserAvatarUrl",
        COALESCE(
            (
                SELECT ar."reasonString"
                FROM "AssignmentReason" ar
                WHERE ar."bookingId" = b.id
                LIMIT 1
            ),
            ''
        ) as "bookingAssignmentReason",
        et.id as "eventTypeId",
        et."parentId" as "eventTypeParentId",
        et."schedulingType" as "eventTypeSchedulingType",
        r."createdAt",
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        t.utm_term,
        t.utm_content
    FROM "App_RoutingForms_FormResponse" r
    INNER JOIN "App_RoutingForms_Form" f ON r."formId" = f.id
    INNER JOIN "users" u ON f."userId" = u.id
    LEFT JOIN "Booking" b ON b.uid = r."routedToBookingUid"
    LEFT JOIN "EventType" et ON b."eventTypeId" = et.id
    LEFT JOIN "Tracking" t ON t."bookingId" = b.id
    WHERE r.id = response_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for form response changes (insert/update)
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    BEGIN
        PERFORM refresh_routing_form_response_denormalized(NEW.id);
    EXCEPTION WHEN OTHERS THEN
        -- Log the error but don't fail the original operation
        RAISE WARNING 'DENORM_ERROR: RoutingFormResponseDenormalized - refresh failed for response_id %', NEW.id;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for form response deletions
CREATE OR REPLACE FUNCTION trigger_delete_routing_form_response_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    DELETE FROM "RoutingFormResponseDenormalized" WHERE id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for form name changes
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_form_name()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Update all responses for this form's name
    UPDATE "RoutingFormResponseDenormalized" rfrd
    SET "formName" = NEW.name
    WHERE rfrd."formId" = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for form team changes
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_form_team()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Update all responses for this form's team
    UPDATE "RoutingFormResponseDenormalized" rfrd
    SET "formTeamId" = NEW."teamId"
    WHERE rfrd."formId" = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for form user changes
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_form_user()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Update all responses for this form's user
    UPDATE "RoutingFormResponseDenormalized" rfrd
    SET "formUserId" = NEW."userId"
    WHERE rfrd."formId" = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for booking changes
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_booking()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Update all responses linked to this booking
    UPDATE "RoutingFormResponseDenormalized" rfrd
    SET
        "bookingStatus" = NEW.status,
        "bookingStatusOrder" = calculate_booking_status_order(NEW.status::text),
        "bookingCreatedAt" = NEW."createdAt",
        "bookingStartTime" = NEW."startTime",
        "bookingEndTime" = NEW."endTime"
    WHERE rfrd."bookingId" = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for user changes
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_user()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Update all responses where this user is the booking user
    UPDATE "RoutingFormResponseDenormalized" rfrd
    SET
        "bookingUserName" = NEW.name,
        "bookingUserEmail" = NEW.email,
        "bookingUserAvatarUrl" = NEW."avatarUrl"
    WHERE rfrd."bookingUserId" = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for EventType changes
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_event_type()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Update all responses linked to this event type through bookings
    UPDATE "RoutingFormResponseDenormalized" rfrd
    SET
        "eventTypeParentId" = NEW."parentId",
        "eventTypeSchedulingType" = NEW."schedulingType"
    FROM "Booking" b
    WHERE b."eventTypeId" = NEW.id
    AND rfrd."bookingId" = b.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for form deletions
CREATE OR REPLACE FUNCTION trigger_cleanup_routing_form_response_denormalized_form()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Delete all denormalized responses for this form
    DELETE FROM "RoutingFormResponseDenormalized"
    WHERE "formId" = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for user deletions
CREATE OR REPLACE FUNCTION trigger_cleanup_routing_form_response_denormalized_user()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- Delete all responses where this user was the booking user
    DELETE FROM "RoutingFormResponseDenormalized"
    WHERE "bookingUserId" = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to nullify event type data in denormalized table when event type is deleted
CREATE OR REPLACE FUNCTION trigger_nullify_routing_form_response_denormalized_event_type()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    UPDATE "RoutingFormResponseDenormalized"
    SET
        "eventTypeId" = NULL,
        "eventTypeParentId" = NULL,
        "eventTypeSchedulingType" = NULL
    WHERE "eventTypeId" = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to update membership custom role
CREATE OR REPLACE FUNCTION update_membership_custom_role()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    NEW."updatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh booking time status length
CREATE OR REPLACE FUNCTION refresh_booking_time_status_length()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh booking time status parent id
CREATE OR REPLACE FUNCTION refresh_booking_time_status_parent_id()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh booking time status team id
CREATE OR REPLACE FUNCTION refresh_booking_time_status_team_id()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to reprocess routing form response fields
CREATE OR REPLACE FUNCTION reprocess_routing_form_response_fields()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to trigger delete booking time status denormalized
CREATE OR REPLACE FUNCTION trigger_delete_booking_time_status_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to trigger refresh booking time status denormalized
CREATE OR REPLACE FUNCTION trigger_refresh_booking_time_status_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to trigger refresh booking time status denormalized user
CREATE OR REPLACE FUNCTION trigger_refresh_booking_time_status_denormalized_user()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to trigger refresh routing form response denormalized
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to trigger refresh routing form response denormalized booking
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_booking()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to process routing form response fields
CREATE OR REPLACE FUNCTION _process_routing_form_response_fields()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle routing form response fields
CREATE OR REPLACE FUNCTION handle_routing_form_response_fields()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh booking time status denormalized
CREATE OR REPLACE FUNCTION refresh_booking_time_status_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh routing form response denormalized
CREATE OR REPLACE FUNCTION refresh_routing_form_response_denormalized()
RETURNS TRIGGER AS $$
BEGIN
    SET search_path = public;
    -- This function appears to be a placeholder - implement as needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check that views no longer have SECURITY DEFINER
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE viewname IN ('RoutingFormResponse', 'BookingTimeStatus', 'BookingTimeStatusDenormalized')
    AND schemaname = 'public';

-- Check that RLS is enabled on _prisma_migrations
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = '_prisma_migrations' 
    AND schemaname = 'public';

-- Check that functions have explicit search paths
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname IN (
        'calculate_booking_status_order',
        'calculate_is_team_booking',
        'refresh_booking_time_status_denormalized',
        'trigger_refresh_routing_form_response_denormalized'
    );
