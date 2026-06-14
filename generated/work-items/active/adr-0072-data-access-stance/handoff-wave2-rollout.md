# Handoff — Wave 2: ADR-0072 Rollout (Rubric Updates + Data Node Ratification)

**Initiative:** `adr-0072-data-access-stance`
**Wave:** 2 (rubric updates + Data Node ratification)
**Trigger:** Packet 00 merged — ADR-0072 is Accepted.
**Date:** 2026-05-24

> Per ADR-0008 D7 and invariant 24, this handoff is immutable. Read once at the wave transition; it is not a living tracker.

## What landed in Wave 1

**Packet 00** — ADR-0072 flipped to **Accepted**. The ADR row is in `adrs/README.md` after ADR-0057 as the last row. The `adr-0072-data-access-stance` initiative is registered in `initiatives/active-initiatives.md` with the packet checklist for this folder.

**No invariants were added.** ADR-0072 explicitly commits its five conventions (EF Core default, writes through DbContext, `AsNoTracking()` / explicit `Include` / lazy off, per-Node DbContext, connection strings from Vault) as **review-enforced**, not as numbered invariants. Packet 00's `## No New Invariants` section records the scope-time judgment: none of the five conventions is elevated. The enforcement lives in the `review` agent's rubric (packet 01 of this initiative) and the `database` specialist agent's rubric (packet 02), not in `constitution/invariants.md`. If a future audit determines that any convention needs invariant-level enforcement, a follow-up ADR amendment elevates it. That is not Wave 2's concern.

## What Wave 2 ships

Five packets. Three are independently actionable (01, 03a, 04) once packet 00 merges. Two carry **hard textual cross-initiative gates** on `adr-0048-schema-evolution`:

- Packet **02** waits on `adr-0048-schema-evolution` packet 02 (`database.md` agent file).
- Packet **03b** waits on `adr-0048-schema-evolution` packet 01 (`## Schema Deployment Coordination` section + `schema_evolution` catalog field).

The filing pipeline's `work-item:NN` form only resolves intra-initiative; cross-initiative gates are enforced by the executor at PR-open time (issue stays open with a wait comment until the sibling artifact exists on `main`).

### Packet 01 — `review.md` D3 category 13 — EF discipline + Dapper evidence checks (Architecture)

Extends `.claude/agents/review.md` D3 category 13 (Data and persistence integrity) with:

- **EF Core query discipline sub-section** (per ADR-0072 D5): `AsNoTracking()`, projections preferred, explicit `Include`, lazy loading off, N+1 detection, compiled-query handling, parameterized `FromSqlRaw`.
- **Dapper-evidence-burden sub-section** (per ADR-0072 D2): Dapper introductions flagged for specialist depth review; Dapper-write rejection at surface; evidence-burden checklist (EF query / Dapper query / benchmarks / workload context).
- **Connection-strings-from-Vault check** (per ADR-0072 D4 / ADR-0005 / invariant 9): hardcoded connection strings in `appsettings.json` are **Block**.
- **Per-Node DbContext check** (per ADR-0072 D4; grounded in invariants 2 and 11, not invariant 3): cross-Node DbContext references are **Block**.

Sibling-edit coexistence note: sibling initiative `adr-0048-schema-evolution` packet 03 also edits category 13 to add a delegation stanza. The two edits are additive and order-tolerant — preserve any delegation language already present.

### Packet 02 — `database` specialist agent rubric — ORM-choice and query-discipline categories (Architecture)

Extends `.claude/agents/database.md` with two new rubric categories (categories 9 and 10 in the existing rubric authored by sibling initiative `adr-0048-schema-evolution` packet 02):

- **Category 9 — ORM choice** (per ADR-0072 D1/D2): EF Core as the default; Marten / RepoDb / raw ADO.NET / EF 6 deviations require ADR amendment; Dapper-introduction evidence burden verification; Dapper-write rejection; per-Node-per-query scope; `FromSqlRaw`-vs-Dapper preference.
- **Category 10 — Query discipline** (per ADR-0072 D5): `AsNoTracking()` depth confirmation; projection adequacy; `Include` chain audit; lazy-loading off; N+1 confirmation; compiled-query justification; raw-SQL parameterization depth check; tenant predicate presence.

**Hard sibling sequencing**: this packet is gated on `adr-0048-schema-evolution` packet 02 having merged. Executor confirms `.claude/agents/database.md` exists on `main` before opening the PR. No holding-document fallback.

The agent's invocation surface is extended to include Dapper introductions and EF query pattern modifications, so the specialist is invoked on data-layer PRs even when no `HoneyDrunk.<Node>.Database/` or `Backfill/` file is touched.

### Packet 03a — `repos/HoneyDrunk.Data/overview.md` ORM Commitment (Architecture)

Single-file governance task: add an "ORM Commitment" section to `repos/HoneyDrunk.Data/overview.md` recording EF Core as the ratified ORM behind `IRepository<T>` / `IUnitOfWork` per ADR-0072 D1/D4. Includes the negative form (Dapper not default, Marten not adopted, raw ADO.NET not default, EF 6 forbidden, RepoDb / Pomelo not adopted) per D1; the query-discipline summary per D5; the testing-discipline summary per D6; and the migration-path-away mechanism per D7. Standalone-actionable once packet 00 merges.

### Packet 03b — Per-Node `integration-points.md` Data-Access Stance sweep (Architecture)

Extend every existing `repos/HoneyDrunk.<Node>/integration-points.md` with a `## Data-Access Stance` section placed as a sibling to `## Schema Deployment Coordination`. Default content per Node based on `schema_evolution` value in `catalogs/grid-health.json`.

**Hard sibling sequencing**: gated on `adr-0048-schema-evolution` packet 01 having merged (that packet introduces `## Schema Deployment Coordination` and the `schema_evolution` catalog field). Executor confirms both artifacts exist on `main` before opening the PR.

**No catalog edit.** `catalogs/grid-health.json` is not modified. The `schema_evolution` field implies the ORM choice per ADR-0072 D1 — no separate `data_access` field is needed.

### Packet 04 — Data repo ratification (Data)

Updates the `HoneyDrunk.Data` repo's own documentation:

- **`HoneyDrunk.Data/README.md`** — new ORM Commitment section citing ADR-0072 with the full content (EF Core default, Dapper scoped exception, SQL project/DACPAC deployment, per-Node DbContext, query discipline, testing discipline, migration-path-away mechanism).
- **`HoneyDrunk.Data.Abstractions/README.md`** — new ORM Stance paragraph citing ADR-0072 D1/D7.
- **`HoneyDrunk.Data.EntityFramework/README.md`** — new ADR-0072 Ratification paragraph naming this package as the default implementation per D1.
- **`HoneyDrunk.Data/CHANGELOG.md`** — conditional ratification entry. Default Option (a) — defer the CHANGELOG line to the next release that requires a version bump for non-docs reasons. Option (b) — bump patch with new dated section. Operator's choice; record in PR body.

**No code change.** The EF Core implementation already exists in `HoneyDrunk.Data.EntityFramework`; this packet ratifies it explicitly in docs.

**No version bump for docs alone** per invariants 12/27. No per-package CHANGELOG entries (citation-only docs is not a functional change per invariant 12).

## Parallelism

Wave-2 has five packets. Three (**01**, **03a**, **04**) are independently actionable once **00** merges. Two (**02**, **03b**) carry hard textual gates on `adr-0048-schema-evolution` and may queue at PR-open time:

- **01** edits `.claude/agents/review.md` category 13.
- **02** edits `.claude/agents/database.md` — **waits for** `adr-0048-schema-evolution` packet 02.
- **03a** edits `repos/HoneyDrunk.Data/overview.md`.
- **03b** edits every `repos/HoneyDrunk.<Node>/integration-points.md` — **waits for** `adr-0048-schema-evolution` packet 01.
- **04** edits the `HoneyDrunk.Data` repo's READMEs and (conditionally) CHANGELOG.

None of the five touches the same file as another. The unblocked three can be filed and worked on simultaneously by separate agents; the gated two stay open with wait comments until their sibling artifacts exist on `main`.

## Coupling with sibling initiative `adr-0048-schema-evolution`

ADR-0072 and ADR-0048 are tightly coupled by topic. The two initiatives ship coupled artifacts:

- **`database` specialist agent file** — authored by `adr-0048-schema-evolution` packet 02. ADR-0072's packet 02 extends its rubric. **Hard textual gate**: packet 02 here waits for the sibling to merge.
- **`review.md` D3 category 13** — `adr-0048-schema-evolution` packet 03 adds a delegation stanza; ADR-0072's packet 01 adds the EF / Dapper discipline checks. Different sub-sections; additive; no gate.
- **`integration-points.md` per-Node** — `adr-0048-schema-evolution` packet 01 adds `## Schema Deployment Coordination`; ADR-0072's packet 03b adds Data-Access Stance as a sibling section. **Hard textual gate**: packet 03b here waits for the sibling to merge.
- **`catalogs/grid-health.json` `schema_evolution` field** — added by `adr-0048-schema-evolution` packet 01. ADR-0072's stance overlaps semantically; no separate field added. Packet 03b reads the field to determine per-Node defaults — another reason for the sibling gate.

Standalone ADR-0072 packets (00, 01, 03a, 04) can land in any order relative to ADR-0048. The two gated packets (02, 03b) require the sibling artifacts to exist on `main` first; the filing pipeline cannot wire cross-initiative `work-item:NN` references, so the executor enforces the gate at PR-open time.

## What this wave does NOT ship

Per the dispatch plan's Cross-Cutting Concerns / Deferred Follow-ups:

- **Per-Node EF Core adoption** for Identity (ADR-0060), Files (ADR-0061), Audit (ADR-0030/0031), Communications (ADR-0019), Memory (ADR-0022), Knowledge (ADR-0021), Billing (ADR-0037), Notify Cloud (ADR-0027), consumer-app PDRs (PDR-0003/0005/0006/0008). Each follows in that Node's standup-ADR track.
- **First Dapper hot-path read introduction.** No production workload yet to provide the evidence. The first introduction is a per-Node packet with benchmark evidence inline, reviewed by the `database` specialist agent under the rubric this initiative ships.
- **EF Core interceptor discipline as a Grid invariant.** ADR-0072's Alternatives Considered names this as deferred-not-rejected. A follow-up ADR may commit a Grid-wide interceptor pattern once the patterns settle in production.
- **Marten as a backing for one specific Node.** ADR-0072 keeps this open as a per-Node choice; no follow-up filed here.
- **Per-Node tutorial / template for "add an entity, write a migration, ship in CI."** Named in ADR-0072's Follow-up Work as belonging to the DX-baseline ADR. Not in this initiative.

## Acceptance for Wave 2 completion

- [ ] Packet 01 merged — `review.md` D3 category 13 carries the EF / Dapper discipline checks
- [ ] Packet 02 merged — `database.md` carries categories 9 and 10 (sibling `adr-0048-schema-evolution` packet 02 has merged first)
- [ ] Packet 03a merged — `repos/HoneyDrunk.Data/overview.md` carries the ORM Commitment section
- [ ] Packet 03b merged — every `repos/HoneyDrunk.<Node>/integration-points.md` carries the `## Data-Access Stance` section (sibling `adr-0048-schema-evolution` packet 01 has merged first)
- [ ] Packet 04 merged — Data repo READMEs cite ADR-0072; CHANGELOG entry handled per Option (a) or (b)

When all five Wave-2 packets merge, **the initiative is complete.** There is no Wave 3 — ADR-0072 is a policy ratification, not a code-rollout initiative. Per-Node EF Core adoption is deferred to each Node's standup track. The `database` specialist agent's rubric (extended in packet 02) and the generalist `review` agent's rubric (extended in packet 01) carry the enforcement surface forward into every future data-layer PR.

When the initiative completes, the operator can move the dispatch plan and packets to `generated/work-items/completed/` per invariant 37 (the `hive-sync` agent handles this when filed issues close on GitHub).
