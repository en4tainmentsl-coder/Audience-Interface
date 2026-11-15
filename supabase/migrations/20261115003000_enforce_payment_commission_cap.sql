-- D-003a: payments.commission_portion must derive from the parent booking's
-- commission, never be recomputed from client_total_amount, base_amount or
-- gross_amount at payment time.
--
-- Settled 2026-11-15 by Praveen:
--   * commission_portion covers BOTH legs — commission_client_amount plus
--     commission_talent_amount. The talent-side leg is retained out of the same
--     client money before payout, so both are collected through these rows.
--   * The trigger enforces a CEILING, not exact equality. Deposit and balance
--     arrive in separate transactions, possibly weeks apart, so a DEFERRABLE
--     constraint cannot span them, and there is no "fully paid" signal to hang
--     an exact check on. Over-allocation becomes impossible; under-allocation
--     is a reconciliation concern, to be handled once PayHere's real row
--     patterns are known rather than guessed at now.
--   * Scoped to deposit and balance only, mirroring chk_payment_reconciles, so
--     refund and adjustment rows never enter the sum.
--   * failed and refunded rows hold no allocation and are excluded.
--
-- payments, bookings and quotes were all empty when this was written
-- (verified live 2026-11-15), so nothing is retro-validated.

-- 1. Pin the money columns to numeric(12,2), matching bookings and quotes.
--    They were bare numeric, so an exact-sum invariant would have sat across a
--    type boundary where one side could hold arbitrary scale — the same defect
--    class as the numeric(5,2) rate snapshot on quotes. No dependent views.
alter table public.payments
  alter column gross_amount       type numeric(12,2),
  alter column commission_portion type numeric(12,2),
  alter column net_to_talent      type numeric(12,2),
  alter column platform_revenue   type numeric(12,2),
  alter column gateway_fee        type numeric(12,2),
  alter column sscl_amount        type numeric(12,2),
  alter column vat_amount         type numeric(12,2),
  alter column bank_charge_amount type numeric(12,2);

-- 2. The guard.
create or replace function public.enforce_payment_commission_cap()
returns trigger
language plpgsql
set search_path to ''
as $$
declare
  v_permitted numeric(12,2);
  v_allocated numeric(12,2);
  v_total     numeric(12,2);
begin
  if coalesce(current_setting('en4.admin_override', true), '') = 'on' then
    return new;
  end if;

  if new.payment_type not in (
       'deposit'::public.payments_types,
       'balance'::public.payments_types) then
    return new;
  end if;

  if new.payment_status in (
       'failed'::public.payments_status,
       'refunded'::public.payments_status) then
    return new;
  end if;

  select b.commission_client_amount + b.commission_talent_amount
    into v_permitted
    from public.bookings b
   where b.id = new.booking_id;

  if not found then
    raise exception
      'Cannot write a payment: booking % does not exist.', new.booking_id
      using errcode = '23503';
  end if;

  select coalesce(sum(p.commission_portion), 0)
    into v_allocated
    from public.payments p
   where p.booking_id = new.booking_id
     and p.id <> new.id
     and p.payment_type in (
           'deposit'::public.payments_types,
           'balance'::public.payments_types)
     and p.payment_status not in (
           'failed'::public.payments_status,
           'refunded'::public.payments_status);

  v_total := v_allocated + new.commission_portion;

  if v_total > v_permitted then
    raise exception
      'Commission allocation exceeds the booking total (D-003a). Booking % permits %; % is already allocated; this row adds %, giving %.',
      new.booking_id, v_permitted, v_allocated, new.commission_portion, v_total
      using errcode = '23514';
  end if;

  return new;
end;
$$;

comment on function public.enforce_payment_commission_cap() is
  'D-003a ceiling guard: the sum of commission_portion across a booking''s deposit and balance payments may never exceed commission_client_amount + commission_talent_amount. Bypass with SET en4.admin_override = ''on''.';

revoke execute on function public.enforce_payment_commission_cap()
  from public, anon, authenticated;

drop trigger if exists z_payment_commission_cap on public.payments;

create trigger z_payment_commission_cap
  before insert or update on public.payments
  for each row
  execute function public.enforce_payment_commission_cap();