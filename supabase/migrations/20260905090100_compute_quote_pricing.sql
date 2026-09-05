-- Quote pricing computation. Canonical model in Todoist 6hQpgHxVX8GMh3fX,
-- settled 2026-09-05. This is the last piece blocking booking creation:
-- until now nothing computed the quote money fields, so every booking
-- INSERT failed.
--
--   commission   = 21% of the PERFORMANCE FEE ONLY (not travel, not equipment)
--   talent_payout = performance + travel + equipment   (markup: talent keeps all)
--   base          = talent_payout + commission
--   sscl          = 2.5% of base
--   vat           = 18% of (base + sscl)
--   client_total  = (base + sscl + vat) / 0.967        <- DIVISION, never x1.033
--   gateway_fee   = client_total - subtotal            <- absorbs the rounding
--
-- Deriving gateway_fee as the remainder guarantees
-- quotes_total_adds_up holds exactly, whatever the rounding.
--
-- TRAVEL: threshold, not allowance. Under 10km one-way, no charge at all.
-- At 10km or more the FULL distance is charged, nothing deducted.
--   fee = one_way_km * 2 * 120 * 1.05
-- Coordinates: the request's own first, the venue's as fallback. If
-- neither is available, 7.5% of the performance fee and the estimated
-- flag is set.
--
-- EQUIPMENT: charged only when the talent provides sound. Percentage is
-- per-talent (default 5%, ceiling 10%).
--
-- Fires BEFORE INSERT OR UPDATE, named to sort after enforce_quote_writes
-- so quoted_amount is already set. On UPDATE it pins every money column
-- to OLD: the price is fixed at insert. This also closes a hole, since
-- enforce_quote_writes pinned only quoted_amount and left the rest
-- writable. The en4.admin_override escape hatch is honoured, matching
-- the booking status trigger.

CREATE OR REPLACE FUNCTION public.compute_quote_pricing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  -- v1 constants. Move to platform_config when that table exists.
  c_rate_per_km      constant numeric := 120.00;
  c_uplift           constant numeric := 1.05;
  c_free_threshold   constant numeric := 10.0;
  c_fallback_percent constant numeric := 7.5;

  ev_lat      numeric;
  ev_lon      numeric;
  v_venue     uuid;
  t_lat       numeric;
  t_lon       numeric;
  t_equip_pct numeric;
  dist_km     numeric;
  v_travel    numeric;
  v_equip     numeric;
  v_comm      numeric;
  v_payout    numeric;
  v_base      numeric;
  v_sscl      numeric;
  v_vat       numeric;
  v_sub       numeric;
  v_total     numeric;
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

    RETURN NEW;
  END IF;

  SELECT qr.event_latitude, qr.event_longitude, qr.venue_id
    INTO ev_lat, ev_lon, v_venue
    FROM public.quote_requests qr
   WHERE qr.id = NEW.quote_request_id;

  IF (ev_lat IS NULL OR ev_lon IS NULL) AND v_venue IS NOT NULL THEN
    SELECT pv.latitude, pv.longitude
      INTO ev_lat, ev_lon
      FROM public.profiles_venues pv
     WHERE pv.id = v_venue;
  END IF;

  SELECT pt.base_latitude, pt.base_longitude, pt.equipment_fee_percent
    INTO t_lat, t_lon, t_equip_pct
    FROM public.profiles_talent pt
   WHERE pt.id = NEW.talent_id;

  IF ev_lat IS NULL OR ev_lon IS NULL OR t_lat IS NULL OR t_lon IS NULL THEN
    dist_km  := NULL;
    v_travel := round(NEW.quoted_amount * c_fallback_percent / 100, 2);
    NEW.travel_coordinates_estimated := true;
  ELSE
    dist_km := round(
      6371 * 2 * asin(sqrt(
        power(sin(radians(t_lat - ev_lat) / 2), 2)
        + cos(radians(ev_lat)) * cos(radians(t_lat))
          * power(sin(radians(t_lon - ev_lon) / 2), 2)
      ))::numeric, 2);

    NEW.travel_coordinates_estimated := false;

    IF dist_km < c_free_threshold THEN
      v_travel := 0.00;
    ELSE
      v_travel := round(dist_km * 2 * c_rate_per_km * c_uplift, 2);
    END IF;
  END IF;

  NEW.travel_distance_km := dist_km;
  NEW.travel_fee         := v_travel;

  IF NEW.equipment_provided_by = 'talent'::equipment_responsibility THEN
    v_equip := round(NEW.quoted_amount * coalesce(t_equip_pct, 5.00) / 100, 2);
  ELSE
    v_equip := 0.00;
  END IF;
  NEW.equipment_fee := v_equip;

  v_comm   := round(NEW.quoted_amount * NEW.commission_rate_percent / 100, 2);
  v_payout := NEW.quoted_amount + v_travel + v_equip;
  v_base   := v_payout + v_comm;
  v_sscl   := round(v_base * NEW.sscl_rate_percent / 100, 2);
  v_vat    := round((v_base + v_sscl) * NEW.vat_rate_percent / 100, 2);
  v_sub    := v_base + v_sscl + v_vat;

  IF NEW.gateway_rate_percent >= 100 THEN
    RAISE EXCEPTION 'gateway_rate_percent must be below 100.'
      USING ERRCODE = '22003';
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

DROP TRIGGER IF EXISTS quotes_compute_pricing ON public.quotes;

CREATE TRIGGER quotes_compute_pricing
  BEFORE INSERT OR UPDATE ON public.quotes
  FOR EACH ROW
  EXECUTE FUNCTION public.compute_quote_pricing();
