-- Rewrites enforce_booking_provenance for the canonical money model
-- (Todoist 6hQpgHxVX8GMh3fX). Must ship with 20260905070000, which renames
-- the columns this function reads and writes. Postgres stores function
-- bodies as text, so renames do NOT propagate into them.
--
-- Two defects fixed:
--
--   1. agreed_gross_amount was assigned from quotes.talent_net_earnings.
--      Gross from net. Wrong under any commission model.
--
--   2. Nothing computed the quote money fields, so the trigger pushed NULL
--      into two NOT NULL columns and every booking INSERT failed 23502.
--      A quote with no computed pricing now raises a clear error instead.

CREATE OR REPLACE FUNCTION public.enforce_booking_provenance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  q_status     quotation_status;
  q_talent     uuid;
  q_fee        numeric;
  q_travel     numeric;
  q_equipment  numeric;
  q_commission numeric;
  q_base       numeric;
  q_payout     numeric;
  q_sscl       numeric;
  q_vat        numeric;
  q_gateway    numeric;
  q_total      numeric;
  q_comm_rate  numeric;
  q_sscl_rate  numeric;
  q_vat_rate   numeric;
  q_gw_rate    numeric;
  r_client     uuid;
  r_venue      uuid;
  r_starts     timestamptz;
  r_ends       timestamptz;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT q.quote_status, q.talent_id,
           q.quoted_amount,
           COALESCE(q.travel_fee, 0),
           COALESCE(q.equipment_fee, 0),
           q.commission_amount, q.base_amount, q.talent_payout_amount,
           q.sscl_amount, q.vat_amount, q.gateway_fee_amount, q.total_client_price,
           q.commission_rate_percent, q.sscl_rate_percent,
           q.vat_rate_percent, q.gateway_rate_percent,
           qr.client_user_id, qr.venue_id, qr.starts_at, qr.ends_at
      INTO q_status, q_talent,
           q_fee, q_travel, q_equipment,
           q_commission, q_base, q_payout,
           q_sscl, q_vat, q_gateway, q_total,
           q_comm_rate, q_sscl_rate, q_vat_rate, q_gw_rate,
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
        NEW.quote_id, q_status
        USING ERRCODE = '42501';
    END IF;

    IF q_total IS NULL OR q_base IS NULL THEN
      RAISE EXCEPTION
        'Cannot create a booking: quote % has no computed pricing.',
        NEW.quote_id
        USING ERRCODE = '22004';
    END IF;

    NEW.talent_id      := q_talent;
    NEW.client_user_id := r_client;
    NEW.venue_id       := r_venue;
    NEW.starts_at      := r_starts;
    NEW.ends_at        := r_ends;

    NEW.talent_fee_amount    := q_fee;
    NEW.travel_fee_amount    := q_travel;
    NEW.equipment_fee_amount := q_equipment;
    NEW.commission_amount    := q_commission;
    NEW.base_amount          := q_base;
    NEW.talent_payout_amount := q_payout;
    NEW.sscl_amount          := q_sscl;
    NEW.vat_amount           := q_vat;
    NEW.gateway_fee_amount   := q_gateway;
    NEW.client_total_amount  := q_total;

    NEW.commission_rate_percent := q_comm_rate;
    NEW.sscl_rate_percent       := q_sscl_rate;
    NEW.vat_rate_percent        := q_vat_rate;
    NEW.gateway_rate_percent    := q_gw_rate;

    NEW.created_at := now();
    RETURN NEW;
  END IF;

  NEW.id                      := OLD.id;
  NEW.quote_id                := OLD.quote_id;
  NEW.client_user_id          := OLD.client_user_id;
  NEW.talent_id               := OLD.talent_id;
  NEW.venue_id                := OLD.venue_id;
  NEW.starts_at               := OLD.starts_at;
  NEW.ends_at                 := OLD.ends_at;
  NEW.talent_fee_amount       := OLD.talent_fee_amount;
  NEW.travel_fee_amount       := OLD.travel_fee_amount;
  NEW.equipment_fee_amount    := OLD.equipment_fee_amount;
  NEW.commission_amount       := OLD.commission_amount;
  NEW.base_amount             := OLD.base_amount;
  NEW.talent_payout_amount    := OLD.talent_payout_amount;
  NEW.sscl_amount             := OLD.sscl_amount;
  NEW.vat_amount              := OLD.vat_amount;
  NEW.gateway_fee_amount      := OLD.gateway_fee_amount;
  NEW.client_total_amount     := OLD.client_total_amount;
  NEW.commission_rate_percent := OLD.commission_rate_percent;
  NEW.sscl_rate_percent       := OLD.sscl_rate_percent;
  NEW.vat_rate_percent        := OLD.vat_rate_percent;
  NEW.gateway_rate_percent    := OLD.gateway_rate_percent;
  NEW.created_at              := OLD.created_at;

  RETURN NEW;
END;
$function$;
