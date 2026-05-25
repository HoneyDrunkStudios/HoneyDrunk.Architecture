# Dispatch Plan — ADR-0063: Grid-Wide Date, Time, and Clock Policy

**Initiative:** `adr-0063-clock-policy`
**ADR:** ADR-0063 (Proposed → Accepted via packet 00, the trailing flip)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0063 settles date/time handling broadly across the Grid in a single ADR rather than letting each in-flight packet (ADR-0042 idempotency, ADR-0030 audit, ADR-0019 Communications cadence, ADR-0027 Notify retries, ADR-0047 Tier-2b Testcontainers, ADR-0068 background jobs) reach for the same sub-decisions in slightly different ways. The decisions span twelve D-sections covering storage format (UTC at rest), .NET type usage (`DateTimeOffset` / `DateOnly` / `TimeOnly` / `TimeSpan` — `DateTime` banned), the wall-clock substrate (BCL `TimeProvider`, no HoneyDrunk-owned wrapper), serialization (ISO 8601 with `Z`), time-zone IDs (IANA-only), cadence specification (5-field cron in UTC + ISO 8601 durations), the test substrate (`FakeTimeProvider`), audit timestamp authority, idempotency TTL semantics, Gregorian-only scope cap, and the migration path.

This initiative delivers: the ADR acceptance + the five new date/time invariants (Architecture); the documentation sweep across Kernel docs / tech-stack / ADR cross-references (Architecture); the DI registration helpers `AddSystemTimeProvider` / `AddFakeTimeProvider` in `HoneyDrunk.Kernel`; and the warning-severity Roslyn analyzer rule in `HoneyDrunk.Standards` flagging direct `DateTime.UtcNow` / `.Now` / `DateTimeOffset.UtcNow` / `.Now` reads in non-test projects with an `[AllowSystemClock]` opt-out attribute.

**4 packets across 1 wave**, targeting **3 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Standards`). All 4 are `Actor=Agent`, 0 `Actor=Human`. No packet carries Human Prerequisites — every piece of work is code/docs and fully delegable.

## Trigger

ADR-0063 is Proposed with no scope. The forcing functions (from the ADR's Context section): the **ADR-0047 Tier-2b Testcontainers pilots** are about to hit "how do I make this deterministic" questions and invariant 51's ban on `Thread.Sleep` has no committed alternative; **ADR-0042 idempotency TTLs**, **ADR-0006 rotation deadlines**, audit timestamps per **ADR-0030**, **ADR-0019** Communications cadence, and future Memory expirations all need a single "now" source; **ADR-0028** Service Bus event timestamps and **ADR-0030** audit timestamps have no pinned on-wire format; **ADR-0057** governs public HTTP API shape but defers the date/time serialization detail to a future cross-cutting decision (this ADR is that decision); the **Communications drip-campaign / cadence-policy** work needs cron strings and the clock through a substrate that tests can fake; **ADR-0068** (Proposed, paired with this ADR) pins the cron-string format and depends on this ADR's `TimeProvider` decision.

Every consumer reaches for the same sub-decisions in slightly different ways — without a single Grid-level pin, the divergence between "what packets do" (inject `TimeProvider` in test paths) and "what production code does" (`DateTimeOffset.UtcNow` directly) keeps widening.

## Scope Detection

**Multi-repo, single wave.** ADR-0063 touches `HoneyDrunk.Architecture` (governance/docs/cross-references), `HoneyDrunk.Kernel` (the DI registration helpers and the `Microsoft.Extensions.TimeProvider.Testing` `PackageReference`), and `HoneyDrunk.Standards` (the analyzer rule + opt-out attribute). No contract cascade to downstream Nodes — ADR-0063 explicitly commits no HoneyDrunk-owned contract; it pins to the BCL's `TimeProvider`. Per ADR-0063 D11 the Catalog obligations are nil: "`catalogs/nodes.json` — no entry to add. `catalogs/contracts.json` — no entry to add."

**No new-Node scaffolding.** All three target repos are live, scaffolded Nodes.

**Single wave, four parallel packets.** No code dependency between the packets:
- Packet 00 (acceptance) writes invariants and flips Status — depends operationally on packets 02 and 03 landing first per the ADR's own checklist, but no `dependencies:` edge.
- Packet 01 (docs sweep) is pure documentation — independent of all others.
- Packet 02 (Kernel helpers) ships runtime code against the BCL — independent of acceptance status; the ADR's decisions hold whether or not the Status flag is flipped.
- Packet 03 (analyzer rule) ships a warning-severity rule against the BCL property reads — independent of acceptance status.

The merge ordering is operator discipline (see "Merge Ordering" below), not encoded as `dependencies:` edges, because none of the packets *blocks* on another in the compile-against / consume-from sense. Filing them concurrently is correct; merging them in the documented order is the discipline.

## Wave Diagram

### Wave 1 (all four packets, parallel by `dependencies:`)
- [ ] **00** — Architecture: Accept ADR-0063, add the five date/time invariants (numbers **54, 55, 56, 57, 58**), register the initiative. `Actor=Agent`. **Merge last** per ADR-0063's own "If Accepted" checklist.
- [ ] **01** — Architecture: Kernel docs + tech-stack + cross-references in ADRs 0047/0057/0068. `Actor=Agent`. May merge any time in the wave; merging before 00 lets packet 00's invariant block cite landed cross-references.
- [ ] **02** — Kernel: `AddSystemTimeProvider()` and `AddFakeTimeProvider()` DI helpers; bump solution `0.7.0` → `0.8.0`. `Actor=Agent`. **Version-bumping packet for `HoneyDrunk.Kernel`.**
- [ ] **03** — Standards: `HD0054` analyzer rule at warning severity + `[AllowSystemClock]` opt-out attribute. `Actor=Agent`. Standards version bumps per its own solution cadence.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **53**. Packet 00 claims numbers **54, 55, 56, 57, 58**. If any invariant above 53 lands from outside this initiative before packet 00 merges, shift the block upward (e.g., 55, 56, 57, 58, 59); never reuse a number.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0063](./00-architecture-adr-0063-acceptance.md) | Architecture | Agent | 1 | — (operator merges last) |
| 01 | [Date/time docs + cross-references](./01-architecture-date-time-catalog-and-cross-references.md) | Architecture | Agent | 1 | — |
| 02 | [Kernel `TimeProvider` DI helpers](./02-kernel-time-provider-di-helpers.md) | Kernel | Agent | 1 | — |
| 03 | [Standards analyzer rule + opt-out attribute](./03-standards-date-time-now-analyzer-rule.md) | Standards | Agent | 1 | — |

## Merge Ordering — operator discipline, not `dependencies:` edges

The `dependencies:` arrays are all empty. The intended merge ordering, per ADR-0063's "If Accepted — Required Follow-Up Work" checklist:

1. **Packet 02** (Kernel helpers) **and Packet 03** (Standards analyzer) — merge first, in either order. The ADR commits the Status flip to "after the analyzer rule lands and the DI helpers ship in Kernel."
2. **Packet 01** (docs sweep) — merge any time; merging before 00 is cleaner so 00's invariant block can reference settled docs.
3. **Packet 00** (acceptance) — merge last. This packet flips the Status flag and lands the invariant block.

Why not encode this as `dependencies:` edges? Two reasons:

- The file-packets pipeline reads `dependencies:` and wires `addBlockedBy`. A `blockedBy` edge means "this issue cannot be worked on until the blocker is closed" — a *work-start* gate. For packets 01–03 there is no work-start gate; they can be authored against ADR-0063 whether it is Proposed or Accepted (the ADR's decisions hold either way). The gate is on *packet 00*'s merge order, and "merge after these other PRs land" is not a `dependencies:` semantic.
- The ADR's own "If Accepted" checklist is the source of truth on the merge order. Operators reading this dispatch plan see the order; the issue board does not artificially block 01–03.

If the operator prefers to encode strict ordering, the safe form is to set packet 00's `dependencies:` to `["packet:01", "packet:02", "packet:03"]` after the other three are filed and their packet numbers are stable. This is *optional* and reflects taste, not a correctness requirement.

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is the bumping packet: every non-test `.csproj` moves from `0.7.0` → `0.8.0` in one commit (invariant 27; new feature: DI helpers; additive, no break). Per-package CHANGELOG: `HoneyDrunk.Kernel` gets an entry (functional change); `HoneyDrunk.Kernel.Abstractions` gets no per-package entry (alignment bump only — invariant 12/27).
- **`HoneyDrunk.Standards`** — packet 03 bumps the Standards solution per its own cadence (current at 0.2.9 per `HoneyDrunk.Kernel.csproj`'s `PackageReference`; confirm at execution time). All `.csproj` in the Standards solution move together per invariant 27. The new analyzer rule + new annotations attribute is a new feature; recommend a patch or minor bump per Standards' established CHANGELOG pattern.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/docs edits only.

## Cross-Cutting Concerns

### No HoneyDrunk-owned clock wrapper — D11 is the test of taste

ADR-0063 D11 is explicit: "Kernel does not wrap [`TimeProvider`]. Kernel does not publish `IGridClock` or `IClock` or any HoneyDrunk-owned interface that proxies `TimeProvider`. The platform-level abstraction is the contract; layering an additional interface on top is ceremony without value." Packet 02's review must hold the line. The ADR's Alternatives Considered section ("Wrap `TimeProvider` in a HoneyDrunk-owned `IGridClock` interface") already answers the temptation: rejected. The dispatch plan's review notes call this out so the executing agent and any reviewer remember this is a deliberate decision, not an omission.

### `Microsoft.Extensions.TimeProvider.Testing` is a runtime `PackageReference` on Kernel, not test-only

Packet 02 places the `PackageReference` on the Kernel runtime package because `AddFakeTimeProvider()` is part of Kernel's public runtime API — instantiating `FakeTimeProvider` is a runtime operation, not a test-time one. Hosts that only call `AddSystemTimeProvider()` still transit the package; ADR-0063 Operational Consequences accepts this cost ("MIT-licensed, stewardship is Microsoft; the trust posture is good; the dependency itself is small"). Packet 02's NuGet section confirms this placement explicitly.

Separately, the ADR-0047 testing initiative will eventually add `Microsoft.Extensions.TimeProvider.Testing` to the test-project `Directory.Build.props` so `FakeTimeProvider` is available to every test project without per-Node opt-in. That `Directory.Build.props` change is owned by ADR-0047, not this initiative — packet 01 here commits the cross-reference paragraph in ADR-0047; the actual file change ships in the `adr-0047-testing-patterns-and-tooling` initiative's relevant packet.

### Existing direct `DateTime.UtcNow` reads — surfaced, not migrated

Per ADR-0063 D12, "Existing code is migrated opportunistically. When a packet touches a code path that reads `DateTimeOffset.UtcNow`, that read is converted to `TimeProvider.GetUtcNow()` in the same packet. No bulk-migration packet is filed; the burden is amortized across the natural touch points." Packet 03 ships the analyzer at **warning** severity exactly so the day-after-it-lands experience is informational, not build-breaking — every Node will see warnings on every direct `UtcNow` read, and each touching packet will clear the warnings as it visits the code. The flip-to-error gate is the user's call once the bulk has migrated; that flip is a future one-line severity change in the descriptor, not a separate packet here.

### Cascading invariant 47 — audit timestamp authority

ADR-0063 D8 is "Audit timestamps are read once at emit, never regenerated." This sharpens invariant 47 (Audit substrate) without changing it textually — the existing wording already names `IAuditLog` as the timestamp authority. No invariant edit in this initiative for D8; it is governed by the existing invariant 47 plus the ADR-0063 D8 narrative. If a future Audit Node implementation packet regenerates a timestamp downstream, ADR-0063 D8 is the cite for the violation.

### Reviewer note — symmetry with ADR-0047 / `HD0051`

Packet 03's analyzer is structurally symmetric to `HD0051` (`ThreadSleepInTestsAnalyzer`): same `HD_IsGridTestProject` MSBuild property gates both, in opposite directions (`HD0054` fires in non-test projects; `HD0051` fires in test projects). A reviewer reading packet 03 should confirm the existing `HD0051` precedent is the structural model and that the new analyzer follows the same `RegisterCompilationStartAction` → `IsGridTestProject` → `RegisterOperationAction` pattern, just with the gate inverted.

### Site sync

No site-sync flag. ADR-0063 is internal Core-sector infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packet 00 (acceptance):** revert the PR. ADR returns to Proposed; the five date/time invariants and the `## Date and Time Invariants` section are removed. No runtime impact.
- **Packet 01 (docs sweep):** revert the PR. Kernel docs, tech-stack, and the ADR cross-references return to pre-merge state. No runtime impact.
- **Packet 02 (Kernel helpers):** revert the PR. `HoneyDrunk.Kernel` rolls back `0.8.0` → `0.7.0`; the two DI helpers and the `Microsoft.Extensions.TimeProvider.Testing` `PackageReference` leave the runtime package. Additive — no consuming Node depends on the helpers at runtime until it composes them, so the revert is contained to `HoneyDrunk.Kernel`. Operational escape hatch if the helpers prove broken before any consumer adopts them: revert; if a consumer has already adopted (unlikely in the same merge window), patch forward rather than revert.
- **Packet 03 (Standards analyzer):** revert the PR. `HD0054` and `[AllowSystemClock]` leave the Standards package; Standards rolls back its version. The warnings stop firing across the Grid. No runtime impact (it was a build-time diagnostic at warning severity, not a gate).
- **Operational escape hatch — flip severity back, not revert.** If the analyzer's warnings turn out to be too noisy or hit a false-positive class on day one, the cheaper escape is a `.editorconfig` or `Directory.Build.props` severity-override (`dotnet_diagnostic.HD0054.severity = none`) rather than reverting the whole packet. Document this in packet 03's PR description as the standard rollback for analyzer noise.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

The `dependencies:` arrays in this initiative's packets are all empty, so no `addBlockedBy` edges are wired. The merge ordering described in "Merge Ordering — operator discipline" is enforced by the operator at PR-merge time, not by the file-packets pipeline. If the operator chooses to encode strict ordering, the safe edit is to set packet 00's `dependencies:` to `["packet:01", "packet:02", "packet:03"]` before pushing this folder — that is optional, reflecting taste rather than correctness.
