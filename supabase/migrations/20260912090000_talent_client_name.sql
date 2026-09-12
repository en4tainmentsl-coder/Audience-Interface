-- Talent cannot read profiles_clients at all (client_profile_manage_own is
-- auth.uid() = user_id), so a quote request arrives from an unresolvable UUID.
-- Messaging does not help: messages.booking_id is NOT NULL, so no channel
-- exists until a booking does.
--
-- This exposes the client's full_name ONLY, and only to the talent named on
-- the request. Email and phone stay private until a booking exists.
--
-- SECURITY DEFINER function rather than a view: a view would need
-- security_invoker = false and would be flagged by Supabase's
-- security_definer_view lint, adding noise to the Security Advisor surface.
--
-- The ownership expression mirrors qr_talent_select_targeted exactly.
CREATE OR REPLACE FUNCTION public.get_quote_request_client_names()
RETURNS TABLE (quote_request_id uuid, full_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT qr.id, pc.full_name
  FROM public.quote_requests qr
  JOIN public.profiles_clients pc ON pc.user_id = qr.client_user_id
  WHERE auth.uid() IN (
    SELECT pt.user_id FROM public.profiles_talent pt
    WHERE pt.id = qr.talent_id
  );
$fn$;

-- REVOKE FROM PUBLIC alone does NOT remove anon: Supabase's default
-- privileges grant EXECUTE on new public functions to anon, authenticated
-- and service_role as EXPLICIT role grants, which FROM PUBLIC does not touch.
REVOKE ALL ON FUNCTION public.get_quote_request_client_names() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_quote_request_client_names() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_quote_request_client_names() TO authenticated;
