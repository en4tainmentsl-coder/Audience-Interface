# En4tainment — project documentation

These files are the authoritative record of why this system is the way it is.
They live in the repo so they can be read, grepped and changed in the same
place as the code they govern.

| File | What it holds | Read it when |
|---|---|---|
| [`decisions.md`](./decisions.md) | The numbered decision register (D-001 onward), plus open decisions | Asking "why is it like this", or before proposing a change to settled behaviour |
| [`corrections.md`](./corrections.md) | Things widely assumed to exist that do not, each verified live on a dated check | Before designing anything that depends on an assumption you have not personally verified |

## Rules for changing these files

**1. Supersede, never overwrite.**

When a decision changes, mark the old entry `Superseded` with the date and the
reason, and write a new entry below it. Do not edit the old entry into
agreement with the new one.

The register's value is showing how the thinking changed. An entry that
argued its case well is *more* dangerous once it is wrong, not less — it reads
as someone who already considered and rejected the current position. Leaving
the old reasoning visible with a supersession notice is what stops that.

**2. Register changes ride with the code PR that implements them.**

If a PR changes behaviour that an entry describes, the entry changes in the
same PR. This is the main reason these files are in the repo rather than in a
document somewhere. Decisions and code drifting apart is how `D-003` spent a
month stating a commission rate the system no longer charged.

A documentation-only correction can of course go in its own PR.

**3. Every entry carries a date and who decided it.**

Praveen, Erich, Ragu, the taxation consultant, or a verified observation of
the live system. "We decided" with no attribution is not useful six months
later, when the question is whether the person who decided it had the
authority or the information to.

**4. A claim about live behaviour carries the date it was verified.**

Especially in `corrections.md`. "No such function" is a statement about a
moment in time. Without the date, a reader cannot tell whether it still holds.

## Status of the previous register

`EN4_DECISION_REGISTER.md`, previously maintained outside the repo and
re-uploaded to the Claude project on each change, is **retired as of
2026-10-31**. It is not archived-and-occasionally-updated. It is dead, and
these files replace it. Two live registers is worse than one stale one.
