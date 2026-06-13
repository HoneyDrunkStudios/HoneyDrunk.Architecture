---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0063", "wave-1"]
dependencies: []
adrs: ["ADR-0063", "ADR-0047", "ADR-0057", "ADR-0068"]
wave: 1
initiative: adr-0063-clock-policy
node: honeydrunk-architecture
---

# Record the date/time policy in Kernel docs, tech-stack, and cross-reference ADRs 0047/0057/0068

## Summary
Land the ADR-0063 documentation sweep across the Architecture repo: a new "Date and Time" section in `repos/HoneyDrunk.Kernel/overview.md`, a date/time-policy ownership note in `repos/HoneyDrunk.Kernel/boundaries.md`, a new "Date and Time" row in `infrastructure/reference/tech-stack.md` referencing `TimeProvider` (production) and `Microsoft.Extensions.TimeProvider.Testing` (tests), a cross-reference in ADR-0047 pointing the testing-pattern doc and test-project template at `FakeTimeProvider`, a cross-reference in ADR-0057's serialization detail pinning ISO 8601 with `Z` per ADR-0063 D4, and a cross-reference in ADR-0068 confirming the cron-string format pin (5-field UTC) is sourced from ADR-0063 D6. No catalog (`catalogs/*.json`) entry — ADR-0063 commits no new HoneyDrunk-owned contract; it pins to the BCL's `TimeProvider`.

## Context
ADR-0063 "Required Follow-Up Work" lists three Architecture-repo doc updates and three cross-reference touches:

1. `repos/HoneyDrunk.Kernel/overview.md` — add a "Date and Time" section pointing at ADR-0063.
2. `repos/HoneyDrunk.Kernel/boundaries.md` — record the date/time policy ownership. Kernel is the home for the DI registration helpers, but no Kernel-owned interface wraps `TimeProvider` (it is a BCL type — see ADR-0063 D11).
3. `infrastructure/reference/tech-stack.md` — add a "Date and Time" row referencing `TimeProvider` (production) and `Microsoft.Extensions.TimeProvider.Testing` (tests).
4. ADR-0047 cascade — reference `FakeTimeProvider` as the committed test substrate for time-dependent code in the testing-pattern doc and the test-project templates. ADR-0047 D10 owns the `Directory.Build.props` for the unit-test stack; this packet adds a "Time-dependent tests" sub-bullet to the testing-pattern guidance, and notes the template addition for the ADR-0047 packet that ships `Directory.Build.props`.
5. ADR-0057 serialization section — the D-series covering envelope/payload shape should pin ISO 8601 with `Z` for instants, `YYYY-MM-DD` for dates, and ISO 8601 duration strings for spans, consistent with ADR-0063 D4. Cross-reference is one-way: ADR-0063 pins the format; ADR-0057 governs the API surface.
6. ADR-0068 — pairs with ADR-0063 and pins the cron-string format. ADR-0068 D5 references ADR-0063 D6 for the cron format; this packet adds the one-line cross-reference back to ADR-0063 D6 in ADR-0068's serialization-related section if not already present, and confirms the matching cross-reference exists from ADR-0063 D6 → ADR-0068.

ADR-0063 also says, under Catalog obligations: "`catalogs/nodes.json` — no entry to add. This ADR adds no Node. `catalogs/contracts.json` — no entry to add. This ADR commits no HoneyDrunk-owned contract (it commits to using the BCL's `TimeProvider`)." So this packet is deliberately **not** a catalog-json packet — it does not edit `catalogs/contracts.json`, `catalogs/relationships.json`, or `catalogs/nodes.json`. The DI helpers `AddSystemTimeProvider`/`AddFakeTimeProvider` ship in `HoneyDrunk.Kernel` (packet 02); they are *extension methods*, not new contracts in the catalog sense — the catalog already lists `HoneyDrunk.Kernel`'s contract surface; helper methods are not entries.

This is a docs-only packet. No code, no workflow, no .NET project.

## Scope
- `repos/HoneyDrunk.Kernel/overview.md` — add a "Date and Time" section.
- `repos/HoneyDrunk.Kernel/boundaries.md` — add a "Date and Time" entry under both "What Kernel Owns" (DI registration helpers for `TimeProvider`) and "What Kernel Does NOT Own" (a `TimeProvider` wrapper — `TimeProvider` is a BCL type and Kernel does not wrap it; the existing "BCL wrappers" note already covers this — add a one-line `TimeProvider` clarification).
- `infrastructure/reference/tech-stack.md` — add a "Date and Time" section listing `TimeProvider` (production) and `Microsoft.Extensions.TimeProvider.Testing` (tests).
- `adrs/ADR-0047-testing-patterns-and-tooling.md` — add a one-paragraph cross-reference to ADR-0063 in the D10 section (Naming and structure conventions / the section that owns `Directory.Build.props` defaults), noting `FakeTimeProvider` is the committed test substrate for time-dependent code.
- `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md` — add the ISO 8601 with `Z` serialization detail to the appropriate D-section (the envelope/payload shape series), cross-referencing ADR-0063 D4 as the authoritative pin.
- `adrs/ADR-0068-background-job-and-recurring-work-substrate.md` — confirm the existing ADR-0068 → ADR-0063 cross-reference for the cron-format pin reads correctly; add the back-reference if missing. ADR-0068 is Proposed, paired with ADR-0063.
- **NOT edited:** `catalogs/contracts.json`, `catalogs/relationships.json`, `catalogs/nodes.json` (per ADR-0063 Catalog obligations — no entry to add).

## Proposed Implementation
1. **`repos/HoneyDrunk.Kernel/overview.md`** — append a new section after "Identity Primitives":
   ```markdown
   ## Date and Time

   The Grid reads "now" via the BCL `System.TimeProvider` — no `IGridClock` wrapper. Kernel ships two DI registration helpers — `AddSystemTimeProvider()` (production, wires `TimeProvider.System`) and `AddFakeTimeProvider()` (tests, wires `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`). All persisted and transmitted timestamps are UTC; ISO 8601 with `Z` is the on-wire format. See ADR-0063.
   ```
2. **`repos/HoneyDrunk.Kernel/boundaries.md`** — under "What Kernel Owns" add the bullet:
   ```markdown
   - DI registration helpers for the BCL `TimeProvider` (`AddSystemTimeProvider`, `AddFakeTimeProvider`) — Kernel does not wrap `TimeProvider` itself
   ```
   And under "What Kernel Does NOT Own", extend the existing "BCL wrappers" note:
   ```markdown
   - **BCL wrappers** — No `IClock`, `IIdGenerator`, `ILogSink`, no `IGridClock` wrapping `TimeProvider`. Use the BCL directly; Kernel ships only the DI registration helpers.
   ```
3. **`infrastructure/reference/tech-stack.md`** — add a new section between "Resilience" and "Identity and Auth":
   ```markdown
   ## Date and Time

   | Technology | Version | Used By |
   |-----------|---------|---------|
   | `System.TimeProvider` (BCL) | .NET 10.0 | All production code reads "now" via `TimeProvider.GetUtcNow()` |
   | Microsoft.Extensions.TimeProvider.Testing | 9.x | Test projects (`FakeTimeProvider`) |

   The Grid uses the BCL `TimeProvider` directly — no HoneyDrunk-owned clock interface. DI registration helpers ship from `HoneyDrunk.Kernel`. See ADR-0063.
   ```
   Update the **Last Updated** date to the merge date.
4. **`adrs/ADR-0047-testing-patterns-and-tooling.md`** — add to D10 (Naming and structure conventions, which already owns the `Directory.Build.props` unit-test stack):
   ```markdown
   **Time-dependent tests.** Tests that depend on time use `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`, added to the test-project template via `Directory.Build.props`. Tests advance time via `Advance(TimeSpan)` or `SetUtcNow(DateTimeOffset)`; `Thread.Sleep` (invariant 51) and `Task.Delay`-as-wall-clock-wait (invariant 57) are forbidden. See ADR-0063 D7.
   ```
   The actual addition of the `PackageReference` to the test-project `Directory.Build.props` is owned by the ADR-0047 packet that ships that template (in the `adr-0047-testing-patterns-and-tooling` initiative). This cross-reference paragraph commits the contract; the template change ships in that initiative.
5. **`adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md`** — add an "ISO 8601 with `Z`" paragraph to the appropriate D-section (envelope/payload shape — locate the section that already discusses RFC 7807 Problem Details, cursor pagination, and `Idempotency-Key` headers; add the timestamp serialization paragraph next to it):
   ```markdown
   **Date/time serialization.** Instants serialize as ISO 8601 with the `Z` suffix (`"2026-05-23T14:30:00Z"`); calendar dates as `"YYYY-MM-DD"`; wall-clock times as `"HH:MM:SS"`; durations as ISO 8601 duration strings (`"PT5M"`, `"PT1H30M"`, `"P1D"`). The format is pinned by ADR-0063 D4; this ADR governs the API surface that carries it.
   ```
6. **`adrs/ADR-0068-background-job-and-recurring-work-substrate.md`** — ADR-0068 is Proposed and already cites ADR-0063 D6 for the cron-format pin per ADR-0063's own Context section ("ADR-0068 D5 references this ADR's D6"). Read ADR-0068's current text. If the back-reference from ADR-0068 → ADR-0063 D6 is in place, no edit is needed — confirm it reads correctly. If it's missing, add a one-line cross-reference in ADR-0068's D5 (or equivalent serialization decision): "The cron-string format (5-field, UTC) is pinned by ADR-0063 D6." Do **not** flip ADR-0068's Status — it remains Proposed; this packet only checks/sharpens the cross-reference. If ADR-0068's existing text contradicts ADR-0063 D6 (e.g. specifies 6-field cron), flag it in the PR description and do not silently edit — that warrants an ADR-0068 amendment, not a docs sweep edit.

## Affected Files
- `repos/HoneyDrunk.Kernel/overview.md`
- `repos/HoneyDrunk.Kernel/boundaries.md`
- `infrastructure/reference/tech-stack.md`
- `adrs/ADR-0047-testing-patterns-and-tooling.md`
- `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md`
- `adrs/ADR-0068-background-job-and-recurring-work-substrate.md` (read-and-confirm; edit only if the back-reference is missing or contradicts)

## NuGet Dependencies
None. This packet touches only Markdown documentation; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No `catalogs/*.json` change — ADR-0063 explicitly states no catalog entry is needed (D11: `TimeProvider` is a BCL primitive; Kernel does not wrap it). Helper methods are not catalog entries.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Kernel/overview.md` has a new "Date and Time" section pointing at ADR-0063 and naming the two DI helpers
- [ ] `repos/HoneyDrunk.Kernel/boundaries.md` records the date/time policy ownership: DI helpers under "What Kernel Owns", and the `TimeProvider`-no-wrapper note in the existing BCL-wrappers entry
- [ ] `infrastructure/reference/tech-stack.md` has a new "Date and Time" section/table referencing `System.TimeProvider` (production) and `Microsoft.Extensions.TimeProvider.Testing` (tests), with the Last Updated date refreshed
- [ ] `adrs/ADR-0047-testing-patterns-and-tooling.md` D10 references `FakeTimeProvider` as the test substrate for time-dependent code, citing ADR-0063 D7
- [ ] `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md` carries the ISO 8601 with `Z` serialization detail, citing ADR-0063 D4 as the authoritative pin
- [ ] `adrs/ADR-0068-background-job-and-recurring-work-substrate.md` references ADR-0063 D6 for the cron-format pin (existing or added); any contradiction is flagged in the PR description, not silently edited
- [ ] No `catalogs/contracts.json`, `catalogs/relationships.json`, or `catalogs/nodes.json` edits — ADR-0063 commits no HoneyDrunk-owned contract
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0063 D1 — `TimeProvider` is the Grid-wide clock abstraction.** No HoneyDrunk-owned wrapper; the BCL is the contract. Production wires `TimeProvider.System`; tests wire `FakeTimeProvider`.

**ADR-0063 D4 — ISO 8601 with `Z` for serialization.** Instants `"2026-05-23T14:30:00Z"`; dates `"YYYY-MM-DD"`; times `"HH:MM:SS"`; durations `"PT5M"` / `"PT1H30M"` / `"P1DT2H"`. Pinned for Web.Rest payloads, Service Bus envelopes, audit records, App Configuration values, and any persisted JSON.

**ADR-0063 D6 — Cadence specification.** 5-field cron strings in UTC for recurring; ISO 8601 durations for delays. 6-field-with-seconds explicitly rejected. ADR-0068 D5 references this decision.

**ADR-0063 D7 — `FakeTimeProvider` is the test substrate.** Tests advance time via `Advance(TimeSpan)` or `SetUtcNow(DateTimeOffset)`; never sleep, never wall-clock-poll, never `Task.Delay` to wait for a time-driven event. Added to test projects via `Directory.Build.props` per ADR-0047 D10.

**ADR-0063 D11 — Where the contract lives — Kernel helpers, no Kernel interface.** Kernel ships DI registration helpers (`AddSystemTimeProvider`, `AddFakeTimeProvider`); Kernel does NOT publish `IGridClock` or any HoneyDrunk-owned wrapper around `TimeProvider`. The BCL is the contract.

**ADR-0063 Catalog obligations.** "`catalogs/nodes.json` — no entry to add. This ADR adds no Node. `catalogs/contracts.json` — no entry to add. This ADR commits no HoneyDrunk-owned contract (it commits to using the BCL's `TimeProvider`)."

## Constraints
- **No catalog JSON edits.** ADR-0063 commits no HoneyDrunk-owned contract; `catalogs/*.json` stays untouched. DI helper methods are not catalog entries.
- **Cross-references are one-way.** ADR-0063 is the authority on the format / substrate; the touched ADRs (0047, 0057, 0068) reference back to ADR-0063, not the reverse. Do not weaken ADR-0063's decisions by introducing equivalent-language pins in the other ADRs.
- **Do not flip ADR-0068's Status.** ADR-0068 remains Proposed; this packet only sharpens or confirms an existing cross-reference. If ADR-0068 contradicts ADR-0063 D6 (e.g. 6-field cron), flag in the PR — do not silently edit.
- **`Directory.Build.props` change ships in the ADR-0047 initiative, not here.** This packet commits the documentation/contract; the per-test-template `PackageReference` change belongs in `adr-0047-testing-patterns-and-tooling`.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0063`, `wave-1`

## Agent Handoff

**Objective:** Land the ADR-0063 documentation sweep — Kernel docs, tech-stack, and cross-references in ADRs 0047/0057/0068.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the Grid documentation surface consistent with ADR-0063's decisions so consumers and review agents read a single source of truth on date/time policy.
- Feature: ADR-0063 Date, Time, and Clock Policy rollout, Wave 1 (docs sweep).
- ADRs: ADR-0063 (primary), ADR-0047 D10 (test template), ADR-0057 (API serialization), ADR-0068 (cron format pin).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This packet has no hard dependency on packet 00 — ADR-0063's decisions are the source whether or not the Status flag is flipped yet. Operator-enforced merge ordering: this packet may merge before or after packets 02/03; it should merge before packet 00 (the acceptance flip) so packet 00's invariant block can cite landed cross-references, but no `dependencies:` edge enforces it.

**Constraints:**
- No catalog JSON edits — ADR-0063 commits no HoneyDrunk-owned contract.
- ADR-0068 stays Proposed; this packet only confirms/sharpens cross-references.
- The `Directory.Build.props` test-template change is owned by the ADR-0047 initiative, not here — this packet commits the cross-reference paragraph only.
- Cross-references point back to ADR-0063 as authoritative; do not duplicate the pin in the referenced ADRs.

**Key Files:**
- `repos/HoneyDrunk.Kernel/overview.md`, `boundaries.md`.
- `infrastructure/reference/tech-stack.md`.
- `adrs/ADR-0047-testing-patterns-and-tooling.md`, `adrs/ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md`, `adrs/ADR-0068-background-job-and-recurring-work-substrate.md`.

**Contracts:** None changed — docs-only.
