---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "core", "docs", "adr-0072", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0072", "ADR-0048"]
wave: 2
initiative: adr-0072-data-access-stance
node: honeydrunk-architecture
---

# Add Data-Access Stance to every per-Node `integration-points.md`

## Summary
Extend every existing `repos/HoneyDrunk.<Node>/integration-points.md` with a **Data-Access Stance** section recording the per-Node ORM posture per ADR-0072 D1/D2/D8. **Hard-blocked on `adr-0048-schema-evolution` packet 01 having merged** — that packet introduces the `## Migration Coordination` section this packet sits alongside, and the `schema_evolution` field in `catalogs/grid-health.json` that determines per-Node default content.

## Context
ADR-0072's Follow-up Work names the per-Node stance recording: each Node should record its ORM posture (EF Core by default; Dapper exceptions named if any; document-store SDK for NoSQL backings) in a discoverable place.

Per-Node `integration-points.md` files (in `repos/HoneyDrunk.<Node>/integration-points.md`) document the cross-Node integration surface for each Node. Sibling initiative `adr-0048-schema-evolution` packet 01 adds a `## Migration Coordination` section to every existing `integration-points.md`. This packet adds a **Data-Access Stance** section as a sibling to that one, so the per-Node ORM posture and the per-Node migration framework sit side-by-side.

**Hard sequencing.** This packet is gated on `adr-0048-schema-evolution` packet 01 having merged for two reasons:

1. **Section placement.** The Data-Access Stance section is naturally a sibling to `## Migration Coordination`. Without that section existing, this packet has to invent a placement that the sibling's executor would then have to harmonize with — producing a churned edit and a confusing pair of PRs.
2. **Per-Node default content lookup.** The sibling packet 01 adds the `schema_evolution` field to `catalogs/grid-health.json` (values `ef-core-migrations` / `cosmos-schema-on-read` / `n/a`). This packet's default content per Node reads from that field. Without the field, the executor has to infer the per-Node ORM stance from the actual implementation in each Node repo — a slower, more error-prone path.

The filing pipeline's `packet:NN` form only resolves intra-initiative. Cross-initiative coupling is enforced **textually** here: the executor confirms (a) `catalogs/grid-health.json` contains the `schema_evolution` field on `main`, AND (b) at least one `integration-points.md` has the `## Migration Coordination` section on `main`, before opening this packet's PR. If either condition fails, the issue stays open with a wait comment; no PR is opened.

This is a docs/template packet. No code, no .NET project.

## Scope
- Every existing `repos/HoneyDrunk.<Node>/integration-points.md` — add a `## Data-Access Stance` section (sibling to `## Migration Coordination`).
- No edit to `catalogs/grid-health.json` (the `schema_evolution` field's value implies the ORM stance per ADR-0072 D1; no separate `data_access` field is added).
- No edit to `repos/HoneyDrunk.Data/overview.md` (packet 03a owns it).
- No edit to any Node repo.

## Proposed Implementation

### 1. Confirm sibling sequencing

Read `catalogs/grid-health.json` and any one `repos/HoneyDrunk.<Node>/integration-points.md` on `main`. If `schema_evolution` is not present and `## Migration Coordination` is not present, **do not open the PR**: leave the issue open with a wait comment naming the sibling `adr-0048-schema-evolution` packet 01. Resume when both conditions are satisfied.

### 2. Sweep every existing `integration-points.md`

Locate every existing `repos/HoneyDrunk.<Node>/integration-points.md` (a `Glob` of `repos/*/integration-points.md` returns the current set). For each file, add a `## Data-Access Stance` section as a sibling to `## Migration Coordination`, immediately after that section (so the two cross-Node data concerns sit side-by-side).

The section template:

```markdown
## Data-Access Stance

**ORM:** {EF Core (default per ADR-0072 D1) | Document-store SDK (per ADR-0072 D8) | N/A — library only}

**Provider package(s):** {`Microsoft.EntityFrameworkCore.SqlServer` | `Microsoft.EntityFrameworkCore.Npgsql` | `Microsoft.Azure.Cosmos` | `StackExchange.Redis` | N/A}

**Dapper hot-path reads:** {None | List of adopted Dapper queries with PR references and the workload reason}

**Notes:** {anything else relevant — e.g., "Audit's `AuditEntry` table is high-write append-only-by-interface per ADR-0030; Dapper hot-path optimization for forensic queries is a candidate but not adopted today (no production workload yet)."}
```

### 3. Per-Node defaults driven by `schema_evolution`

Read `catalogs/grid-health.json` (the sibling packet 01 has landed by step 1's gate). For each Node, assign default content by its `schema_evolution` value:

- **`ef-core-migrations`** — ORM: "EF Core (default per ADR-0072 D1)". Provider: as appropriate. Dapper: "None." Notes per Node.
- **`cosmos-schema-on-read`** — ORM: "Document-store SDK (per ADR-0072 D8 — NoSQL out of scope)." Provider: `Microsoft.Azure.Cosmos`. Dapper: "N/A — NoSQL backing." Notes per Node.
- **`n/a`** — ORM: "N/A — library only." Provider: "N/A." Dapper: "N/A." Notes: "No persistent store."

Per-Node specific notes worth recording:
- **HoneyDrunk.Data** — primary affected Node per ADR-0072. ORM: "EF Core (the ratified implementation; see `repos/HoneyDrunk.Data/overview.md` for the full commitment)." Provider package: "`HoneyDrunk.Data.EntityFramework` (the EF Core implementation behind `IRepository<T>` / `IUnitOfWork`)." Dapper: "None at the substrate level; per-Node consumers may adopt Dapper for hot-path reads per ADR-0072 D2 — those adoptions are recorded in the consuming Node's stance, not here."
- **HoneyDrunk.Notify** — ORM: "EF Core (default per ADR-0072 D1)." Provider: confirm at edit time (likely Azure SQL via `Microsoft.EntityFrameworkCore.SqlServer`). Dapper: "None today; Notify Cloud's send-history queries are a candidate for Dapper hot-path optimization once production workload data exists (per ADR-0072 D2)."
- **HoneyDrunk.Audit** (Seed) — ORM: "EF Core (default per ADR-0072 D1)." Provider: confirm at standup. Dapper: "Forensic queries are a candidate for Dapper hot-path optimization per ADR-0072 D2; not adopted today."
- **HoneyDrunk.Kernel** — ORM (for the relational core): "EF Core (default per ADR-0072 D1)." For the document-store sub-pieces (`HoneyDrunk.Kernel.Idempotency.*` etc.): "Document-store SDK per ADR-0072 D8." Dapper: "None."
- **HoneyDrunk.Vault**, **HoneyDrunk.Auth**, **HoneyDrunk.Transport**, **HoneyDrunk.Web.Rest**, **HoneyDrunk.Architecture**, **HoneyDrunk.Standards**, **HoneyDrunk.Studios**, **HoneyDrunk.Actions**, **HoneyDrunk.AI**, **HoneyDrunk.Capabilities**, **HoneyDrunk.Agents**, **HoneyDrunk.Communications**, **HoneyDrunk.Lore** — "N/A — library only" (Vault stores in Key Vault, not a relational store).

For Nodes that don't exist yet but are cataloged as Seed (Identity per ADR-0060, Files per ADR-0061, Memory per ADR-0022, Knowledge per ADR-0021, Billing per ADR-0037, Notify Cloud per ADR-0027): record the **committed** stance based on the relevant standup ADR. Identity / Files / Memory / Knowledge / Billing all commit to relational stores; their stance is "EF Core (default per ADR-0072 D1). Per-standup-ADR engine choice (Azure SQL vs Postgres) per ADR-0072 D8."

### 4. Do not edit `catalogs/grid-health.json`

The `schema_evolution` field added by sibling packet 01 implies the ORM choice per ADR-0072 D1:
- `ef-core-migrations` → ORM is EF Core (D1's default).
- `cosmos-schema-on-read` → ORM is the per-backing SDK (D8's NoSQL carve-out).
- `n/a` → no ORM (library-only Node).

Adding a separate `data_access` field would be noise; the `schema_evolution` field already carries the signal. This packet does **not** edit `grid-health.json`.

## Affected Files
- Every existing `repos/HoneyDrunk.<Node>/integration-points.md` (use a `Glob` of `repos/*/integration-points.md` to enumerate).

## NuGet Dependencies
None. This packet touches only Markdown template files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `repos/{Node}/...` files are per-Node governance docs that live in the Architecture repo.
- [x] No code change in any other repo.
- [x] The per-Node `integration-points.md` template is the cross-Node integration-surface doc; this packet's addition is consistent with ADR-0072's D1/D2/D8 commitments.

## Acceptance Criteria
- [ ] The PR body records that (a) `schema_evolution` field exists in `catalogs/grid-health.json` on `main` and (b) at least one `integration-points.md` carries `## Migration Coordination` on `main`, before the PR was opened
- [ ] Every existing `repos/HoneyDrunk.<Node>/integration-points.md` file carries a `## Data-Access Stance` section placed as a sibling to `## Migration Coordination`
- [ ] Each Data-Access Stance entry names ORM, provider package(s), Dapper hot-path reads (default "None"), and per-Node notes
- [ ] For Nodes already cataloged with `schema_evolution: ef-core-migrations` in `catalogs/grid-health.json`, the stance is "EF Core (default per ADR-0072 D1)"
- [ ] For Nodes with `schema_evolution: cosmos-schema-on-read`, the stance is "Document-store SDK per ADR-0072 D8 — NoSQL out of scope"
- [ ] For library-only Nodes, the stance is "N/A — library only"
- [ ] No edit to `catalogs/grid-health.json` (the `schema_evolution` field implies the stance; no separate `data_access` field)
- [ ] No edit to `repos/HoneyDrunk.Data/overview.md` (packet 03a owns it)
- [ ] No edit to Node repos
- [ ] No invariant change

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0072 D1 — EF Core as the default ORM.** Every Node touching a relational store uses EF Core. Marten / RepoDb / raw ADO.NET / EF 6 / Pomelo are not defaults.

**ADR-0072 D2 — Dapper as the scoped exception with mandatory evidence.** Per-Node, per-query. Scoped to read paths only.

**ADR-0072 D4 — Per-Node DbContext, scoped composition.** Each Node owns its own DbContext. Connection strings come from Vault per ADR-0005.

**ADR-0072 D8 — NoSQL out of scope.** Document-store backings (Cosmos, Redis) have their own SDKs; EF Core's Cosmos provider is permitted but not required.

**ADR-0048 (sibling initiative `adr-0048-schema-evolution` packet 01)** — adds the `schema_evolution` field to `catalogs/grid-health.json` and the `## Migration Coordination` section to every existing `integration-points.md`. This packet is hard-blocked on that packet having merged.

**Invariants 2 and 11 (referenced) — Same-layer dependency rule and one-repo-per-Node.** Together cover the per-Node DbContext rule.

## Constraints
- **Hard sibling sequencing.** This packet is gated on `adr-0048-schema-evolution` packet 01 having merged. The filing pipeline's `packet:NN` form only resolves intra-initiative; cross-initiative coupling is enforced textually: the executor confirms the `schema_evolution` field and `## Migration Coordination` section exist on `main` before opening this packet's PR.
- **No catalog edit.** Do not add a `data_access` field to `catalogs/grid-health.json`. The `schema_evolution` field implies the ORM choice.
- **Match existing `integration-points.md` styling.** Heading hierarchy, list style, link format — match the file's established conventions.
- **No invariant change.** ADR-0072 explicitly does not add invariants; this packet does not edit `constitution/invariants.md`.
- **Inline ADR-0072 D-decisions.** Per the self-containment rule, cite full text not just decision numbers in the per-Node documentation.

## Labels
`feature`, `tier-3`, `core`, `docs`, `adr-0072`, `wave-2`

## Agent Handoff

**Objective:** Add a `## Data-Access Stance` section to every per-Node `integration-points.md`. **Hard-blocked on `adr-0048-schema-evolution` packet 01 having merged** — confirm the `schema_evolution` field and `## Migration Coordination` section exist on `main` before opening the PR.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Record the per-Node ORM posture as a discoverable cross-Node integration concern.
- Feature: ADR-0072 Data Access Stance rollout, Wave 2.
- ADRs: ADR-0072 D1/D2/D4/D8 (primary), ADR-0048 (sibling initiative for `schema_evolution` field and `## Migration Coordination` section).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0072 must be Accepted so the stance content cites its decisions as live rules.
- **Sibling sequencing (textual, not in `dependencies:`)** — `adr-0048-schema-evolution` packet 01 must merge first. The filing pipeline does not support cross-initiative `packet:NN` resolution, so this constraint is enforced by the executor at PR-open time.

**Constraints:**
- Confirm sibling-packet artifacts exist on `main` before opening the PR; otherwise the issue stays open with a wait comment.
- No catalog edit (`grid-health.json` not modified — `schema_evolution` field implies the stance).
- No edit to `repos/HoneyDrunk.Data/overview.md` (packet 03a owns it).
- Match existing file styling.
- No invariant change.
- Inline ADR-0072 D-decisions as full text.

**Key Files:**
- Every existing `repos/HoneyDrunk.<Node>/integration-points.md` (use `Glob` `repos/*/integration-points.md` to enumerate).

**Contracts:** None changed.
