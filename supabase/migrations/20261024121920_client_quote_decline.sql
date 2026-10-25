-- 20261024121920_client_quote_decline.sql
--
-- WHY
-- quotation_status has carried 'rejected' since the table was created, but
-- nothing could ever write it: clients have no UPDATE policy on quotes, and
-- enforce_quote_writes raises 42501 on any talent-initiated status change.
-- The only way a client could kill a quote was to cancel the parent request,
-- which cascade_quote_request_close then recorded as 'expired' -- identical in
-- the data to a quote nobody ever answered.
--
-- TERMINAL BY CONSTRUCTION
-- quotes_one_per_request is UNIQUE (quote_request_id), and enforce_quote_writes
-- pins talent_id from the parent request, so a second quote can never exist.
-- Returning the request to 'open' after a decline would be a dead end. It goes
-- to 'cancelled'; a client who wants a different artist raises a fresh request.
--
-- ORDER IS LOAD-BEARING
-- cascade_quote_request_close rewrites any still-'pending' quote to 'expired'
-- when the request closes. The quote is therefore set to 'rejected' FIRST and
-- the request to 'cancelled' SECOND, so the cascade finds nothing to do.
-- Reversing those two statements silently loses the rejection.
--
-- NOT WRAPPED IN BEGIN/COMMIT -- supabase db push runs each file in its own
-- transaction already.

create type public.quote_rejection_reason as enum (
  'price_too_high',
  'booked_alternative_talent',
  'terms_not_suitable',
  'event_cancelled',
  'event_postponed',
  'client_other'
);

alter table public.quotes
  add column rejected_reason public.quote_rejection_reason,
  add column rejected_note   text,
  add column rejected_at     timestamptz;

-- The status and its provenance are one fact, so they are constrained as one.
-- Mirrors chk_cancelled_status_has_provenance on bookings.
alter table public.quotes
  add constraint chk_quote_rejection_provenance
  check (
    (quote_status = 'rejected'::public.quotation_status)
    = (rejected_at is not null and rejected_reason is not null)
  );

alter table public.quotes
  add constraint chk_quote_rejected_note_length
  check (rejected_note is null or length(btrim(rejected_note)) <= 200);

-- 'client_other' tells the talent nothing on its own. Mirrors
-- chk_cancellation_note_required.
alter table public.quotes
  add constraint chk_quote_rejected_note_required
  check (
    rejected_reason is distinct from 'client_other'::public.quote_rejection_reason
    or (rejected_note is not null and length(btrim(rejected_note)) > 0)
  );

create or replace function public.decline_quote(
  p_quote_id       uuid,
  p_client_user_id uuid,
  p_reason         public.quote_rejection_reason,
  p_note           text
)
returns void
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_request_id uuid;
  v_client     uuid;
  v_req_status quotation_request_status;
  v_status     quotation_status;
  v_expires    timestamptz;
begin
  -- Same lock order as accept_quote_and_create_booking: quote, then request.
  select q.quote_request_id, q.quote_status, q.expires_at
    into v_request_id, v_status, v_expires
    from public.quotes q
   where q.id = p_quote_id
   for update;

  if not found then
    raise exception 'Quote % does not exist.', p_quote_id
      using errcode = '23503';
  end if;

  select qr.client_user_id, qr.status
    into v_client, v_req_status
    from public.quote_requests qr
   where qr.id = v_request_id
   for update;

  if v_client is distinct from p_client_user_id then
    raise exception 'Only the client who made this request can decline the quote.'
      using errcode = '42501';
  end if;

  if v_status <> 'pending'::quotation_status then
    raise exception 'This quote is % and can no longer be declined.', v_status
      using errcode = '42501';
  end if;

  if v_expires <= now() then
    raise exception 'This quote expired on %.', v_expires
      using errcode = '42501';
  end if;

  if v_req_status not in ('open'::quotation_request_status,
                          'matched'::quotation_request_status) then
    raise exception 'This request is % and is no longer live.', v_req_status
      using errcode = '42501';
  end if;

  if p_reason is null then
    raise exception 'A decline reason is required.'
      using errcode = '23502';
  end if;

  update public.quotes
     set quote_status    = 'rejected'::quotation_status,
         rejected_reason = p_reason,
         rejected_note   = nullif(btrim(p_note), ''),
         rejected_at     = now()
   where id = p_quote_id;

  update public.quote_requests
     set status = 'cancelled'::quotation_request_status
   where id = v_request_id;
end;
$$;

-- Revoking only from PUBLIC leaves Supabase's default role grants intact,
-- so anon and authenticated are named explicitly as well.
revoke execute on function
  public.decline_quote(uuid, uuid, public.quote_rejection_reason, text)
  from public, anon, authenticated;

grant execute on function
  public.decline_quote(uuid, uuid, public.quote_rejection_reason, text)
  to service_role;