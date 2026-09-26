-- Hiding the profile does not by itself stop quote requests: this trigger never
-- checked talent visibility, and PostgREST is directly reachable. Block requests
-- aimed at a talent who has asked to be deleted.
create or replace function public.enforce_quote_request_writes()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  caller_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  caller_role := get_my_role();

  IF caller_role = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF EXISTS (SELECT 1 FROM public.profiles_talent t
                WHERE t.id = NEW.talent_id
                  AND t.deletion_requested_at IS NOT NULL) THEN
      RAISE EXCEPTION 'This artist is no longer accepting bookings.'
        USING ERRCODE = '42501';
    END IF;

    NEW.status         := 'open'::quotation_request_status;
    NEW.decline_reason := NULL;
    NEW.created_at     := now();
    NEW.updated_at     := now();
    RETURN NEW;
  END IF;

  NEW.id                     := OLD.id;
  NEW.client_user_id         := OLD.client_user_id;
  NEW.talent_id              := OLD.talent_id;
  NEW.venue_id               := OLD.venue_id;
  NEW.event_type             := OLD.event_type;
  NEW.starts_at              := OLD.starts_at;
  NEW.ends_at                := OLD.ends_at;
  NEW.created_at             := OLD.created_at;
  NEW.talent_rate_at_request := OLD.talent_rate_at_request;
  NEW.decline_reason         := OLD.decline_reason;

  IF OLD.status <> 'open'::quotation_request_status THEN
    NEW.location             := OLD.location;
    NEW.event_address        := OLD.event_address;
    NEW.event_latitude       := OLD.event_latitude;
    NEW.event_longitude      := OLD.event_longitude;
    NEW.budget_min           := OLD.budget_min;
    NEW.budget_max           := OLD.budget_max;
    NEW.special_requirements := OLD.special_requirements;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (OLD.status IN ('open', 'matched') AND NEW.status = 'cancelled') THEN
      RAISE EXCEPTION
        'A quote request owner may only cancel, and only while open or matched (attempted % -> %).',
        OLD.status, NEW.status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;