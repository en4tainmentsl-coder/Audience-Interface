-- D-020: when a Venue-role user originates a quote request, venue_id must
-- point at a venue that user owns. A client may still name any venue as the
-- event location, so this cannot be a CHECK constraint -- the rule depends on
-- who is asking, and get_my_role() / auth.uid() are request-scoped.
--
-- Note venue_id is the EVENT LOCATION, not the requester. The requester is
-- always client_user_id regardless of role.

-- Ownership check is SECURITY DEFINER so it does not inherit the caller's RLS
-- on profiles_venues (venue_profile_manage_own restricts to auth.uid() =
-- user_id). Without this, correctness would depend on OR short-circuit
-- evaluation order, which Postgres does not guarantee across all plans.
CREATE OR REPLACE FUNCTION public.venue_is_owned_by_caller(p_venue_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles_venues pv
    WHERE pv.id = p_venue_id AND pv.user_id = auth.uid()
  );
$fn$;

REVOKE ALL ON FUNCTION public.venue_is_owned_by_caller(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_is_owned_by_caller(uuid) TO authenticated;

DROP POLICY IF EXISTS quote_requests_owner_insert ON public.quote_requests;

CREATE POLICY quote_requests_owner_insert ON public.quote_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = client_user_id
    AND get_my_role() = ANY (ARRAY['client'::text, 'venue'::text])
    AND (
      get_my_role() <> 'venue'
      OR (venue_id IS NOT NULL AND public.venue_is_owned_by_caller(venue_id))
    )
  );

DROP POLICY IF EXISTS quote_requests_owner_update ON public.quote_requests;

CREATE POLICY quote_requests_owner_update ON public.quote_requests
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = client_user_id
    AND status = ANY (ARRAY['open'::quotation_request_status,
                            'matched'::quotation_request_status])
  )
  WITH CHECK (
    auth.uid() = client_user_id
    AND (
      get_my_role() <> 'venue'
      OR (venue_id IS NOT NULL AND public.venue_is_owned_by_caller(venue_id))
    )
  );

-- Naming trap: status defaults to 'open' and the enum contains 'open'. This
-- means AWAITING A QUOTE, not floated to the market. No broadcast exists in
-- v1 (D-020) and no policy grants open-request visibility.
COMMENT ON COLUMN public.quote_requests.status IS
  'Lifecycle state of the request. ''open'' means AWAITING A QUOTE from the '
  'single talent named in talent_id -- NOT broadcast or floated to multiple '
  'talent. No broadcast capability exists in v1 (D-020).';
