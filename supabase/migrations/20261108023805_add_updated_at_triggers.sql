-- updated_at was maintained nowhere.
--
-- Fifteen tables carry an updated_at column. Before this migration no table
-- had a trigger for it, and no generic function existed to attach.
--
-- Three tables set it inside their enforcement triggers
-- (quotes, quote_requests, talent_payout_accounts) but the assignment sits
-- AFTER an early return for admin and for auth.uid() IS NULL. So admin,
-- service_role and Directus writes left the column stale. The remaining
-- twelve never set it at all.
--
-- Consequence, observed 2026-11-07: talent_identity 3d387c5b was written on
-- 2026-09-26 and its updated_at still read 2026-08-29, so the column could
-- not be used to date the change. The corruption had to be dated from a Vue
-- timestamp inside the bad value instead.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- CREATE FUNCTION grants EXECUTE to PUBLIC by default. Revoking from anon and
-- authenticated alone is a no-op while that grant stands.
revoke execute on function public.set_updated_at() from public, anon, authenticated;

-- Named z_set_updated_at so it fires last. Trigger order is alphabetical, and
-- z_directus_column_scope must evaluate the caller's own changes before this
-- one adds a column the caller did not send.
do $$
declare
  t text;
  tables text[] := array[
    'client_approvals',
    'client_payment_methods',
    'contracts',
    'events',
    'genres',
    'payments',
    'profiles_clients',
    'profiles_talent',
    'profiles_venues',
    'quote_requests',
    'quotes',
    'talent_identity',
    'talent_payout_accounts',
    'talent_stats',
    'venue_payment_accounts'
  ];
begin
  foreach t in array tables loop
    execute format('drop trigger if exists z_set_updated_at on public.%I', t);
    execute format(
      'create trigger z_set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;
