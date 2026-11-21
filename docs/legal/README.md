# Legal documents

The public-facing legal documents for En4tainment (Client/Venue, on the
website) and En410 (Talent, in the app), kept here so they change in the same
place and the same PR as the behaviour they describe.

**Nothing in this folder is published.** See Status below.

## The files

| File | Audience | Surface |
|---|---|---|
| [`client-venue-privacy-policy.md`](./client-venue-privacy-policy.md) | Clients and Venues | www.en4tainment.com |
| [`client-venue-cookie-policy.md`](./client-venue-cookie-policy.md) | Clients and Venues | www.en4tainment.com |
| [`client-venue-terms.md`](./client-venue-terms.md) | Clients and Venues | www.en4tainment.com |
| [`talent-privacy-policy.md`](./talent-privacy-policy.md) | Talent | En410 (app.en4tainment.com) |
| [`talent-terms.md`](./talent-terms.md) | Talent | En410 (app.en4tainment.com) |

All five are the `PDPA_Revised` drafts, converted 2026-11-01. The five earlier
`.txt` originals are deliberately **not** here. Keeping both versions is how
the Talent calendar disclosure was silently dropped during the last revision —
two sources, one of them stale, and nothing to say which was current.

There is no Talent cookie policy. En410 is a PWA using local storage rather
than cookies; that is covered in the Talent privacy policy instead.

## Status

**Draft. Not published. Not lawyer-reviewed.**

Verified live 2026-10-19 and still true: there is no privacy policy in either
repo and the domain is not indexed. If a policy is hosted anywhere it is
outside these repos.

Lawyer review before publication was settled 2026-09-20. Professional
trilingual translation comes after the English is final — do not commission it
before then.

### Why publishing is blocked, and what it blocks in turn

Publishing is not just a compliance chore. It sits on the critical path for
two separate things:

- **Google OAuth verification** (`6hh4WRMmQchrv9g5`). The consent screen is
  stuck in Testing mode because no privacy policy URL exists. Testing caps the
  app at **100 users over its lifetime** — not concurrent — so every test
  sign-in permanently burns a slot. That in turn blocks the whole Google
  Calendar sync group (`6hh269xcJCQvh3H5` and its five subtasks).
- **PDPA compliance** generally, and the `privacy@` mailbox the policy must
  name (`6hcq3VPRxr59mvjX`), which needs a real owner because the 21-working-day
  response clock starts when mail lands there.

Tracked in `6hXQ3qjxFh98chW5`.

## How to change these files

The rules in [`../README.md`](../README.md) apply here in full. Two matter most:

**Rule 2 — register changes ride with the code PR that implements them.** If a
PR changes behaviour a document describes, the document changes in the same
PR. This is the entire reason these files are in the repo. A document that
describes last month's system is a liability, not a record.

**Rule 4 — a claim about live behaviour carries the date it was verified.**
Especially security claims. One of the inaccuracies below is a security claim
that outran reality by weeks.

Two rules specific to this folder:

**Never publish around a known inaccuracy.** Fix it or remove the claim.
A policy that describes a feature you do not have is worse than silence —
silence is an omission, a false claim is a misrepresentation.

**Keep the status banner at the top of each file** until that document is
published. It is the only thing standing between a draft and someone pasting
it onto a live page.

## Known inaccuracies

Found in the audit of 2026-10-19. Items marked **[VERIFIED LIVE]** were
queried against the database, not inferred. **These must be resolved before
publication.**

### 1. The calendar disclosure is in the wrong document

**[VERIFIED LIVE 2026-11-01]** `client-venue-privacy-policy.md` describes
Google Calendar access in four places. `talent-privacy-policy.md` mentions
calendar **zero** times.

Calendar code exists only in Talent_Interface. So the drafts disclose calendar
access to the people who do not have it, and stay silent for the people who
do. Exactly backwards — and this is the document a Google verification
reviewer will read.

The original `04_En410_App_Privacy_Policy.txt` had a correct section 2.6
naming the `calendar.events` scope. The revision dropped it.

The replacement text must be written against the **import-on-demand** design
(`6hpJg4VVQmqGpHgX`), not the old passive 7-day read: the app reads events
*when the Talent chooses to import*, so they can select which dates to mark
unavailable. Not a background read of their diary.

### 2. Review sub-ratings do not exist

**[VERIFIED LIVE]** `reviews_star` has a single `rating` column, plus
`comment` and `would_book_again`.

Both `talent-privacy-policy.md` (3.4) and `talent-terms.md` (9) describe
sub-ratings for stage presence, musical ability, professionalism, sound
quality and audience response.

**Praveen 2026-10-19: delete the claim. Do not build the feature.**

### 3. "RLS is enforced on every database table" was false when written

The claim appeared while `talent_favourites` carried `rh_select_public` —
SELECT to `public` USING `true`, exposing `user_id` and client `notes` to
anyone with the anon key.

**Fixed 2026-10-20** by migration `20261020175354`, so the claim is now true.
It is listed here as a standing warning rather than an open item: a security
claim was published-ready for weeks while being false. Re-verify every security
sentence in these documents against live state before publication, and date the
verification.

### 4. The payment processor is named wrong in all five documents

Every draft names **Payable.lk**. **Praveen 2026-10-19: it is PayHere.**

`client_payment_methods` stores a generic `gateway_token`, so the schema never
contradicted either name — nothing would have caught this but reading.

### 5. Sub-processors that are built and disclosed nowhere

- **Resend** — **[VERIFIED LIVE]** `email_deliveries.resend_id`; holds
  recipient addresses, bounce reasons, complaint status. **Name it as a
  sub-processor.**
- **RackNerd LLC** — hosts the internal admin system and the database backups.
  **Name it**, with this agreed wording and no more:
  > RackNerd LLC — virtual private server infrastructure hosting our internal
  > administrative system, used for identity-document review and platform
  > operations, and holding our database backups.

  **No product name, no version, no hostname, no IP, no file paths.** Do not
  name Directus — describe the function. **Location: USA**, which goes in the
  cross-border section.

  **STILL OPEN: are those backups encrypted at rest?** Do not write a security
  claim about them until that is confirmed. Item 3 above is already one
  security claim that outran reality.

Also undisclosed and **[VERIFIED LIVE]** present: `talent_profile_view`
(now admin-only as of 2026-11-01, so this is an internal-analytics disclosure
rather than third-party sharing — but Clients must still be told it is
collected), `subscriptions` (`plan_type`, `monthly_fee`,
`subscription_status` — a recurring billing model in no document), `towns` and
the location model, `talent_contact`, `sensitive_asset_access_log`,
`client_approvals`, `revenue_ledger`, `contact_submissions`.

### 6. Retention periods are vague where real figures exist

**[VERIFIED LIVE]** Four cron jobs are running:

| Job | Schedule | Effect |
|---|---|---|
| `expire-quote-requests` | hourly :05 | `open` → `expired`. **Does not delete** |
| `purge-contact-submissions` | daily 19:30 | deletes after **6 months** |
| `purge-email-deliveries` | daily 19:45 | deletes after **12 months** |
| `prune-cron-history` | daily 20:00 | 30 days |

The two purges are genuine retention mechanisms disclosed nowhere. Put the
concrete figures in the retention tables. A real number beats "a reasonable
period" both for compliance and for the reader.

### 7. Timing rules in the T&Cs do not match the system

**[VERIFIED LIVE]** `set_request_responds_by` enforces a **120-hour (5-day)**
minimum lead time before the event for authenticated non-admins, and
`responds_by = greatest(now+2h, least(created_at+48h, starts_at-72h))` — a
48-hour response window, where 120 = 48 + 72.

Both T&C documents say cancellations "must generally be made at least 48 hours
in advance". Check that against the cancellation-tier model before publishing.

### 8. Commission is described as a deduction, not a markup

The drafts describe Commission as a percentage "retained from the gross
booking amount". The money model settled since then is a two-sided
commission — see D-003 and D-008 in [`../decisions.md`](../decisions.md).
Reconcile the wording with what the system now charges.

## Still to add before publication

Beyond fixing the above:

- The full **Schedule V** disclosure list in the privacy policies: controller
  identity, purposes, lawful bases, withdrawal mechanism, recipients,
  cross-border basis, retention per s.9, Part II rights procedure, right to
  complain to the Authority, whether provision is a statutory or contractual
  requirement and the consequences of not providing, and automated
  decision-making.
- A **cookie consent mechanism**, not just a cookie policy. The document
  describes a banner that does not exist.
- The **self-billing authority** for En4 to raise invoices in the Talent's
  name.
- The **abandoned-signup 7-day purge** disclosure.
- Band-member **name and likeness consent** (a V2 feature, but the clause can
  land now).
- Placeholders throughout: `[REGISTERED ADDRESS]`, `[REGISTRATION NUMBER]`,
  `[CITY]`, `[DATE]`. None can be filled from the repo.
