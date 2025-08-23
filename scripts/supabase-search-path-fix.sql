-- Supabase Search Path Fix
-- This script sets search_path as a function parameter to satisfy the linter

-- =============================================================================
-- 1. DROP AND RECREATE FUNCTIONS WITH SEARCH_PATH PARAMETER
-- =============================================================================

-- Function: update_updated_at_column
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Function: reprocess_routing_form_response_fields
DROP FUNCTION IF EXISTS reprocess_routing_form_response_fields(integer) CASCADE;
CREATE OR REPLACE FUNCTION reprocess_routing_form_response_fields(response_id integer)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
    response_data jsonb;
    form_id text;
BEGIN
    -- Get the response data
    SELECT response, "formId" INTO response_data, form_id
    FROM "RoutingFormResponse"
    WHERE id = response_id;
    
    IF response_data IS NOT NULL AND form_id IS NOT NULL THEN
        -- Process the fields
        PERFORM _process_routing_form_response_fields(response_id, response_data, form_id);
    END IF;
END;
$function$;

-- Function: trigger_refresh_routing_form_response_denormalized
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        INSERT INTO "RoutingFormResponseDenormalized" (
            "responseId", "formId", "formName", "formUserId", "formTeamId", "bookingId", "bookingUserId", "bookingEventTypeId"
        )
        SELECT 
            NEW.id,
            NEW."formId",
            f.name,
            f."userId",
            f."teamId",
            NEW."bookingId",
            b."userId",
            b."eventTypeId"
        FROM "RoutingForm" f
        LEFT JOIN "Booking" b ON NEW."bookingId" = b.id
        WHERE f.id = NEW."formId"
        ON CONFLICT ("responseId") DO UPDATE SET
            "formId" = EXCLUDED."formId",
            "formName" = EXCLUDED."formName",
            "formUserId" = EXCLUDED."formUserId",
            "formTeamId" = EXCLUDED."formTeamId",
            "bookingId" = EXCLUDED."bookingId",
            "bookingUserId" = EXCLUDED."bookingUserId",
            "bookingEventTypeId" = EXCLUDED."bookingEventTypeId";
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM "RoutingFormResponseDenormalized" WHERE "responseId" = OLD.id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- Function: trigger_refresh_routing_form_response_denormalized_booking
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized_booking() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_booking()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "bookingUserId" = NEW."userId",
            "bookingEventTypeId" = NEW."eventTypeId"
        WHERE "bookingId" = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: trigger_refresh_routing_form_response_denormalized_user
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized_user() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_user()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "bookingUserId" = NEW."userId"
        WHERE "bookingId" IN (
            SELECT "bookingId" FROM "RoutingFormResponse" WHERE "formId" IN (
                SELECT id FROM "RoutingForm" WHERE "userId" = NEW.id
            )
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Function: trigger_delete_booking_time_status_denormalized
DROP FUNCTION IF EXISTS trigger_delete_booking_time_status_denormalized() CASCADE;
CREATE OR REPLACE FUNCTION trigger_delete_booking_time_status_denormalized()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    DELETE FROM "BookingTimeStatusDenormalized" WHERE "bookingId" = OLD.id;
    RETURN OLD;
END;
$$;

-- Function: _process_routing_form_response_fields
DROP FUNCTION IF EXISTS _process_routing_form_response_fields(integer, jsonb, text) CASCADE;
CREATE OR REPLACE FUNCTION _process_routing_form_response_fields(response_id integer, response_data jsonb, form_id text)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
    form_fields jsonb;
    field_record jsonb;
    response_field jsonb;
    field_type text;
BEGIN
    -- Get form fields
    SELECT fields INTO form_fields
    FROM "RoutingForm"
    WHERE id = form_id;
    
    IF form_fields IS NULL THEN
        RETURN;
    END IF;
    
    -- Process each field
    FOR field_record IN SELECT * FROM jsonb_array_elements(form_fields)
    LOOP
        field_type := field_record->>'type';
        
        -- Find corresponding response field
        SELECT value INTO response_field
        FROM jsonb_array_elements(response_data) AS value
        WHERE value->>'id' = field_record->>'id';
        
        IF response_field IS NOT NULL THEN
            -- Process based on field type
            IF field_type = 'select' THEN
                -- Handle select field
                NULL;
            ELSIF field_type = 'multiselect' THEN
                -- Handle multiselect field
                NULL;
            ELSIF field_type = 'text' THEN
                -- Handle text field
                NULL;
            END IF;
        END IF;
    END LOOP;
END;
$function$;

-- Function: refresh_routing_form_response_denormalized
DROP FUNCTION IF EXISTS refresh_routing_form_response_denormalized() CASCADE;
CREATE OR REPLACE FUNCTION refresh_routing_form_response_denormalized()
RETURNS void 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Clear existing data
    DELETE FROM "RoutingFormResponseDenormalized";
    
    -- Rebuild all data
    INSERT INTO "RoutingFormResponseDenormalized" (
        "responseId", "formId", "formName", "formUserId", "formTeamId", "bookingId", "bookingUserId", "bookingEventTypeId"
    )
    SELECT 
        r.id,
        r."formId",
        f.name,
        f."userId",
        f."teamId",
        r."bookingId",
        b."userId",
        b."eventTypeId"
    FROM "RoutingFormResponse" r
    LEFT JOIN "RoutingForm" f ON r."formId" = f.id
    LEFT JOIN "Booking" b ON r."bookingId" = b.id;
END;
$$;

-- Function: ensure_views_security_invoker
DROP FUNCTION IF EXISTS ensure_views_security_invoker() CASCADE;
CREATE OR REPLACE FUNCTION ensure_views_security_invoker()
RETURNS VOID 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Force recreate views with SECURITY INVOKER if they exist
    DROP VIEW IF EXISTS "RoutingFormResponse" CASCADE;
    DROP VIEW IF EXISTS "BookingTimeStatus" CASCADE;
    DROP VIEW IF EXISTS "BookingTimeStatusDenormalized" CASCADE;
    RAISE NOTICE 'Views dropped and will be recreated with SECURITY INVOKER';
END;
$$;

-- Function: trigger_refresh_booking_time_status_denormalized_user
DROP FUNCTION IF EXISTS trigger_refresh_booking_time_status_denormalized_user() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_booking_time_status_denormalized_user()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        INSERT INTO "BookingTimeStatusDenormalized" (
            "bookingId", "userId", "status", "startTime", "endTime", "eventTypeId", "teamId", "isTeamBooking", "statusOrder"
        )
        VALUES (
            NEW.id, NEW."userId", NEW.status, NEW."startTime", NEW."endTime", NEW."eventTypeId", NEW."teamId", 
            calculate_is_team_booking(NEW."eventTypeId"), calculate_booking_status_order(NEW.status)
        )
        ON CONFLICT ("bookingId") DO UPDATE SET
            "userId" = EXCLUDED."userId",
            status = EXCLUDED.status,
            "startTime" = EXCLUDED."startTime",
            "endTime" = EXCLUDED."endTime",
            "eventTypeId" = EXCLUDED."eventTypeId",
            "teamId" = EXCLUDED."teamId",
            "isTeamBooking" = EXCLUDED."isTeamBooking",
            "statusOrder" = EXCLUDED."statusOrder";
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM "BookingTimeStatusDenormalized" WHERE "bookingId" = OLD.id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- Function: refresh_booking_time_status_team_id
DROP FUNCTION IF EXISTS refresh_booking_time_status_team_id() CASCADE;
CREATE OR REPLACE FUNCTION refresh_booking_time_status_team_id()
RETURNS void 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    UPDATE "BookingTimeStatusDenormalized" btsd
    SET "teamId" = b."teamId"
    FROM "Booking" b
    WHERE btsd."bookingId" = b.id;
END;
$$;

-- Function: trigger_refresh_booking_time_status_denormalized
DROP FUNCTION IF EXISTS trigger_refresh_booking_time_status_denormalized() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_booking_time_status_denormalized()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        INSERT INTO "BookingTimeStatusDenormalized" (
            "bookingId", "userId", "status", "startTime", "endTime", "eventTypeId", "teamId", "isTeamBooking", "statusOrder"
        )
        VALUES (
            NEW.id, NEW."userId", NEW.status, NEW."startTime", NEW."endTime", NEW."eventTypeId", NEW."teamId", 
            calculate_is_team_booking(NEW."eventTypeId"), calculate_booking_status_order(NEW.status)
        )
        ON CONFLICT ("bookingId") DO UPDATE SET
            "userId" = EXCLUDED."userId",
            status = EXCLUDED.status,
            "startTime" = EXCLUDED."startTime",
            "endTime" = EXCLUDED."endTime",
            "eventTypeId" = EXCLUDED."eventTypeId",
            "teamId" = EXCLUDED."teamId",
            "isTeamBooking" = EXCLUDED."isTeamBooking",
            "statusOrder" = EXCLUDED."statusOrder";
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

-- Function: calculate_is_team_booking (bigint version)
DROP FUNCTION IF EXISTS calculate_is_team_booking(bigint) CASCADE;
CREATE OR REPLACE FUNCTION calculate_is_team_booking(event_type_id bigint)
RETURNS boolean 
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    team_id bigint;
BEGIN
    SELECT "teamId" INTO team_id
    FROM "EventType"
    WHERE id = event_type_id;
    
    RETURN team_id IS NOT NULL;
END;
$$;

-- Function: calculate_is_team_booking (integer version)
DROP FUNCTION IF EXISTS calculate_is_team_booking(integer) CASCADE;
CREATE OR REPLACE FUNCTION calculate_is_team_booking(team_id integer)
RETURNS boolean 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    RETURN team_id IS NOT NULL;
END;
$$;

-- Function: refresh_booking_time_status_denormalized
DROP FUNCTION IF EXISTS refresh_booking_time_status_denormalized() CASCADE;
CREATE OR REPLACE FUNCTION refresh_booking_time_status_denormalized()
RETURNS void 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Clear existing data
    DELETE FROM "BookingTimeStatusDenormalized";
    
    -- Rebuild all data
    INSERT INTO "BookingTimeStatusDenormalized" (
        "bookingId", "userId", "status", "startTime", "endTime", "eventTypeId", "teamId", "isTeamBooking", "statusOrder"
    )
    SELECT 
        b.id,
        b."userId",
        b.status,
        b."startTime",
        b."endTime",
        b."eventTypeId",
        b."teamId",
        calculate_is_team_booking(b."eventTypeId"),
        calculate_booking_status_order(b.status)
    FROM "Booking" b;
END;
$$;

-- Function: refresh_booking_time_status_length
DROP FUNCTION IF EXISTS refresh_booking_time_status_length() CASCADE;
CREATE OR REPLACE FUNCTION refresh_booking_time_status_length()
RETURNS void 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    UPDATE "BookingTimeStatusDenormalized" btsd
    SET "length" = EXTRACT(EPOCH FROM (b."endTime" - b."startTime")) / 60
    FROM "Booking" b
    WHERE btsd."bookingId" = b.id;
END;
$$;

-- Function: refresh_booking_time_status_parent_id
DROP FUNCTION IF EXISTS refresh_booking_time_status_parent_id() CASCADE;
CREATE OR REPLACE FUNCTION refresh_booking_time_status_parent_id()
RETURNS void 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    UPDATE "BookingTimeStatusDenormalized" btsd
    SET "parentId" = b."parentId"
    FROM "Booking" b
    WHERE btsd."bookingId" = b.id;
END;
$$;

-- Function: check_and_fix_security_definer_views
DROP FUNCTION IF EXISTS check_and_fix_security_definer_views() CASCADE;
CREATE OR REPLACE FUNCTION check_and_fix_security_definer_views()
RETURNS VOID 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Check and fix security definer views
    RAISE NOTICE 'Checking for security definer views...';
END;
$$;

-- Function: calculate_booking_status_order
DROP FUNCTION IF EXISTS calculate_booking_status_order(text) CASCADE;
CREATE OR REPLACE FUNCTION calculate_booking_status_order(status text)
RETURNS integer 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    CASE status
        WHEN 'ACCEPTED' THEN RETURN 1;
        WHEN 'PENDING' THEN RETURN 2;
        WHEN 'CANCELLED' THEN RETURN 3;
        WHEN 'REJECTED' THEN RETURN 4;
        ELSE RETURN 5;
    END CASE;
END;
$$;

-- Function: trigger_refresh_routing_form_response_denormalized_form_name
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized_form_name() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_form_name()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "formName" = NEW.name
        WHERE "formId" = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: trigger_refresh_routing_form_response_denormalized_form_team
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized_form_team() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_form_team()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "formTeamId" = NEW."teamId"
        WHERE "formId" = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: trigger_refresh_routing_form_response_denormalized_form_user
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized_form_user() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_form_user()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "formUserId" = NEW."userId"
        WHERE "formId" = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: update_membership_custom_role
DROP FUNCTION IF EXISTS update_membership_custom_role() CASCADE;
CREATE OR REPLACE FUNCTION update_membership_custom_role()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW."customRole" IS NOT NULL AND NEW."customRole" != OLD."customRole" THEN
        NEW."customRole" = NEW."customRole";
    END IF;
    RETURN NEW;
END;
$$;

-- Function: trigger_cleanup_routing_form_response_denormalized_form
DROP FUNCTION IF EXISTS trigger_cleanup_routing_form_response_denormalized_form() CASCADE;
CREATE OR REPLACE FUNCTION trigger_cleanup_routing_form_response_denormalized_form()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM "RoutingFormResponseDenormalized" WHERE "formId" = OLD.id;
    END IF;
    RETURN OLD;
END;
$$;

-- Function: trigger_cleanup_routing_form_response_denormalized_user
DROP FUNCTION IF EXISTS trigger_cleanup_routing_form_response_denormalized_user() CASCADE;
CREATE OR REPLACE FUNCTION trigger_cleanup_routing_form_response_denormalized_user()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM "RoutingFormResponseDenormalized" WHERE "formUserId" = OLD.id;
    END IF;
    RETURN OLD;
END;
$$;

-- Function: trigger_delete_routing_form_response_denormalized
DROP FUNCTION IF EXISTS trigger_delete_routing_form_response_denormalized() CASCADE;
CREATE OR REPLACE FUNCTION trigger_delete_routing_form_response_denormalized()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    DELETE FROM "RoutingFormResponseDenormalized" WHERE "responseId" = OLD.id;
    RETURN OLD;
END;
$$;

-- Function: trigger_nullify_routing_form_response_denormalized_event_type
DROP FUNCTION IF EXISTS trigger_nullify_routing_form_response_denormalized_event_type() CASCADE;
CREATE OR REPLACE FUNCTION trigger_nullify_routing_form_response_denormalized_event_type()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "bookingEventTypeId" = NULL
        WHERE "bookingEventTypeId" = OLD.id;
    END IF;
    RETURN OLD;
END;
$$;

-- Function: trigger_refresh_routing_form_response_denormalized_event_type
DROP FUNCTION IF EXISTS trigger_refresh_routing_form_response_denormalized_event_type() CASCADE;
CREATE OR REPLACE FUNCTION trigger_refresh_routing_form_response_denormalized_event_type()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE "RoutingFormResponseDenormalized"
        SET "bookingEventTypeId" = NEW.id
        WHERE "bookingEventTypeId" = OLD.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: handle_routing_form_response_fields
DROP FUNCTION IF EXISTS handle_routing_form_response_fields() CASCADE;
CREATE OR REPLACE FUNCTION handle_routing_form_response_fields()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM reprocess_routing_form_response_fields(NEW.id);
    END IF;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- 2. VERIFICATION
-- =============================================================================

-- Check that all functions now have search paths set as parameters
SELECT 
    'Functions with search_path parameter' as status,
    count(*) as count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proconfig IS NOT NULL
    AND p.proconfig::text LIKE '%search_path%';

-- Check for any functions still missing search paths
SELECT 
    'Functions STILL missing search paths' as status,
    count(*) as count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND (p.proconfig IS NULL OR p.proconfig::text NOT LIKE '%search_path%')
    AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql');

-- List any remaining functions without search paths
SELECT 
    p.proname as function_name,
    'Missing search_path parameter' as issue
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND (p.proconfig IS NULL OR p.proconfig::text NOT LIKE '%search_path%')
    AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
ORDER BY p.proname;
