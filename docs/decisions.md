# En4tainment — Decision Register

**This file is authoritative for settled decisions.** If a decision appears
here, it has been made. Do not re-litigate it, do not ask about it again, and
do not propose an alternative unless the entry is explicitly marked `Open` or
`Superseded`.

Maintained by: Praveen (REAP Holdings Pvt Ltd)

See [`README.md`](./README.md) for how to change this file.
Verified-wrong assumptions live in [`corrections.md`](./corrections.md).

---

## Index

| ID | Decision | Status |
|---|---|---|
| D-001 | Tax (VAT + SSCL) disabled for v1 | Settled |
| D-002 | Definition of `platform_revenue` | Settled |
| D-003 | Commission direction and commission base | Settled — amended 2026-09-08, **2026-10-25** |
| D-003a | `payments.commission_portion` must derive from the booking | Settled; **not enforced** |
| D-004 | Fee absorption — PayHere vs HNB | Settled |
| D-005 | Travel is a threshold, not an allowance | Settled |
| D-006 | Equipment fee applies only when talent provides sound | **Superseded by D-042** |
| D-007 | Cancellation penalty is uniform regardless of reason | Settled |
| D-008 | Client/venue cancellation splits across two columns | Settled |
| D-009 | Talent cancellation — full client refund + penalty formula | Settled |
| D-010 | Cancellation reason mandatory; talent-side note required | Settled |
| D-011 | Rate model — pro-rata duration with a 4-hour floor | **Superseded by D-038** |
| D-012 | Upload defence hard-blocks; it does not flag asynchronously | Settled |
| D-013 | NIC numbers stored as keyed HMAC-SHA256, never plaintext | Settled |
| D-014 | `pricing_per_session` excluded from all v1 public surfaces | Settled — **question resolved by D-046** |
| D-015 | Schema migrations live exclusively in `Audience-Interface` | Settled |
| D-016 | Directus, not NocoBase, is the admin layer | Settled |
| D-017 | Directus connects via `nocobase_admin` with `BYPASSRLS` | Settled |
| D-018 | Two-store media split — Cloudinary public, R2 sensitive | Settled |
| D-019 | Dependabot PRs are never closed without merging | Settled |
| D-020 | Venue-originated quote requests; no broadcast in v1 | Settled — **implemented 2026-09-11/12** |
| D-021 | Edge Function authorisation model + standing audit rule | Settled — **CORS rule unimplemented, corrected 2026-10-31** |
| D-022 | RLS must be tested through a real authenticated session | Settled |
| D-023 | Trust-field guards on every profile table, `a_`-prefixed | Settled — **all four compliant** |
| D-024 | Tax base and application order (dormant while D-001 holds) | Settled |
| D-025 | Talent sees the client's name only, until a booking exists | Settled, implemented |
| D-026 | `REVOKE ... FROM PUBLIC` does not remove the `anon` grant | Settled |
| D-027 | Both frontends deploy as Cloudflare Workers static assets | Settled |
| D-028 | Node 22 pinned in both frontend repos via `.nvmrc` | Settled |
| D-029 | Google OAuth is the talent sign-in method; Testing mode for now | Settled |
| D-030 | Trust guards must fail closed when `get_my_role()` returns NULL | Settled |
| D-031 | A signed-in user creates their own `profiles_users` row; the app sets the role | Settled |
| D-032 | Talent base location is a chosen town; coordinates derived by the DB | Settled |
| D-033 | Public talent must be approved; what "complete" means for submission | Settled — gate live, Submit button pending |
| D-034 | ACPOSL music-licensing tariff — organiser is licensee; En4 informs, does not collect | **Open** — parts 1–2 pending Ragu / Erich; part 3 proposed |
| D-035 | Profile rows are never hard-deleted; erasure is anonymise-in-place | Settled — request half implemented |
| D-036 | The review panel owns the approve/reject transition, not the dropdowns | Settled, implemented |
| D-037 | Clients need no approval; venues do | Settled — venue side unbuilt |
| D-038 | Eight-category talent rate model with fixed duration packages | Settled — **rates built 2026-09-27; packages unbuilt; no open questions**; supersedes D-011 |
| D-039 | Price ranges are client-facing and talent-blind | Settled — **amended and built 2026-09-27** |
| D-040 | A talent may decline a quote request, with a reason | Settled — **unbuilt** |
| D-041 | Email: Resend for sending, Cloudflare Routing for receiving | Settled, implemented |
| D-042 | Equipment is a single talent-entered fee | Settled — **unbuilt**; supersedes D-006 |
| D-043 | Travel is charged at a flat Rs 150/km | Settled — **unbuilt; folded into D-044** |
| D-044 | Platform rate configuration layer, append-only with snapshots | Settled — **unbuilt** |
| D-045 | Contact form is stored first and notified second | Settled, implemented |
| D-046 | Publishing the talent's rate is revoked on all fronts | Settled, **built 2026-09-28 — the leak is closed** |
| D-047 | Submission for approval is attempted, not pre-validated | Settled, implemented |
| D-048 | Email delivery outcomes are recorded platform-wide | Settled, implemented |
| D-049 | Retention rules are scheduled, and their health is visible | Settled, implemented |
| D-050 | Packages are fixed and platform-defined; 'other' removed | Settled, implemented |
| D-051 | The fee is the category rate; duration prices nothing | Settled, implemented |
| D-052 | Controlled-disclosure views for browsing without rates | Settled, implemented |

---

## D-001 — Tax (VAT and SSCL) is disabled for v1

**Date:** 2026-09-05
**Status:** Settled, implemented
**Source:** Todoist `6hQpgHxVX8GMh3fX`; migration `20260905140000_disable_tax_v1`

**Decision.** `quotes.sscl_rate_percent` and `quotes.vat_rate_percent` default to `0.00`. Neither tax is charged on any v1 quote.

**Rationale.** REAP Holdings is not registered for VAT or SSCL, and an unregistered person may not lawfully charge either. This was never a threshold question in the first place.

**Mechanism.** `compute_quote_pricing` reads rates off the quote row rather than hardcoding them, so no function change was required. Rates are pinned per row: reversing the defaults later taxes new quotes only, and every historical quote keeps the rate it was sold at.

**Correction to a figure still in circulation.** The Rs.120 Mn threshold is wrong twice over — it is not VAT, and it is not current. It was the original SSCL transitional threshold from October 2022; both IRD notices in the project files (`PN/SSCL/2021-01` and `-02`) are superseded. Verified against IRD sources 2026-09-05:

- **SSCL** — Rs. 9 Mn/quarter or Rs. 36 Mn/four quarters, effective 1 July 2026, Act No. 10 of 2026. Rate 2.5%.
- **VAT** — Rs. 15 Mn/period or Rs. 60 Mn/twelve months, unchanged; the proposed cut to Rs. 36 Mn was dropped before enactment. Act No. 14 of 2026. Rate 18%.

The two have diverged. SSCL bites first. **Two independent monitoring flags are required, not one.** Quarterly check: Todoist `6hR3g8WrH3GW7VqX`.

**Consequence to remember.** Enabling tax later is a ~17% price rise on every quote. It needs notice to an active user base, not a silent flip.

---

## D-002 — Definition of `platform_revenue`

**Date:** 2026-09-05
**Status:** Settled, implemented
**Source:** Todoist `6hQpgHxVX8GMh3fX`; migration `20260905140100_payments_hardening`

**Decision.** `platform_revenue` is **what En4 keeps, net**: commission minus the Rs.25 HNB bank charge, plus any retained convenience or cancellation fee. Everything else on a payments row is a pass-through.

**Rejected.** An earlier formulation — client charges minus gateway, bank and tax — double-counted. It left the talent payout inside `platform_revenue`, so `platform_revenue + net_to_talent` came to nearly twice the money that existed.

**Mechanism.** Because the bank charge is netted out, it must appear as its own term for a payments row to reconcile. `payments.bank_charge_amount` exists for exactly this, and `chk_payment_reconciles` enforces it on deposit and balance rows.

---

## D-003 — Commission direction and commission base

**Date:** 2026-09-04
**Status:** Settled, implemented

**Decision (SUPERSEDED 2026-10-25 — see the amendment below).** Commission is a **markup**, not a deduction. Talent receives their quoted fee in full; 21% is added on top and paid by the client.

**Commission base is the performance fee only** — not travel, not equipment.

**Column renames (2026-09-05).** `quotes.talent_net_earnings` → `talent_payout_amount`; `bookings.talent_net_amount` → `talent_payout_amount`; `bookings.agreed_gross_amount` → `base_amount`. The old names implied a net figure that was never net.

---

### Amendment, 2026-09-08 — the base is fixed at quote time and never recomputed

**Rule.** Commission is computed **once**, at quote computation, off the performance fee. It is copied to the booking at insert and is **never recalculated** at confirmation, at completion, or at any later status transition. There is no downstream event at which commission is recomputed against any other base.

**Verified against live schema and functions, 2026-09-08:**

- `compute_quote_pricing` computes `v_comm := round(NEW.quoted_amount * NEW.commission_rate_percent / 100, 2)`. `quoted_amount` is the performance fee. Travel and equipment are added afterwards into `talent_payout_amount` and never enter the commission base.
- `enforce_booking_provenance` (BEFORE INSERT OR UPDATE on `bookings`) copies `commission_amount` and `commission_rate_percent` from the accepted quote on INSERT, and on UPDATE forces every money column back to `OLD` **unconditionally**. Recomputation at confirm or complete is structurally impossible, not merely discouraged.

**Noted while verifying — not yet decided.** `enforce_booking_provenance` has **no `en4.admin_override` escape hatch**, unlike `compute_quote_pricing`. Booking money is frozen even for admins, so a legitimate pricing correction has no path short of `service_role`. Whether that is intended is an open question, deliberately left open here.

**The rule is NOT yet enforced at the payments layer.** See D-003a below.

---

### Amendment, 2026-10-25 — commission is two legs, and only one is a markup

**Supersedes the original Decision above.** That entry describes a single
21% markup on the client side. Both halves of it are now wrong.

**Rule.** Commission has two independent legs:

| Leg | Direction | Charged on | Rate |
|---|---|---|---|
| Client-side | **Added** to the client bill | The full talent bill — fee **plus travel, meals and accommodation** | 10% |
| Talent-side | **Deducted** from the talent payout | The performance fee **only** | 10% |

**The platform takes 20, not 21.** On a fee of 100: the client is billed 110,
the talent is paid 90. The talent-side 10% is charged on the talent's own fee
of 100, **not** on the grossed-up client figure of 110. Charging it on 110
would yield 11 and a total of 21 — that is the error this amendment exists to
correct, and it is a plausible enough reading that it was briefly the settled
position.

**"Talent receives their quoted fee in full" is no longer true.** The
client-side leg is still a markup. The talent-side leg is a genuine
deduction. The original entry's framing predates the second leg entirely.

**"Commission base is the performance fee only" now splits.** It holds for
the talent-side leg. It does **not** hold for the client-side leg, which is
charged on travel, meals and accommodation as well.

**Meals and accommodation reach the talent whole** — no commission is
deducted from either.

**Not yet implemented.** `compute_quote_pricing` still computes a single
21% leg, and `enforce_quote_writes` hardcodes `21.00` separately from the
column default. The rates now live in `rate_configs`, seeded at 10/10 but
not yet read. The pricing rewrite is Stage 2C.

**Unchanged by this amendment:** the 2026-09-08 rule that commission is
computed once at quote time and never recomputed downstream. That applies to
both legs.

### D-003a — `payments.commission_portion` must derive from the booking

**Date:** 2026-09-08
**Status:** Rule settled; **enforcement not built**
**Todoist:** `6hRMFVCj62V373q5`

**Rule.** `payments.commission_portion` must derive from `bookings.commission_amount` for the parent booking. The `commission_portion` values across a booking's `deposit` and `balance` rows must sum to exactly `bookings.commission_amount` — no more, no less. Commission must never be recomputed from `client_total_amount`, `base_amount`, or `gross_amount` at payment time.

**Why this needs stating.** Verified 2026-09-08: `payments` has **no triggers at all**. `chk_payment_commission` checks only `commission_portion >= 0`. `chk_payment_reconciles` verifies `gross_amount = net_to_talent + platform_revenue + gateway_fee + bank_charge_amount + sscl_amount + vat_amount` — **`commission_portion` does not appear in that identity**. It is unconstrained beyond non-negativity, and nothing links it to the booking.

The rule holds today only because nothing writes to `payments` yet. **PayHere integration is what will start writing these rows**, so enforcement must land before or with it.

---

## D-004 — Fee absorption: PayHere vs HNB

**Date:** 2026-09-04
**Status:** Settled

**Decision.**

- **PayHere (~3.30%, inward only)** — passed to the client, grossed up **by division**: `client_total = subtotal / 0.967`.
- **HNB Rs.25 per talent payment** — absorbed by En4. Never client-facing.

**Why division, not multiplication.** PayHere charges its fee on the amount actually charged. Multiplying by 1.033 undershoots the target and leaks silently on every transaction. Dividing by 0.967 recovers it exactly. `gateway_fee` is then derived as the remainder so it absorbs rounding.

**Notes.** The Rs.25 is per payment to a talent *profile*, regardless of band size. A client cancellation triggers a second Rs.25 for the compensation payout, also absorbed by En4. All outward payments go via HNB bulk transfer — **PayHere is never used for disbursement** (it has no disbursement API).

---

## D-005 — Travel is a threshold, not an allowance

**Date:** 2026-09-04
**Status:** Settled

**Decision.** Under 10 km one-way there is **no** travel charge. At 10 km or more the **full** distance is charged with nothing deducted.

```
fee = one_way_km × 2 × 120 × 1.05
```

At 12 km one-way the charge is for 12 km, not 2 km. Cliff edge is deliberate: 9.9 km charges nothing, 10.0 km charges 2,520.

**Coordinate resolution.** `quote_requests.event_latitude/longitude` first, `profiles_venues.latitude/longitude` as fallback. If neither is usable, travel = 7.5% of `talent_fee`, `travel_coordinates_estimated` is set true and `travel_distance_km` is NULL.

`quote_requests_has_location` requires `venue_id` or both coordinates, so a request can never lack a location. The 7.5% fallback only fires when the *talent* has no base coordinates, or a venue-based request points at a venue without them.

---

## D-006 — Equipment fee applies only when talent provides sound

**Date:** 2026-09-04
**Status:** **Superseded by D-042** (2026-09-27). Retained for history; do not build from this entry.

**Decision.** `equipment_fee = profiles_talent.equipment_fee_percent × talent_fee`, applied **only** when `quotes.equipment_provided_by = 'talent'`.

**There is no "shared" case.** Do not build one.

---

## D-007 — Cancellation penalty is uniform regardless of reason

**Date:** 2026-09-04
**Status:** Settled

**Decision.** The penalty is the same whichever reason is given.

**Rejected.** A three-tier fault model (talent fault / no fault / client fault) was proposed and rejected.

**The reason enum is purely analytical.** Do not build pricing logic that branches on it. The 22-value enum exists for reporting only.

**What does escalate** is repeat count, not reason — see D-009. Note the escalation counter has nothing to count against yet: `talent_stats` has no cancellation counter.

**Definition worth pinning:** `event_terms_changed` means out-of-band requests that could not be agreed. Clients cannot alter bookings in-system.

---

## D-008 — Client/venue cancellation splits across two columns

**Date:** 2026-09-04
**Status:** Settled

**Decision.** On a client or venue cancellation:

```
convenience_fee_base = commission
                     + 0.20 × talent_fee
                     + 0.20 × equipment_fee
                     + 0.20 × travel_fee
refund = client_total − convenience_fee_total
```

**The 20% portion is talent compensation and is paid out to the talent.** It is not En4 revenue — the talent may already have committed to an equipment renter and a travel provider. En4 retains only the 20% commission.

**Storage.** `bookings.cancellation_fee_amount` holds the En4 portion; `talent_compensation_amount` holds the 20%. **Do not record the convenience fee as one lump** — the 20% must never be booked as revenue.

---

## D-009 — Talent cancellation: full client refund plus penalty

**Date:** 2026-09-04
**Status:** Settled (one commercial sub-question open — see Open Decisions)

**Decision.** The client is refunded **everything they paid** (`client_total`). The cancellation is not their fault.

**Talent penalty:**

```
penalty    = max(Rs.5,000, gateway_fee_amount + Rs.25) × escalation
escalation = 1× first, 2× second, 4× third or more, rolling 12 months
```

The floor keeps a deterrent on small bookings; cost recovery protects En4 on large ones; the multiplier makes repeat offending hurt regardless of size.

**Debt handling.** Held against the talent profile as an admin alert. **Not** auto-deducted — an admin enters the deduction at the next payout run. *This ledger does not exist yet.*

**Rating impact.** Immediate −0.1 star. *No home in the schema yet.*

**Refund timing.** Within 7 working days. All refunds via HNB, never PayHere.

---

## D-010 — Cancellation reason mandatory; talent-side note required

**Date:** 2026-09-05
**Status:** Settled, implemented
**Source:** migrations `20260905140200_cancellation_provenance`, `20260905160000_talent_cancellation_note`

**Decision.** A reason is mandatory on any cancellation. All nine talent-side reasons additionally require a short free-text note, maximum 200 characters.

---

## D-011 — Rate model

**Date:** 2026-09-04
**Status:** **Superseded by D-038** (2026-09-27). Duration is no longer a client input; each category is a fixed package. Retained for history; do not build from this entry.

**Decision.** Continuous pro-rata duration multiplier with a **4-hour floor**:

```
talent_fee = pricing_per_session × greatest(1, duration_hours / 4)
```

A 30-minute break is allotted per 4-hour block.

---

## D-012 — Upload defence hard-blocks; it does not flag asynchronously

**Date:** 2026-08-29
**Status:** Settled (implementation incomplete)
**Source:** Todoist `6h979CwmRf3J9qv5`

**Decision.** Four independent checkpoints, of which 1–3 are **synchronous and must pass before the asset is reachable**. Not an async quarantine-and-flag model.

1. Client-side React validation — UX only, assume bypassed
2. Cloudinary preset locking via `allowed_formats` allowlists
3. Edge Function magic-byte check — the real gate
4. Async ClamAV on the VPS — catches valid-format files carrying known malware

**Known limits, already documented.** Cloudinary's `max_file_size` is **silently discarded on the free plan** (confirmed empirically). Checkpoint 3's `detect()` currently inspects leading bytes only, so a valid header followed by arbitrary data passes — trailer validation is outstanding (`6hPPgf5mPfj7Fpf5`).

**Rule that follows.** Never trust the file extension or the declared MIME type. Both are attacker-controlled.

---

## D-013 — NIC numbers stored as keyed HMAC-SHA256

**Date:** 2026-08
**Status:** Settled

**Decision.** NIC numbers are stored as HMAC-SHA256 hashes, keyed from a pepper held in Supabase Vault. Plaintext NIC is never persisted. `nic_last_four` is retained separately for support lookup.

**Rationale.** The Sri Lankan NIC keyspace is small enough for exhaustive reversal of an unkeyed hash.

**Consequence.** The Vault pepper is unrecoverable if lost — backing up the `vault` schema is a live task (`6hJ5JvPRv968GF5X`).

---

## D-014 — `pricing_per_session` excluded from all v1 public surfaces

**Date:** 2026-08
**Status:** Settled — **open question resolved 2026-09-27 by D-046**

**Decision.** `pricing_per_session` must not appear in any v1 public-facing talent query or display, including quote-request talent selection.

**Related but distinct:** publishing a derived "Starting Rate" per 4-hour session is a separate open piece of work (`6hJ8MmhmpM2Vv2M5`), not a reversal of this.

**Resolved 2026-09-27 — see D-046.** The question was whether a range counts as exposing the rate. The answer turned out to be the reverse of what was asked: it is not that ranges disclose rates, it is that **published rates disclose the ranges**. If a client can see both the range a talent sits in and that talent's rate, the boundaries can be derived exactly by browsing — no probing, no account, no quote form. That would defeat D-039's hard rule rather than weaken it.

So the "Starting Rate" work item (`6hJ8MmhmpM2Vv2M5`) is **cancelled, not deferred**, and this entry's exclusion is widened from public surfaces to every surface. D-046 carries the decision and its implementation.

---

## D-015 — Schema migrations live exclusively in `Audience-Interface`

**Date:** 2026-08
**Status:** Settled

**Decision.** All schema migrations live in `Audience-Interface`. `Talent_Interface` is a **consumer only** and owns Edge Functions. Never write a migration into `Talent_Interface`.

### Amendment, 2026-09-27 — the filename must equal the ledger version

When a migration is applied through the Supabase MCP, **the MCP generates its own timestamp** and writes that as the `version` in `supabase_migrations.schema_migrations`. A file then named by hand gets a different timestamp, and the migration exists under two identities. `supabase db push` sees the repo file as unapplied and replays it.

**The rule: apply first, read the ledger version back, then commit the file named exactly `<version>_<name>.sql`.**

This was not followed before 2026-09-26 and the drift reached **22 of 55 files** — 20 renamed pairs plus 2 with no ledger row at all. Reconciled 2026-09-27 (PR #130). See the Standing Correction.

---

## D-016 — Directus, not NocoBase, is the admin layer

**Date:** 2026-08
**Status:** Settled, permanent

**Decision.** NocoBase is permanently abandoned. Directus is self-hosted on the Racknerd VPS at `admin.en4tainment.com` behind Caddy.

**Rationale.** NocoBase's FDW plugin hardcodes a `BEFORE INSERT` trigger requirement that cannot work on views, and requires `TRIGGER` grants that Supabase's dashboard role cannot self-grant. Directus connects directly with no schema-mutation requirements.

**Do not revisit.** This was investigated to exhaustion.

---

## D-017 — Directus connects via `nocobase_admin` with `BYPASSRLS`

**Date:** 2026-08
**Status:** Settled

**Decision.** The Postgres role name `nocobase_admin` is **kept deliberately** despite NocoBase being abandoned. Renaming it would require touching connection strings, grants and the running container for no functional gain.

The role carries `BYPASSRLS`. Note that `FORCE ROW LEVEL SECURITY` on a table overrides `BYPASSRLS` entirely.

---

## D-018 — Two-store media split

**Date:** 2026-08
**Status:** Settled

**Decision.**

- **Cloudinary** (cloud name `en4tainment`) — public assets only: avatars, covers, portfolio. All upload presets in signed mode, `allowed_formats` locked per preset.
- **Cloudflare R2** bucket `en4tainment-sensitive` — KYC documents and venue business registration certificates.

**Format note.** KYC identity documents (NIC front/back) may be **image or PDF**. Only venue BR copies are always PDF. Any review UI must handle both.

---

## D-019 — Dependabot PRs are never closed without merging

**Date:** 2026-08
**Status:** Settled

**Decision.** Closing a Dependabot PR without merging **permanently suppresses that version**. Only merge, or leave open. Never close.

---

## D-020 — Venue-originated quote requests; no broadcast in v1

**Date:** 2026-09-06
**Status:** Settled; **fully implemented 2026-09-11/12**
**Source:** Todoist `6hJ8MmqfGpGc8Fj5`

**Decision, in three parts.**

1. **A Venue can originate a quote request.** No change required — this was already live.
2. **No broadcast or floated requests in v1.** Directed, one talent per request, only. Broadcast is deferred to V2.
3. **When a Venue originates, `venue_id` must point at a venue that Venue user owns.**

**What the live schema already enforced** (verified 2026-09-06, per the task — re-confirm before writing the migration):

- `quote_requests.talent_id` is NOT NULL — every request is directed at exactly one talent
- `quotes_one_per_request` UNIQUE on `quote_request_id`
- `quotes_talent_matches_request` CHECK — the quote's talent must match the request's talent
- `quote_requests_owner_insert` already permits `get_my_role()` of either `client` or `venue`
- `qr_talent_select_targeted` — talent sees only requests naming them; no open-request visibility exists anywhere

The directed model was enforced at three independent points. **Broadcast was never possible**, so part 2 is a confirmation, not a restriction to build.

**Critical distinction.** `venue_id` is **not the requester**. It is the **event location** — a nullable FK to `profiles_venues` used by `quote_requests_has_location`. The requester always lands in `client_user_id` regardless of whether they are a client or a venue.

**Why part 3 cannot be a CHECK constraint.** The rule is conditional on *who is asking*. A client must still be able to name any listed venue as the event location; only a venue-role requester is restricted to their own. Role comes from `get_my_role()` and ownership needs `auth.uid()` — both request-scoped, and neither survives a restore or backfill inside a CHECK.

**Enforcement point is RLS.** Extend `quote_requests_owner_insert` and `quote_requests_owner_update`:

```sql
get_my_role() <> 'venue'
OR (venue_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM profiles_venues
                WHERE id = venue_id AND user_id = auth.uid()))
```

`profiles_venues.user_id` is NOT NULL, so ownership is checkable.

**Trigger backstop required.** RLS is bypassed by `service_role`. Once quote request writes move to the orchestration layer — the direction `6hPq7j7jFhF6Xx65` sets for bookings — this rule silently stops applying. Fold the trigger in alongside `6hQ9jG2mgx5cfQx5`.

**Frontend consequence.** `RequestQuote.tsx` currently satisfies `quote_requests_has_location` via district-centroid coordinates with the venue picker **optional**. A venue user on that path would file with `venue_id` NULL and now be rejected at insert. The venue-originated path needs the venue **preselected and locked**. Sequence with `6h9798GcmjxpHP65`.

**Good side effect.** A venue-originated request always carries `venue_id`, so travel distance resolves via `profiles_venues.latitude/longitude`. The 7.5% estimated-coordinate fallback in D-005 never fires for venue requests.

**Naming trap — add a column comment.** `quote_requests.status` defaults to `'open'` and the enum contains `'open'`. This means **awaiting a quote**, not floated to the market. If broadcast is ever built in V2, this value will read as though the capability already existed.

**Implementation, complete.** Migration `20260911165534` (file `20260908190000`) rewrote `quote_requests_owner_insert` and `_owner_update`, using `venue_is_owned_by_caller()` — a `SECURITY DEFINER` helper, so the check does not inherit the caller's RLS on `profiles_venues`. Without it, correctness would rest on `OR` short-circuit order, which Postgres does not guarantee across plans. The `status` column comment shipped with it.

**Client path regression-tested** 2026-09-12: a client insert with `venue_id` NULL returned HTTP 201. The rewrite touched the policy every client uses, so this was the real risk, not the venue rule.

**Frontend, shipped** (commit `b43caae`): venue-role users see only their **own approved** venues, preselected and locked, with no "not at a listed venue" option. The venue loader now waits for the role rather than firing on mount.

**Decided 2026-09-12:** a venue user whose venue is **pending approval is blocked from filing entirely**. Nothing can be booked at a venue until the venue is approved. Someone with no venue is simply a client — `profiles_users.role` is a single `text` column, so one user holds one role.

**Never exercised.** No venue accounts exist, so `userRole === 'venue'` has never been true in a browser. The venue path typechecks and builds; that is all.

`6h979FFm6FX7FW2X` (Phase 1 booking flow) is no longer blocked schema-side.

---

## D-021 — Edge Function authorisation model, and the standing audit rule

**Date:** 2026-09-08
**Status:** Settled; **CORS half of the model NOT implemented — corrected 2026-10-31**
**Source:** Todoist `6h979JFpvXGXvFX5` (closed), standing check `6hRh4cxvfhxGqQG5`, correction `6hv3JvRg52pwWCfX`

**The model.** Every Edge Function must have `verify_jwt: true`, independently return 401 on a missing `Authorization` header, and call `getUser()` rather than trusting the header's contents. Any user identity passed onward must come from the **verified user object, never from the request body**. Origins must be an explicit `ALLOWED_ORIGINS` allowlist with `Vary: Origin` — never `'*'`.

**Audit 2026-09-08 — partially wrong, corrected 2026-10-31.** The JWT half holds: every function read carries `verify_jwt`, an independent 401, `getUser()`, and identity taken from the verified user object. **The origin rule was never implemented.** Source as at 2026-10-31:

| Function | CORS origin | `Vary: Origin` | Meets the model |
| --- | --- | --- | --- |
| `cloudinary-sign` | `ALLOWED_ORIGINS`, checked per request | yes | **yes** |
| `process-upload` | `'*'` | no | no |
| `cloudinary-delete` | `'*'` | no | no |
| `submit-nic` | `'*'` | no | no |
| `upload-document` | `'*'` | no | no |
| `r2-deliver` | `'*'` | no | no |
| `r2-delete` | `'*'` | no | no |
| `accept-quote` | unverified | — | unknown |

**The "deliberate divergence" never existed.** This entry previously recorded that `r2-deliver` alone allowlists `https://admin.en4tainment.com` for the Directus KYC review extension. `r2-deliver` has no allowlist at all. `cloudinary-sign`, the one function that does, correctly omits `admin.en4tainment.com`. Nothing was diverging; the claim was never true.

**Not an open door, and why.** CORS is not the access control on these functions. Every one authenticates the JWT. `r2-deliver` adds a role check and writes `sensitive_asset_access_log` before issuing a 120-second presigned URL, failing closed if the write fails. `r2-delete` requires `role === 'admin'`. `upload-document` resolves ownership from the JWT and gates on actual size and magic bytes. A hostile origin cannot read a response without a valid Supabase JWT it has no way to obtain.

**Still to decide** (`6hv3JvRg52pwWCfX`): verify `accept-quote`, then either implement the allowlist across the six non-compliant functions using `cloudinary-sign`'s `cors(req)` helper, or amend the model to say the origin rule is aspirational. Do not leave the gap between the two. Note these allowlists are hardcoded in function source, not env vars, so any change is a redeploy — fold it into the `profile.` subdomain CORS work (`6hcqCCCwJmP68P6X`) rather than touching these files twice.

**The rule that came out of the original audit, and matters more than the result.** The prior audit recorded seven functions. There were **eight**. `accept-quote` — the quote→booking transition, the most money-critical function on the platform — shipped after that audit and was never added to it. It passed when finally read, but that was luck, not process.

So: **a completed audit does not stay true.** Any new Edge Function is auth-audited at deploy time, checked against the table in the closed task. Anything not in that table has never been audited.

**Verify grants with SQL, not comments.** `accept-quote`'s source claims the RPC it calls is revoked from `authenticated`. That claim is load-bearing — if false, a browser could call `accept_quote_and_create_booking` directly with any `p_client_user_id` and forge a booking as any client. It was verified true against `pg_proc.proacl` (`postgres=X/postgres | service_role=X/postgres`). A code comment asserting a grant state is not evidence of one.

**And the corollary this correction adds: a register entry asserting an audit result is not evidence of one either.** This entry claimed a control that had never been implemented, which is worse than claiming nothing — it stopped anyone looking for fourteen months. Audit claims in this register state the date they were verified and the method used, or they are not audit claims.

## D-022 — RLS must be tested through a real authenticated session

**Date:** 2026-09-03
**Status:** Settled
**Source:** Todoist `6hQQ5cC2q6rjc8FX`; open work carried to `6hRh5rQ73gRm2G7X`

**Rule.** RLS is never considered verified until it has been exercised through a real authenticated PostgREST session. `execute_sql` runs as `postgres`, which is **`BYPASSRLS`** — it cannot test RLS at all. `DO` blocks with simulated `request.jwt.claims` exercise triggers correctly but not policies.

**What established this.** Ten migrations shipped 2026-09-01/02, each verified by rolled-back `DO` block tests. The **first authenticated request ever made** against the schema failed outright: `42P17` infinite recursion on both `quote_requests` and `quotes`. `quote_requests_talent_read` queried `quotes`; `quotes_client_read` queried `quote_requests`. Both policies predated the hardening work and had been verified *as written*, never *as enforced*. It would have stopped the orchestration layer dead on first contact.

**Second rule, from a test that gave a false pass.** A `BEFORE` trigger error **masks** an RLS `42501`, because `BEFORE` triggers run ahead of RLS `WITH CHECK`. A client POST to `quotes` with a fake `quote_request_id` returned `22004` from the pricing trigger, not `42501` from the policy. Always use **valid** data so the trigger passes, then read the policy outcome. This applies to any RLS test on a table with a `BEFORE` trigger — which is most of them.

**Never use the `service_role` key in an RLS test.** It bypasses RLS and invalidates the result. Test writes are real and do not roll back; clean up afterwards.

**Verified complete for the quote path only** (11 checks, 2026-09-03). `messages`, `talent_payout_accounts`, `profiles_venues` and `profiles_clients` remain untested through the real API.

---

## D-023 — Every profile table carries an `a_`-prefixed trust-field guard

**Date:** 2026-08-29
**Status:** Settled; `profiles_clients` **not yet compliant** (`6hRh5rJj3jg459g5`)

**Rule.** Every profile table gets a `BEFORE INSERT OR UPDATE`, `SECURITY DEFINER` trust-field trigger. Non-admin JWT callers cannot raise their own trust fields: `is_verified` reverts to `OLD`, and `approval_status` reverts unless the transition is `draft → pending_approval`. **Self-submission allowed, self-approval blocked.**

**The naming prefix is load-bearing.** `BEFORE` triggers fire in **name order**. `trg_enforce_talent_trust_fields` was renamed to `a_enforce_talent_trust_fields` precisely because it previously sat between the pricing check and the DOB check, so two validations saw different values for the same write. **Do not rename these without re-checking the ordering.**

**Status per table — all four compliant as of 2026-09-08.** `profiles_talent` ✅ · `profiles_venues` ✅ (`20260829030000`, PR #63, commit `d8b5d11`) · `profiles_users` ✅ · `profiles_clients` ✅ (`20260908120000`, commit `733e5ce`).

**`profiles_clients` is the only one proven behaviourally** (2026-09-11, real authenticated session): self-approval silently reverted, self-submission allowed, reverse transition reverted. The DOB check firing *after* the guard also proved the `a_` ordering works in practice, not just on inspection. The other three are structurally verified only — `profiles_venues` has never been tested venue-side because no venue accounts exist (`6hRh5rQ73gRm2G7X`).

**Testing note:** `profiles_clients` has no `date_of_birth` column. `check_client_dob_before_submission` reads it from `profiles_users` via `WHERE id = NEW.user_id`. Writing it to `profiles_clients` returns `PGRST204`.

---

## D-024 — Tax base and application order

**Date:** 2026-09-04
**Status:** Settled, but **dormant** — both rates are zero for v1 under D-001
**Source:** Todoist `6hQpgHxVX8GMh3fX` (closed)

**Decision.** SSCL and VAT apply to the **composite base** — talent fee + travel + equipment + commission. **Not commission-only.**

**Order is compounding, and the order matters:**

1. SSCL on the composite base
2. VAT on the **SSCL-inclusive** figure
3. PayHere grossed up on the result (by division — see D-004)

**Why this is recorded even though both rates are zero.** Under D-001 the rates default to `0.00`, so today this changes nothing. When a threshold is crossed and tax is enabled, this is the specification — and reconstructing it from scratch under time pressure, with the agent-vs-principal question (D-001, awaiting Ragu) also live, is exactly when it would be got wrong.

**Cancellation interaction.** The convenience fee base in D-008 takes SSCL then VAT on top in the same order. Also zero for v1.

---

## D-025 — A talent sees the client's name only, until a booking exists

**Date:** 2026-09-12
**Status:** Settled; backend and frontend both shipped
**Source:** Todoist `6h9798GcmjxpHP65`; migration `20260912090000`

**Decision.** At quote-request stage a talent sees the client's `full_name` and nothing else. Email and phone stay private until a booking exists.

**Two alternatives were ruled out by facts, not preference.**

*"Let the talent see the client via the FK"* is **impossible**. `profiles_clients` (`client_profile_manage_own`) and `profiles_users` (`users_read_own`) are both strictly own-row. A talent cannot read client rows at all, so the FK resolves to nothing they may read.

*"Persist name/email/phone onto `quote_requests`"* was rejected: it makes the client retype data the system already holds, duplicates it into a second table, and hands over contact details before any commitment — contradicting the platform's own design, since **`messages.booking_id` is `NOT NULL`** and no `conversations` table exists, so messaging deliberately does not open until a booking.

**Consequence worth remembering.** There is **no communication channel at quote-request stage**. A talent must decide whether to quote without being able to ask a single question. `quote_requests.special_requirements` (nullable) is the only route for client-supplied context, and nothing requires it.

**Mechanism.** `get_quote_request_client_names()` — `SECURITY DEFINER`, `search_path` pinned, ownership expression mirroring `qr_talent_select_targeted`. A **function, not a view**: a view would need `security_invoker = false` and be flagged by Supabase's `security_definer_view` lint, adding noise to the Advisor surface.

The function is callable by any authenticated user **by design** — all protection is in the `WHERE`. Verified 2026-09-12: called as a client, returns `[]`.

**Frontend.** The three dead required fields are removed from `RequestQuote.tsx` (commit `b742909`).

---

## D-026 — `REVOKE ... FROM PUBLIC` does not produce an authenticated-only function

**Date:** 2026-09-12
**Status:** Settled — applies to every future function
**Source:** Todoist `6hVQh2qFCrj4P5PX` (closed); migration `20260912140000`

**Rule — revoke BOTH, in one statement.** Two independent grant paths exist and removing either alone achieves nothing:

1. Postgres grants `EXECUTE` to `PUBLIC` on every function by default (ACL entry `=X/postgres`). `anon` and `authenticated` inherit through it.
2. Supabase's `ALTER DEFAULT PRIVILEGES` additionally grants `EXECUTE` to `anon`, `authenticated` and `service_role` as **explicit role grants**, which a `FROM PUBLIC` revoke does not touch.

```sql
REVOKE EXECUTE ON FUNCTION public.<fn>(<args>) FROM PUBLIC, anon, authenticated;
```

**This lesson has now been learned twice, from opposite directions.** Migration `20260822190000_revoke_public_execute_trigger_functions.sql` recorded that revoking from the roles alone had no effect, because they inherited through `PUBLIC`. Three weeks later `20260908190000` revoked `PUBLIC` alone and `anon` survived on its explicit grant. Neither half is sufficient. The first record lived only in a migration comment, where nothing surfaced it — which is why it is here now.

**How this was found.** `venue_is_owned_by_caller` shipped in `20260908190000` with `REVOKE ALL ... FROM PUBLIC` and a grant to `authenticated`, intending authenticated-only. Live ACL showed `anon=X` regardless. Harmless — `auth.uid()` is NULL for `anon`, so it returned false for every input and could not be used as an oracle — but the code asserted one thing and the database did another.

**Deliberately not revoked.** Eleven `SECURITY DEFINER` functions returning `trigger` carry the same `anon` grant and are **left alone**: a plpgsql trigger function called outside trigger context raises immediately, so there is nothing to gain and churning eleven grants adds risk. **`get_my_role()` is deliberately never revoked.** It returns NULL for `anon`, and **nine RLS policies call it** (counted live 2026-09-12, across `quote_requests`, `reviews_star`, `sensitive_asset_access_log`, `talent_favourites`, `talent_profile_sync_logs`, `talent_unavailability`). Removing `EXECUTE` from `authenticated` would break all nine, and **the symptom would be rows silently disappearing rather than a permission error** — the worst possible failure mode to diagnose.

Do not trust any recorded count of these. The `20260822190000` comment said seven; it is nine now, because the two `quote_requests` policies were added since. **Count it live before acting on it.**

**Nothing enforces this on the next function written.** Check `pg_proc.proacl` after creating any callable `SECURITY DEFINER` function.

---

## D-027 — Both frontends deploy as Cloudflare Workers static assets; `server.ts` is not deployed

**Date:** 2026-09-17 (Talent_Interface; Audience-Interface 2026-09-15)
**Status:** Settled, implemented
**Source:** `Talent_Interface` PR #76 (`be088ba`); `Audience-Interface` PRs #110–#112

**Decision.** Both frontends are Cloudflare **Workers** projects, not Pages, deployed as static assets from `./dist` with `not_found_handling: "single-page-application"`. Config lives in a committed `wrangler.jsonc` in each repo.

```jsonc
{
  "name": "talent-interface",
  "compatibility_date": "2026-09-15",
  "assets": { "directory": "./dist", "not_found_handling": "single-page-application" },
  "observability": { "enabled": true }
}
```

Live: `talent-interface.en4tainment-sl.workers.dev`, `audience-interface.en4tainment-sl.workers.dev`.

**Why Workers rather than Pages.** Cloudflare's "Continue with GitHub" now routes new projects into Workers Builds; Pages is in maintenance mode. The deciding argument was project-specific: Pages settings live only in the dashboard, invisible to the repo and unreviewable, whereas `wrangler.jsonc` is committed. Given this project's repeated declared-state-vs-running-state drift, config in version control is the better default.

**`Talent_Interface/server.ts` is deliberately not deployed.** Its production branch is `express.static(dist)` plus a `app.get('*')` catch-all returning `index.html` — which `not_found_handling: "single-page-application"` reproduces exactly. Its only other route is `GET /api/health` returning a hardcoded literal. It reads no config, proxies nothing, signs nothing, touches no Supabase. `npm run dev` still uses it and is unaffected. **Consequence: `/api/health` does not exist in production.** If anything ever monitors it, that breaks silently.

**Environment variables are Cloudflare BUILD variables, never runtime variables.** Vite inlines at build time, and a static-assets Worker runs no code, so runtime bindings are invisible to the app. Setting them in the wrong place produces a green build and a dead app.

**This was proven empirically, not assumed.** The first `talent-interface` deploy went green with the variables unset. The bundle came out at `index-_T2jfPAg.js` 913.73 kB against a local baseline of `index-BjlH6ru6.js` 913.98 kB — 250 bytes smaller, identical module count (2898). That gap is the project URL plus the anon key JWT compiling to empty strings. `curl -s <bundle> | grep -c sqovyodycuyajmumcjnn` returned `0`. After setting build variables and rebuilding, the hash, size and gzip figure matched local **exactly** and the grep returned non-zero.

**Standing diagnostic.** A green build proves nothing about env vars in either repo, because the guard in the Supabase client throws in the *browser* at module load, not at build time. Verify with `curl -s <bundle-url> | grep -c sqovyodycuyajmumcjnn`.

**Do not add `public/_redirects`.** It collides with `not_found_handling` and the Workers deploy API rejects it outright as an infinite loop.

**The check to run first on any failed build: which branch and commit is it building?** It is in the build header. Two hours were lost on the Audience deploy to Cloudflare rebuilding a merged-and-deleted branch whose commit predated the config file; three wrong theories (stale cache, root directory, config path) were chased before that question was asked. Note `main` is protected in both repos — work lands by squash-merged PR, so the commit to verify against is the **merge commit**, not the one pushed to the branch.

**Auto-deploy needs a GitHub App grant that nothing in Cloudflare's UI points at.** Added 2026-09-18. A Worker's build configuration can be entirely correct — repository connected, production branch `main`, non-production builds enabled, manual builds cloning the right commit — and still never deploy on merge, because push events are delivered through the **Cloudflare GitHub App installation**, and the repository must be in that installation's selected-repositories list. `Talent_Interface` was not. It was added on 2026-09-18 and a build fired immediately on the next push with nothing clicked.

Repo Settings → Webhooks is *not* where to look: the App delivers events through the installation, so the absence of a Cloudflare webhook there is correct and proves nothing. The only page that reveals the problem is `https://github.com/settings/installations`.

**Diagnostic:** push a throwaway branch (non-production builds are on). If a build fires unprompted, event delivery works. Delete the branch afterwards.

This also resolves both deploy mysteries from setup. `Audience-Interface` **was** in the grant, which is why Cloudflare could rebuild a merged-and-deleted branch there on 2026-09-15 — a dashboard build cannot spontaneously pick a stale branch. `Talent_Interface` was not, which is why every version in its history until 2026-09-18 was dashboard-fired or a manual retry. Same setup process, same day, one repo silently omitted.

**Unpinned deploy tool, noted not fixed:** the deploy command is `npx wrangler deploy`, which resolved to `wrangler@4.133.0` on 2026-09-17 and `4.134.0` on 2026-09-18 — whatever is latest at build time. In a project that pins Node via `.nvmrc` and installs with `npm ci`, the deploy tool itself remains an uncontrolled variable.

---

## D-028 — Node 22 is pinned in both frontend repos via `.nvmrc`

**Date:** 2026-09-17
**Status:** Settled, implemented

**Decision.** `.nvmrc` containing `22` is committed to both `Audience-Interface` and `Talent_Interface`. Cloudflare detects it and installs `nodejs@22.23.2`.

**Rationale.** Two frontends on two Node majors is a drift source with no compensating benefit. The alternative considered was pinning Talent to 24 to match the Codespace it was built in; consistency won.

**Verified reproducible.** `Talent_Interface` was rebuilt from a clean `rm -rf node_modules dist && npm ci && npm run build` on Node 24.14.0 and Node 22.22.1. Output was **byte-identical** across both: `index-BjlH6ru6.js` 913.98 kB / gzip 269.14 kB, `index-Cs6ALzLm.css` 38.08 kB, PWA precache 930.61 KiB. Cloudflare then produced the same figures again from the same commit.

**Why this matters beyond tidiness.** `Audience-Interface` has an open finding of a 512 kB local bundle against 734 kB on Cloudflare from the same commit — local `node_modules` drifted from the lockfile. `Talent_Interface` demonstrably does not have that problem, and the recorded baseline above makes any future divergence immediately visible rather than ambiguous.

**Use `npm ci`, never `npm install`, when checking a build against Cloudflare.** `ci` installs exactly what the lockfile pins and fails if lockfile and `package.json` disagree, which is what the build container does. `npm install` quietly resolves new versions and recreates the drift.

---

## D-029 — Google OAuth is the talent sign-in method; the consent screen stays in Testing until the privacy policy exists

**Date:** 2026-09-17
**Status:** Settled, implemented (Testing mode)
**Owner:** Praveen — not Ashey
**Source:** Todoist `6hPmpjMQXGXHqQ25`

**Decision.** Talent sign-in is Google OAuth. Considered and rejected for now: magic link via Resend (needs custom SMTP wired first, since Supabase's built-in sender is rate-limited to a handful per hour), and email + password (introduces a credential store and reset flows that would later be removed).

**Configuration.** Google Cloud project `En4tainment`, project id `enter10-488017`, owned by `en4tainment.sl@gmail.com`. OAuth client `En4tainment Supabase`, Web application.

- Authorised JavaScript origin: `https://sqovyodycuyajmumcjnn.supabase.co`
- Authorised redirect URI: `https://sqovyodycuyajmumcjnn.supabase.co/auth/v1/callback`

**The Google redirect URI is Supabase's, not the app's.** Google hands the user back to Supabase; Supabase then forwards to whichever app URL is in **its** Redirect URLs list. One Google entry therefore covers both frontends, every future custom domain, and localhost. Confusing the two is the standard way this setup fails, and it is why app hostnames belong in Supabase's list rather than Google's.

**Supabase Redirect URLs** now hold `http://localhost:3000`, `https://talent-interface.en4tainment-sl.workers.dev/**` and `https://audience-interface.en4tainment-sl.workers.dev/**`. The `/**` wildcard is required — Supabase matches the full redirect target, so a bare origin fails for any non-root landing path. **`Site URL` is deliberately untouched**: it is a single global value shared by both apps, and repointing it at one breaks the other.

**Testing mode is a deliberate choice, not an oversight.** External/Testing keeps the privacy policy, homepage and terms URLs optional, so this does not inherit the privacy-policy chain that gates custom domains. No logo was uploaded — that triggers Google brand verification, a multi-day review. Scopes are Supabase's non-sensitive defaults (`email`, `profile`, `openid`); none were configured.

**⚠️ The 100-user cap is lifetime, not concurrent.** Google's wording: *"Allowed user cap prior to app verification is 100, and is counted over the entire lifetime of the app."* Removing a test user does **not** free the slot. This is the same shape as `talent_identity_nic_hash_key` — a test action that permanently consumes something. Testing against production now burns Google slots as well as NICs.

**Known consequences, accepted for now:**

- **Google-only excludes any artist without a Google account.** A real constraint on the harder side of the marketplace. To be revisited before launch, deliberately.
- **No calendar scope was requested**, but `BookingManager.tsx` calls `session.provider_token` for Google Calendar. That path can now run for the first time and will fail at the API call. Adding `calendar.events` later re-prompts every existing user for consent — cheaper to decide while there is one Google user.
- **Publishing before launch requires the privacy policy URL**, which does not exist. Sequence after the legal-documents work.
- **Google is now a third-party processor in the identity path.** Record in the PDPA processing inventory and cover in the privacy notice.

---

## D-030 — Trust guards must fail closed when `get_my_role()` returns NULL

**Date:** 2026-09-18
**Status:** Settled, implemented
**Source:** `Audience-Interface` PRs #113 and the follow-up comment correction; migration `20260917190000_fix_trust_guard_null_role_bypass.sql`; Todoist `6hX2G6fqHXXRWVhX`

**Decision.** Every trust-field guard gates its pins as `get_my_role() IS DISTINCT FROM 'admin'`, never `get_my_role() <> 'admin'`. Any new guard follows this form.

**Why.** `get_my_role()` is `SELECT role::text FROM public.profiles_users WHERE id = auth.uid() LIMIT 1`. It returns **NULL**, not an error, when the caller holds a valid session but has no `profiles_users` row. Under `<>`, `NULL <> 'admin'` evaluates to NULL — not TRUE — so the gate never fires and the entire guard body is skipped. Under `IS DISTINCT FROM`, NULL is TRUE and the guard fires. No behaviour changes for any real role.

**The reusable lesson is the idiom split**, which divided the existing guards exactly:

| Idiom | On NULL |
|---|---|
| `IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN RETURN NEW;` | fails **closed** — correct |
| `IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN` | fails **open** — the defect |

Written as "return early if privileged", a NULL role fails to trigger the early return and the guard still runs. Written as "apply the pins unless admin", a NULL role skips the pins. Same intent, opposite failure mode. `enforce_user_trust_fields`, `enforce_message_writes` and `enforce_payout_account_trust_fields` used the safe form and were untouched; `enforce_talent_trust_fields`, `enforce_client_trust_fields`, `enforce_venue_trust_fields`, `enforce_featured_requires_admin` and the INSERT branch of `enforce_quote_writes` used the unsafe one and were fixed. Note `enforce_quote_writes` contained **both** idioms in one function.

**Severity: latent, not live.** This must be recorded accurately because it was initially reported — in the PR description and the migration's own header comments — as a live exploitable bypass, and it is not. Every surface those five guards protect was already masked:

- `profiles_talent`, `profiles_clients`, `profiles_venues` all carry `FOREIGN KEY (user_id) REFERENCES profiles_users(id)`
- `quotes` has **no INSERT policy for `authenticated` at all** — `service_role` only

So a caller with no `profiles_users` row cannot insert anywhere the NULL window would matter. Verified live 2026-09-17 through a real authenticated session, which returned `409 / 23503 / Key is not present in table "profiles_users"`. A caller who *has* a `profiles_users` row returns a non-NULL role and the guard fires normally.

It becomes live if any of those FKs is dropped, if an INSERT policy is added to `quotes` for `authenticated`, or if a new guard uses the failing-open idiom on a table without that FK. **None of those masks is documented as load-bearing** — which is the actual argument for fixing the guards rather than relying on them.

**Verified behaviourally, not by reading the function text.** Regression tested 2026-09-18 through a real session with `role = 'talent'`: an insert requesting `is_public: true`, `is_verified: true`, `approval_status: 'approved'` landed as `false` / `false` / `draft`, with `profile_status: pending`, `rating: 0.00`, `is_featured: false`, `pricing_updated_at: null`. Per D-022 and the `compute_quote_pricing` precedent, reading a replaced function back proves only that the text changed.

**Confirmed after apply:** one trigger bound per function, ACLs unchanged including the pre-existing `anon=X` / PUBLIC `=X` grants on four of the five (the D-026 pattern, deliberately left alone).

**Still open, and not fixed by this:** `talent_select_public` reads `USING (is_public = true)` and checks neither `approval_status` nor `is_verified`. This migration removes the ability to set `is_public` without admin rights, which makes that policy far harder to abuse, but does not make it correct.

---

## D-031 — A signed-in user creates their own `profiles_users` row; the app decides the role

**Date:** 2026-09-19
**Status:** Settled, implemented
**Source:** `Audience-Interface` migration `20260919120000_profiles_users_self_insert.sql`; `Talent_Interface` PR #78 (`ensureTalentAccount`)
**Recorded late:** decided and shipped on 2026-09-19, written into this register on 2026-09-21.

**Decision.** `profiles_users` gets an INSERT policy so the app creates the row itself on first sign-in, rather than a database trigger on `auth.users`. **The app that the person signed into decides the role:** Talent_Interface writes `talent`, Audience-Interface writes `client` or `venue`.

Policy as it stands live:

```sql
users_insert_own  INSERT  authenticated
  WITH CHECK (auth.uid() = id
              AND role IN ('talent','client','venue')
              AND status = 'active')
```

**Why the app and not a trigger.** A trigger on `auth.users` cannot know which app the person came from. `signInWithOAuth` accepts no metadata — unlike `signUp`, there is no `options.data` — and `raw_user_meta_data` holds only what Google's token carries. So a trigger could only ever apply the `'client'` default, mislabelling every talent. Since `role` is then pinned immutable for non-admins by `enforce_user_trust_fields`, correcting it would need `service_role` or an admin.

**Why self-asserted roles are safe here.** The policy refuses `admin` outright, and `a_enforce_user_trust_fields` refuses it again on INSERT and pins `role` on UPDATE. Beyond that, a self-declared `talent` grants nothing: a talent profile is invisible until approved (D-033), and KYC is a separate check. The security model rests on approval and verification, not on the role being unforgeable.

`status` is forced to `'active'` at insert, so it cannot be self-set to anything else.

**Consequence, noted 2026-09-21:** `profiles_users.phone` had to become nullable (`Audience-Interface` #115), because Google returns no phone number.

---

## D-032 — A talent's base location is a town chosen from a list; coordinates are derived by the database

**Date:** 2026-09-21
**Status:** Settled, implemented
**Source:** migrations `20260921100000_towns_reference`, `20260921100100_towns_data`; `Talent_Interface` PR #81. Todoist `6hX929667RvXHPm5`.

**Decision.** The talent types into the location field, matching towns appear, and they choose one. The base coordinates are the **centre of that town**, taken from a `public.towns` reference table of 17,564 Sri Lankan towns.

**Rejected, with reasons.** A map pin is the most accurate and stores what we least want to hold: most people would pin their home, and performers travel to late-night events, so it is a safety question as much as a PDPA one. Geocoding the existing free text needs a paid provider and a new Edge Function, and fails **silently** on repeated and transliterated Sri Lankan place names — a talent charged travel from the wrong town with nothing to flag it.

**A town must be chosen; free text cannot stand in for one.** Typing without selecting discards any previous choice, and the form refuses to save. Coordinates are required before a profile can be submitted for review (D-033).

**Coordinates are derived, never sent by the client.** The trigger `set_talent_base_coordinates` copies the chosen town's centre into `base_latitude` / `base_longitude` and **overwrites anything the client supplies**; with no town, both are NULL. This matters because D-005 charges travel on distance: client-written coordinates would let a talent place their base far from every venue and inflate every travel charge. Verified by attempting exactly that — Jaffna's coordinates were replaced with Athurugiriya's.

**On the data.** GeoNames LK, **CC BY 4.0 — attribution is required wherever town data is shown**, and appears under the field. Cleaning is documented in the data migration and reproducible: 278 places had no district, **including every regional capital**, and their province codes were often wrong (a Matale village labelled Southern Province); districts were filled from the nearest GN-division point and validated at 99.3% against places with a known district. Duplicates were merged, same-name places disambiguated by DS division, and suggestions ranked so the town people mean comes first.

**Accuracy is a town centre, a few kilometres at worst.** Enough for D-005's 10 km threshold, except for a talent and venue sitting right on the line. That was accepted deliberately in exchange for not holding home addresses.

**Note against D-005:** the 7.5% travel fallback was, until this landed, the *only* case — no talent had coordinates. It is now what it was meant to be: the incomplete-profile case.

**Venue coordinates are a separate decision** (`6hMv5Jc6jm5M4w85`). A venue is a specific public address, where precision is useful and harmless.

---

## D-033 — A talent profile is public only if approved; and what "complete" means for submission

**Date:** 2026-09-21
**Status:** Visibility rule and completeness gate both settled and implemented. The Submit for review button is not yet built.
**Source:** migration `20260921100200_talent_visibility_requires_approval`. Todoist `6hX95jpJQ8pQG8r5`.

**Visibility.** `talent_select_public` changed from `USING (is_public = true)` to also require `approval_status = 'approved'`.

The policy never checked approval. Verified live: one profile was public while still `pending_approval`, and was readable by `anon` over PostgREST despite never having been approved. Approval was enforced only by frontend query filters. The trust guard already stopped a talent setting `is_public` themselves, so it was not self-exploitable — but "approved" is what should make a profile visible, and the database should say so rather than relying on every query to remember.

**Directus is unaffected — verified, not assumed.** The policy is granted `TO public`, which covers every role; Directus connects as `nocobase_admin`, which has `BYPASSRLS`. If that role ever loses it, this policy would hide every pending profile from the tool that reviews them.

**Submission decisions (Praveen, 2026-09-21).**

1. **Everything is required except** the four secondary locations and the second and third genres.
2. **The NIC blocks submission.** No parallel KYC: without it, KYC cannot be reviewed, so the profile is not complete.
3. **Base coordinates are required**, captured per D-032.
4. **Editing an approved profile sends the edit to review, and the last approved version stays live.** No direct publishing of edits, and no talent dropping out of listings while a change is reviewed. This needs somewhere to hold pending changes, so it is its own build; it only matters once someone real is approved.

Point 4 is what makes the visibility rule safe: an approved talent stays approved during review, so requiring approval never removes a live profile on edit.

**The gate shipped the same day** as `check_talent_completeness_before_submission` (migrations `20260921210000` and `20260921210100`), a third check of the same shape as the existing date-of-birth and starting-rate guards. It refuses a transition into `pending_approval` or `approved` and names **everything** missing in one message, rather than the first failure, so the Submit button's checklist can show the same list. Tested both ways through an authenticated session: incomplete refused with a precise list; complete accepted, landing `pending_approval`, not public.

**Still to build:** the Submit for review button itself.

**A blocker the gate exposed:** `talent_media` has never had a row written to it, for any talent. The gate now requires at least one gallery image, so if the upload path does not work, every real submission is blocked. Test an upload end to end before building the button.

**Consequence accepted:** the hand-made "Test Talent" fixture disappeared from Artists and Home, because it is not approved. Decided 2026-09-21 to complete it properly and then approve it, rather than approving an incomplete profile as an exception.

---

## D-034 — ACPOSL music-licensing tariff: the organiser is the licensee; En4 informs, does not collect

**Date:** 2026-09-22
**Status:** **Open.** Part 1 pending legal opinion (Ragu). Part 2 pending Erich. Part 3 proposed by Praveen, not yet built.
**Source:** Gazette Part I Sec (IIB), 05.06.2026, pp. 1850–1863 ("Licensing Tariff Framework — Public Performance and Communication to the Public"), ACPOSL. Todoist label `acposl` (15 tasks, created 2026-09-22).

**What happened.** ACPOSL, a CMO registered with NIPO, gazetted a tariff for public performance of musical works. Press reports it came into force around 2026-09-15. Press also reports it initially covers Sri Lankan works represented by ACPOSL plus Hindi and Tamil works via IPRS, and that events using **only English or other foreign music need no licence**. That exemption is **not in the gazette text** and needs confirming with ACPOSL. Hotels (THASL) have pushed back publicly, and clause 2.xv lets ACPOSL revise rates at will, so treat every figure as volatile.

**Proposed decision, in three parts.**

1. **The event organiser (client or venue) is the licensee, never En4.** The terms and artist agreement must say so. *Pending:* whether the two-invoice model (client pays En4 for the whole engagement, talent balance as "reimbursement") could lead ACPOSL to treat En4 as the organiser, and whether facilitating an unlicensed booking could be treated as authorising the use. → `6hXwq6CwWFjvcgq5`.
2. **v1 shows an indicative licence band; En4 does not collect the fee.** Collecting would put a pass-through on the payable invoice and disturb the reimbursement/turnover treatment settled by the taxation manager. Commission stays on the performance fee only (D-003). → `6hXwq6HJ5ff9cJ7X`.
3. **The platform captures what the tariff prices on, and keeps the tariff as data.** It needs an audience capacity band on `quote_requests` (6.3: <100 / 100–300 / >300), repertoire languages on the talent profile, and a tariff rules table rather than hardcoded logic, so an amendment is a data edit. The indicative notice is shown in `RequestQuote.tsx` and at quote acceptance, with an acknowledgement timestamp stored on the booking as dispute evidence. → `6hXwq6QqXQhMwFGX`, `6hXwq6PgW8MJv9V5`, `6hXwq6RwXQxfVrc5`.

**How the tariff maps onto our enums** (gazette figures, LKR):

| Scenario | Tariff route | Buyer's cost |
|---|---|---|
| F&B venue, `dinner_service`/`lunch_service`, `solo`/`duo`/`3-piece` | Venue's annual F&B licence covers incidental live ≤3 performers (5.2), *if the venue holds one* | none per event |
| F&B venue, `full band`, or a DJ promoted as an event / themed night | Separate event licence (5.3, 5.4) | 20k–50k |
| Hotel wedding, banquet, function | Hospitality licence excludes live, DJ and banquets (4.3) | per 6.4 |
| `wedding`/`birthday`/`private`/`corporate` — DJ | Private/Corporate (6.4) | 25k / 40k / 60k |
| same — live or hybrid | Private/Corporate (6.4) | 50k / 75k / 125k |
| `concert`, or a brand-sponsored event reclassified as one (6.5) | Per work (7.4), setlist before the event (7.6) | up to 10k per song |

Press reports the large private DJ fee as Rs 50k. **The gazette says Rs 60k. The gazette governs.**

**Why this matters beyond compliance.**

- **Price shock.** The fee is invisible at quote time today. A client can accept a Rs 60k solo booking and then face a Rs 50k licence, and the blame lands on the platform.
- **The burden is regressive.** A solo act at a 60-person private party pays the same Rs 50k as a full band, and private live is double the public live rate. Small private bookings are hit hardest.
- **Demand will shift** toward line-ups of three or fewer at F&B venues and toward English sets, and away from Sinhala, Tamil and Hindi acts, which are a large share of our supply.
- **Talent are exposed.** 5.6(b) names "the licensee *or performer*" for setlists. A setlist is also the only evidence that a set was English-only.

**Not decided here.** Setlist capture, venue licence status and any ACPOSL collect-and-remit partnership are V2 (`6hXwq6Cg8wwCGWPX`, `6hXwq6F94vHRCJpX`, `6hXwq6Gj5v9V6McX`). Monthly amendment watch: `6hXwq6C7v3vc3qFX`.

**Close this entry** (Status → Settled) once the legal opinion and Erich's answer are in. Record any change to parts 1–2 here rather than in task descriptions.

---

## D-035 — Profile rows are never hard-deleted; erasure is anonymise-in-place

**Date:** 2026-09-26
**Status:** Settled — request half implemented, admin erasure unbuilt

**Decision.** A profile row is never deleted. Erasure means blanking personal fields in place and keeping the row id. Around twenty tables cascade from `profiles_users` and `profiles_talent` — `payments`, `contracts`, `messages`, `reviews_star`, `documents`, `talent_payout_transactions`, `talent_identity`, `talent_media`, `availability`, `talent_stats` and more — so deleting a profile row destroys legal-hold data that must be retained.

**Any migration that flips one of those foreign keys to CASCADE removes a guardrail.**

**What was wrong.** `talent_profile_manage_own` was `FOR ALL`, which includes DELETE. Proven behaviourally on 2026-09-26: a talent with no bookings deleted their own `profiles_talent` row and the `talent_identity` row — NIC hash and KYC references — cascaded away with it, leaving R2 objects orphaned and no audit record. `profiles_clients` and `profiles_venues` had the same shape. DELETE and TRUNCATE are now revoked from `anon` and `authenticated` on all six profile tables plus `talent_identity`; `service_role` retains them for the erasure path.

**Sub-decisions.**

1. The hashed NIC **is** erased, so the person can register again. Accepted consequence: this weakens the link from a retained booking to a verified identity, and someone removed for misconduct can return under the same NIC.
2. Name and personal fields are removed; the user id is kept. Required, not preferred.
3. The profile is hidden on request, not left visible as dormant. Dormant-but-listed is a separate feature.
4. `profile_status` is deliberately untouched — `inactive` belongs to the dormant feature, so "requested deletion" and "taking a break" stay distinguishable in the data.
5. Open bookings, open quote requests and pending sent quotes all block the request outright.
6. Withdrawal is admin-only. A talent cannot reverse their own request.
7. Erasure within **14 calendar days** — deliberately stricter than the PDPA s.17 ceiling of 21 working days.
8. The confirmation email goes to `auth.users.email`, **not** `profiles_talent.email`. The latter is a user-editable contact field and was found diverging from the sign-in address on a live row. The message is a security notice telling the person to reply if the request was not theirs, so it must reach the verified account.

**Legal note.** SL PDPA s.16 is narrower than GDPR Art. 17. If the lawful basis is contract necessity, offering this is a **product choice**, not a statutory duty — which is why the 14-day promise is ours to set and ours to keep.

---

## D-036 — The review panel owns the approve/reject transition, not the Directus dropdowns

**Date:** 2026-09-26
**Status:** Settled, implemented

**Decision.** Approving or rejecting a talent is a single action performed in the `kyc-document-review` extension, which calls the `review-talent` Edge Function, which calls `review_talent()`. That function sets `approval_status`, `profile_status`, `is_public`, `is_verified`, the reviewer trail and `talent_identity.kyc_status` — **all of them or none**.

**Why, and this is the part that matters.** Approval was two uncoupled fields. `approval_status = 'approved'` publishes nobody; only `profile_status = 'active'` sets `is_public`, via `handle_talent_approval`. `talent_select_public` requires **both**. An admin changing one dropdown and not the other produced an approved-but-invisible or active-but-unapproved talent, **silently**. The dropdown was not merely permissive — it was already doing the job wrongly.

**Rules now enforced.**

- Approval requires the reviewer to have opened **both** `kyc_front` and `kyc_back` for that talent within **30 minutes**, checked against `sensitive_asset_access_log` server-side.
- Only a profile in `pending_approval` can be reviewed. A pending deletion request blocks approval outright.
- `kyc_status` is marked `rejected` **only** for `documents_unclear` and `identity_mismatch`. Rejecting someone for a thin bio says nothing about their NIC.
- `other` and `incomplete_profile` require a note.
- The reviewer sees the exact sentence the talent will receive next to each reason.

**`incomplete_profile` does not mean what it sounds like.** A profile cannot reach `pending_approval` unless the completeness gate passes, so every required field is present by review time. Choosing it is a quality judgement the database cannot compute. The name was kept deliberately; only the behaviour changed.

**Thirteen trust fields are set read-only in Directus.** This is a guard against habit, not a control — the Directus API still accepts admin writes. The `Talent & Venue Review` policy still grants `fields = *` and only starts mattering once reviewers exist who are not System Administrators.

---

## D-037 — Clients need no approval; venues do

**Date:** 2026-09-27
**Status:** Settled — venue side unbuilt

**Decision.** There is **no approval workflow for clients**. Do not build one. The `approval_status` column stays as scaffolding but is not a workflow.

**Venues do require approval**, built alongside the venue portal, following the D-036 pattern: one action setting `approval_status` and `is_verified` together, an Edge Function, email templates with the reason rendered as a sentence, and a business-registration document check.

**Why they differ.** Clients are the demand side; an approval queue for every buyer adds friction to the side you want more of and is a queue nobody would keep up with. Venues are businesses that receive payments, so a registration check is meaningful.

**At decision time, neither approval did anything.** No policy, trigger or function referenced either column. `enforce_quote_request_writes` never checked client approval.

**⚠️ The venue portal is a live dead end.** `VenuePortal.tsx` already sets `pending_approval` and tells the venue *"still under review, we will contact you once approved."* Nothing can approve them. Zero venue rows, so nobody is stuck — but the portal is live.

**⚠️ The client 18+ check is dead code.** `check_client_dob_before_submission` fires only on a transition to `pending_approval` or `approved`, which now never happens. There is currently no age gate on clients at all. **Open:** whether clients must be 18+, and if so the check belongs on quote-request creation.

---

## D-038 — Eight-category talent rate model with fixed duration packages

**Date:** 2026-09-27
**Status:** Settled — **the rate side is built** (migrations `20260927162423`, `20260927164332`, `20260927183713`, plus the talent-app UI). **Fixed duration packages remain unbuilt.** Supersedes D-011.

> **Read the build notes at the end of this entry.** Several details were decided during implementation and are not in the original text.

**Decision.** A talent sets a fee **per category**, and setting a fee is how they opt in.

| Category | Client-facing event types |
|---|---|
| Special events | corporate, birthday, private — one fee across all three |
| Wedding | wedding |
| Concert | concert |
| Clubs and pubs | new enum value |
| Dinner service | dinner_service — *hotels and restaurants* |
| Lunch service | lunch_service — *hotels and restaurants* |
| Spot performance | new enum value — 3 songs, ~15 min |
| Other | other — no band, free hand on the fee |

`concert` already exists in `events_type`. Only clubs/pubs and spot performance are new.

**No fee for a category means the talent does not do that work:** excluded from client searches for those event types, and the public profile lists only the categories they have agreed to.

**Shape.** A `talent_rates` child table, one row per talent per category with its own `updated_at`, so opt-out and the **per-category 30-day cooldown** fall out naturally. `talent_rate_at_request` must snapshot the category's rate.

**Fixed duration packages replace client-entered duration:** typical gig 4.5 hours; wedding 6 hours with a 15-minute break each hour; concert 90 minutes; spot performance ~15 minutes for 3 songs. **The package must state both hours on site and hours of playing** — per Senal's interview, playing caps at 3.5–4 hours whatever the event spans, and the ambiguity is a dispute waiting to happen.

**Quote form.** Fee, performer count and setup arrival time are required. Performer count is required because the client owes meals and cannot cater for a group of unknown size. Everything else is optional with a specific nudge saying what it adds.

**Meals** are mandatory for a typical gig within proximity. Distance add-ons open as fields once the system knows the venue-to-talent distance: extra meal and changing room over 100 km, accommodation over 150 km.

### ~~Open — spot performance breaks the travel maths~~ — CLOSED 2026-09-27

The original concern: at Rs 150/km, a 15-minute set 40 km out generates roughly Rs 12,000 of travel against a small fee, apparently needing a radius, a cap, or free-zone only before that category could ship.

**Closed. Spot performance needs no special travel handling** and ships on the standard rules.

Two reasons, from different directions:

**The fee is not mathematical** (Praveen, from Senal's interview). For this kind of booking, value for money is not calculable. If a talent is popular and clients are willing to pay, the logic and practicality of the fee are irrelevant — what is being bought is the celebrity being at the event, not fifteen minutes of stage time.

**Travel is a function of distance, not stage time.** The talent drives the same round trip for three songs as for three hours, so charging full travel for a short set is the model working, not an inconsistency in it. The original framing implicitly compared travel against the fee — one a cost, the other a price — and there is no reason those two should be proportionate.

**What this closes:** no radius, no cap, no free-zone-only restriction, and no category-aware travel branch in `compute_quote_pricing` that would otherwise have had to be carried forever.

**What it does not touch:** the 10 km threshold and cliff edge from D-005 are unchanged — under 10 km travel is zero, at 10.1 km the full distance is charged.

**Residual, and it is presentation rather than pricing.** On a modest spot-performance fee, travel can be a large fraction of the client total. The client quote view should itemise travel clearly enough that it reads as a cost rather than a markup. Not a blocker; a note for when that view is built.

### Build notes, 2026-09-27

**Two enums, not one.** `rate_category` (eight values) is separate from `events_type` (now ten). `special_events` is one fee covering corporate, birthday and private, so keying rates by event type would mean three rows holding the same number that have to be kept in step — and "one fee replicated" is how sync bugs start. `rate_category_for_event_type()` is the single place the mapping lives. Verified: all ten event types map, none returns NULL.

**`club_pub` and `spot_performance` needed their own migration.** Postgres allows `ALTER TYPE ... ADD VALUE` inside a transaction, but the new value **cannot be used until that transaction commits**. Anything referencing them has to be a separate file. This passes when applied statement by statement and fails on `db push` against a fresh database — worth remembering for every future enum addition.

**Eight rows always exist, and `amount` is nullable.** NULL means the talent does not do that work. Rows are seeded on profile creation; a talent holds SELECT and UPDATE only, **no INSERT and no DELETE**.

This is what makes the cooldown real rather than decorative. Had row-absence meant opting out, a talent wanting to raise a wedding fee inside 30 days could delete the row and re-add it. With permanent rows, `IS DISTINCT FROM` catches value→value, value→NULL and NULL→value alike, so **clearing a rate costs 30 days exactly like changing one**. The bypass closes structurally rather than by another guard.

**Floor of 1,000**, matching Range 1 in `price_ranges` (D-039). Below it a rate resolves to no range at all and the talent drops out of every client filter — which reads as a broken search rather than a bad rate.

**The cooldown only fires for `caller_role = 'talent'`,** mirroring the old `enforce_pricing_cooldown`: an admin correcting a typo must not cost the talent their next 30 days. **Consequence: `service_role` and admin bypass it entirely.** Any future Edge Function writing rates gets no cooldown and must not be written as though it does.

**A quote request is refused when the talent has no rate for that category.** `set_talent_rate_at_request` now resolves the category from the requested event type. The client-facing picker filters those talent out, so the exception is a **backstop** — but clients hold INSERT on `quote_requests`, so a hand-crafted insert through PostgREST bypasses the picker entirely and the picker cannot be the only enforcement. Without the guard the NULL snapshot reaches `enforce_quote_writes`, which multiplies it into `quoted_amount` and fails as a NOT NULL violation: the wrong error, in the wrong place, shown to a client who did nothing wrong. **The message names no number**, because a client reads it and rates are not published (D-046).

**The submission gate became "at least one category rate."** On INSERT the check cannot be expressed at all — `talent_rates` rows are seeded by an AFTER INSERT trigger and do not exist when the BEFORE trigger runs — so that case gets its own message. `approval_status` defaults to `draft`, so the normal create → set rates → submit path is unaffected.

**UI.** A `TalentRates` component in the talent app, rendered as a section inside `ProfileEditor` rather than on its own screen, because the submission gate requires a rate and a talent must not be refused for never having visited a separate page. Locked categories render as **text with their unlock date**, not as inputs that accept a number and then reject it. Only changed rows are sent, so a save never trips a cooldown on a category nobody edited.

**`amount` arrives from PostgREST as a string**, because `numeric` is serialised as a string to avoid float precision loss. Without `Number()` every row compares as changed and a single save would trip cooldowns across every category.

**Still unbuilt from this entry:** fixed duration packages, the quote form, meals and distance add-ons, and the spot-performance travel problem above.

---

## D-039 — Price ranges are client-facing and talent-blind

**Date:** 2026-09-27, substantially amended the same day
**Status:** Settled — **amended and built 2026-09-27** (migration `20260927155227_price_ranges`)

> **Read the amendment below before the original.** Two things in the original decision were reversed: ranges are **shared across event types**, not per event type, and the open schema question is closed. The term "band" is replaced by "range" throughout.

**Decision.**

- Clients see the band and the talent who fit it. Band is chosen **per event type**, so a talent can sit in different bands for different categories — band membership cannot be a single label on a profile card. **[REVERSED — see the amendment. One shared ladder applies to all event types.]**
- **HARD RULE: the talent never sees the bands.** When quoting they are warned only if **above** their band. Quoting lower is fine.
- `other` has no band.
- Admin can see actual rates, analyses quoted amounts per band, and shifts bands quickly.

**⚠️ The check must be server-side.** A browser-side check ships the thresholds inside the frontend bundle, where anyone can read them. That does not merely permit probing — it hands over the numbers. The check returns within/above, never the figure.

**`quote_price_checks` logs every attempt** — quote request, talent, amount, above-band yes/no, timestamp. **Three checks per quote request**, then no more warnings; the quote can still be submitted. The third warning must say plainly that no further checks remain — silently ceasing to warn reads as approval.

**That log is also the band-shifting dataset.** Sent quotes show only what talent settled on after being pushed down. The attempts show what they wanted to charge, which is the signal that a band is set too low.

**The tension, stated so it is not rediscovered.** "Never sees the bands" and "warn when above" cannot both be absolute — any warning that fires at a boundary reveals where the boundary is. The resolution is to accept the leak, limit probing to three, keep the warning wording vague, and have admin shift bands periodically.

**Open:** whether a band is a fixed money range set by En4 or percentile-based. This determines the schema. **[CLOSED — fixed money ranges. See the amendment.]**

### Amendment, 2026-09-27 — naming, the shared ladder, and the built schema

**Named `Range 1` to `Range 10`, ascending with price.** The criteria set were *ordered* and *non-judgemental*, and those two together rule out most candidates. Tier, Level, Grade, Class and Category each rank the performer rather than the price — "a Grade 3 act" is a verdict. Bronze/Silver/Gold runs out well before ten steps. Musically authentic scales (tempo, dynamics) carry no judgement but no client knows that Vivace outranks Andante. A neutral noun plus a number is the only form that **stays ordered when the label appears away from the filter** — on a quote, in an email, in a conversation with a client's manager. Band and Bracket were the other two finalists.

Ascending, so a new talent does not start at what reads like a bottom rank.

**Schema naming.** Table `price_ranges`, FK `price_range_id`. Two existing columns already use the word — `profiles_clients.typical_budget_range` and `profiles_venues.audience_age_range` — so the column name says which kind of range it is while the UI label stays the short "Range N".

**One shared ladder across all eight event types.** This reverses the original "per event type". The worry was that a shared card would dump every spot performance into Range 1, but the ladder spans 1,000 to 2.3m+ and they spread out naturally: a spot performance lands around Range 3-4, a club gig 4, a wedding 6, a headline act 9. Shared keeps "Range 6" meaning the same money everywhere, **which is the property that made a numbered label worth choosing in the first place** — per-event-type would have destroyed it, since Range 6 would mean one thing for a wedding and another for fifteen minutes of spot performance, and the label would be unreadable without its event type attached.

Per-event-type overrides remain cheap later: a nullable `event_type` column plus a lookup change, not a rewrite.

**The ladder, agreed 2026-09-27.** Floors only:

| Range | Floor | Up to |
|---|---|---|
| 1 | 1,000 | 7,499 |
| 2 | 7,500 | 17,999 |
| 3 | 18,000 | 34,999 |
| 4 | 35,000 | 79,999 |
| 5 | 80,000 | 179,999 |
| 6 | 180,000 | 319,999 |
| 7 | 320,000 | 574,999 |
| 8 | 575,000 | 974,999 |
| 9 | 975,000 | 1,399,999 |
| 10 | 1,400,000 | no ceiling |

Geometric — each step 2.4x down to 1.44x, tightening as the money grows, because 5,000 matters at Range 1 and is invisible at Range 9. Range 1 is the widest in relative terms (7.5x); split it if spot performances turn out to cluster at 3-5k.

**Lower bound only, and this is not a style choice.** The first draft of the ladder stored both bounds — 1,000-7,500, then 7,600-18,000, and so on. That left **7,550 in no range at all**, and the same hole at every boundary from 1 to 8. A talent landing in a hole would have had no range and dropped out of every client filter, and it would have read as a broken search rather than a config gap. A range now runs from its own floor to the next floor, exclusive; the floor belongs to the range above, so 7,499 is Range 1 and 7,500 is Range 2. Range 10 is uncapped so the most expensive acts cannot fall off the top.

**Range 1 floors at 1,000 and nothing below resolves.** `talent_rates` **must** therefore carry `CHECK (amount >= 1000)`, or the floor merely relocates the hole rather than closing it.

**Membership is derived, never stored.** A talent's range is whichever floor their rate falls above, computed at query time by `price_range_for_amount(amount, at)`. Ten ranges against a few hundred talent is nothing, and it means shifting a boundary re-buckets everyone at once — which is what "shift the bands quickly" requires. A stored range column would be a denormalised value that goes stale.

**Append-only, enforced by trigger rather than convention.** Two tables — `price_range_sets` and `price_ranges` — because a set must stay whole; with `effective_from` repeated on ten rows, nothing stops nine moving and one not. `UPDATE` and `DELETE` are refused outright, including from the SQL editor. Amending means inserting a new set of ten with a later `effective_from`. Editing in place would retroactively rewrite what a past client was shown. A deferred constraint trigger refuses any set that is not exactly ten rows and strictly ascending.

**Not readable by `anon` or `authenticated`.** This is load-bearing, not hygiene. Publishing the boundaries hands a talent their own ceiling by subtraction. See D-026 — Supabase's default privileges grant both roles on every new table in `public`, so the revokes name the roles explicitly.

**Verified live after applying, not inferred from the migration succeeding:** 7,499 → Range 1 and 7,500 → Range 2 (no gap at the boundary); 50,000,000 → Range 10; 999 → null; `UPDATE` refused with the floor still 7,500 afterwards; a one-row set refused at commit; no `anon` or `authenticated` grant on either table.

**Still unbuilt from the original decision:** `quote_price_checks`, the three-checks-per-quote limit, and the above-range warning itself.

---

## D-040 — A talent may decline a quote request, with a reason

**Date:** 2026-09-27
**Status:** Settled — **unbuilt**

**Decision.** A talent can decline a specific quote request and must give a reason.

**What is wrong today.** `enforce_quote_writes` refuses any talent-initiated `quote_status` change: *"Acceptance and rejection are client actions handled by the orchestration service."* The only permitted talent transition is `pending → expired`, and only when the parent request is already dead. So a talent who does not want a gig has no way to say so, and **the client waits up to seven days for an answer that was never coming**.

**Requirements.** A reason enum plus optional note, matching the rejection model. The client must be told, not left to notice. Check `cascade_quote_request_close` and the existing `quote_decline_reason` enum before creating anything new. Decide whether declining returns the parent request to `open` or closes it.

**Distinct from D-038.** Declining a whole category is handled by the absence of a rate — the request never arrives. This entry is about declining a specific request in a category the talent does work.

---

## D-041 — Email: Resend for sending, Cloudflare Routing for receiving

**Date:** 2026-09-26
**Status:** Settled, implemented

**Decision.** Two systems, deliberately separate. Resend sends; Cloudflare Email Routing receives. Both on the free tier.

**⚠️ The apex SPF authorises Cloudflare, not Resend.** Resend's SPF is on `send.mail.`. Anything sending via Resend **must** use an address on `mail.en4tainment.com`. A From of `x@en4tainment.com` fails SPF and lands in spam, and it will look like a Resend fault when it is not.

**Sender split.** Directus operational mail (invites, password resets) sends as `no-reply@mail.en4tainment.com`. Customer-facing mail sends as `notifications@mail.en4tainment.com` with Reply-To `support@en4tainment.com`.

**Two API keys**, both sending-access only, kept separate so they rotate independently and the logs show which system sent what.

**Catch-all is set to Drop.** Consequence: **any address published anywhere must exist as a routing rule, or mail to it vanishes with no bounce.** `privacy@` especially — a data request into a dropped address is a missed statutory obligation with no trace.

**Free-tier limits:** 3,000/month, **100/day**, one verified domain. The daily cap is the one that bites, and it matters for batched sends.

**Deliverability is unproven.** Every successful inbox delivery during setup was to an account already trained by a "not spam" click.

---

## D-042 — Equipment is a single talent-entered fee

**Date:** 2026-09-27
**Status:** Settled — **unbuilt**. Supersedes D-006.

**Decision.** The equipment fee is **one amount the talent enters on the quote**. Remove `quotes.equipment_provided_by`, `profiles_talent.equipment_fee_percent`, and the unbuilt `sound_provided_by`.

**Why D-006 fails.** It applies a percentage only when `equipment_provided_by = 'talent'` — which is the column **default**. So every quote carries an equipment fee whether or not the talent brought anything, and the talent is never asked. A venue with its own PA would have its client charged for equipment nobody supplied.

**The talent is not taken into who-provides territory at all.** It is simply a fee they enter. Senal's interview supports this: serious acts always bring their own rig for quality control and rent according to venue size, so the cost is real but varies per gig in a way a fixed percentage cannot express.

**The fee is price-bearing** — it feeds `talent_payout_amount` — so it must be trust-guarded and pinned on update like every other money field. A client must never be able to declare it.

---

## D-043 — Travel is charged at a flat Rs 150/km

**Date:** settled September 2026, restated and confirmed 2026-09-27
**Status:** Settled — **unbuilt**

**Decision.** Rs 150 per km, return trip doubled, with the old 1.05 uplift folded in and dropped. Stored as a single value, not tiered by party size.

**The live function still runs `120 × 1.05`** — an effective 126. This entry existed and was never implemented (see Standing Correction below).

Unchanged: the 10 km free threshold, the cliff edge (beyond 10 km the **full** distance is charged, nothing deducted), and the 7.5% fallback when coordinates are unavailable.

**Note for the implementation.** `quotes` snapshots `sscl_rate_percent`, `vat_rate_percent`, `gateway_rate_percent` and `commission_rate_percent`, but **not** the travel rate. A future rate change therefore silently rewrites the basis of quotes already sent. Add `travel_rate_per_km` to the snapshot in the same migration.

### Amendment, 2026-09-27 — folded into D-044, not shipped standalone

The three-line constant change is **not** to be done on its own. It lands as part of the rate configuration layer (D-044), so the rate is config-driven and snapshotted from the first moment it changes value. Doing it standalone means rewriting `compute_quote_pricing` twice and leaving the config work to inherit a half-done change.

**Accepted consequence: the live function stays at an effective 126 LKR/km until D-044 ships.** Safe only while `quotes` has zero rows. The moment the first talent is approved and a client raises a request, a quote can be created at 126 — that is the point at which this stops being free, and it should be watched alongside the first real approval.

Todoist `6hf5q5FjfCjCPrQ5` is now a subtask of the config panel task and is retitled so it cannot be picked up standalone.

---

## D-044 — Platform rate configuration layer, append-only with snapshots

**Date:** 2026-09-27
**Status:** Settled — **unbuilt**

**Decision.** All five platform rates — commission, travel, SSCL, VAT and gateway — move together into an admin-editable configuration layer with effective dates. Not travel alone.

**Each quote carries BOTH an FK to the config version AND the numeric values.**

- The **numeric** is what an invoice reprints, and it survives a config row being deleted or edited by someone who did not know the rule.
- The **FK** gives lineage: "which config version priced this quote" becomes answerable, and one reference captures the whole rate set rather than five loose numbers.

**The config table must be append-only, and this is the load-bearing part.** An FK preserves a snapshot only if the row it points at can never change. If an admin edits a rate in place, every quote pointing at it silently reprices — which is exactly what the snapshot exists to prevent. Effective dates give append-only for free: a rate change inserts a new row with a new `effective_from` and never updates the old one. **Enforce it with a trigger, do not merely intend it** — `price_ranges` (D-039) does this and is the pattern to copy.

**Why all five together.** `quotes` already snapshots four rates as plain numerics and `bookings` mirrors them. Travel is the only one missing. Adding an FK for travel alone would leave two mechanisms for one concept, and the next person reading the schema has to learn both.

**Why travel is the sharpest case.** Travel is commission-free and lands inside `talent_payout_amount`, so a silently shifting travel rate misstates **what En4 owes the talent**, not just what the client is shown.

**Sequencing.** Land with the D-038 rate model, which rewrites `compute_quote_pricing` wholesale anyway. Doing it separately means rewriting that function twice.

---

## D-045 — The contact form is stored first and notified second

**Date:** 2026-09-27
**Status:** Settled, implemented

**Decision.** A contact submission is written to `contact_submissions` **before** the notification email is attempted, and the visitor is told "sent" once the row exists. Chosen over a mailto handoff and over an email-only path.

**Why.** An email-only path has no record when delivery fails, and Resend's free tier caps at 100/day **across the whole platform**, shared with talent approvals, rejections and deletion notices. `notify_error` is the column that makes a failed or skipped notification queryable rather than silent:

```sql
select * from contact_submissions where notified_at is null and notify_error is not null;
```

**Two limits that behave differently, deliberately.** Per-IP (3/hour, 10/day) is abuse control: **rejected, nothing stored**. The global 30-per-24h cap is quota protection: **stored, email skipped**, `notify_error` records why. An unthrottled form could otherwise burn the day's Resend quota and silently stop a talent approval from sending.

**No browser-reachable write path.** `contact_submissions` grants nothing to `anon` or `authenticated`; rows arrive only through the `contact` Edge Function under `service_role`, which is where validation, the honeypot and the rate limits live.

**PDPA.** Controller REAP Holdings (Pvt) Ltd; purpose is answering the enquiry; retention 6 months via `purge_contact_submissions()`. The submitter's IP is stored for abuse limiting and is purged with the row. **Nothing schedules the purge** — `pg_cron` is not installed — so retention is defined and not yet enforced, alongside the deletion deadline and booking auto-completion.

**Known limitation.** `notified_at` records **Resend acceptance, not delivery**. A bounced message and a delivered one are indistinguishable in the table; both of the 2026-09-27 test rows looked identical and only one arrived. A Resend webhook writing bounce events back to the row is the fix.

**Not launch-ready, deliberately.** No privacy notice exists for the form to link to. It stays behind Cloudflare Access until the legal documents exist.

---

## D-046 — Publishing the talent's rate is revoked on all fronts

**Date:** 2026-09-27
**Status:** Settled — **partly unbuilt**

**Decision.** The talent's rate is **not published anywhere**: not to clients, not to other talent. Clients see the range; only admin sees the number. This widens D-014 from public surfaces to every surface, and **cancels** the "Starting Rate" work item (`6hJ8MmhmpM2Vv2M5`) rather than deferring it.

**Why it is forced, not chosen.** Ranges and published rates cannot coexist. Anyone could browse Range 6, read the rates on those profiles, and derive the boundaries exactly — no probing, no quote form, no account, because the data is public. That defeats D-039's hard rule rather than weakening it, and the three-checks limit would be protecting a secret already in the open.

**RLS cannot fix this.** RLS gates **rows**, not columns. A policy that lets a talent see other public profiles lets them see every granted column on those rows. There is no policy expressing "your own rate yes, everyone else's no" — it needs column-level grants or a different table. Revoking from `anon` alone fails too, since `authenticated` holds the same grant and every talent with an account is authenticated.

**Implementation, inside the D-038 rate model:**

1. ✅ **Done 2026-09-27.** `talent_rates` created with explicit revokes — never publicly selectable; owner, admin and `service_role` only. `CHECK (amount >= 1000)` per D-039.
2. ✅ **Done 2026-09-28** (migration `20260928031427`). `pricing_per_session` and `pricing_updated_at` dropped, along with `enforce_pricing_cooldown`, its trigger, and `profiles_talent_pricing_range`.
3. ⬜ **Not done.** The public talent query still returns no range, because the client-facing filter is unbuilt.

**Ordering was load-bearing.** The frontend write had to be removed and deployed **first** (Talent_Interface #96). With the column gone and the app still sending it, PostgREST rejects the upsert and profile saving breaks for every talent.

**Verified from outside the database.** The call that returned every talent's rate earlier the same night now returns `42703 column does not exist`:

```
curl '.../rest/v1/profiles_talent?select=stage_name,pricing_per_session' -H 'apikey: <publishable key>'
```

The leak is closed **by construction** — not by a grant someone has to remember not to re-add.

**Accepted consequences.** The public profile loses its price signal entirely until ranges ship — there is currently nothing else on the page to replace it. And admin needs a surface to read rates; Directus connects as `nocobase_admin` with `BYPASSRLS` (D-017) and is unaffected.

---

## D-047 — Submission for approval is attempted, not pre-validated

**Date:** 2026-09-27
**Status:** Settled, implemented

**Decision.** The "Submit for approval" action attempts the transition and surfaces whatever the database says. It does **not** check completeness client-side first.

**Why.** The completeness gate alone checks **sixteen fields across three tables** — `profiles_talent`, `talent_media` and `talent_identity` — plus the DOB gate and the rate gate. Replicating that in the frontend would duplicate logic that then drifts from the trigger, and the drift would be silent: the button would either refuse a profile the database would have accepted, or promise a submission the database then refuses.

The gates' messages are already written for a talent and name exactly what is missing — *"Your profile is not complete. Still needed: bio, cover photo, NIC back image."* Attempting and reporting is both simpler and always accurate.

**Accepted cost.** The gates fire as separate triggers, so a talent missing two different things sees one message, fixes it, resubmits, and sees the next. Clunky, but honest, and it never lies about what is required.

**The status must be read back after the update.** `enforce_talent_trust_fields` handles a disallowed transition by assigning `NEW.approval_status := OLD.approval_status` — it **coerces silently rather than raising**. The update returns 200 with no error and the profile stays in draft. Without reading the stored value back, a talent would see a success state while nothing had happened. See the Standing Correction.

---

## D-048 — Email delivery outcomes are recorded platform-wide

**Date:** 2026-09-28
**Status:** Settled, implemented

**Decision.** Every email the platform sends gets a row in `email_deliveries`, keyed by the Resend message ID, recording whether it was **delivered** — not merely accepted.

**Why.** A 2xx from Resend means accepted, not received. `send-email` logged the message ID and discarded it, so **no email the platform sent could be traced to an outcome** — not talent approvals, not rejections, not the deletion alert that starts the 14-day PDPA erasure clock.

**One table, not a column on the feature that noticed.** `contact_submissions` gains the truth by joining rather than duplicating it. A webhook reaching into one feature's table is coupling that the next feature to send mail would forget.

**`template` and `recipient` are nullable** because a webhook event can arrive before `send-email` has written its row. Both sides upsert; whichever lands first creates it. Do not add NOT NULL without solving that race.

**Open and click events are deliberately not stored.** Behavioural tracking of talent and clients, answering no operational question, and they would make this table considerably more sensitive. Unticked at the Resend end as well as ignored in code.

**`resend-webhook` is the only function in the project with `verify_jwt: false`**, because Resend has no JWT. That makes Svix signature verification the only thing between the endpoint and anyone wanting to write fake delivery data. **It must be deployed with `--no-verify-jwt` every time** — otherwise Resend's calls return 401, and Resend retries quietly, so the table simply stops updating with nothing surfacing anywhere.

The raw body is read before parsing (re-serialising changes the bytes and the signature never matches), and the timestamp is checked against a five-minute window (a valid signature is otherwise replayable forever).

**The `send-email` insert is best effort.** By that line the email is already accepted by Resend; failing the call over bookkeeping would make the caller retry and send twice — the exact harm the table exists to observe.

**PDPA.** `recipient` is personal data. Retention 12 months, longer than the contact form's six because a bounce log is operational and a quietly failing domain takes time to spot. `purge_email_deliveries()` expresses it and **nothing schedules it**.

**The query this buys:**

```sql
select recipient, template, sent_at, bounce_reason
from email_deliveries
where bounced_at is not null
   or (delivered_at is null and sent_at < now() - interval '15 minutes');
```

**Verified live:** a contact submission recorded `sent_at` and `delivered_at` 7.8 seconds apart with template and recipient set; an unsigned probe returns 401 rather than 500. **Untested:** the bounce branch.

---

## D-049 — Retention rules are scheduled, and their health is visible

**Date:** 2026-09-28
**Status:** Settled, implemented

**Decision.** `pg_cron` installed. `purge_contact_submissions()` runs at 19:30 UTC and `purge_email_deliveries()` at 19:45 — 01:00 and 01:15 in Colombo.

**What it does not close.** The PDPA deletion deadline, booking auto-completion and the abandoned-signup purge were missing **the function as well as the scheduler**. There is nothing to call. This makes them cheap to finish; it does not finish them.

**A third job, and the reason for it.** A pg_cron job that fails writes a row to `cron.job_run_details` and **notifies nobody** — the same shape as every silent failure this project has produced. Scheduling a purge that errors nightly and reports nowhere would have been one more. So `scheduled_job_health` exists to be looked at:

```sql
select * from public.scheduled_job_health;
```

`last_success` with a recent date means the schedule is alive; NULL means it never ran, which is the case that would otherwise be invisible. A third job prunes `cron.job_run_details`, because a run log nobody prunes becomes a run log nobody reads.

`cron.schedule` upserts by job name, so re-running the migration re-registers rather than duplicates. The `cron` schema is revoked from `anon` and `authenticated` explicitly.

**Untested until the first scheduled run.** Both functions execute cleanly by hand. Whether pg_cron fires them is unknown until the window passes.

---

## D-050 — Packages are fixed and platform-defined; 'other' removed

**Date:** 2026-09-28
**Status:** Settled, implemented

**Packages are defined by En4, not by talent.** Praveen's reasoning: talent-defined packages would not show a uniform offering to a client, so one performer's idea of a wedding set would sit beside another's.

**Seven packages, durations including breaks except spot performance:**

| Category | Package |
|---|---|
| Special events | 4.5 hours, including breaks |
| Weddings | 6 hours, including breaks |
| Concerts | 90 minutes |
| Clubs and pubs | 4.5 hours, including breaks |
| Dinner service | 4.5 hours, including breaks |
| Lunch service | 4.5 hours, including breaks |
| Spot performance | A short set of 3 songs, 15-20 minutes |

Only spot performance is a range; the rest are stored as min = max. The **maximum is advertised to the client**, and a shorter window is their informed choice and the talent's gain — settled after Praveen first considered hiding the duration in that case, then took it back as the cleaner position. Nothing validates the window against the package.

**'other' is removed from both `events_type` and `rate_category`.** Every remaining category has a defined package and a priceable rate; `other` had neither, and under D-039 no price range either — the one category with two carve-outs. A client whose event does not fit picks the nearest. v1 ships nine event types; v2 can add more on real feedback. Done while free: zero quotes, bookings and requests, and the three `other` rate rows all had NULL amounts.

**Append-only**, like `price_ranges`, because a package definition is what a past client was told they were buying. A set must cover every rate category. **Readable by anyone** — unlike rates and ranges, a package is exactly what the platform advertises.

**The enum surgery has a trap worth recording.** Postgres cannot drop an enum value, so both types are rename-create-alter-drop — and the obvious order fails, because **enum types appear in function signatures** and pin the old type alive. The three functions must be dropped with CASCADE before the types and recreated after, triggers included.

`rate_category_for_event_type` now **raises instead of returning NULL**. With no fallback category, an unmapped event type must fail at the mapping rather than surfacing as a NOT NULL violation three triggers later.

---

## D-051 — The fee is the category rate; duration prices nothing

**Date:** 2026-09-28
**Status:** Settled, implemented

**Decision.** `enforce_quote_writes` set `quoted_amount` to `round(req_rate * greatest(1, req_hours / 4), 2)`. With fixed packages that multiplier is wrong. The fee is what the talent charges for the category, full stop.

`req_hours` had exactly one reader — that multiplier — so it drops out entirely, and `quote_requests.duration_hours` returns to being only the client's event window, for the calendar, which is all a generated column off `starts_at`/`ends_at` was ever good for.

**Single insert, no draft state.** `compute_quote_pricing` freezes every money field on UPDATE and prices once at INSERT. A draft phase would require that freeze to know about status, and a hole in that branch means an issued quote is mutable — the money model broken. Considered and rejected.

**`preview_quote_pricing` instead.** A read-only RPC giving composition without a mutable phase. It returns **payout only** — performance fee, travel, equipment — and **no commission or taxes**, which is Praveen's decision: the talent sees what reaches them, not the client total.

*Accepted consequence:* the talent does not know what the client was shown. "You quoted 300,000" versus "I quoted 250,000" is a support conversation, not a bug, and is the price of keeping commission unsalient.

**It checks ownership, and that is load-bearing.** It returns the talent's rate; an unguarded version would let any authenticated user read any talent's rate, reopening D-046 through a new door.

**`calc_travel_fee` and `calc_equipment_fee` extracted** so the preview and the trigger share one implementation. Twenty lines of duplicated haversine is how a preview and a stored figure end up disagreeing. The travel constants now live in one place, so D-044's rate change touches one function.

**Quotes record `package_id`**, set on insert and frozen on update.

**`budget_min` and `budget_max` dropped.** No form ever wrote them; they were only displayed, in `VenueDashboard`, where they rendered as an empty range. The price range already expresses budget, and a budget shown to a talent invites quoting to it rather than to their rate.

**Verified:** wedding at 250,000, 2-hour window, Colombo to Kandy. Quoted 250,000 — the old multiplier would have given 125,000. Travel 84.22 km to 21,223.44, equipment 12,500, payout 283,723.44, commission 52,500 on the fee only, client total 347,697.46.

---

## D-052 — Controlled-disclosure views for browsing without rates

**Date:** 2026-09-28
**Status:** Settled, implemented

**The problem.** The client-facing picker must exclude talent who have no rate for the chosen event type — the backstop in `set_talent_rate_at_request` catches a hand-crafted insert, it is not the path a real client should walk. But `talent_rates` grants nothing to `anon` or `authenticated` beyond a talent's own rows (D-046), so the frontend had no way to know who offers weddings. **Without a deliberate disclosure the picker could not be built at all.**

**`talent_offered_event_types`** — talent_id, event_type, price_range_ordinal, for public talent only. Discloses **THAT** a performer takes wedding bookings and their range bucket. Never **WHAT** they charge, and never the range boundaries.

**`event_type_packages`** — the package per event type.

**Both expose event types rather than rate categories**, so the frontend never carries the event-type-to-rate-category mapping. A TypeScript copy of `rate_category_for_event_type` is a second truth free to drift — which is exactly how the quote form ended up offering `other` after the enum dropped it and missing `club_pub` and `spot_performance` after the enum gained them.

**Where each is shown.** The talent profile page lists the event types a performer takes. The artists listing shows the **fee category** per talent, but **only after the client applies the event-type filter** — a range means nothing without a category, since one talent sits in different ranges for different work. *Accepted consequence:* before the filter is applied there is no range to show, so unfiltered cards carry only name, photo and rating. The filter is what makes the listing informative rather than optional decoration.

**Never add an amount column to either view.**

---

# Open Decisions

These are not settled. Each links to its Todoist task. When one is resolved it moves up into the numbered register above and is deleted from this list.

## Blocking code

| Todoist | Question |
|---|---|
| `6hJ8Mp2rC7mPWqV5` | How are Client and Venue payment details handled? (PCI scope) |
| `6hPWCvCxJrmHq3HX` | Do anonymous hearts count, and how is heart-stuffing prevented? *Blocks the talent dashboard heart display.* |
| `6hPr9wRvcpwJ2W6X` | Two talent dashboards exist in two repos — which one is real? |
| `6h979FQpFWqHH8p5` | Is `completion_due_at` derived from event end time, or from a talent "mark as performed" action? These diverge when an event overruns. *Must be answered before the auto-completion window can be built.* |
| `6hJ8Mp3PGW3xR5mX` | What triggers release of a talent payout? The 24h auto-completion window it was assumed to hang off **does not exist** — see below. |
| — | **Must clients be 18+?** `check_client_dob_before_submission` is dead code (D-037), so there is currently **no age gate on clients at all**. If the answer is yes, the check belongs on quote-request creation. *No task exists.* |

## Not blocking, but open

| Todoist | Question |
|---|---|
| `6hPPgf579WrHHHqX` | KYC approve/reject for v1 — plain Directus dropdown, or extension-owned transition? |
| `6h979Hw5f23XxfCX` | The four open PDPA decisions (this task contains four sub-decisions) |
| `6hJ8MpCMjHxH2C5X` | SMS/OTP verification — which provider? |
| `6hQHqjPVpcvJXhG5` | Should `profiles_users.email` be self-writable? (no uniqueness constraint exists) |
| `6hQQJpMvjWC5rwj5` | Should admins be able to read other users' rows in `profiles_users`? |
| `6hPVPPp8FRggpqM5` | Should full-history secret scanning become scheduled? |
| `6hRh6v7xrcjmqV4X` | Uncollectable talent debt — block new bookings until settled? A talent who cancels and never returns never pays. |
| — | Is `bookings.deposit_amount` vestigial? v1 collects in full upfront. Decide whether to drop it. *No task exists for this.* |

## Awaiting someone else

| Owner | Question | Todoist |
|---|---|---|
| **Erich** | Does the talent penalty withhold the gateway fee? PayHere does not return its ~3.30% on a refund; if the talent is not charged for it, En4 absorbs it. | `6hRh6v83w4rG5Q2X` |
| **Ragu** | Is En4 turnover for tax purposes the full `client_total_amount`, or commission only? Disclosed agent vs principal — moves the threshold crossing point by roughly 13×. Monitor conservatively against `client_total` until answered. | — |
| **Ragu** | Do payouts to performers attract withholding tax, and does En4 have a deduction or reporting obligation as the paying party? Most performers are individuals without their own registrations. *Not currently tracked in any task.* | — |
