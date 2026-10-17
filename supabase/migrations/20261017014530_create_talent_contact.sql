-- Expand phase of moving talent contact details off the publicly readable
-- profiles_talent row. Creates and backfills talent_contact; drops nothing.
-- The columns on profiles_talent come out in a later migration, once the
-- frontends and the two SECURITY DEFINER functions stop reading them.

create table public.talent_contact (
  talent_id  uuid primary key references public.profiles_talent (id) on delete cascade,
  email      text,
  mobile     text,
  created_at timestamptz not null default now()
);

comment on table public.talent_contact is
  'Talent email and mobile, held off profiles_talent because that row carries a public SELECT policy. Readable by the talent, by service_role, and by the counterparty on a confirmed or disputed booking.';

alter table public.talent_contact enable row level security;

insert into public.talent_contact (talent_id, email, mobile)
select id, email, mobile
from public.profiles_talent
where email is not null or mobile is not null;

revoke all on public.talent_contact from anon;
grant select, insert, update on public.talent_contact to authenticated;
grant all on public.talent_contact to service_role;

create policy talent_contact_service_role_all
  on public.talent_contact for all to service_role
  using (true) with check (true);

create policy talent_contact_manage_own
  on public.talent_contact for all to authenticated
  using (exists (select 1 from public.profiles_talent t
                 where t.id = talent_contact.talent_id and t.user_id = auth.uid()))
  with check (exists (select 1 from public.profiles_talent t
                      where t.id = talent_contact.talent_id and t.user_id = auth.uid()));

create policy talent_contact_counterparty_select
  on public.talent_contact for select to authenticated
  using (exists (
    select 1 from public.bookings b
    where b.talent_id = talent_contact.talent_id
      and b.booking_status in ('confirmed', 'disputed')
      and (
        b.client_user_id = auth.uid()
        or exists (select 1 from public.profiles_venues v
                   where v.id = b.venue_id and v.user_id = auth.uid())
      )
  ));
