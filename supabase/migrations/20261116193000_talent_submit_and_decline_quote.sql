-- Talent quote submission and talent decline.
-- Tasks 6hqc4MRH9hXcm3w5 (quote composition) and 6hqm9Ffwvf6XJR45 (decline).
--
-- WHY THIS EXISTS
-- Nothing has ever been able to create a quote. `quotes` has no INSERT policy
-- for `authenticated`, by design, and no function inserts into it. So zero
-- quotes exist and nothing downstream of a quote has ever run: accept,
-- decline, bookings, auto-completion, ratings, payments. In the other
-- direction a talent has SELECT only on `quote_requests`, so the decided
-- "a talent can decline, with a reason" has been unreachable too.
--
-- THE SHAPE -- the mirror of accept_quote_and_create_booking and decline_quote
-- Two SECURITY DEFINER functions, service_role only, called by thin Edge
-- Functions that verify the JWT and pass the caller's user id through. Every
-- rule is checked here, under a row lock on the request, so the checks and
-- the write share one transaction.
--
-- DECISIONS THIS IMPLEMENTS
--   * The fee is not an input. Settled by Praveen 2026-10-25: a talent cannot
--     quote an amount different from their stored rate. enforce_quote_writes
--     already overwrites quoted_amount with the request's pinned rate; this
--     function simply never accepts one.
--   * Performer count and setup arrival time are REQUIRED on a quote
--     (2026-09-27). The columns are nullable; the requirement lives here.
--   * Setup arrival: any time after now and before the event starts. Settled
--     by Praveen 2026-11-16, chosen over a 12-hour and a 24-hour window.
--   * Meals and accommodation are talent-entered fees. Their distance gates
--     are enforced by compute_quote_pricing, not repeated here.
--   * A decline carries a reason, plus a note that is required for 'other'
--     (2026-09-27: "enum plus optional note"). The enum quote_decline_reason
--     already exists and has never been writable.
--   * A decline CLOSES the request. talent_id is pinned on a request, so
--     there is nobody else it could go to; the client raises a new one.
--   * No email to the client in this build, for either action. Settled by
--     Praveen 2026-11-16 for the quote; the decline follows it so that both
--     land with the client-KYC visibility gate rather than ahead of it.
--
-- NOT CHANGED
-- Pricing. compute_quote_pricing, calc_travel_fee and set_quote_expiry are
-- untouched and do all the arithmetic, exactly as they would for any insert.

-- == 1. quote_requests.decline_note ==========================================

alter table public.quote_requests
  add column if not exists decline_note text;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.quote_requests'::regclass
                    and conname = 'chk_qreq_decline_note_length') then
    alter table public.quote_requests
      add constraint chk_qreq_decline_note_length
      check (decline_note is null or length(btrim(decline_note)) between 1 and 200);
  end if;

  -- A note exists only on a declined request.
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.quote_requests'::regclass
                    and conname = 'chk_qreq_decline_note_only_when_declined') then
    alter table public.quote_requests
      add constraint chk_qreq_decline_note_only_when_declined
      check (decline_note is null or status = 'declined'::quotation_request_status);
  end if;

  -- 'other' on its own tells the client nothing. Same rule as
  -- chk_quote_rejected_note_required on quotes.
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.quote_requests'::regclass
                    and conname = 'chk_qreq_decline_note_required') then
    alter table public.quote_requests
      add constraint chk_qreq_decline_note_required
      check (decline_reason is distinct from 'other'::quote_decline_reason
             or decline_note is not null);
  end if;
end $$;

-- == 2. enforce_quote_request_writes: pin the new column ======================
-- The request's owner has an UPDATE policy on this table, and this guard is
-- what stops them writing decline_reason. decline_note needs the same pin or
-- a client could write a note onto their own request.
--
-- The body below is the definition from 20261018115132 with exactly two lines
-- added, both naming decline_note. It was produced by reading that file and
-- inserting the lines, not by retyping the function.

CREATE OR REPLACE FUNCTION public.enforce_quote_request_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    NEW.decline_note   := NULL;
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
  NEW.decline_note           := OLD.decline_note;

  IF OLD.status <> 'open'::quotation_request_status THEN
    NEW.location             := OLD.location;
    NEW.event_address        := OLD.event_address;
    NEW.event_latitude       := OLD.event_latitude;
    NEW.event_longitude      := OLD.event_longitude;
    NEW.special_requirements := OLD.special_requirements;
    NEW.audience_capacity    := OLD.audience_capacity;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status IN ('open', 'matched') AND NEW.status = 'cancelled')
      OR (
        OLD.status = 'open'::quotation_request_status
        AND NEW.status = 'matched'::quotation_request_status
        AND EXISTS (SELECT 1 FROM public.quotes q
                     WHERE q.quote_request_id = OLD.id
                       AND q.quote_status = 'pending'::quotation_status)
      )
    ) THEN
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

-- == 3. submit_quote ==========================================================

create function public.submit_quote(
  p_quote_request_id  uuid,
  p_talent_user_id    uuid,
  p_performer_count   integer,
  p_setup_arrival_at  timestamptz,
  p_notes             text    default null,
  p_meals_fee         numeric default 0,
  p_accommodation_fee numeric default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_talent     uuid;
  v_status     quotation_request_status;
  v_starts     timestamptz;
  v_responds   timestamptz;
  v_rate       numeric;
  v_approval   approval_status;
  v_deleting   timestamptz;
  v_notes      text := nullif(btrim(p_notes), '');
  v_quote_id   uuid;
begin
  select qr.talent_id, qr.status, qr.starts_at, qr.responds_by, qr.talent_rate_at_request
    into v_talent, v_status, v_starts, v_responds, v_rate
    from public.quote_requests qr
   where qr.id = p_quote_request_id
   for update;

  if not found then
    raise exception 'Quote request % does not exist.', p_quote_request_id
      using errcode = '23503';
  end if;

  -- Ownership first, so nothing below can tell a stranger anything about a
  -- request that is not theirs.
  select pt.approval_status, pt.deletion_requested_at
    into v_approval, v_deleting
    from public.profiles_talent pt
   where pt.id = v_talent
     and pt.user_id = p_talent_user_id;

  if not found then
    raise exception 'Only the artist this request was sent to can quote on it.'
      using errcode = '42501';
  end if;

  if v_approval is distinct from 'approved'::approval_status or v_deleting is not null then
    raise exception 'Your profile must be approved and active before you can send a quote.'
      using errcode = '42501';
  end if;

  if v_status = 'matched'::quotation_request_status then
    raise exception 'You have already sent a quote for this request.'
      using errcode = '42501';
  end if;

  if v_status <> 'open'::quotation_request_status then
    raise exception 'This request is % and can no longer be quoted on.', v_status
      using errcode = '42501';
  end if;

  -- The hourly expiry job may not have caught up yet, so the window is
  -- checked here rather than inferred from the status.
  if v_responds <= now() or v_starts <= now() then
    raise exception 'The time to respond to this request has passed.'
      using errcode = '42501';
  end if;

  if p_performer_count is null or p_performer_count < 1 or p_performer_count > 50 then
    raise exception 'Say how many performers will be on stage, between 1 and 50.'
      using errcode = '23514';
  end if;

  if p_setup_arrival_at is null then
    raise exception 'Say when you will arrive to set up.'
      using errcode = '23514';
  end if;

  if p_setup_arrival_at <= now() or p_setup_arrival_at >= v_starts then
    raise exception 'Your setup arrival time must be in the future and before the event starts.'
      using errcode = '23514';
  end if;

  if length(v_notes) > 1000 then
    raise exception 'Your note to the client is too long (1000 characters maximum).'
      using errcode = '23514';
  end if;

  if coalesce(p_meals_fee, 0) < 0 or coalesce(p_accommodation_fee, 0) < 0 then
    raise exception 'Meals and accommodation cannot be negative.'
      using errcode = '23514';
  end if;

  -- quoted_amount is supplied only because the column is NOT NULL.
  -- enforce_quote_writes overwrites it with this same pinned rate, sets
  -- talent_id, the package and the rate snapshot; compute_quote_pricing does
  -- the arithmetic and the distance gates; set_quote_expiry sets expires_at;
  -- set_request_matched_on_quote moves the request to 'matched'.
  insert into public.quotes
    (quote_request_id, talent_id, quoted_amount,
     performer_count, setup_arrival_at, notes_to_client,
     meals_fee, accommodation_fee)
  values
    (p_quote_request_id, v_talent, v_rate,
     p_performer_count, p_setup_arrival_at, v_notes,
     coalesce(p_meals_fee, 0), coalesce(p_accommodation_fee, 0))
  returning id into v_quote_id;

  return v_quote_id;
end;
$$;

revoke all on function public.submit_quote(uuid, uuid, integer, timestamptz, text, numeric, numeric)
  from public, anon, authenticated;
grant execute on function public.submit_quote(uuid, uuid, integer, timestamptz, text, numeric, numeric)
  to service_role;

-- == 4. decline_quote_request =================================================

create function public.decline_quote_request(
  p_quote_request_id uuid,
  p_talent_user_id   uuid,
  p_reason           quote_decline_reason,
  p_note             text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_talent uuid;
  v_status quotation_request_status;
  v_note   text := nullif(btrim(p_note), '');
begin
  select qr.talent_id, qr.status
    into v_talent, v_status
    from public.quote_requests qr
   where qr.id = p_quote_request_id
   for update;

  if not found then
    raise exception 'Quote request % does not exist.', p_quote_request_id
      using errcode = '23503';
  end if;

  if not exists (select 1 from public.profiles_talent pt
                  where pt.id = v_talent and pt.user_id = p_talent_user_id) then
    raise exception 'Only the artist this request was sent to can decline it.'
      using errcode = '42501';
  end if;

  if v_status = 'matched'::quotation_request_status then
    raise exception 'You have already sent a quote for this request, so it can no longer be declined.'
      using errcode = '42501';
  end if;

  if v_status <> 'open'::quotation_request_status then
    raise exception 'This request is % and can no longer be declined.', v_status
      using errcode = '42501';
  end if;

  if p_reason is null then
    raise exception 'A reason is required.' using errcode = '23502';
  end if;

  if p_reason = 'other'::quote_decline_reason and v_note is null then
    raise exception 'Please say why, so the client knows what to do next.'
      using errcode = '23514';
  end if;

  if length(v_note) > 200 then
    raise exception 'Your note is too long (200 characters maximum).'
      using errcode = '23514';
  end if;

  -- Status, reason and note in ONE update: chk_qreq_decline_reason_consistency
  -- requires status and reason to change together. No quote exists while a
  -- request is open, so cascade_quote_request_close has nothing to expire.
  update public.quote_requests
     set status         = 'declined'::quotation_request_status,
         decline_reason = p_reason,
         decline_note   = v_note
   where id = p_quote_request_id;
end;
$$;

revoke all on function public.decline_quote_request(uuid, uuid, quote_decline_reason, text)
  from public, anon, authenticated;
grant execute on function public.decline_quote_request(uuid, uuid, quote_decline_reason, text)
  to service_role;

-- == 5. preview_quote_pricing: return the two distance thresholds =============
-- The screen has to know whether to offer the meals and accommodation fields.
-- The thresholds live in rate_configs, which no browser role can read, and
-- hardcoding 100 and 150 in the app would silently disagree with the database
-- the first time a rate row changes them. The preview already resolves the
-- configuration in force, so it returns the two numbers alongside the
-- distance they are compared with.
--
-- A changed return type cannot be CREATE OR REPLACEd, so the function is
-- dropped and recreated. The body is the 20261031170000 definition with the
-- two columns added, produced by reading that file. Nothing depends on the
-- function and no application code calls it yet.

drop function if exists public.preview_quote_pricing(uuid, numeric, numeric);

create function public.preview_quote_pricing(
  p_quote_request_id  uuid,
  p_meals_fee         numeric default 0,
  p_accommodation_fee numeric default 0
)
returns table (
  talent_fee               numeric,
  travel_fee               numeric,
  meals_fee                numeric,
  accommodation_fee        numeric,
  commission_talent_amount numeric,
  talent_payout            numeric,
  distance_km              numeric,
  coordinates_estimated    boolean,
  package_label            text,
  meals_threshold_km         numeric,
  accommodation_threshold_km numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  req_rate numeric; req_talent uuid; req_event public.events_type;
  v_dist numeric; v_travel numeric; v_est boolean;
  cfg public.rate_configs;
  v_meals numeric := coalesce(p_meals_fee, 0);
  v_accom numeric := coalesce(p_accommodation_fee, 0);
  v_comm_talent numeric;
begin
  if v_meals < 0 or v_accom < 0 then
    raise exception 'Meals and accommodation cannot be negative.'
      using errcode = '22003';
  end if;

  select qr.talent_rate_at_request, qr.talent_id, qr.event_type
    into req_rate, req_talent, req_event
    from public.quote_requests qr where qr.id = p_quote_request_id;

  if req_talent is null then
    raise exception 'No such quote request.' using errcode = '42704';
  end if;

  if not exists (
    select 1 from public.profiles_talent pt
     where pt.id = req_talent and pt.user_id = auth.uid()
  ) and coalesce(public.get_my_role(), '') <> 'admin' then
    raise exception 'You can only preview pricing for your own quote requests.'
      using errcode = '42501';
  end if;

  select * into cfg from public.rate_config_at(now());
  if cfg.id is null then
    raise exception 'No rate configuration is in force.' using errcode = '22004';
  end if;

  select t.distance_km, t.travel_fee, t.estimated
    into v_dist, v_travel, v_est
    from public.calc_travel_fee(p_quote_request_id, req_talent, req_rate) t;

  v_comm_talent := round(req_rate * cfg.commission_talent_rate_percent / 100, 2);

  return query select
    req_rate,
    v_travel,
    v_meals,
    v_accom,
    v_comm_talent,
    round(req_rate + v_travel + v_meals + v_accom - v_comm_talent, 2),
    v_dist,
    v_est,
    (select p.label from public.packages p
      where p.id = public.package_for_category(
              public.rate_category_for_event_type(req_event), now())),
    cfg.meals_threshold_km,
    cfg.accommodation_threshold_km;
end;
$$;

revoke all on function public.preview_quote_pricing(uuid, numeric, numeric) from public, anon;
grant execute on function public.preview_quote_pricing(uuid, numeric, numeric) to authenticated, service_role;
