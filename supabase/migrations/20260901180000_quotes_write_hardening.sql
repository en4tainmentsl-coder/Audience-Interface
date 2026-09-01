-- Harden writes on quotes, and remove the counter-offer dead code.
--
-- quotes_talent_manage was FOR ALL: correctly ownership-scoped, but it let a
-- talent write every column in every state. The sharpest consequence was not
-- the money columns - it was that a talent could set quote_status='accepted'
-- on their own quote, and acceptance is what creates a booking.
--
-- Decisions settled 2026-09-01:
--   - Quote creation is service-role only. No talent INSERT path.
--   - quoted_amount is computed by trigger, never caller-supplied, and is
--     immutable afterwards for every caller including service_role.
--   - Counter-offers are dead: 'countered' and counter_used are removed.
--
-- Note: talent_net_earnings, commission_amount and total_client_price are
-- GENERATED ALWAYS columns. Postgres rejects writes to them from any role,
-- so they need no policy or trigger protection.

-- 1. Counter-offer dead code. Postgres has no DROP VALUE, so the enum is
--    recreated. Safe here: quotation_status has exactly one dependent
--    column and the table has no rows.
ALTER TABLE public.quotes DROP COLUMN IF EXISTS counter_used;

ALTER TABLE public.quotes DROP CONSTRAINT IF EXISTS chk_quote_status;

ALTER TYPE public.quotation_status RENAME TO quotation_status_old;

CREATE TYPE public.quotation_status AS ENUM
  ('pending', 'accepted', 'rejected', 'expired');

ALTER TABLE public.quotes
  ALTER COLUMN quote_status TYPE public.quotation_status
  USING quote_status::text::public.quotation_status;

DROP TYPE public.quotation_status_old;

-- chk_quote_status is not recreated. It enumerated every value of the enum,
-- so the type is already the constraint.

-- 2. Column defaults. quote_status and created_at were nullable with no
--    default; sent_at was NOT NULL with no default.
UPDATE public.quotes SET quote_status = 'pending'::public.quotation_status
  WHERE quote_status IS NULL;
UPDATE public.quotes SET created_at = now() WHERE created_at IS NULL;

ALTER TABLE public.quotes
  ALTER COLUMN quote_status SET DEFAULT 'pending'::public.quotation_status,
  ALTER COLUMN quote_status SET NOT NULL,
  ALTER COLUMN created_at   SET DEFAULT now(),
  ALTER COLUMN created_at   SET NOT NULL,
  ALTER COLUMN sent_at      SET DEFAULT now();

-- 3. Redundant CHECK constraints, each strictly superseded.
--    quotes_amounts_positive covers quoted_amount > 0 and both fees >= 0.
--    quotes_commission_rate_valid is identical to chk_quote_commission_rate.
ALTER TABLE public.quotes
  DROP CONSTRAINT IF EXISTS chk_quote_amount_positive,
  DROP CONSTRAINT IF EXISTS chk_quote_commission_rate,
  DROP CONSTRAINT IF EXISTS chk_quote_travel_fee,
  DROP CONSTRAINT IF EXISTS chk_quote_equipment_fee;

-- 4. Pricing and write control.
CREATE OR REPLACE FUNCTION public.enforce_quote_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  req_rate  numeric;
  req_hours numeric;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT qr.talent_rate_at_request, qr.duration_hours
      INTO req_rate, req_hours
      FROM public.quote_requests qr
     WHERE qr.id = NEW.quote_request_id;

    IF req_rate IS NULL THEN
      RAISE EXCEPTION
        'Cannot price a quote: quote_request % has no talent_rate_at_request.',
        NEW.quote_request_id
        USING ERRCODE = '22004';
    END IF;

    -- Hard floor at 1x below a 4-hour session, pro-rata above it.
    -- Computed here so the figure is correct regardless of caller,
    -- including a buggy orchestration service writing as service_role.
    NEW.quoted_amount := round(req_rate * greatest(1, req_hours / 4), 2);

    NEW.created_at := now();
    NEW.updated_at := now();

    IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
      NEW.commission_rate_percent := 21.00;
      NEW.quote_status            := 'pending'::quotation_status;
    END IF;

    RETURN NEW;
  END IF;

  -- Immutable for every caller, service_role included. quoted_amount is a
  -- function of two immutable inputs, so repricing means a new quote.
  NEW.id               := OLD.id;
  NEW.quote_request_id := OLD.quote_request_id;
  NEW.talent_id        := OLD.talent_id;
  NEW.quoted_amount    := OLD.quoted_amount;
  NEW.created_at       := OLD.created_at;
  NEW.updated_at       := now();

  IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  -- Talent-owner path. Fees and logistics stay editable while pending;
  -- the policy already restricts which rows are reachable.
  NEW.commission_rate_percent := OLD.commission_rate_percent;
  NEW.sent_at                 := OLD.sent_at;
  NEW.expires_at              := OLD.expires_at;

  IF NEW.quote_status IS DISTINCT FROM OLD.quote_status THEN
    RAISE EXCEPTION
      'A talent cannot change quote_status. Acceptance and rejection are client actions handled by the orchestration service.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

-- Sorts before quotes_set_expiry, which fills expires_at when null.
DROP TRIGGER IF EXISTS enforce_quote_writes ON public.quotes;
CREATE TRIGGER enforce_quote_writes
  BEFORE INSERT OR UPDATE ON public.quotes
  FOR EACH ROW EXECUTE FUNCTION public.enforce_quote_writes();

-- 5. Policies. No INSERT and no DELETE policy for authenticated, so both
--    are denied by absence - quote creation is service-role only.
DROP POLICY IF EXISTS quotes_talent_manage ON public.quotes;

CREATE POLICY quotes_talent_select ON public.quotes
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles_talent pt
     WHERE pt.id = quotes.talent_id AND pt.user_id = auth.uid()
  ));

CREATE POLICY quotes_talent_update ON public.quotes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles_talent pt
       WHERE pt.id = quotes.talent_id AND pt.user_id = auth.uid()
    )
    AND quote_status = 'pending'::quotation_status
  )
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles_talent pt
     WHERE pt.id = quotes.talent_id AND pt.user_id = auth.uid()
  ));

COMMENT ON FUNCTION public.enforce_quote_writes() IS
  'Computes quoted_amount from quote_requests.talent_rate_at_request and '
  'duration_hours on insert, and freezes it thereafter for all callers. '
  'Restricts talent updates to fees and logistics while pending; quote_status '
  'changes are refused. service_role and admin bypass the talent pins only.';
