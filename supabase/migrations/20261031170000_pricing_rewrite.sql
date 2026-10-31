-- Stage 2C-2b: the pricing rewrite.
--
-- THIS CHANGES BEHAVIOUR. Everything before it was additive.
--
-- Before: one commission leg of 21%, charged on the performance fee and
--         added to the client bill. Travel at Rs 120/km with a 1.05 uplift.
--         Equipment at 5% of the fee. All rates hardcoded in functions and
--         column defaults.
--
-- After:  two legs of 10% each -- the client leg ADDED to the client bill and
--         charged on the full talent bill, the talent leg DEDUCTED from the
--         talent payout and charged on the performance fee only. Travel at
--         Rs 150/km flat. No equipment fee. Every rate read from
--         rate_configs at insert time and snapshotted onto the quote.
--
-- The equipment columns still EXIST after this migration -- they are simply
-- no longer written or read. Dropping them is 2C-3, so that this migration
-- can be reverted without data loss.

-- =====================================================================
-- 1. Renames. The singular name must not survive anywhere: a column
--    called "commission_amount" in a two-leg model will be read as "the"
--    commission by the next person to touch it.
-- =====================================================================

alter table public.quotes
  rename column commission_amount to commission_client_amount;
alter table public.quotes
  rename column commission_rate_percent to commission_client_rate_percent;

alter table public.bookings
  rename column commission_amount to commission_client_amount;
alter table public.bookings
  rename column commission_rate_percent to commission_client_rate_percent;

-- The 21.00 default is the superseded model. Rates now come from
-- rate_configs via enforce_quote_writes, which runs for every insert, so
-- this default should never be reached. Set to 0 so that if it ever IS
-- reached the result is visibly wrong rather than plausibly wrong.
alter table public.quotes
  alter column commission_client_rate_percent set default 0.000;

-- tax_base_amount, added 2026-10-29, never read. The taxation consultant's
-- answer (2026-10-26, full client invoice) makes it identical to
-- base_amount on every row. Two columns that are always equal invite
-- someone to "fix" the redundant-looking one, and they will not pick the
-- one the tax calculation reads.
alter table public.quotes
  drop column tax_base_amount;

-- =====================================================================
-- 2. Constraints. Five, not the two originally scoped: the payout
--    identities define payout as fee + travel + equipment, which is wrong
--    in two ways under the new model.
-- =====================================================================

alter table public.quotes drop constraint quotes_base_adds_up;
alter table public.quotes add constraint quotes_base_adds_up check (
  base_amount is null or base_amount = (
      quoted_amount
    + coalesce(travel_fee, 0)
    + coalesce(meals_fee, 0)
    + coalesce(accommodation_fee, 0)
    + commission_client_amount
  )
);

alter table public.quotes drop constraint quotes_payout_adds_up;
alter table public.quotes add constraint quotes_payout_adds_up check (
  talent_payout_amount is null or talent_payout_amount = (
      quoted_amount
    + coalesce(travel_fee, 0)
    + coalesce(meals_fee, 0)
    + coalesce(accommodation_fee, 0)
    - coalesce(commission_talent_amount, 0)
  )
);

alter table public.quotes drop constraint quotes_amounts_positive;
alter table public.quotes add constraint quotes_amounts_positive check (
      quoted_amount > 0
  and coalesce(travel_fee, 0) >= 0
  and coalesce(meals_fee, 0) >= 0
  and coalesce(accommodation_fee, 0) >= 0
  and coalesce(commission_talent_amount, 0) >= 0
);

alter table public.bookings drop constraint bookings_base_adds_up;
alter table public.bookings add constraint bookings_base_adds_up check (
  base_amount = 0.00 or base_amount = (
      talent_fee_amount
    + travel_fee_amount
    + meals_fee_amount
    + accommodation_fee_amount
    + commission_client_amount
  )
);

alter table public.bookings drop constraint bookings_payout_adds_up;
alter table public.bookings add constraint bookings_payout_adds_up check (
  talent_payout_amount is null or talent_payout_amount = (
      talent_fee_amount
    + travel_fee_amount
    + meals_fee_amount
    + accommodation_fee_amount
    - commission_talent_amount
  )
);

-- =====================================================================
-- 3. calc_travel_fee -- reads the config instead of four constants.
--    Behaviour preserved deliberately: the fee is charged on DOUBLE the
--    one-way distance (round trip), as the previous implementation did.
--    That was never written down as a decision; it is preserved here
--    rather than silently changed, and should be confirmed.
-- =====================================================================

create or replace function public.calc_travel_fee(
  p_quote_request_id uuid,
  p_talent_id        uuid,
  p_quoted_amount    numeric,
  out distance_km    numeric,
  out travel_fee     numeric,
  out estimated      boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cfg    public.rate_configs;
  ev_lat numeric; ev_lon numeric; v_venue uuid; t_lat numeric; t_lon numeric;
begin
  select * into cfg from public.rate_config_at(now());
  if cfg.id is null then
    raise exception 'No rate configuration is in force. Cannot price travel.'
      using errcode = '22004';
  end if;

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
    travel_fee  := round(p_quoted_amount * cfg.travel_fallback_percent / 100, 2);
    estimated   := true;
  else
    distance_km := round(
      (6371 * 2 * asin(sqrt(
        power(sin(radians(t_lat - ev_lat) / 2), 2)
        + cos(radians(ev_lat)) * cos(radians(t_lat))
          * power(sin(radians(t_lon - ev_lon) / 2), 2)
      )))::numeric, 2);
    estimated := false;
    if distance_km < cfg.travel_free_threshold_km then
      travel_fee := 0.00;
    else
      travel_fee := round(distance_km * 2 * cfg.travel_rate_per_km, 2);
    end if;
  end if;
end;
$$;

-- =====================================================================
-- 4. enforce_quote_writes -- resolves the configuration and stamps the
--    rates. Runs BEFORE compute_quote_pricing (alphabetical trigger
--    order), which is what makes the rates available to the arithmetic.
--
--    CHANGE OF BEHAVIOUR: rates are now stamped from the config for EVERY
--    insert, including admin inserts. Previously an admin could insert a
--    quote with a hand-chosen commission rate. An admin who needs a
--    different rate now inserts a rate_configs row, so that every quote's
--    rates remain traceable to a configuration rather than to a session.
-- =====================================================================

create or replace function public.enforce_quote_writes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  req_rate      numeric;
  req_talent    uuid;
  req_event     public.events_type;
  parent_status quotation_request_status;
  cfg           public.rate_configs;
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

    SELECT * INTO cfg FROM public.rate_config_at(now());
    IF cfg.id IS NULL THEN
      RAISE EXCEPTION 'No rate configuration is in force. Cannot price a quote.'
        USING ERRCODE = '22004';
    END IF;

    NEW.rate_config_id                 := cfg.id;
    NEW.commission_client_rate_percent := cfg.commission_client_rate_percent;
    NEW.commission_talent_rate_percent := cfg.commission_talent_rate_percent;
    NEW.sscl_rate_percent              := cfg.sscl_rate_percent;
    NEW.vat_rate_percent               := cfg.vat_rate_percent;
    NEW.gateway_rate_percent           := cfg.gateway_rate_percent;

    NEW.created_at := now();
    NEW.updated_at := now();

    IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
      NEW.quote_status := 'pending'::quotation_status;
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

  NEW.commission_client_rate_percent := OLD.commission_client_rate_percent;
  NEW.commission_talent_rate_percent := OLD.commission_talent_rate_percent;
  NEW.rate_config_id                 := OLD.rate_config_id;
  NEW.sent_at                        := OLD.sent_at;
  NEW.expires_at                     := OLD.expires_at;

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
$$;

-- =====================================================================
-- 5. compute_quote_pricing -- the arithmetic.
--
--   talent_bill = fee + travel + meals + accommodation
--   client leg  = client_rate% of talent_bill        (ADDED to the bill)
--   talent leg  = talent_rate% of the FEE ONLY       (DEDUCTED from payout)
--   base        = talent_bill + client leg           (= the tax base)
--   sscl        = base * sscl_rate
--   vat         = (base + sscl) * vat_rate
--   total       = (base + sscl + vat) / (1 - gateway_rate)
--   payout      = talent_bill - talent leg
--
-- The talent leg is charged on the FEE, not on the grossed-up client
-- figure. On a fee of 100 the platform takes 20, not 21.
-- =====================================================================

create or replace function public.compute_quote_pricing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  v_travel numeric; v_dist numeric; v_est boolean;
  v_bill numeric; v_comm_client numeric; v_comm_talent numeric;
  v_payout numeric; v_base numeric;
  v_sscl numeric; v_vat numeric; v_sub numeric; v_total numeric;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF coalesce(current_setting('en4.admin_override', true), '') = 'on' THEN
      RETURN NEW;
    END IF;
    NEW.travel_fee                     := OLD.travel_fee;
    NEW.meals_fee                      := OLD.meals_fee;
    NEW.accommodation_fee              := OLD.accommodation_fee;
    NEW.equipment_fee                  := OLD.equipment_fee;
    NEW.commission_client_amount       := OLD.commission_client_amount;
    NEW.commission_talent_amount       := OLD.commission_talent_amount;
    NEW.talent_payout_amount           := OLD.talent_payout_amount;
    NEW.base_amount                    := OLD.base_amount;
    NEW.sscl_amount                    := OLD.sscl_amount;
    NEW.vat_amount                     := OLD.vat_amount;
    NEW.gateway_fee_amount             := OLD.gateway_fee_amount;
    NEW.total_client_price             := OLD.total_client_price;
    NEW.commission_client_rate_percent := OLD.commission_client_rate_percent;
    NEW.commission_talent_rate_percent := OLD.commission_talent_rate_percent;
    NEW.sscl_rate_percent              := OLD.sscl_rate_percent;
    NEW.vat_rate_percent               := OLD.vat_rate_percent;
    NEW.gateway_rate_percent           := OLD.gateway_rate_percent;
    NEW.rate_config_id                 := OLD.rate_config_id;
    NEW.travel_distance_km             := OLD.travel_distance_km;
    NEW.travel_coordinates_estimated   := OLD.travel_coordinates_estimated;
    NEW.equipment_provided_by          := OLD.equipment_provided_by;
    NEW.package_id                     := OLD.package_id;
    RETURN NEW;
  END IF;

  SELECT t.distance_km, t.travel_fee, t.estimated
    INTO v_dist, v_travel, v_est
    FROM public.calc_travel_fee(NEW.quote_request_id, NEW.talent_id, NEW.quoted_amount) t;

  NEW.travel_distance_km           := v_dist;
  NEW.travel_fee                   := v_travel;
  NEW.travel_coordinates_estimated := v_est;

  -- Equipment is retired. The column survives until 2C-3; zero it so no
  -- stale value can be mistaken for a live fee.
  NEW.equipment_fee := 0.00;

  NEW.meals_fee         := coalesce(NEW.meals_fee, 0.00);
  NEW.accommodation_fee := coalesce(NEW.accommodation_fee, 0.00);

  v_bill := NEW.quoted_amount + v_travel + NEW.meals_fee + NEW.accommodation_fee;

  v_comm_client := round(v_bill * NEW.commission_client_rate_percent / 100, 2);
  v_comm_talent := round(NEW.quoted_amount * NEW.commission_talent_rate_percent / 100, 2);

  v_payout := v_bill - v_comm_talent;
  v_base   := v_bill + v_comm_client;

  v_sscl := round(v_base * NEW.sscl_rate_percent / 100, 2);
  v_vat  := round((v_base + v_sscl) * NEW.vat_rate_percent / 100, 2);
  v_sub  := v_base + v_sscl + v_vat;

  IF NEW.gateway_rate_percent >= 100 THEN
    RAISE EXCEPTION 'gateway_rate_percent must be below 100.' USING ERRCODE = '22003';
  END IF;

  v_total := round(v_sub / (1 - NEW.gateway_rate_percent / 100), 2);

  NEW.commission_client_amount := v_comm_client;
  NEW.commission_talent_amount := v_comm_talent;
  NEW.talent_payout_amount     := v_payout;
  NEW.base_amount              := v_base;
  NEW.sscl_amount              := v_sscl;
  NEW.vat_amount               := v_vat;
  NEW.gateway_fee_amount       := v_total - v_sub;
  NEW.total_client_price       := v_total;
  RETURN NEW;
END;
$$;

-- =====================================================================
-- 6. preview_quote_pricing -- talent-facing. Signature changes, so the
--    old one is dropped rather than replaced.
--
--    The talent-side commission IS shown. It is money deducted from them
--    and a payout 10% below their stated rate, unexplained, is worse than
--    showing the line. The CLIENT-side leg and the client total remain
--    hidden -- that is what D-046 protects.
-- =====================================================================

drop function if exists public.preview_quote_pricing(uuid, equipment_responsibility);

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
  package_label            text
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
              public.rate_category_for_event_type(req_event), now()));
end;
$$;

revoke all on function public.preview_quote_pricing(uuid, numeric, numeric) from public, anon;
grant execute on function public.preview_quote_pricing(uuid, numeric, numeric) to authenticated, service_role;

-- =====================================================================
-- 7. enforce_booking_provenance -- carry the new columns across.
-- =====================================================================

create or replace function public.enforce_booking_provenance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  q_status      quotation_status;
  q_talent      uuid;
  q_fee         numeric;
  q_travel      numeric;
  q_meals       numeric;
  q_accom       numeric;
  q_comm_client numeric;
  q_comm_talent numeric;
  q_base        numeric;
  q_payout      numeric;
  q_sscl        numeric;
  q_vat         numeric;
  q_gateway     numeric;
  q_total       numeric;
  q_cc_rate     numeric;
  q_ct_rate     numeric;
  q_sscl_rate   numeric;
  q_vat_rate    numeric;
  q_gw_rate     numeric;
  r_client      uuid;
  r_venue       uuid;
  r_starts      timestamptz;
  r_ends        timestamptz;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT q.quote_status, q.talent_id,
           q.quoted_amount,
           COALESCE(q.travel_fee, 0),
           COALESCE(q.meals_fee, 0),
           COALESCE(q.accommodation_fee, 0),
           q.commission_client_amount,
           COALESCE(q.commission_talent_amount, 0),
           q.base_amount, q.talent_payout_amount,
           q.sscl_amount, q.vat_amount, q.gateway_fee_amount, q.total_client_price,
           q.commission_client_rate_percent, q.commission_talent_rate_percent,
           q.sscl_rate_percent, q.vat_rate_percent, q.gateway_rate_percent,
           qr.client_user_id, qr.venue_id, qr.starts_at, qr.ends_at
      INTO q_status, q_talent,
           q_fee, q_travel, q_meals, q_accom,
           q_comm_client, q_comm_talent,
           q_base, q_payout,
           q_sscl, q_vat, q_gateway, q_total,
           q_cc_rate, q_ct_rate, q_sscl_rate, q_vat_rate, q_gw_rate,
           r_client, r_venue, r_starts, r_ends
      FROM public.quotes q
      JOIN public.quote_requests qr ON qr.id = q.quote_request_id
     WHERE q.id = NEW.quote_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Cannot create a booking: quote % does not exist.',
        NEW.quote_id USING ERRCODE = '23503';
    END IF;

    IF q_status <> 'accepted'::quotation_status THEN
      RAISE EXCEPTION
        'A booking requires an accepted quote (quote % is %).',
        NEW.quote_id, q_status USING ERRCODE = '42501';
    END IF;

    IF q_total IS NULL OR q_base IS NULL THEN
      RAISE EXCEPTION
        'Cannot create a booking: quote % has no computed pricing.',
        NEW.quote_id USING ERRCODE = '22004';
    END IF;

    NEW.talent_id      := q_talent;
    NEW.client_user_id := r_client;
    NEW.venue_id       := r_venue;
    NEW.starts_at      := r_starts;
    NEW.ends_at        := r_ends;

    NEW.talent_fee_amount         := q_fee;
    NEW.travel_fee_amount         := q_travel;
    NEW.meals_fee_amount          := q_meals;
    NEW.accommodation_fee_amount  := q_accom;
    NEW.equipment_fee_amount      := 0.00;
    NEW.commission_client_amount  := q_comm_client;
    NEW.commission_talent_amount  := q_comm_talent;
    NEW.base_amount               := q_base;
    NEW.talent_payout_amount      := q_payout;
    NEW.sscl_amount               := q_sscl;
    NEW.vat_amount                := q_vat;
    NEW.gateway_fee_amount        := q_gateway;
    NEW.client_total_amount       := q_total;

    NEW.commission_client_rate_percent := q_cc_rate;
    NEW.commission_talent_rate_percent := q_ct_rate;
    NEW.sscl_rate_percent              := q_sscl_rate;
    NEW.vat_rate_percent               := q_vat_rate;
    NEW.gateway_rate_percent           := q_gw_rate;

    NEW.created_at := now();
    RETURN NEW;
  END IF;

  NEW.id                             := OLD.id;
  NEW.quote_id                       := OLD.quote_id;
  NEW.client_user_id                 := OLD.client_user_id;
  NEW.talent_id                      := OLD.talent_id;
  NEW.venue_id                       := OLD.venue_id;
  NEW.starts_at                      := OLD.starts_at;
  NEW.ends_at                        := OLD.ends_at;
  NEW.talent_fee_amount              := OLD.talent_fee_amount;
  NEW.travel_fee_amount              := OLD.travel_fee_amount;
  NEW.meals_fee_amount               := OLD.meals_fee_amount;
  NEW.accommodation_fee_amount       := OLD.accommodation_fee_amount;
  NEW.equipment_fee_amount           := OLD.equipment_fee_amount;
  NEW.commission_client_amount       := OLD.commission_client_amount;
  NEW.commission_talent_amount       := OLD.commission_talent_amount;
  NEW.base_amount                    := OLD.base_amount;
  NEW.talent_payout_amount           := OLD.talent_payout_amount;
  NEW.sscl_amount                    := OLD.sscl_amount;
  NEW.vat_amount                     := OLD.vat_amount;
  NEW.gateway_fee_amount             := OLD.gateway_fee_amount;
  NEW.client_total_amount            := OLD.client_total_amount;
  NEW.commission_client_rate_percent := OLD.commission_client_rate_percent;
  NEW.commission_talent_rate_percent := OLD.commission_talent_rate_percent;
  NEW.sscl_rate_percent              := OLD.sscl_rate_percent;
  NEW.vat_rate_percent               := OLD.vat_rate_percent;
  NEW.gateway_rate_percent           := OLD.gateway_rate_percent;
  NEW.created_at                     := OLD.created_at;

  RETURN NEW;
END;
$$;

-- =====================================================================
-- 8. Function ACLs. "revoke from public" does NOT remove the EXECUTE that
--    Supabase grants to anon and authenticated BY NAME -- they must be
--    named. This cost an extra migration on 2026-10-26.
-- =====================================================================

revoke all on function public.calc_travel_fee(uuid, uuid, numeric) from public, anon, authenticated;
grant execute on function public.calc_travel_fee(uuid, uuid, numeric) to service_role;

revoke all on function public.compute_quote_pricing() from public, anon, authenticated;
revoke all on function public.enforce_quote_writes() from public, anon, authenticated;
revoke all on function public.enforce_booking_provenance() from public, anon, authenticated;
