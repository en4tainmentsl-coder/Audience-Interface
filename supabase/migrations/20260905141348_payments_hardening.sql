-- Harden `payments` before any money moves through it.
--
-- Audited live 2026-09-05: 0 rows, no triggers, RLS = service_role_full_access
-- (ALL) + payments_payer_read (SELECT). The table predates the settled money
-- model and does not reconcile against it.

-- 1. payer_user_id default is unreachable.
--    DEFAULT auth.uid() returns NULL under service_role, and service_role is
--    the ONLY role that can write here. The default can therefore only ever
--    produce a NOT NULL violation. Same failure class as the booking
--    provenance 23502. The caller must pass the id explicitly.
ALTER TABLE public.payments ALTER COLUMN payer_user_id DROP DEFAULT;

-- 2. Tax and bank columns, zeroed.
--    Tax is disabled for v1 (see 20260905140000) but the columns exist now so
--    the reconciliation CHECK below never has to be rewritten on a live table.
--    bank_charge_amount is the HNB Rs.25 per transfer, absorbed by En4 and
--    never client-facing. It is netted OUT of platform_revenue, so it must
--    appear as its own term for the row to sum. A client cancellation pays
--    the talent twice, so that row carries 50.00.
ALTER TABLE public.payments
  ADD COLUMN sscl_amount        numeric NOT NULL DEFAULT 0.00,
  ADD COLUMN vat_amount         numeric NOT NULL DEFAULT 0.00,
  ADD COLUMN bank_charge_amount numeric NOT NULL DEFAULT 0.00;

ALTER TABLE public.payments
  ADD CONSTRAINT chk_payment_sscl_nonneg  CHECK (sscl_amount        >= 0),
  ADD CONSTRAINT chk_payment_vat_nonneg   CHECK (vat_amount         >= 0),
  ADD CONSTRAINT chk_payment_bank_nonneg  CHECK (bank_charge_amount >= 0);

-- 3. Timestamps. A `pending` row currently carries no time at all -- paid_at
--    is nullable and only set on completion. For a webhook-driven ledger that
--    leaves no way to age or debug a stuck payment.
ALTER TABLE public.payments
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

-- 4. gateway_order_id: idempotency.
--    Was NOT NULL DEFAULT ''. Two rows would both take '' and collide under a
--    unique constraint, and the value is meaningless for an HNB refund, which
--    is not a gateway transaction. Made nullable with the default dropped:
--    Postgres permits multiple NULLs under UNIQUE, so PayHere rows carry a
--    real order id and HNB rows carry none.
--    gateway_transaction_id (PayHere payment_id) is already UNIQUE nullable
--    and is the webhook's natural idempotency key.
ALTER TABLE public.payments ALTER COLUMN gateway_order_id DROP DEFAULT;
ALTER TABLE public.payments ALTER COLUMN gateway_order_id DROP NOT NULL;
ALTER TABLE public.payments
  ADD CONSTRAINT payments_gateway_order_id_unique UNIQUE (gateway_order_id);

-- 5. Reconciliation.
--    platform_revenue is what En4 KEEPS: commission net of the bank charge,
--    plus any retained convenience or cancellation fee. Everything else in the
--    row is a pass-through. On the worked example (tax off):
--      net_to_talent    50,217.72
--      platform_revenue      5,225.00   (21% of 25,000, less Rs.25)
--      gateway_fee           1,892.90
--      bank_charge_amount       25.00
--      sscl / vat                0.00
--      = gross_amount       57,360.62
--
--    Scoped to INBOUND collections only. A refund row's decomposition across
--    these columns is not yet designed -- it belongs with the cancellation
--    ledger, not here. Constraining it now would encode a guess.
--
--    gateway_fee must be written as the REMAINDER, not recomputed, exactly as
--    bookings does it. That is what makes this hold under rounding.
ALTER TABLE public.payments
  ADD CONSTRAINT chk_payment_reconciles CHECK (
    payment_type NOT IN ('deposit'::payments_types, 'balance'::payments_types)
    OR gross_amount = net_to_talent
                    + platform_revenue
                    + gateway_fee
                    + bank_charge_amount
                    + sscl_amount
                    + vat_amount
  );
