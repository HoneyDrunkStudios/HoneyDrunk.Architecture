# Dispatch Plan — ADR-0072: Data Access Stance — EF Core Default, Dapper for Hot-Path Reads

**Initiative:** `adr-0072-data-access-stance`
**ADR:** ADR-0072 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0072 commits the Grid's data-access stance: **EF Core is the default ORM for every Node touching a relational store** (D1); **Dapper is the scoped exception** for hot-path reads where EF generates poor SQL or where allocation matters, with evidence required in the PR (D2); **EF Migrations is the migration tool** per ADR-0048 (D3); **per-Node DbContext, scoped composition** with the repository pattern on top (D4); **query discipline** — `AsNoTracking()` on reads, projections preferred, `Include` explicit, lazy loading off, raw SQL parameterized (D5); **testing discipline** — in-memory provider for unit, Testcontainers for integration including Dapper paths (D6); **migration path away** bounded by the `HoneyDrunk.Data` abstraction (D7); explicit **out of scope** items including specific engine choice, NoSQL access, and connection-resiliency policy (D8).

The ADR is a **policy / ratification** ADR. The committed implementation (EF Core via `HoneyDrunk.Data.EntityFramework`) already exists in the Data repo; this initiative ratifies it explicitly, lands the discipline in the `review` agent's rubric and the `database` specialist agent's rubric, and updates the Data Node's README/overview to make the stance discoverable.

**6 packets across 2 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Data`). All 6 are `Actor=Agent`, 0 `Actor=Human`. No Human Prerequisites in any packet — the work is pure docs/governance/rubric editing with no portal clicks or manual deploys. Packets 02 and 03b carry a **textual cross-initiative gate** on `adr-0048-schema-evolution` (the filing pipeline's `work-item:NN` form only resolves intra-initiative; cross-initiative sequencing is enforced by the executor at PR-open time).

## Trigger

ADR-0072 is Proposed with no scope. The forcing functions from the ADR's Context:

- **Most Nodes touching relational data are scaffolded but not yet in production**, so the question has not been forced at scale. The few that have data access today (Vault's secret cache backing, AI's cost-rate cache, Communications's pre-implementation preference store) all use ad-hoc compositions. The choice will be made implicitly by the first packet that lands; the precedent will be near-permanent.
- **ADR-0048 (Schema Evolution)** committed EF Migrations as the canonical migration tool. The ORM that owns the migration tool was implicit; ADR-0072 makes it explicit.
- **ADR-0049 (PII Handling)** introduced data-classification attributes on entity models. The classification mechanism assumed an ORM with model-attribute support — EF Core fits that shape natively; raw ADO.NET does not.
- **ADR-0060 (Identity standup)** introduces `IdentityMap`, `UserRecord`, `UserProfile`, `ExternalSubjectMap` — four tables needing EF-model-attribute support per ADR-0049.
- **ADR-0061 (Files standup)** introduces a blob-metadata table.
- **ADR-0030/0031 (Audit substrate)** — Audit's primary write path is append-only-by-interface; the underlying table is high-write, query-light, and one of the candidates that might be argued as a "Dapper-only" exception. Settling the default before Audit ships its production-grade backing matters.
- **ADR-0050 (Tenant lifecycle)** introduces per-tenant data partitions. The partition mechanic leans heavily on EF Core's DbContext model.

The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo (2 repos).** The policy lands in `HoneyDrunk.Architecture` (governance, ADR acceptance, `review` agent rubric, `database` specialist agent rubric, per-Node `overview.md` and `integration-points.md` updates) and `HoneyDrunk.Data` (the README + CHANGELOG ratification for the EF Core implementation that already exists).

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. The Identity / Files / Audit / Communications / Memory / Knowledge / Billing / Notify Cloud / Consumer-app PDR adoptions named in ADR-0072's Affected Nodes are deliberately **out of scope** for this initiative — each follows in its own standup ADR's track (ADR-0060 for Identity, ADR-0061 for Files, ADR-0031 for Audit, ADR-0019 for Communications, etc.). This initiative ships the foundation and the per-consumer adoption happens in each consumer's standup.

**No new contracts.** ADR-0072 introduces no Grid-wide runtime contracts. No `relationships.json` edge changes; no `contracts.json` interface additions. The existing `IRepository<T>` and `IUnitOfWork` in `HoneyDrunk.Data.Abstractions` are unchanged; ADR-0072 ratifies their EF Core implementation behind those abstractions.

**No new invariants.** ADR-0072 explicitly states in its Consequences/Invariants section: "No new Grid-wide invariants are introduced in `constitution/invariants.md`. The following are committed conventions enforced by the `review` agent's data-quality category per ADR-0044 D3." The conventions (EF Core default, writes through DbContext, `AsNoTracking()` on reads, per-Node DbContext, connection strings via Vault) are enforced at review-time, not codified as numbered invariants. Packet 00 records this stance and does not add invariants.

## Cross-Dependency with sibling ADRs

ADR-0072 references several sibling ADRs as live context:

- **ADR-0048 (Schema Evolution, Proposed)** — committed EF Migrations as the migration tool. ADR-0072 D3 ratifies the implicit ORM. **Strong conceptual coupling** but no hard packet dependency — ADR-0048 is itself Proposed and being scoped in the sibling initiative `adr-0048-schema-evolution`. The `database` specialist agent's rubric (the home for ADR-0072's review checks per packet 02) is being authored in `adr-0048-schema-evolution` packet 02. **Soft dependency** — if ADR-0048's `database` agent file lands first, this initiative's packet 02 amends it. If not, packet 02 documents the rubric additions to be incorporated when the agent file is authored. The two initiatives are sibling threads on the same Core/data sector; they can land independently but co-evolve.
- **ADR-0049 (PII Classification, Proposed)** — introduced data-classification attributes on entity models. ADR-0072 D1 cites ADR-0049 as one of the forcing functions for choosing an ORM with model-attribute support. **No hard packet dependency** — ADR-0049's classification attributes are documented; ADR-0072 ratifies the ORM that consumes them.
- **ADR-0044 (Cloud Code Review, Accepted) D3** — names the twenty-category review rubric. Category 13 (Data and persistence integrity) is the home for ADR-0072 D5's query-discipline checks. **Strong coupling** — packet 01 extends category 13 directly. ADR-0044 is Accepted; the rubric exists.
- **ADR-0046 (Specialist Review Agents, Proposed)** — names the pattern the `database` specialist agent follows. ADR-0072's review checks ride on top of the `database` agent created under ADR-0048. **Soft dependency** — ADR-0046 is Proposed; the pattern is documented regardless of status.
- **ADR-0047 (Testing Patterns, Accepted) D2 + D11** — names the in-memory provider for unit tests and Testcontainers for integration. ADR-0072 D6 cites both. **No hard dependency** — ADR-0047 is Accepted; the tiers exist.
- **ADR-0005 (Configuration and Secrets, Accepted)** — connection strings come from Vault via `ISecretStore`. ADR-0072 D4 ratifies this. **No hard dependency** — ADR-0005 is Accepted.
- **ADR-0050 (Tenant Lifecycle, Proposed)** — per-tenant DbContext composition. ADR-0072 D4 references this. **No hard dependency** — packet 04 documents the per-tenant DbContext as the canonical multi-tenant data-partition mechanic per ADR-0072 + ADR-0050; the implementation per Node ships under the relevant standup ADRs.
- **ADR-0042 (Idempotency, Proposed)** — names the Cosmos-backed `IIdempotencyStore`. ADR-0072 D8 explicitly carves NoSQL out of scope; document-store backings have their own SDKs (StackExchange.Redis, Microsoft.Azure.Cosmos). **No coupling** — ADR-0072 commits the relational ORM only; document-store access remains per-backing.

**No cross-initiative `dependencies:` edges in this initiative's packets.** The cross-ADR relationships above are conceptual and documentation-level; the filing pipeline does not need to wire `addBlockedBy` between this initiative and the sibling initiatives. The packets cite each sibling ADR by ID in the body for traceability.

## Wave Diagram

### Wave 1 (Foundation — acceptance)
- [ ] **00** — Architecture: Accept ADR-0072 — flip status, register the initiative. No invariants per ADR's explicit stance. `Actor=Agent`.

### Wave 2 (Rubric updates + Data Node ratification — parallel where unblocked)
- [ ] **01** — Architecture: extend `.claude/agents/review.md` D3 category 13 (Data and persistence integrity) with the ADR-0072 D5 query-discipline checks + the D2 Dapper-evidence-burden check. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: extend the `database` specialist agent's rubric (authored under sibling initiative `adr-0048-schema-evolution` packet 02) with the ADR-0072 D2/D5 ORM-choice and query-discipline categories. **Hard sibling sequencing**: this packet is gated on `adr-0048-schema-evolution` packet 02 having merged. Executor confirms `.claude/agents/database.md` exists on `main` before opening the PR. No holding-document fallback. `Actor=Agent`. Blocked by: 00 + textual gate on sibling adr-0048 packet 02.
- [ ] **03a** — Architecture: update `repos/HoneyDrunk.Data/overview.md` to record EF Core as the ratified ORM behind `IRepository<T>` / `IUnitOfWork`. Single-file packet; standalone-actionable. `Actor=Agent`. Blocked by: 00.
- [ ] **03b** — Architecture: extend every per-Node `integration-points.md` with a `## Data-Access Stance` section. **Hard sibling sequencing**: gated on `adr-0048-schema-evolution` packet 01 having merged (that packet introduces `## Migration Coordination` and the `schema_evolution` catalog field). Executor confirms both artifacts exist on `main` before opening the PR. `Actor=Agent`. Blocked by: 00 + textual gate on sibling adr-0048 packet 01.
- [ ] **04** — Data: ratify EF Core as the implementation behind `IRepository<T>` / `IUnitOfWork` in the Data repo — update `HoneyDrunk.Data/README.md`, `HoneyDrunk.Data.EntityFramework/README.md`, and the per-package CHANGELOG(s) to cite ADR-0072; add a Data-Access Stance section to the repo-level README documenting the EF Core default and the Dapper exception. `Actor=Agent`. Blocked by: 00.

Within Wave 2, packets **01**, **03a**, and **04** are independently actionable once **00** merges. Packets **02** and **03b** carry textual cross-initiative gates and may queue until the relevant `adr-0048-schema-evolution` packet merges. **Packet 01** edits `review.md`'s category 13 stanza; **packet 02** edits the `database` agent file; **packet 03a** edits `repos/HoneyDrunk.Data/overview.md`; **packet 03b** edits per-Node `integration-points.md` files; **packet 04** edits the Data repo's own README/CHANGELOG. No cross-packet edits to the same file inside this initiative.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0072](./00-architecture-adr-0072-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [review.md D3 category 13 — EF discipline + Dapper evidence checks](./01-architecture-review-d3-category-13-ef-dapper-discipline.md) | Architecture | Agent | 2 | 00 |
| 02 | [`database` specialist agent rubric — ORM-choice and query-discipline categories](./02-architecture-database-agent-orm-and-query-discipline.md) | Architecture | Agent | 2 | 00 + textual gate on `adr-0048-schema-evolution` packet 02 |
| 03a | [`repos/HoneyDrunk.Data/overview.md` ORM Commitment](./03a-architecture-data-overview-orm-commitment.md) | Architecture | Agent | 2 | 00 |
| 03b | [Per-Node `integration-points.md` Data-Access Stance sweep](./03b-architecture-integration-points-data-access-stance-sweep.md) | Architecture | Agent | 2 | 00 + textual gate on `adr-0048-schema-evolution` packet 01 |
| 04 | [Data repo ratification: EF Core README/CHANGELOG citing ADR-0072](./04-data-ratify-ef-core-readme-and-changelog.md) | Data | Agent | 2 | 00 |

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution. Catalog/doc/governance/agent edits only (packets 00, 01, 02, 03).
- **`HoneyDrunk.Data`** — packet 04 is docs-only (README + CHANGELOG citations). **No version bump for docs alone** per invariants 12/27; if a Data release is already in flight, the doc rides along. Confirm at execution time.

## Cross-Cutting Concerns

### Coupling with the `adr-0048-schema-evolution` initiative

ADR-0072 and ADR-0048 are tightly coupled by topic — schema evolution presupposes an ORM, and ratifying the ORM presupposes a schema-evolution story. The two initiatives ship coupled artifacts:

- **`database` specialist agent file** — authored under `adr-0048-schema-evolution` packet 02. ADR-0072's packet 02 adds rubric categories to that file. **Hard sequencing**: this initiative's packet 02 is gated textually on the sibling having merged; no holding-document fallback.
- **`integration-points.md` per-Node section** — `adr-0048-schema-evolution` packet 01 adds a `## Migration Coordination` section. ADR-0072's packet 03b adds a sibling `## Data-Access Stance` section so the per-Node ORM posture and the per-Node migration framework are recorded side-by-side. **Hard sequencing**: this initiative's packet 03b is gated textually on the sibling having merged.
- **`catalogs/grid-health.json` `schema_evolution` field** — `adr-0048-schema-evolution` packet 01 adds this field. ADR-0072's stance overlaps semantically — a Node with `schema_evolution: ef-core-migrations` is by definition on the EF Core ORM per ADR-0072 D1. No additional `data_access` field is added in this initiative; the `schema_evolution` field's value implies the ORM choice. Packet 03b reads the field to determine per-Node defaults — another reason for the sibling gate.

**Sequencing.** This initiative's standalone-actionable packets (00, 01, 03a, 04) can land independently of `adr-0048-schema-evolution`. Packets 02 and 03b carry **hard textual gates** on the sibling — packet 02 on sibling packet 02 (the `database.md` agent file), and packet 03b on sibling packet 01 (`## Migration Coordination` + `schema_evolution`). The filing pipeline's `work-item:NN` form does not resolve cross-initiative, so these gates are enforced by the executor at PR-open time: leave the issue open with a wait comment until the sibling artifact exists on `main`.

### Identity, Files, Audit, Communications, Memory, Knowledge, Billing, Notify Cloud, Consumer-app PDRs — deliberate deferral

ADR-0072's Affected Nodes section names Identity (ADR-0060), Files (ADR-0061), Audit (ADR-0030/0031), Communications (ADR-0019), Notify Cloud (ADR-0027), consumer-app PDRs (PDR-0003, PDR-0005, PDR-0006, PDR-0008) as future EF Core adopters. This initiative does **not** ship those adoptions, by design:

- **Each per-Node EF Core adoption is part of that Node's standup track**, not this initiative. Per the memory note "New-Node / standup work gets its own ADR; don't bundle into feature packets." ADR-0060's Identity standup is the place where `IdentityMap`/`UserRecord`/`UserProfile`/`ExternalSubjectMap` become EF Core models; ADR-0061's Files standup is where the blob-metadata table becomes an EF Core model; ADR-0031's Audit standup is where the primary write path lands as EF Core; and so on.
- **The Dapper hot-path read pilots** named in ADR-0072 D2 (Audit forensic queries, Notify Cloud send-history queries) are deliberately deferred — no production workload exists yet to provide the evidence that D2 requires for a Dapper introduction. The first Dapper introduction will be a per-Node packet with the benchmark evidence inline, reviewed by the `database` specialist agent (under the rubric this initiative ships in packet 02).

This initiative ships **the foundation** (governance, rubric, ratification). Every other consumer adopts the shipped policy in its own track. This keeps the initiative bounded and consistent with the Grid's standup-gets-its-own-ADR rule.

### The `EF Core LTS version` is not pinned here

ADR-0072 D1 says EF Core "current LTS, tracked to the .NET LTS cadence." Pinning an exact EF Core version (e.g. `9.0.x` vs `10.0.x`) is a per-Node SemVer concern and a Grid-wide LTS-cadence concern — not in this initiative's scope. The `database` agent's rubric (packet 02) and the Data repo's README (packet 04) refer to "EF Core current LTS" rather than pinning a number, so the docs are forward-stable across the .NET 8 → 10 → 12 LTS hops.

### NoSQL data-access stance — out of scope

ADR-0072 D8 explicitly carves NoSQL data-access out of scope. The Audit Node may use Cosmos DB per ADR-0031; the Kernel idempotency dedup store uses Cosmos per ADR-0042 D2; future caches may use Redis per ADR-0058. These NoSQL backings have their own SDKs (`Microsoft.Azure.Cosmos`, `StackExchange.Redis`, `Azure.Storage.Blobs`); EF Core's Cosmos provider is permitted but not required. The `database` specialist agent's rubric (packet 02) limits its ORM-choice check to relational stores; document-store schema concerns ride under ADR-0048 D7 (schema-on-read) instead.

### Connection-resiliency policies, read-replica routing, DbContext lifetime tuning — out of scope

ADR-0072 D8 explicitly defers these to per-Node decisions. Packets 01 and 02 do not add review checks for these; per-Node Nodes commit their own posture when the need arises (typically `EnableRetryOnFailure` for Azure SQL transient-fault handling; default `Scoped` DbContext lifetime; no read-replica routing today).

### Site sync

No site-sync flag. ADR-0072 is internal Core-sector infrastructure — no public-facing Studios website content changes.

### Deferred follow-ups (explicitly out of scope)

- **Identity / Files / Audit / Communications / Memory / Knowledge / Billing / Notify Cloud / consumer-app EF Core adoption** — each follows in its own standup ADR's track.
- **First Dapper hot-path read introduction** — a per-Node packet with benchmark evidence, when the workload data exists. Not in this initiative.
- **EF Core interceptor discipline as a Grid invariant** — ADR-0072's Alternatives Considered section notes this is deferred, not rejected. A follow-up ADR may commit a Grid-wide interceptor pattern once the patterns settle in production.
- **Marten as a backing option for one specific Node** — ADR-0072 keeps this open as a per-Node Node-specific choice (e.g. a future event-store-shaped Node); the Grid-wide default stays EF Core. No follow-up filed here.
- **Per-Node tutorial / template for "how to add an entity, write a migration, ship it in CI"** — named in ADR-0072's Follow-up Work as belonging to the DX-baseline ADR. Not in this initiative.

## Rollback Plan

- **Packet 00 (acceptance):** revert the PR. ADR returns to Proposed; the initiative entry in `active-initiatives.md` is removed. No invariants to roll back (none were added). No runtime impact.
- **Packet 01 (review.md D3 category 13):** revert the PR. The category 13 stanza returns to its prior state; the EF discipline + Dapper evidence checks are removed from the generalist `review` agent's rubric. The `database` specialist agent (if it exists from sibling initiative) still carries the depth checks per packet 02.
- **Packet 02 (`database` agent rubric):** revert the PR. The `database` agent file's ORM-choice and query-discipline categories are removed. The agent file itself stays (it belongs to the sibling initiative).
- **Packet 03a (Data overview ORM Commitment):** revert the PR. `repos/HoneyDrunk.Data/overview.md` returns to its prior state. No runtime impact.
- **Packet 03b (integration-points Data-Access Stance sweep):** revert the PR. Every modified `integration-points.md` loses its `## Data-Access Stance` section. The sibling `## Migration Coordination` sections remain. No runtime impact.
- **Packet 04 (Data repo ratification):** revert the PR. The Data repo's README and CHANGELOG citations of ADR-0072 are removed. No code change is reverted (the EF Core implementation pre-dates this initiative); only the documentation is removed.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
