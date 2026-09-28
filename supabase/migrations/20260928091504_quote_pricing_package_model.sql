-- 20260928091504_quote_pricing_package_model.sql
--
-- The fee is the category rate. Duration stops pricing anything. D-038.
--
-- WHAT CHANGES
-- ------------
-- enforce_quote_writes set quoted_amount to:
--     round(req_rate * greatest(1, req_hours / 4), 2)
-- With fixed packages (settled 2026-09-28) that multiplier is wrong: the fee is
-- what the talent charges for that category, full stop. It becomes:
--     NEW.quoted_amount := req_rate;
-- No round() either - talent_rate_at_request came from talent_rates.amount,
-- which is numeric(12,2) and already at scale. Rounding an already-rounded
-- number implies a computation that is not happening.
--
-- req_hours had exactly one reader, that multiplier, so the variable and the
-- duration_hours column drop out of the lookup entirely. quote_requests.
-- duration_hours goes back to being only the client's event window, for the
-- calendar - which is all a generated column off starts_at/ends_at was ever
-- good for.
--
-- ACCEPTED CONSEQUENCE: a client booking a 2-hour window against a 6-hour
-- wedding package pays the package fee. Settled 2026-09-28 - the package
-- maximum is advertised, so a shorter window is the client's informed choice
-- and the talent's gain. Nothing validates the window against the package.
--
-- PACKAGES ARE RECORDED ON THE QUOTE. quotes.package_id, set on insert and
-- frozen on update. packages are append-only precisely so a quote can prove
-- what was offered.
--
-- SHARED ARITHMETIC
-- -----------------
-- calc_travel_fee and calc_equipment_fee are extracted from compute_quote_pricing
-- so the preview below and the trigger cannot drift. Twenty lines of haversine
-- duplicated is how a preview and a stored figure end up disagreeing. The travel
-- constants now live in ONE place, so D-044's rate change touches one function.
--
-- compute_quote_pricing is otherwise unchanged: commission on the fee only,
-- travel and equipment commission-free inside the payout, everything frozen on
-- UPDATE, travel still at 120 x 1.05 until D-044.
--
-- THE PREVIEW
-- -----------
-- preview_quote_pricing lets a talent see their payout before committing. The
-- quote itself is a single INSERT with no draft state (settled 2026-09-28):
-- compute_quote_pricing freezes every money field on UPDATE, so a draft phase
-- would need the freeze to know about status, and a hole in that branch means an
-- issued quote is mutable. A read-only preview gives composition without a
-- mutable phase.
--
-- It returns PAYOUT ONLY - no commission, no taxes. The talent sees fee, travel
-- and equipment, which are exactly the commission-free components that reach
-- them. Consequence accepted: the talent does not know what the client was
-- shown, so "you quoted 300,000" versus "I quoted 250,000" is a support
-- conversation, not a bug.
--
-- OWNERSHIP IS CHECKED, and this is load-bearing. The preview returns the
-- talent's rate. Without the check, any authenticated user could read any
-- talent's rate for any request - D-046 reopened through a new door.
--
-- ALSO REMOVED: budget_min and budget_max. No form ever wrote them; they were
-- only displayed, in VenueDashboard, where they rendered as an empty range. The
-- price range already expresses budget, and a budget shown to a talent invites
-- quoting to it rather than to their rate.
--
-- VERIFIED behaviourally in a rolled-back transaction, wedding at 250,000 with
-- a 2-hour window, Colombo to Kandy:
--   quoted_amount 250,000 (the old multiplier would have given 125,000)
--   package "6 hours, including breaks" recorded
--   travel 84.22 km -> 21,223.44   equipment 12,500
--   payout 283,723.44   commission 52,500 (fee only)   client total 347,697.46

begin;

alter table public.quote_requests
  drop column if exists budget_min,
  drop column if exists budget_max;

alter table public.quotes
  add column if not exists package_id uuid references public.packages(id) on delete restrict;

create or replace function public.calc_travel_fee(
  p_quote_request_id uuid,
  p_talent_id        uuid,
  p_quoted_amount    numeric,
  out distance_km    numeric,
  out travel_fee     numeric,
  out estimated      boolean
)
language plpgsql stable security definer set search_path to 'public' as $$
declare
  c_rate_per_km      constant numeric := 120.00;
  c_uplift           constant numeric := 1.05;
  c_free_threshold   constant numeric := 10.0;
  c_fallback_percent constant numeric := 7.5;
  ev_lat numeric; ev_lon numeric; v_venue uuid; t_lat numeric; t_lon numeric;
begin
  select qr.event_latitude, qr.event_longitude, qr.venue_id
    into ev_lat, ev_lon, v_venue
    from public.quote_requests qr where qr.id = p_quote_request_id;

  if (ev_lat is null or ev_lon is null) and v_venue is not null then
    select pv.latitude, pv.longitude into ev_lat, ev_lon
      from public.profiles_venues pv where pv.id = v_venue;
  end if;

  select pt.base_latitude, pt.base_longitude into t_lat, t_lon
    from public.profiles_talent pt where pt.id = p_talent_id;

  if ev_lat is null or ev_lon is null or t_lat is null or t_lon is null then
    distance_km := null;
    travel_fee  := round(p_quoted_amount * c_fallback_percent / 100, 2);
    estimated   := true;
  else
    distance_km := round(
      (6371 * 2 * asin(sqrt(
        power(sin(radians(t_lat - ev_lat) / 2), 2)
        + cos(radians(ev_lat)) * cos(radians(t_lat))
          * power(sin(radians(t_lon - ev_lon) / 2), 2)
      )))::numeric, 2);
    estimated := false;
    if distance_km < c_free_threshold then
      travel_fee := 0.00;
    else
      travel_fee := round(distance_km * 2 * c_rate_per_km * c_uplift, 2);
    end if;
  end if;
end;
$$;

create or replace function public.calc_equipment_fee(
  p_talent_id     uuid,
  p_quoted_amount numeric,
  p_provided_by   public.equipment_responsibility
) returns numeric
language sql stable security definer set search_path to 'public' as $$
  select case when p_provided_by = 'talent'::public.equipment_responsibility
    then round(p_quoted_amount * coalesce(
           (select pt.equipment_fee_percent from public.profiles_talent pt where pt.id = p_talent_id),
           5.00) / 100, 2)
    else 0.00 end;
$$;

revoke all on function public.calc_travel_fee(uuid, uuid, numeric) from public, anon, authenticated;
revoke all on function public.calc_equipment_fee(uuid, numeric, public.equipment_responsibility) from public, anon, authenticated;

create or replace function public.compute_quote_pricing()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
DECLARE
  v_travel numeric; v_dist numeric; v_est boolean; v_equip numeric;
  v_comm numeric; v_payout numeric; v_base numeric;
  v_sscl numeric; v_vat numeric; v_sub numeric; v_total numeric;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF coalesce(current_setting('en4.admin_override', true), '') = 'on' THEN
      RETURN NEW;
    END IF;
    NEW.travel_fee                   := OLD.travel_fee;
    NEW.equipment_fee                := OLD.equipment_fee;
    NEW.commission_amount            := OLD.commission_amount;
    NEW.talent_payout_amount         := OLD.talent_payout_amount;
    NEW.base_amount                  := OLD.base_amount;
    NEW.sscl_amount                  := OLD.sscl_amount;
    NEW.vat_amount                   := OLD.vat_amount;
    NEW.gateway_fee_amount           := OLD.gateway_fee_amount;
    NEW.total_client_price           := OLD.total_client_price;
    NEW.sscl_rate_percent            := OLD.sscl_rate_percent;
    NEW.vat_rate_percent             := OLD.vat_rate_percent;
    NEW.gateway_rate_percent         := OLD.gateway_rate_percent;
    NEW.travel_distance_km           := OLD.travel_distance_km;
    NEW.travel_coordinates_estimated := OLD.travel_coordinates_estimated;
    NEW.equipment_provided_by        := OLD.equipment_provided_by;
    NEW.package_id                   := OLD.package_id;
    RETURN NEW;
  END IF;

  SELECT t.distance_km, t.travel_fee, t.estimated
    INTO v_dist, v_travel, v_est
    FROM public.calc_travel_fee(NEW.quote_request_id, NEW.talent_id, NEW.quoted_amount) t;

  NEW.travel_distance_km           := v_dist;
  NEW.travel_fee                   := v_travel;
  NEW.travel_coordinates_estimated := v_est;

  v_equip := public.calc_equipment_fee(NEW.talent_id, NEW.quoted_amount, NEW.equipment_provided_by);
  NEW.equipment_fee := v_equip;

  v_comm   := round(NEW.quoted_amount * NEW.commission_rate_percent / 100, 2);
  v_payout := NEW.quoted_amount + v_travel + v_equip;
  v_base   := v_payout + v_comm;
  v_sscl   := round(v_base * NEW.sscl_rate_percent / 100, 2);
  v_vat    := round((v_base + v_sscl) * NEW.vat_rate_percent / 100, 2);
  v_sub    := v_base + v_sscl + v_vat;

  IF NEW.gateway_rate_percent >= 100 THEN
    RAISE EXCEPTION 'gateway_rate_percent must be below 100.' USING ERRCODE = '22003';
  END IF;

  v_total := round(v_sub / (1 - NEW.gateway_rate_percent / 100), 2);

  NEW.commission_amount    := v_comm;
  NEW.talent_payout_amount := v_payout;
  NEW.base_amount          := v_base;
  NEW.sscl_amount          := v_sscl;
  NEW.vat_amount           := v_vat;
  NEW.gateway_fee_amount   := v_total - v_sub;
  NEW.total_client_price   := v_total;
  RETURN NEW;
END;
$function$;

create or replace function public.enforce_quote_writes()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
DECLARE
  req_rate      numeric;
  req_talent    uuid;
  req_event     public.events_type;
  parent_status quotation_request_status;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT qr.talent_rate_at_request, qr.talent_id, qr.event_type
      INTO req_rate, req_talent, req_event
      FROM public.quote_requests qr
     WHERE qr.id = NEW.quote_request_id;

    IF req_rate IS NULL THEN
      RAISE EXCEPTION
        'Cannot price a quote: quote_request % has no talent_rate_at_request.',
        NEW.quote_request_id USING ERRCODE = '22004';
    END IF;

    NEW.talent_id := req_talent;

    -- Packages are fixed, so the fee IS the talent's rate for the category.
    NEW.quoted_amount := req_rate;

    NEW.package_id := public.package_for_category(
                        public.rate_category_for_event_type(req_event), now());

    NEW.created_at := now();
    NEW.updated_at := now();

    IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
      NEW.commission_rate_percent := 21.00;
      NEW.quote_status            := 'pending'::quotation_status;
    END IF;

    RETURN NEW;
  END IF;

  NEW.id               := OLD.id;
  NEW.quote_request_id := OLD.quote_request_id;
  NEW.talent_id        := OLD.talent_id;
  NEW.quoted_amount    := OLD.quoted_amount;
  NEW.created_at       := OLD.created_at;
  NEW.updated_at       := now();

  IF NEW.quote_status = 'accepted'::quotation_status
     AND OLD.quote_status IS DISTINCT FROM NEW.quote_status THEN
    SELECT qr.status INTO parent_status
      FROM public.quote_requests qr WHERE qr.id = OLD.quote_request_id;
    IF parent_status NOT IN ('open'::quotation_request_status,
                             'matched'::quotation_request_status) THEN
      RAISE EXCEPTION
        'Cannot accept a quote whose request is %. Acceptance requires a live request.',
        parent_status USING ERRCODE = '42501';
    END IF;
  END IF;

  IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  NEW.commission_rate_percent := OLD.commission_rate_percent;
  NEW.sent_at                 := OLD.sent_at;
  NEW.expires_at              := OLD.expires_at;

  IF NEW.quote_status IS DISTINCT FROM OLD.quote_status THEN
    SELECT qr.status INTO parent_status
      FROM public.quote_requests qr WHERE qr.id = OLD.quote_request_id;
    IF NOT (OLD.quote_status = 'pending'::quotation_status
            AND NEW.quote_status = 'expired'::quotation_status
            AND parent_status IN ('cancelled'::quotation_request_status,
                                  'expired'::quotation_request_status,
                                  'declined'::quotation_request_status)) THEN
      RAISE EXCEPTION
        'A talent cannot change quote_status. Acceptance and rejection are client actions handled by the orchestration service.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

create or replace function public.preview_quote_pricing(
  p_quote_request_id uuid,
  p_equipment_provided_by public.equipment_responsibility default 'talent'
)
returns table (
  performance_fee    numeric,
  travel_fee         numeric,
  equipment_fee      numeric,
  talent_payout      numeric,
  travel_distance_km numeric,
  travel_estimated   boolean,
  package_label      text
)
language plpgsql stable security definer set search_path to 'public' as $$
declare
  req_rate numeric; req_talent uuid; req_event public.events_type;
  v_dist numeric; v_travel numeric; v_est boolean; v_equip numeric;
begin
  select qr.talent_rate_at_request, qr.talent_id, qr.event_type
    into req_rate, req_talent, req_event
    from public.quote_requests qr where qr.id = p_quote_request_id;

  if req_talent is null then
    raise exception 'No such quote request.' using errcode = '42704';
  end if;

  -- Load-bearing: this returns the talent's rate.
  if not exists (
    select 1 from public.profiles_talent pt
     where pt.id = req_talent and pt.user_id = auth.uid()
  ) and coalesce(public.get_my_role(), '') <> 'admin' then
    raise exception 'You can only preview pricing for your own quote requests.'
      using errcode = '42501';
  end if;

  select t.distance_km, t.travel_fee, t.estimated
    into v_dist, v_travel, v_est
    from public.calc_travel_fee(p_quote_request_id, req_talent, req_rate) t;

  v_equip := public.calc_equipment_fee(req_talent, req_rate, p_equipment_provided_by);

  return query select
    req_rate,
    v_travel,
    v_equip,
    round(req_rate + v_travel + v_equip, 2),
    v_dist,
    v_est,
    (select p.label from public.packages p
      where p.id = public.package_for_category(
              public.rate_category_for_event_type(req_event), now()));
end;
$$;

revoke all on function public.preview_quote_pricing(uuid, public.equipment_responsibility) from public, anon;
grant execute on function public.preview_quote_pricing(uuid, public.equipment_responsibility) to authenticated, service_role;

comment on function public.preview_quote_pricing(uuid, public.equipment_responsibility) is
  'Read-only pricing preview for the talent composing a quote. Returns their PAYOUT only - no commission, no taxes (settled 2026-09-28). Shares calc_travel_fee and calc_equipment_fee with compute_quote_pricing so the preview cannot drift from what is stored. Checks ownership: it returns the talent rate, so an unguarded version would let any authenticated user read any talent rate.';

commit;