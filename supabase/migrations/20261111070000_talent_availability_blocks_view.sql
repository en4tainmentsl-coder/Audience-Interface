-- Clients need to see WHEN a talent is unavailable, never WHY.
-- talent_unavailability.reason is free text the talent writes themselves
-- and may name a medical appointment, a family event or anything else
-- personal. A read policy on the table grants row access, so the reason
-- would travel with it over PostgREST.
--
-- This view is the only client-facing route: three columns, no reason.

create view public.talent_availability_blocks
with (security_invoker = false) as
  select
    tu.talent_id,
    tu.starts_at,
    tu.ends_at
  from public.talent_unavailability tu
  join public.profiles_talent pt on pt.id = tu.talent_id
  where pt.is_public = true
    and pt.approval_status = 'approved'
    and tu.ends_at >= now();

comment on view public.talent_availability_blocks is
  'Client-facing availability blocks. DELIBERATELY security_invoker = false: it must read past RLS on talent_unavailability, because the alternative - a client read policy on the table - grants row access and would expose the free-text reason column. Do not flip this flag to satisfy the SECURITY DEFINER view lint without first solving reason exposure another way. Scoped to public, approved talent and to blocks ending now or later.';

revoke all on public.talent_availability_blocks from public, anon, authenticated;
grant select on public.talent_availability_blocks to authenticated;