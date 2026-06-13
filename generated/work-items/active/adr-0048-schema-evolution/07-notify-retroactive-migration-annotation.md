---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["chore", "tier-2", "ops", "adr-0048", "wave-4"]
dependencies: ["work-item:00", "work-item:02", "work-item:06", "work-item:09"]
adrs: ["ADR-0048"]
wave: 4
initiative: adr-0048-schema-evolution
node: honeydrunk-notify
---

# Retroactively annotate Notify scaffold migrations and adopt the Migrations/README.md template

## Summary
Apply ADR-0048's conventions retroactively to Notify's existing one or two scaffold migrations: add `[Rollback]` attributes (referencing the canonical `RollbackAttribute` type shipped from `HoneyDrunk.Standards` by packet 09) to each migration class per ADR-0048 D10/D12, copy the canonical `Migrations/README.md` template (from packet 06) into Notify's `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/README.md` with Notify-specific values filled in, and (if a Tier 2b test project exists or per ADR-0047 D11's roll-out for Notify) add round-trip tests for the existing scaffold migrations. No new migration is authored in this packet; this is a documentation-and-attribute pass on the existing scaffold.

## Context
ADR-0048 Consequences — Affected Nodes: "`HoneyDrunk.Notify` — gains the per-Node `Migrations/README.md`; existing scaffold migrations are retroactively annotated. No data migration today."

Notify is one of the few currently-live Nodes that already has scaffold migrations in its `DbContext` (per ADR-0048 Context: "Notify carries an EF Core `DbContext` with one or two migrations generated at scaffold time; nothing has been deployed against a populated store with traffic on it"). The retroactive annotation makes the scaffold conform to the new conventions without inventing new schema changes — it's a hygiene packet.

**Why retroactive annotation matters.** ADR-0048 invariant 95 (numbered 95 at this initiative's acceptance per packet 00) says "every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test." Without retroactive annotation, Notify's existing scaffold migrations would be permanent invariant-95 violations on the first day the invariant lands. Annotating them now closes the gap; future Notify migrations follow the convention from the first PR.

**No new migration in this packet.** This packet does NOT add a new EF migration; it does NOT modify the schema; it does NOT invoke `dotnet ef migrations add`. It only adds attribute decorations to the existing migration classes, drops the README template, and (if applicable) adds round-trip tests. The packet is `Actor=Agent`; the code work is fully delegable.

**Dependency on packet 06.** This packet copies the `Migrations/README.md` template from packet 06's deliverable in the Architecture repo. If packet 06 hasn't landed when this packet executes, the executor reads ADR-0048 D11 directly and authors the README content matching the template's specification. The packet body documents enough for the executor to proceed even without packet 06's template artifact in hand — but the cleaner path is to wait for packet 06.

**Dependency on packet 09.** Packet 09 ships the canonical `RollbackAttribute` and `RollbackStrategy` types from `HoneyDrunk.Standards`. This packet **references** those types via `using HoneyDrunk.Standards.Migrations;` — it does NOT define its own copy. Every Notify project already references `HoneyDrunk.Standards` per invariant 26, so no new `PackageReference` is added. Hard dependency: packet 09's Standards release must be published and the Standards solution version bumped in Notify's `Directory.Packages.props` (or per-project `PackageReference` versions) before this packet's `[Rollback]` decorations compile cleanly.

**Dependency on packet 02.** The `database` specialist agent (packet 02) is manually invoked on this PR per ADR-0046 D3. If packet 02 hasn't landed, the generalist `review` agent's category 13 surface check still runs; the depth review is deferred until `database` exists, but the work itself doesn't block.

This is a hygiene packet on Notify's existing data layer. Tier 2 (involves code change in a runtime project — the migration classes — but no new schema and no public API change).

## Scope
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/<existing-migration-files>.cs` — add `[Rollback(Strategy = RollbackStrategy.ForwardMigration, Notes = "...")]` attributes to each existing migration class.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/README.md` — new file, copied from the template in packet 06 with Notify-specific values filled in.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests.Integration.Containers/Migrations/NotifyMigrationRoundTripTests.cs` — new test class IF Notify already has the Tier 2b containers test project per ADR-0047 D11. If the project doesn't exist yet (ADR-0047's roll-out hasn't reached Notify), defer the round-trip test addition and record in the PR body that it's deferred until Notify's Tier 2b project is created.
- Per-package CHANGELOG entry for `HoneyDrunk.Notify.Data` only (the package whose migration classes are touched); repo-level CHANGELOG entry.
- Per-package README.md update if any public API surface or installation guidance changes (likely not; this is annotation-only).

## Proposed Implementation

### 1. Inventory the existing scaffold migrations

Read `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/` to inventory the existing migration files. The ADR Context names "one or two migrations generated at scaffold time" — confirm the actual count at execution time. Each migration class lives in a file named `<YYYYMMDDHHmmss>_<ClassName>.cs` plus a `<YYYYMMDDHHmmss>_<ClassName>.Designer.cs` paired file, plus the `NotifyDbContextModelSnapshot.cs`.

### 2. Add `[Rollback]` attributes

For each existing migration class, add a `using` directive and a class-level attribute. The canonical `RollbackAttribute` and `RollbackStrategy` types live in `HoneyDrunk.Standards` per packet 09 (Wave 3). Every Notify project already carries a `HoneyDrunk.Standards` `PackageReference` with `PrivateAssets: all` per invariant 26, so no new dependency is added — bump the Notify-side `HoneyDrunk.Standards` package version to the release that includes the types (the version packet 09 ships).

```csharp
using HoneyDrunk.Standards.Migrations;

[Rollback(
    Strategy = RollbackStrategy.ForwardMigration,
    Notes = "Scaffold migration — initial schema. Rollback by writing a compensating forward migration that drops the introduced tables/columns.")]
public partial class <ClassName> : Migration
{
    // existing body unchanged
}
```

**Do NOT define `RollbackAttribute` inside `HoneyDrunk.Notify.Data`.** The attribute is a Grid-wide contract per invariant 95 (the third schema-evolution invariant added by packet 00); shipping it inside a specific Node's data package would violate invariants 1/2 (no Grid-wide contract may live inside a per-Node package). Packet 09 ships the canonical type from `HoneyDrunk.Standards`; this packet references it.

The `[Rollback]` attribute is **informational only** per ADR-0048 D12 — it is not enforced at runtime. Its value is the discipline of declaring intent. The `database` review agent (packet 02) checks for presence and reads the `Notes`/`Reason` for adequacy.

### 3. Copy the `Migrations/README.md` template

Copy the template authored in packet 06 into `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/README.md`. Fill in Notify-specific values:

- **Node Name:** Notify.
- **EF Core version:** confirm at edit time.
- **Schema-evolution posture:** `ef-core-migrations`.
- **Provider:** confirm at edit time (likely Azure SQL based on the existing pattern; confirm by reading Notify's `DbContext` configuration).
- **Expand/Contract phase log:** the scaffold migration(s) are not Expand/Contract pairs — they are initial-schema migrations. Record them in the log with phase `Initial scaffold` (or omit the phase column for these entries with a note "Pre-ADR-0048; no Expand/Contract phase applies"). Future Notify migrations populate the log per the template.
- **Backward-compatibility window:** Notify Cloud (the multi-tenant deployable per ADR-0027) is Tier 0/Tier 1 customer-facing per ADR-0048 D5 — 2 stable deploys or 14 days. The current Notify Node (pre-Notify-Cloud) is more accurately Tier 2 internal; record the more conservative value (14 days) since Notify is on the path to becoming customer-facing.
- **Audit-specific constraints:** N/A — Notify is not the Audit Node.
- **Schema-on-read:** N/A — Notify has no document-store sub-piece today.
- **Running migrations:** point at `migrate.yml` per ADR-0048 D3/D11 (the workflow lands in HoneyDrunk.Actions per packet 05). Note that until packet 05's `migrate.yml` is consumed by a per-environment caller workflow in this repo, migrations are run manually by the operator from a local terminal against `dev` only. **Do NOT add a per-environment caller workflow in this packet** — that is a Notify-side follow-up when Notify's first real migration lands.
- **Failure recovery:** point at `dr-runbook.md` per ADR-0036 D9 — if `dr-runbook.md` doesn't exist in Notify yet (ADR-0036 is still Proposed), note "to be added when ADR-0036 lands."
- **Tests:** point at `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests.Integration.Containers/Migrations/` per ADR-0048 D12 — if the project doesn't exist yet, note "to be added when Notify adopts ADR-0047 Tier 2b."

### 4. Round-trip tests (conditional)

If `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests.Integration.Containers/` already exists in the Notify repo (per ADR-0047 D11's roll-out), add a `Migrations/NotifyMigrationRoundTripTests.cs` test class that:
1. Spins up a Testcontainers backing matching Notify's production provider (likely Azure SQL Edge container or Postgres if Notify uses Postgres).
2. Applies the scaffold migration(s).
3. Asserts the resulting schema matches the `NotifyDbContextModelSnapshot.cs`.
4. Inserts representative scaffold-shape test data.
5. Reads it back; asserts integrity.

Use the test-stack convention per ADR-0047 D2 (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet) and the Tier 2b container-test infrastructure per ADR-0047 D11. No `Thread.Sleep` (invariant 51); use an injected `TimeProvider` for any time-dependent waits.

If the Tier 2b project does NOT yet exist, defer the test addition and record in the PR body that the round-trip test is parked until ADR-0047's Tier 2b roll-out reaches Notify. The PR still merges; the Tier 2b test is a follow-up.

### 5. CHANGELOG + README

- **Per-package `HoneyDrunk.Notify.Data/CHANGELOG.md`:** add an entry for the annotation pass. The package has a functional change (the `[Rollback]` attribute decorations and the new `RollbackAttribute` type, if defined inside this package), so a per-package CHANGELOG entry is warranted per invariant 12.
- **Repo-level `CHANGELOG.md`:** add an entry for the Notify solution version. Per invariant 27, all projects in a Notify solution share one version. This packet is annotation-and-docs only — a **patch bump** is appropriate (no new public API, no new feature, no break). Confirm Notify's current version at execution time and bump patch.
- **`HoneyDrunk.Notify.Data/README.md`:** no edit needed unless the package's public API changes (the new `RollbackAttribute` type is public; if so, the README's "Public API" section should mention it).

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/<scaffold-migration>.cs` — `using HoneyDrunk.Standards.Migrations;` + `[Rollback]` attribute added to each migration class.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/README.md` — new file, copied from packet 06's template with Notify values.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests.Integration.Containers/Migrations/NotifyMigrationRoundTripTests.cs` (conditional — only if the project exists).
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/CHANGELOG.md` — per-package changelog entry.
- Repo-level `CHANGELOG.md` — solution-version-bump entry.
- Every non-test `.csproj` in the Notify solution — patch version bump per invariant 27.
- Whichever file pins the `HoneyDrunk.Standards` package version for Notify (`Directory.Packages.props` if centrally managed, otherwise per-project `PackageReference`) — bumped to the version packet 09 publishes.

> **Path verification at execution time.** Notify's repo layout is `HoneyDrunk.Notify/HoneyDrunk.Notify/HoneyDrunk.Notify.<Project>/`. The scaffold migrations and `DbContext` live in whichever Notify project hosts them today — confirm at execution time by inspecting `HoneyDrunk.Notify/HoneyDrunk.Notify/` for the data-bearing project. If the project name is not `HoneyDrunk.Notify.Data`, substitute the actual name in every path above.

## NuGet Dependencies
- **`HoneyDrunk.Standards`** (`PrivateAssets: all`) — already referenced by every Notify project per invariant 26. Bump the pinned version in Notify (`Directory.Packages.props` or per-project `PackageReference`) to the release packet 09 publishes (`HoneyDrunk.Standards` minor-bumped to include `RollbackAttribute` + `RollbackStrategy`). No new `PackageReference` is added; only the version pin moves forward.
- **Notify Data project** — no other new HoneyDrunk `PackageReference`.
- **Test project (conditional)** — the repo's existing test stack per ADR-0047 D2 (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet) plus `Testcontainers` per ADR-0047 D11 if the Tier 2b project exists. No new packages unless the Testcontainers backing requires a specific Testcontainers module (e.g. `Testcontainers.MsSql` for Azure SQL Edge, `Testcontainers.PostgreSql` for Postgres).

## Boundary Check
- [x] All edits in `HoneyDrunk.Notify`. Routing rule "notification, email, SMS, ... → HoneyDrunk.Notify" maps exactly for the data layer of this Node.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime edge — Notify already consumes `HoneyDrunk.Standards` per invariant 26; only the pinned version of that existing reference moves forward. No new `PackageReference` is added.
- [x] No public API surface change. The migration classes' public surface (the `Up`/`Down` methods) is unchanged. The `[Rollback]` attribute decoration is metadata, not a runtime API surface. `RollbackAttribute` itself is shipped by packet 09 from `HoneyDrunk.Standards`; this packet only consumes it.
- [x] Grid-wide contract placement preserved per invariants 1/2: `RollbackAttribute` is NOT defined inside `HoneyDrunk.Notify.Data`; it lives in `HoneyDrunk.Standards`.

## Acceptance Criteria
- [ ] Every existing scaffold migration class in `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/` carries a `[Rollback(Strategy = RollbackStrategy.ForwardMigration, Notes = "...")]` attribute with a non-empty `Notes` value
- [ ] If the `RollbackAttribute` type does not exist as a Grid-level type, it is defined inside `HoneyDrunk.Notify.Data` with the shape named in Proposed Implementation (sealed class, `AttributeUsage(Class)`, `Strategy` + `Notes` + `Reason` properties; `RollbackStrategy` enum with `ForwardMigration` and `NonRollback`)
- [ ] The PR body notes the follow-up to consolidate `RollbackAttribute` into a Grid-level type if it landed in `HoneyDrunk.Notify.Data`
- [ ] `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/README.md` exists with the canonical template from packet 06, with Notify-specific values filled in (Node name, EF Core version, provider, schema-evolution posture, backward-compatibility window, etc.)
- [ ] The README's "Expand→Contract phase log" lists the scaffold migrations as initial-schema entries
- [ ] The README's "Running migrations" section points at `migrate.yml` per ADR-0048 D3/D11 and notes that per-environment caller workflows are a Notify follow-up
- [ ] If `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests.Integration.Containers/` exists, a `Migrations/NotifyMigrationRoundTripTests.cs` test is added applying the scaffold migrations against a Testcontainers backing and asserting schema + data integrity; if the project does not exist, the test addition is deferred (recorded in the PR body)
- [ ] Notify's repo-level `CHANGELOG.md` has a new patch-bump entry for the annotation pass
- [ ] `HoneyDrunk.Notify.Data/CHANGELOG.md` has a per-package entry for the same version, citing the `[Rollback]` attribute decorations and (if added) the new `RollbackAttribute` type
- [ ] Every non-test `.csproj` in the Notify solution is at the same new patch version per invariant 27
- [ ] No `Thread.Sleep` in any new test code per invariant 51
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Optional:** before this packet executes, decide whether `RollbackAttribute` lives in `HoneyDrunk.Data.Abstractions` (Grid-level) or in per-Node namespaces (Notify-local at v1). The default for this packet is per-Node (Notify-local); a follow-up Grid-level consolidation packet against `HoneyDrunk.Data` is recorded in the PR body. If the operator wants the Grid-level home shipped first, file a separate `HoneyDrunk.Data` packet and merge it before this Notify packet executes; that bumps the dependency surface and changes this packet's NuGet section.

## Referenced ADR Decisions

**ADR-0048 D10 — Forward-only rollback by default.** EF Core's `Down()` is not committed to in production. Rollback is achieved by writing a new forward migration that reverses the unwanted change. The `[Rollback]` attribute declares the intent; it is informational, not runtime-enforced.

**ADR-0048 D12 — `[Rollback]` attribute on every migration class.** Two strategies: `ForwardMigration` (default, with optional `Notes`) and `NonRollback` (with required `Reason`). Missing the attribute is a review block per the `database` agent (packet 02). The Notify scaffold migrations adopt `ForwardMigration` with appropriate `Notes`.

**ADR-0048 D11 — `Migrations/README.md` per Node.** Copies from the canonical template authored in packet 06.

**ADR-0048 Consequences — Affected Nodes — Notify.** "Gains the per-Node `Migrations/README.md`; existing scaffold migrations are retroactively annotated. No data migration today."

**ADR-0047 D11 — Tier 2b round-trip test job.** The round-trip test added here (conditional on the test project existing) feeds the Tier 2b CI gate.

**Invariant 12 — Per-package CHANGELOG only for packages with functional changes.** `HoneyDrunk.Notify.Data` has a functional change (attribute decorations + possibly the `RollbackAttribute` type); other Notify packages do not, so they get the alignment bump without a per-package CHANGELOG entry.

**Invariant 27 — One version across the solution.** Every non-test `.csproj` bumps to the same new patch version in one commit.

**Invariant 51 — No `Thread.Sleep` in test code.** New round-trip tests use `TimeProvider` for any time-dependent waits.

## Constraints
- **No new schema in this packet.** Do not run `dotnet ef migrations add`; do not modify entity types or `OnModelCreating`. The packet is annotation-and-docs only.
- **The `[Rollback]` attribute is informational.** ADR-0048 D12: it is not enforced at runtime. The review agent reads it; the runtime does not.
- **Round-trip test is conditional.** Only land it if the Tier 2b project exists; otherwise defer.
- **Patch bump, not minor.** No new public API (except possibly `RollbackAttribute`, which is mechanical), no new feature. Per invariant 27 the whole solution bumps; per SemVer (invariant 12) it's a patch. If `RollbackAttribute` is shipped public and the executor judges it a minor-worthy addition, document the reasoning in the PR body.
- **The `RollbackAttribute`'s Grid-level home is a deferred follow-up.** Default is Notify-local for v1; record the follow-up in the PR body.
- **Run `dotnet build` after annotation.** Confirm the attribute compiles cleanly and the existing tests still pass.

## Labels
`chore`, `tier-2`, `ops`, `adr-0048`, `wave-4`

## Agent Handoff

**Objective:** Retroactively annotate Notify's existing scaffold migrations with `[Rollback]` attributes, copy the `Migrations/README.md` template from packet 06 into Notify's data project, and add a Tier 2b round-trip test if the project exists.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Close the invariant-95 gap for Notify's existing scaffold migrations without inventing new schema; establish the per-Node `Migrations/README.md` for Notify as the first Node consuming the template.
- Feature: ADR-0048 Schema Evolution rollout, Wave 4.
- ADRs: ADR-0048 D10/D11/D12 (primary), ADR-0047 D11 (Tier 2b), ADR-0036 D9 (`dr-runbook.md`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0048 must be Accepted so the annotation makes sense as policy compliance.
- `work-item:06` — `Migrations/README.md` template is needed for the copy step. If 06 hasn't merged, the executor reads ADR-0048 D11 directly and authors the README content matching the template's specification.
- `work-item:02` — the `database` specialist agent ideally reviews this PR. Soft dependency — if 02 hasn't landed, the generalist `review` agent runs its category 13 surface check; the depth review is deferred.

**Constraints:**
- No new schema; no `dotnet ef migrations add` invocation.
- `[Rollback]` attribute is informational; not runtime-enforced.
- Round-trip test conditional on Tier 2b project existing.
- Patch bump; the whole solution bumps together per invariant 27.
- `RollbackAttribute`'s Grid-level home is a follow-up; ship Notify-local for v1.
- No `Thread.Sleep` per invariant 51.

**Key Files:**
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/<scaffold>.cs` — attribute decoration.
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/RollbackAttribute.cs` (new, conditional).
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Data/Migrations/README.md` (new).
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests.Integration.Containers/Migrations/NotifyMigrationRoundTripTests.cs` (new, conditional).
- `HoneyDrunk.Notify.Data/CHANGELOG.md`, repo-level `CHANGELOG.md`, every non-test `.csproj` (version bump).

**Contracts:**
- `RollbackAttribute` (new public type if shipped in `HoneyDrunk.Notify.Data`) — `Strategy`/`Notes`/`Reason` properties; `RollbackStrategy` enum with `ForwardMigration` and `NonRollback`. Follow-up to consolidate into a Grid-level type.
