# En4tainment — Standing Corrections

Things widely assumed to exist that **do not**, and things verified to behave
differently from how they were recorded. Each entry is dated to the day it was
verified live. **Check here before designing anything that depends on them.**

This is not a decision log — see [`decisions.md`](./decisions.md) for that.
An entry here is a fact about the system as it actually is.

---

## The 24h auto-completion window does not exist

**Verified 2026-09-08.** `calc_completion_due_at` — no such function. `bookings.completion_due_at` — no such column. `pg_cron` — not installed.

`bookings.auto_completed` exists and defaults to `false`, and **nothing in the database can ever set it true**. It is a column documenting an intention.

This matters because payout release timing was being reasoned about as though the window were in place, citing `calc_completion_due_at` by name. Build task: `6h979FQpFWqHH8p5`. Do not design a payout release against this until it exists.

## The Rs. 120 Mn tax threshold figure is wrong twice over

See D-001. It is not VAT, and it is not current. Superseded SSCL transitional figure from October 2022. Current: SSCL Rs. 9 Mn/quarter or Rs. 36 Mn/four quarters; VAT Rs. 15 Mn/period or Rs. 60 Mn/twelve months.

## The `nocobase_admin` audit-table revocations exist ONLY in production

**Applied 2026-08-29, deliberately not as a migration** — `nocobase_admin` does not exist in a fresh local database, so a migration referencing it would break `db reset`.

```sql
REVOKE INSERT, UPDATE, DELETE ON public.sensitive_asset_access_log FROM nocobase_admin;
REVOKE INSERT, UPDATE, DELETE ON public.audit_log FROM nocobase_admin;
REVOKE TRIGGER ON public.profiles_talent FROM nocobase_admin;
```

**A rebuild from migrations silently restores the hole.** Directus connects as `nocobase_admin` with `BYPASSRLS` and previously held `UPDATE`/`DELETE` on both audit tables — a KYC reviewer could have deleted the record of their own document access. `sensitive_asset_access_log` has RLS enabled but **not forced**, with a single `SELECT` policy, so append-only was an assertion rather than an enforced property.

Expected state after: `audit_log → SELECT`, `sensitive_asset_access_log → SELECT`, `profiles_talent → DELETE, INSERT, SELECT, UPDATE`. Re-apply these three statements after any rebuild and verify.

## `quotes_talent_matches_request` is sound only while the `talent_id` pin holds

Postgres does not truly support subqueries in `CHECK` constraints. The helper-function wrapper is a known workaround and is **not re-validated when the other table changes**.

It is safe only because `quote_requests.talent_id` is pinned immutable by `enforce_quote_request_writes()`. **If that pin is ever removed, this constraint becomes unsound** and quotes can drift from their request's talent without anything complaining.

## D-009's talent cancellation penalty cannot currently be applied

**Verified 2026-09-08.** The policy is settled and documented. None of its three enforcement mechanisms exist. Task: `6hRh6v7xrcjmqV4X`.

- **The −0.1 star has no home, and is currently impossible.** `talent_stats` carries `CHECK (rating_sum BETWEEN rating_count AND rating_count * 5)`, which an arbitrary −0.1 violates. Blocked behind the star rating rebuild.
- **No cancellation counter exists**, so the 1×/2×/4× escalation has nothing to escalate against and always evaluates to 1×. Every talent cancellation currently costs the same however many times they do it.
- **No debt ledger exists.** Nothing records that a talent owes anything.

Do not describe the escalation as live. `6hPqRpRPcFP5HQCX` (cancellation Edge Function) is blocked on the ledger.

## The four original project attachments are stale

`Supabase_Snippet_Schema_Column_Overview.csv` (truncated at 100 rows, has already caused a false "missing columns" conclusion on `profiles_venues`), `Edge_Funcs.txt` (predates the current eight functions), `En4tainment_RLS_Corrected.docx` and `CHECK_Constraints_Reference.docx` (both predate the 2026-08-29 fixes). Verify against the live database rather than these.

## Neither frontend could be logged into, for two days after being declared live

**Verified 2026-09-17.** `Audience-Interface` was recorded as live on 2026-09-15 — *"renders correctly, routes, and reaches Supabase."* All three were true. **Authentication was not in that list and had never been exercised.**

Two independent faults, either of which alone was fatal:

1. **Google OAuth was not enabled on the Supabase project at all.** Clicking sign-in returned `{"code":400,"error_code":"validation_failed","msg":"Unsupported provider: provider is not enabled"}`. It had never been enabled — the three `auth.users` rows are `provider = 'email'` and were created directly inside Supabase, never through an app flow.
2. **`Authentication → URL Configuration → Redirect URLs` contained exactly one entry: `http://localhost:3000`** — the hardcoded `PORT` in `Talent_Interface/server.ts`. Neither workers.dev hostname was registered. Scaffold default, never revisited.

Both fixed 2026-09-17 (see D-029). Recorded here because the lesson generalises: **"deployed" and "renders" are not "works."** A deployment checklist that stops at rendering will keep producing this. The parked manual-verification checklists (hearts, star display, `ProfileEditor` end-to-end) were blocked on an authenticated session the whole time, and nothing surfaced that — they were filed as blocked on *deployment*.

## `Talent_Interface`'s `.env.example` and its `vite.config.ts` `define` block are both inert

**Verified 2026-09-17.** Two separate mechanisms in that repo appear to supply Supabase config. **Neither works.** The app runs only because the third path does.

- `.env.example` documents `SUPABASE_URL` and `SUPABASE_ANON_KEY`, unprefixed. Vite only exposes `VITE_`-prefixed variables on `import.meta.env`, so those names cannot reach the client from a `.env` file.
- `vite.config.ts` has `define: { 'process.env.SUPABASE_URL': ..., 'process.env.SUPABASE_ANON_KEY': ... }`. **Nothing in `src/` reads `process.env`** — confirmed by grep across all `.ts`/`.tsx`. The block has never done anything.
- `src/supabase.ts` reads `import.meta.env.VITE_SUPABASE_URL || import.meta.env.SUPABASE_URL`. The second operand is dead for the reason above. **The `VITE_`-prefixed names are the only live path.**

Anyone reading `.env.example` or the `define` block will configure the wrong variable names, get a green build, and a white screen. The fail-fast throw in `src/supabase.ts` at least makes the failure loud rather than silent — but the documentation actively points the wrong way. Fix the file; do not trust it meanwhile.

## The D-023 guard audit verified the wrong thing

**Found 2026-09-18.** D-023 records trust-field guards on all four profile tables as compliant. That audit confirmed the guards **exist** and **pin the correct columns**. It did not test what they do when `get_my_role()` returns NULL — and five of them did nothing at all in that case. See D-030.

The correction is not that D-023 was wrong. The guards do exist and do pin the right columns. The correction is that "compliant" was recorded on the strength of reading the functions rather than exercising them, and the gap between those two is exactly where this defect lived for weeks.

**Severity, stated precisely because it was first reported wrongly:** the defect was **latent, not live**. Foreign keys on all three profile tables and the absence of an INSERT policy on `quotes` meant no caller could reach the NULL window. The initial report — in PR #113's description and the migration's own header comments — claimed a live exploitable bypass and included a worked exploit that cannot succeed. Both were corrected on 2026-09-18 in the PR thread and in a follow-up comment-only PR.

Two things generalise:

- **An audit that reads code verifies intent, not behaviour.** This is the same lesson as the generated-columns incident, where `compute_quote_pricing` deployed cleanly, read back correctly, and wrote nothing. Add a behavioural check before recording anything as compliant.
- **Masks that are not written down cannot be relied on.** The FKs that made this unexploitable are real, but nothing recorded them as a security control. Anyone dropping one for an unrelated reason would have opened the hole without knowing it existed.

## The profile form and the database disagreed about a valid rate, and only the database was right

**Found live 2026-09-21.** `ProfileEditor` validated the starting rate as `z.number().min(0)` and loaded a missing rate as `Number(pricing_per_session ?? 0)`. So a profile with no rate loaded as **0**, passed the form's own validation, and was refused by the database:

```
23514  new row for relation "profiles_talent" violates check constraint
       "profiles_talent_pricing_range"
```

The constraint has always read `pricing_per_session IS NULL OR (> 0 AND <= 10000000)`. The form permitted a value the schema had never allowed, and the two only met at save time.

Fixed the same day: the rate is required, whole rupees, 1 to 10,000,000, formatted with separators, and blank rather than 0 when unset.

**Two things generalise.**

- **Form validation that doesn't mirror the constraint is not validation.** It moves the failure from the field to the save, where it is far more expensive to understand. Where a CHECK constraint exists, the form should carry the same bounds and say so in its message. Worth auditing the other numeric fields against their constraints.
- **The field had no error display at all.** Every other field in that section showed `errors.<field>.message`; this one didn't, so even a caught problem would have had nowhere to appear. A field with validation and no error element is a silent field.

**On the near-miss:** the failure was found only because the database was checked after a test that *looked* successful on screen. The app does surface these errors — it raises an alert with the database's message — but during testing it read as expected noise. Checking the row is what made it undeniable.

## Two settled decisions were recorded and never implemented

**Found 2026-09-27.** The register records that the equipment fee was removed entirely in September, and that travel moved to a flat Rs 150/km. **Neither happened.** `compute_quote_pricing` still computes an equipment fee, `equipment_provided_by` still exists with default `'talent'`, and the travel constant is still `120 × 1.05`.

Both were discussed as live behaviour in a working session before anyone noticed the register said otherwise. That is the cost: the register is what people reason from when they are not reading SQL, and it was wrong in two places.

This is the migration-ledger drift one layer up. There, the repo and the database disagreed. Here, the **decisions** and the database disagree, which is worse.

**What generalises: pay attention to anything recorded as removed.** Removals are the easiest thing to record and never do, because nothing breaks when you skip them. An addition that is skipped fails loudly the first time something needs it; a removal that is skipped just sits there, working, contradicting the record.

## Approval was two uncoupled fields, and nothing anywhere caught it

**Found 2026-09-26.** Publishing a talent requires `is_public` **and** `approval_status = 'approved'`. But `is_public` is set by a trigger on `profile_status`, not by `approval_status`. So the two halves of "approved" lived in different columns with nothing linking them — no constraint, no trigger, no check — and the admin UI presented both as ordinary dropdowns.

An admin setting one and not the other produced a talent who was approved but unfindable, or active but unapproved. Neither state errors, neither is visible in the UI, and both look correct from the record being edited.

**What generalises: when a single concept is spread across more than one column, something must own setting them together.** A UI that exposes each independently is not neutral — it is an invitation to produce states the system considers impossible.

## Trust guards do not run for admins or `service_role`

**Found 2026-09-26.** Every trust guard is gated on `auth.uid() IS NOT NULL`. Under `service_role` that is NULL, so **the entire guard is skipped**. A SECURITY DEFINER function that relied on the guard to force `is_public = false` silently did not get it, and the profile would have stayed publicly listed after a deletion request.

The same gap caused a second bug the same day: clearing a rejection reason was implemented inside the guard, so an admin re-opening a review hit a constraint violation instead. The fix was to move it to a trigger with no role condition.

**What generalises: a guard that exempts privileged callers is not a guard for privileged code paths.** Any function running as `service_role` must set every trust field explicitly, and anything that must hold for *everyone* belongs in a trigger with no role condition at all.

## Scaffolding written against a guessed schema survives indefinitely

**Found 2026-09-27.** `BookingManager.tsx` in En410 queries `from('quotations')` — a table that has never existed — filters bookings on `.eq('talent_id', user.id)` when `talent_id` is `profiles_talent.id`, and updates a `status` column actually named `booking_status`. Its own comments say *"Assuming we update the booking for now"* and *"Or whatever status represents quoted"*.

It has never worked. It renders, it errors quietly, and it looks like a feature. `Dashboard.tsx` had the identical `talent_id` bug and was found and fixed in an earlier session; nobody thought to check the sibling component.

**Two things generalise.**

- **A component written before the schema settled is a guess, and guesses do not announce themselves.** Anything carrying "assuming" in a comment should be treated as unverified until exercised against the real database.
- **When a bug class is found, sweep for it.** The `talent_id`-versus-`user.id` confusion was understood, documented and fixed in one file while an identical instance sat two files away for weeks.


## The migration ledger and the repo disagreed about 22 of 55 files

**Found and fixed 2026-09-27.** `supabase db push` would have replayed **22 migrations** as unapplied: 20 that existed under two identities, plus 2 with no ledger row under any version.

The cause is mechanical. A migration applied through the Supabase MCP is recorded under a timestamp **the MCP generates**; the file was then committed with a timestamp chosen by hand. Same migration, two names.

**The concrete risk it carried:** `compute_quote_pricing.sql` is a `CREATE OR REPLACE FUNCTION` still holding `c_rate_per_km := 120.00` and `c_uplift := 1.05`. A replay after the D-043 change to Rs 150/km would have **reverted the rate silently** — no error, no failed migration, just the old number back.

Reconciled in PR #130: 20 `git mv` renames at 100% similarity, and the two orphans (`20260921210200`, `20260921210300`) recorded in the ledger after verifying both were already applied live. Repo and ledger now agree on all 55 versions in both directions.

**What generalises.** Everything from 20260926 onward already matched, so the drift was historical and stopped once the apply-then-name discipline started. See the D-015 amendment for the rule. The deeper point: **this was invisible until someone diffed two lists.** Nothing failed, nothing warned, and the damage would only have appeared as a quietly reverted function months later.

## An address printed on the public site had never been able to receive mail

**Found 2026-09-27.** `info@en4tainment.com` is displayed on the public Contact page. It had **no Cloudflare Email Routing rule**, so every message sent to it bounced with "recipient not found". Anyone who read that page and emailed directly got nothing through — and no bounce reaches the site owner, only the sender.

It surfaced only because the contact form was wired up and a test message was traced end to end. The row stored, `send-email` ran, Resend accepted, `notified_at` was set, `notify_error` was null — **every signal the platform had said success** — and the mail bounced. Resend then suppressed the address, so the next attempt would have failed differently and looked like the fix had not worked.

**Two things generalise.**

- **Sending and receiving are unrelated systems.** Resend sends from `mail.en4tainment.com` (SPF and DKIM verified); delivery to `info@en4tainment.com` is Cloudflare Email Routing, configured separately and never tested. A verified sending domain says nothing about whether your own addresses work.
- **Check the destination address of every alert path.** `support@` is the global `REPLY_TO` on every email the platform sends, including talent rejections that say "reply to this email", and `alerts@` receives the deletion alert that starts the 14-day PDPA erasure clock. Both existed; had they not, the failure would have been silent and aimed at the people least able to report it.

## Every talent's rate is currently readable by anyone holding the publishable key

**Verified live 2026-09-27. Still open** until D-046 ships.

`anon` holds `SELECT` on `profiles_talent` including `pricing_per_session`, and the `talent_select_public` policy grants `SELECT` to `public`. The publishable key ships in the frontend bundle by design, so:

```
curl 'https://<project>.supabase.co/rest/v1/profiles_talent?select=stage_name,pricing_per_session' \
  -H 'apikey: <publishable key>'
```

returns every listed talent's rate. No account, no app, no probing.

**The UI is not where this lives.** `Audience-Interface` never displays the rate at all — it appears only in generated types. Hiding it in the frontend would have changed nothing, and D-014 was written as though the display were the exposure.

This closes when rates move to `talent_rates` and `pricing_per_session` is dropped (D-046). Until then, treat the rates as public.


## No talent could ever be submitted for approval

**Found 2026-09-27. Fixed the same day.**

`pending_approval` appeared **nowhere in either repository** except one read — `ProfileEditor` rendering a "your profile is under review" state that could not be reached. No component, no Edge Function and no database trigger ever set it.

Everything downstream was built and correct: `enforce_talent_trust_fields` explicitly permits `draft` or `rejected` → `pending_approval`; four gates guard that transition (completeness, talent DOB, client DOB, and from 2026-09-27 at least one category rate); `review_talent` exists to approve or reject and sends the emails. **All of it hung off a transition nothing could trigger.**

The three fixture profiles' statuses had been set by hand, which is why nobody noticed. It surfaced only when wiring the rates UI raised the question of where a talent submits.

**What generalises.** Every gate, guard and trigger on that path passed review and tested correctly in isolation. The missing piece was not a broken component but an **absent** one, and nothing in the system can report the absence of a caller. Ask of any guard: *what invokes the thing this guards, and has anyone followed that path end to end?*

## A trust guard that coerces silently rather than raising

**Found 2026-09-27. Live, by design, and worth knowing about.**

`enforce_talent_trust_fields` — and its client and venue counterparts — handle a disallowed change by **assigning the old value back**:

```sql
NEW.approval_status := OLD.approval_status;
```

rather than raising. The write returns **HTTP 200 with no error**, and nothing changed.

This is the correct design for a trust guard: a client attempting to set their own `approval_status` should be ignored, not handed a diagnostic that teaches them which fields are protected. But it means **a successful response from any write touching a trust-guarded field is not evidence the write took effect.**

Any legitimate caller changing a trust-guarded field must **read the value back and check it**, not test for an error. The submit-for-approval action (D-047) does this. Anything else touching those fields should be audited for the same assumption.


## A cooldown that could be rewound by an update it did not inspect

**Found and fixed 2026-09-28, before it reached anyone.**

`enforce_talent_rate_cooldown` stamps `rate_updated_at := now()` **only inside the `IF NEW.amount IS DISTINCT FROM OLD.amount` branch**. A talent holds UPDATE on their own `talent_rates` rows with no column-level restriction. So:

1. `UPDATE talent_rates SET rate_updated_at = '2020-01-01'` with `amount` unchanged — the branch never runs, nothing overwrites the value, and what the talent sent is stored.
2. Change the amount. The cooldown reads `OLD.rate_updated_at`, sees 2020, and passes.

The 30-day per-category cooldown was bypassable in two requests.

Fixed by pinning `rate_updated_at` in `enforce_talent_rate_immutable` alongside `id`, `talent_id`, `category` and `created_at`. That trigger is named `a0_` and sorts before the cooldown's `a_`, so the cooldown can still overwrite with `now()` when an amount genuinely changes.

**What generalises, and it is the same lesson twice.** The eight-permanent-rows design closed this exact bypass arriving through **row deletion** — opt out, opt back in, clock reset. It then reappeared through a **column** nobody had thought to protect. A guard that writes a value only under a condition leaves that value writable whenever the condition is false; if the value is what the guard later trusts, the guard can be fed its own input.

Ask of any trigger: *what does this read on the next call that it did not write on this one?*


## A migration header that claimed a verification it never performed

**2026-09-28.** `20260928031427` carries a header reading "VERIFIED AFTER APPLYING" followed by a list of checks. Every one of those checks concerned the **columns being dropped**. None touched the function the same migration had rewritten — and that rewrite had broken it.

The header is accurate about what it checked and silent about what it did not, which reads, to anyone scanning it, as though the whole migration was proven.

**What generalises.** A verification note is worth exactly what it checked. When a migration does two things, verifying one of them and writing "verified" is worse than writing nothing, because it converts an unknown into a false assurance. Name the thing verified, not the migration.

## Rewriting a function to change two lines

**2026-09-28. Fixed by `20260928091608`, but it was live for roughly an hour.**

`20260928031427` needed **two lines removed** from `enforce_talent_trust_fields`. Instead it replaced the whole body, written from assumption after grepping only the two matching lines. The original was never read in full.

The rewrite **invented** four columns that do not exist — `total_bookings`, `is_featured`, `approved_at`, `approved_by` — which broke every non-admin update to a talent profile. **That breakage is the only reason any of it was noticed.**

Silently, it also:

- dropped the guards on `is_public`, `profile_status`, `rating`, `reviewed_at`, `reviewed_by` and `deletion_requested_at` — a talent could have set their own `is_public`, `profile_status` and `rating`
- removed the deletion-request path, including the rule that a profile with `deletion_requested_at` set cannot re-enter the review queue
- reverted PR #129's resubmission-after-rejection fix
- changed the outer condition so `service_role` writes were no longer passed through

Had the invented column names happened to be real, all of that would have shipped in silence.

**What generalises.** Rewriting a function to change two lines means re-deriving every line you did not intend to change, from memory, without the original in front of you. Read the whole definition first, or edit surgically. The blast radius of a rewrite is the whole function, not the part you meant to touch.

## A view does not grant EXECUTE

**2026-09-28. Caught before merge, by one test.**

`20260928181002` computed a price range inside a view by calling `price_range_for_amount`, on the assumption that a view runs everything with its owner's privileges.

That holds for **table** permissions. **Function EXECUTE is checked against the calling role**, even inside a view. That function is revoked from `anon` and `authenticated`, so every anonymous read of the view failed with `permission denied for function price_range_for_amount`.

It applied cleanly and passed every check that did not read the view **as anon**. A `SET ROLE anon` test caught it; without that it would have merged and failed only in a browser, on the artists listing.

**The fix mattered as much as the bug.** Granting `anon` EXECUTE would have cleared the error and handed out a **boundary-probing oracle** — call it repeatedly and binary-search the range edges, which is precisely what keeping `price_ranges` unreadable prevents and what D-039's three-checks limit assumes is impossible. The lookup was inlined as a correlated subquery instead: no function call, no EXECUTE needed, boundaries still unreachable.

**What generalises.** Test a permission-sensitive object **as the role that will use it**, not as the role that built it. "The view exists and returns rows" is not the same claim as "an anonymous visitor can read it."
