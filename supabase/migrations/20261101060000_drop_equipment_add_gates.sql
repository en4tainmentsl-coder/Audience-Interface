-- Stage 2C-3: retire equipment, and gate meals and accommodation by distance.
--
-- Equipment was superseded by D-042: the talent's rate is all-inclusive and
-- the platform no longer prices gear separately. Since 20261031170000 nothing
-- computes an equipment fee -- the columns were kept one migration longer so
-- that the pricing rewrite could be reverted without data loss. That window
-- has closed.
--
-- NOT TOUCHED: cancellation_reason carries a value called 'equipment_failure'.
-- That is a talent's gear breaking as a reason to cancel a booking. It has
-- nothing to do with the equipment FEE and stays exactly as it is.

-- =====================================================================
-- 1. compute_quote_pricing -- stop writing equipment, and enforce the
--    distance gates.
--
--    The gates live here rather than in a CHECK constraint because the
--    thresholds are configuration: a CHECK must be immutable and cannot
--    read rate_configs. Hardcoding 100 and 150 in a constraint would put
--    the numbers back in the schema, which is what the config layer
--    exists to prevent.
--
--    The thresholds are read via NEW.rate_config_id -- the row
--    enforce_quote_writes already stamped -- so the gate is evaluated
--    against the same configuration that priced the quote, not against
--    whatever is current at the time of the check.
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
  v_meals_min numeric; v_accom_min numeric;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF coalesce(current_setting('en4.admin_override', true), '') = 'on' THEN
      RETURN NEW;
    END IF;
    NEW.travel_fee                     := OLD.travel_fee;
    NEW.meals_fee                      := OLD.meals_fee;
    NEW.accommodation_fee              := OLD.accommodation_fee;
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
    NEW.package_id                     := OLD.package_id;
    RETURN NEW;
  END IF;

  SELECT t.distance_km, t.travel_fee, t.estimated
    INTO v_dist, v_travel, v_est
    FROM public.calc_travel_fee(NEW.quote_request_id, NEW.talent_id, NEW.quoted_amount) t;

  NEW.travel_distance_km           := v_dist;
  NEW.travel_fee                   := v_travel;
  NEW.travel_coordinates_estimated := v_est;

  NEW.meals_fee         := coalesce(NEW.meals_fee, 0.00);
  NEW.accommodation_fee := coalesce(NEW.accommodation_fee, 0.00);

  -- Distance gates. Both thresholds come from the configuration this quote
  -- was priced against.
  IF NEW.meals_fee > 0 OR NEW.accommodation_fee > 0 THEN
    SELECT rc.meals_threshold_km, rc.accommodation_threshold_km
      INTO v_meals_min, v_accom_min
      FROM public.rate_configs rc WHERE rc.id = NEW.rate_config_id;

    -- Since 20261101053000 both ends of the journey are guaranteed to have
    -- coordinates, so a NULL distance should be unreachable. If it ever
    -- happens the gate cannot be evaluated, and an unverifiable claim is
    -- refused rather than waved through.
    IF v_dist IS NULL THEN
      RAISE EXCEPTION
        'Meals and accommodation need a known travel distance. This booking has none, so the distance thresholds cannot be checked.'
        USING ERRCODE = '22004';
    END IF;

    IF NEW.meals_fee > 0 AND v_dist < v_meals_min THEN
      RAISE EXCEPTION
        'A meals fee applies only beyond % km. This booking is % km.',
        v_meals_min, v_dist USING ERRCODE = '23514';
    END IF;

    IF NEW.accommodation_fee > 0 AND v_dist < v_accom_min THEN
      RAISE EXCEPTION
        'An accommodation fee applies only beyond % km. This booking is % km.',
        v_accom_min, v_dist USING ERRCODE = '23514';
    END IF;
  END IF;

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
-- 2. enforce_booking_provenance -- stop carrying equipment across.
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
-- 3. Drop the equipment estate.
--    Functions first, then columns, then the enum -- each step removes
--    the dependency the next one would otherwise hit.
--    Dropping a column drops its CHECK constraints with it, which is how
--    chk_talent_equipment_fee_percent goes.
-- =====================================================================

drop function if exists public.calc_equipment_fee(uuid, numeric, public.equipment_responsibility);

alter table public.quotes
  drop column equipment_fee,
  drop column equipment_provided_by,
  drop column equipment_notes;

alter table public.bookings
  drop column equipment_fee_amount;

alter table public.profiles_talent
  drop column equipment_fee_percent;

drop type if exists public.equipment_responsibility;

-- =====================================================================
-- 4. Documentation.
-- =====================================================================

comment on column public.quotes.meals_fee is
  'Talent-entered meals fee. Permitted only beyond rate_configs.meals_threshold_km, enforced in compute_quote_pricing -- a CHECK cannot read configuration. Reaches the talent whole; no commission is deducted from it.';

comment on column public.quotes.accommodation_fee is
  'Talent-entered accommodation fee. Permitted only beyond rate_configs.accommodation_threshold_km, enforced in compute_quote_pricing. Reaches the talent whole.';
