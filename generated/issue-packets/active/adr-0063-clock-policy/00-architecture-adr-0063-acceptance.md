---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0063", "wave-1"]
dependencies: ["packet:01", "packet:02", "packet:03"]
adrs: ["ADR-0063"]
accepts: ["ADR-0063"]
wave: 1
initiative: adr-0063-clock-policy
node: honeydrunk-architecture
---

# Accept ADR-0063 — flip status, add the date/time invariants, register the initiative

## Summary
Flip ADR-0063 (Grid-Wide Date, Time, and Clock Policy) from Proposed to Accepted: update the ADR header, add an ADR-0063 row to `adrs/README.md`, add the five new date/time invariants ADR-0063 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0063-clock-policy` initiative in `initiatives/active-initiatives.md`. ADR-0063 stays Proposed in the *file* until the analyzer rule (packet 03) and the Kernel DI helpers (packet 02) ship — but the **acceptance flip itself** is this packet's job, scheduled to land last in the initiative per the ADR's own follow-up checklist. This packet is the **acceptance-tracking packet**; its PR is opened first as a documentation-only acceptance trail and merged last, after packets 01–03 land. (See Constraints — this is the only packet in the initiative whose merge order does not match its number.)

## Context
ADR-0063 settles date/time handling broadly across the Grid: storage format (UTC at rest, D2), .NET type usage (`DateTimeOffset` / `DateOnly` / `TimeOnly` / `TimeSpan` — `DateTime` banned per D3), the wall-clock substrate (BCL `TimeProvider`, no HoneyDrunk-owned wrapper, D1 + D11), serialization (ISO 8601 with `Z`, D4), time-zone IDs (IANA-only, D5), cadence specification (5-field cron in UTC + ISO 8601 durations, D6), the test substrate (`FakeTimeProvider`, D7), audit timestamp authority (read-once at emit, D8), idempotency TTL semantics (D9), Gregorian-only scope cap (D10), and the migration path (D12). The ADR was authored 2026-05-23 in response to a convergence of forcing functions across in-flight packets (ADR-0042 idempotency, ADR-0030 audit, ADR-0019 Communications cadence, ADR-0027 Notify retries, ADR-0047 Tier-2b Testcontainers, ADR-0068 background-job substrate) all reaching for the same sub-decisions in slightly different ways.

ADR-0063 D1, D2, D3, and D11 are the decisions promoted into numbered invariants here. The others (D4, D5, D6, D7, D8, D9, D10, D12) remain ADR-only — they govern specific contracts and migration discipline but are not themselves Grid-wide enforcement rules.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0063-date-time-and-clock-policy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — add a new ADR-0063 row (one does not exist yet — the index currently runs through ADR-0079 in the file list but the README table stops earlier; insert in numerical position).
- `constitution/invariants.md` — add the five new date/time invariants (see Proposed Implementation for exact text), numbered **{N1}, {N2}, {N3}, {N4}, {N5}** under a new `## Date and Time Invariants` section. **{N1}–{N5}** is the contiguous block claimed for this ADR in `constitution/invariant-reservations.md` (range **69–73** at the time of authoring, after the ADR-0050 reservation at 67–68; resolve placeholders against the reservation row at execution time in case the block shifted upward per a first-merge-wins collision). The current verified maximum in `constitution/invariants.md` is **53**.
- `constitution/invariant-reservations.md` — confirm the ADR-0063 row exists in **Active Reservations** with the block of five (`{N1}`–`{N5}`); if a colliding ADR's packet 00 has already merged into a higher block since this packet was filed, shift this ADR's reservation upward to the next free block of five and update every `{N*}` placeholder reference in this packet and packet 03's Acceptance Criteria/HD0054 note accordingly.
- `initiatives/active-initiatives.md` — register the `adr-0063-clock-policy` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0063 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Add a new ADR-0063 row to `adrs/README.md`, in numerical order, with status Accepted and a one-line summary matching the existing row prose style.
3. Add five new invariants to `constitution/invariants.md`, numbered **{N1}, {N2}, {N3}, {N4}, {N5}** under a new `## Date and Time Invariants` section placed after `## Audit Invariants`. Resolve `{N1}`–`{N5}` against the block claimed in `constitution/invariant-reservations.md` for ADR-0063 (range **69–73** at the time of authoring; shift upward if the row has moved due to a parallel ADR's first-merge-wins claim). The text, taken verbatim-in-substance from ADR-0063's "New invariants" Consequences section:
   - **{N1} — Production code reads time via `TimeProvider`.** Direct calls to `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, or `DateTimeOffset.Now` are forbidden outside documented interop boundaries. Production composition wires `TimeProvider.System`; tests wire `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`. The opt-out attribute on the analyzer rule (per packet 03) permits documented interop cases. See ADR-0063 D1, D11.
   - **{N2} — All persisted and transmitted timestamps are UTC.** Database columns, Service Bus message envelopes and user-properties, audit records, cache TTL boundaries, idempotency expiry instants, configuration timestamps, and any JSON document persisted in the Grid carry UTC instants. Local-time storage and local-time on-wire formats are forbidden. Conversion to a user's or tenant's display timezone happens at the presentation boundary, never before. See ADR-0063 D2.
   - **{N3} — `DateTime` is banned in new code.** `DateTimeOffset` is the committed type for instants; `DateOnly` for calendar dates; `TimeOnly` for wall-clock times; `TimeSpan` for durations. `DateTime`'s `Kind` discipline has historically been the source of timezone bugs at .NET-ecosystem scale; `DateTimeOffset` carries the offset in the type. Exceptions for legacy interop are opt-in via the analyzer attribute. See ADR-0063 D3.
   - **{N4} — Tests that depend on time advance `FakeTimeProvider`.** `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider` is the committed test substrate. Tests advance time via `Advance(TimeSpan)` or `SetUtcNow(DateTimeOffset)`; they never `Thread.Sleep` (invariant 51), never `await Task.Delay()` as a "wait for time-driven event" pattern (a real wall-clock wait is not a fake), and never wall-clock-poll. **Enforcement note:** the `Thread.Sleep` clause is already analyzer-enforced by `HD0051` (invariant 51). The `Task.Delay`-as-wait and wall-clock-poll clauses are **reviewer-judgment-enforced** — no analyzer ships in this initiative for them. A future packet may add a paired analyzer (e.g., `HD00xx-TaskDelayAsWallClockWaitInTests`), but that is out of scope here. Add this enforcement note as a parenthetical at the end of the invariant text so reviewers know the line. See ADR-0063 D7.
   - **{N5} — Stored time-zone identifiers are IANA.** When a Node persists or transmits a time zone identifier (tenant default timezone, user preference, business-hours window timezone), the value is an IANA string (`"America/New_York"`, `"Europe/London"`). Windows time-zone IDs (`"Eastern Standard Time"`, `"GMT Standard Time"`) are forbidden in stored or transmitted data — they are a Windows-platform convention that does not survive cross-platform interop. Intake converts Windows TZ IDs to IANA at the API boundary. See ADR-0063 D5.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0063-date-time-and-clock-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (confirm/shift the ADR-0063 row; consume the reservation by moving it to **Reservation History** with the merge date)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0063 header reads `**Status:** Accepted`
- [ ] `adrs/README.md` has a new ADR-0063 row in numerical order with status Accepted
- [ ] `constitution/invariants.md` carries the five new date/time invariants (production code reads time via `TimeProvider`; all persisted and transmitted timestamps are UTC; `DateTime` is banned in new code; tests that depend on time advance `FakeTimeProvider`; stored time-zone identifiers are IANA), numbered **{N1}, {N2}, {N3}, {N4}, {N5}** (resolve from `constitution/invariant-reservations.md` — range **69–73** at authoring time) under a new `## Date and Time Invariants` section, each citing ADR-0063. The `FakeTimeProvider` invariant carries the parenthetical noting `Thread.Sleep` is `HD0051`-enforced and the `Task.Delay`-as-wait / wall-clock-poll clauses are reviewer-judgment-enforced
- [ ] `constitution/invariant-reservations.md` row for ADR-0063 is moved from **Active Reservations** to **Reservation History** with the merge date, and the resolved numbers replace the `{N1}`–`{N5}` placeholders inline
- [ ] `initiatives/active-initiatives.md` registers the `adr-0063-clock-policy` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog/docs sweep lands in packet 01)
- [ ] Packets 01, 02, and 03 are merged before this packet's PR is merged (the ADR's own "If Accepted" checklist requires the analyzer rule and the DI helpers to ship before the Status flip)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0063 D1 — `TimeProvider` is the Grid-wide clock abstraction.** Every Node reads "now" via `System.TimeProvider.GetUtcNow()`. Direct calls to `DateTimeOffset.UtcNow`, `DateTimeOffset.Now`, `DateTime.UtcNow`, and `DateTime.Now` are forbidden in production code. Documented interop and process-startup carve-outs only.

**ADR-0063 D2 — UTC at rest, everywhere.** All persisted timestamps are UTC. No Node stores a local-time timestamp; no Node stores a timezone offset alongside a local instant. Conversion to display timezone happens at the presentation boundary.

**ADR-0063 D3 — Type usage policy.** `DateTimeOffset` for instants; `DateOnly` for calendar dates; `TimeOnly` for wall-clock times; `TimeSpan` for durations. `DateTime` is banned in new code; exceptions are interop-only, opt-in via analyzer attribute.

**ADR-0063 D5 — Time zone IDs use IANA, never Windows.** Storage format pinned to IANA; intake converts Windows TZ IDs at the API boundary.

**ADR-0063 D7 — `FakeTimeProvider` is the test substrate.** `Microsoft.Extensions.TimeProvider.Testing` is the committed package; tests `Advance` or `SetUtcNow`, never sleep, never wall-clock-poll, never `Task.Delay` to wait for a time-driven event.

**ADR-0063 D11 — Where the contract lives.** Kernel ships DI registration helpers (`AddSystemTimeProvider`, `AddFakeTimeProvider`); no HoneyDrunk-owned `IGridClock` wrapper — the BCL's `TimeProvider` is the contract.

**ADR-0063 "If Accepted — Required Follow-Up Work" — Scope agent flips Status → Accepted after the analyzer rule lands and the DI helpers ship in Kernel.** This packet is the trailing flip, sequenced after packets 02 (Kernel helpers) and 03 (Standards analyzer).

## Constraints
- **Acceptance precedes flip.** ADR-0063 stays Proposed in the file until this packet's PR merges. Do not flip the ADR in any other packet.
- **This packet merges last in the initiative.** The ADR's own "If Accepted" checklist commits the scope agent to flipping Status only after the analyzer rule and the DI helpers ship — so packets 02 and 03 must merge first. Packet 01 (catalog/docs sweep) is also a hard prerequisite via `dependencies:` so packet 00 lands strictly after the other three. Sequence: file all four packets together; merge 02 → 03 → 01 → 00. The `dependencies: ["packet:01", "packet:02", "packet:03"]` array on this packet encodes the gate so the file-packets pipeline wires `blockedBy` edges and The Hive will surface packet 00 as blocked until the other three close. This is the safe form when packets are dispatched to parallel autonomous agents — without the edge, packet 00 could merge first and flip the ADR before the analyzer/helpers/docs ship, contradicting the ADR's own "If Accepted" checklist.
- **Invariant numbers — claimed via `constitution/invariant-reservations.md`.** This packet claims a contiguous block of five (`{N1}`–`{N5}`); at authoring time the reservation row sits at **69–73** (after the ADR-0050 reservation at 67–68). The current verified max accepted invariant in `constitution/invariants.md` is **53**. If a colliding ADR's packet 00 lands a higher block between filing and merge, edit the ADR-0063 reservation row in `invariant-reservations.md` to shift upward to the new "next free" block of five, then update every `{N1}`–`{N5}` placeholder reference in this packet (Scope, Proposed Implementation, Acceptance Criteria) and in packet 03 (Acceptance Criteria invariant-number references, the HD0054 stability note) to match. Do not reuse a claimed number; do not silently renumber existing invariants.
- **New section.** The five date/time invariants are a new cross-cutting topic; create a `## Date and Time Invariants` section after `## Audit Invariants` rather than appending to an unrelated section.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0063`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0063 to Accepted, add the five date/time invariants to `constitution/invariants.md`, add the ADR-0063 row to `adrs/README.md`, and register the date/time-policy initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0063 so the date/time policy is a live Grid rule and unblocks ADR-0068's cron-format pin and the in-flight cadence/idempotency/audit packets.
- Feature: ADR-0063 Date, Time, and Clock Policy rollout, Wave 1 closeout.
- ADRs: ADR-0063 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None expressed in `dependencies:`. Operator-enforced merge ordering: merge after packets 02 and 03 (and 01 for cleanliness) per the ADR's own "If Accepted" checklist.

**Constraints:**
- Acceptance precedes flip — ADR-0063 stays Proposed until this PR merges.
- Add the five new invariants as numbers **54, 55, 56, 57, 58** under a new `## Date and Time Invariants` section; do not renumber existing invariants. Current verified max is 53. If any invariant above 53 lands from outside this initiative before merge, shift this block upward, never reuse a claimed number.
- Merge this packet last in the initiative — packets 02 (Kernel helpers) and 03 (Standards analyzer) must land first per the ADR.

**Key Files:**
- `adrs/ADR-0063-date-time-and-clock-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
