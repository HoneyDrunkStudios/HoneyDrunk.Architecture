---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0021"]
dependencies: []
adrs: ["ADR-0021"]
accepts: ADR-0021
wave: 1
initiative: adr-0021-knowledge-standup
node: honeydrunk-knowledge
---

# Chore: Register HoneyDrunk.Knowledge's standup decisions in Architecture catalogs

## Summary

Reflect ADR-0021's stand-up decisions in the canonical Architecture catalogs. Promote `IKnowledgeSource` interface → `KnowledgeSource` record per the grid-wide naming rule. Add `honeydrunk-agents` to `consumed_by_planned` (reconciles `catalogs/nodes.json` prose-vs-`relationships.json`-edges drift). Refresh `grid-health.json` and `nodes.json`. Add `integration-points.md` and `active-work.md` under `repos/HoneyDrunk.Knowledge/`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0021 establishes Knowledge's exposed contracts and the embedding-model coherence rule. Drift items:

1. **`contracts.json`** lists `IKnowledgeSource` as an interface. Per D3 and the grid-wide naming rule, it's a record — rename to `KnowledgeSource` with `kind: "type"`.
2. **`relationships.json` `exposes.contracts`** uses the same name — rename to `KnowledgeSource`.
3. **`relationships.json` `consumed_by_planned`** has `honeydrunk-sim` and `honeydrunk-lore` but is missing `honeydrunk-agents` (and prose in `catalogs/nodes.json` says Agents + Lore + HoneyHub).
4. **`grid-health.json`** is a stub. Refresh.
5. **`constitution/ai-sector-architecture.md`** and `repos/HoneyDrunk.Knowledge/overview.md` reference `IKnowledgeSource` — replace with `KnowledgeSource`.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-knowledge` block

Replace with the four D3 surfaces:

```json
{
  "node": "honeydrunk-knowledge",
  "node_name": "HoneyDrunk.Knowledge",
  "package": "HoneyDrunk.Knowledge.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IKnowledgeStore", "kind": "interface", "description": "Ingest, query, and delete knowledge sources. Storage-facing surface that provider packages implement. ADR-0021 D3." },
    { "name": "IDocumentIngester", "kind": "interface", "description": "Parse and chunk documents; delegate embedding generation to IEmbeddingGenerator (HoneyDrunk.AI). ADR-0021 D3 / D5." },
    { "name": "IRetrievalPipeline", "kind": "interface", "description": "Query → ranked results with source attribution and confidence scores. The agent-facing and application-facing RAG entry point. ADR-0021 D3 / D7 / D8." },
    { "name": "KnowledgeSource", "kind": "type", "description": "Record. Metadata about an ingested source — origin, version, last-updated timestamp, embedding-model identifier (per ADR-0021 D6). Value type; no I prefix per the grid-wide naming rule." }
  ]
}
```

Drop the existing `IKnowledgeSource` interface entry.

### `catalogs/relationships.json` — `honeydrunk-knowledge` block

**(a) `exposes.contracts`.** Replace with:

```json
"contracts": ["IKnowledgeStore", "IDocumentIngester", "IRetrievalPipeline", "KnowledgeSource"]
```

(Drop `IKnowledgeSource`, add `KnowledgeSource`.)

**(b) `exposes.packages`.** Confirm includes `HoneyDrunk.Knowledge.Providers.InMemory`:

```json
"packages": ["HoneyDrunk.Knowledge.Abstractions", "HoneyDrunk.Knowledge", "HoneyDrunk.Knowledge.Providers.InMemory"]
```

**(c) `consumes_detail` widening (the AI edge).** Confirm AI `consumes_detail` includes `IEmbeddingGenerator` and `HoneyDrunk.AI.Abstractions`. If incomplete, set to:

```json
"honeydrunk-ai": ["IEmbeddingGenerator", "HoneyDrunk.AI.Abstractions"]
```

**(d) `consumed_by_planned`.** Currently `["honeydrunk-sim", "honeydrunk-lore"]`. Replace with:

```json
"consumed_by_planned": ["honeydrunk-sim", "honeydrunk-lore", "honeydrunk-agents", "honeydrunk-evals"]
```

Add per-edge `consumes_detail`:

- Agents: `["IRetrievalPipeline", "HoneyDrunk.Knowledge.Abstractions"]` (Agents composes Knowledge via `IRetrievalPipeline` for grounded-context retrieval)
- Evals: `["IRetrievalPipeline", "HoneyDrunk.Knowledge.Abstractions"]` (Evals composes deterministic retrieval fixtures via Abstractions)
- Sim: `["IKnowledgeStore", "HoneyDrunk.Knowledge.Abstractions"]` — Sim consumes the contract surface only; provider composition (e.g. `Providers.InMemory`) is host-time per the Knowledge downstream-coupling invariant (see packet 02)
- Lore: `["IRetrievalPipeline", "IKnowledgeStore", "HoneyDrunk.Knowledge.Abstractions"]`

Per the Knowledge downstream-coupling invariant landing in packet 02, downstream Nodes depend on `HoneyDrunk.Knowledge.Abstractions` only. Any specific provider package (`Providers.InMemory`, future `Providers.AzureAISearch`, etc.) is composed at host time and does not appear in `consumes_detail`.

**Prose-only consumer.** `honeydrunk-honeyhub` is NOT added to `consumed_by_planned` (per ADR-0021 framing it is mentioned in prose only — "HoneyHub when live" — and does not create a catalog edge at stand-up). This mirrors how ADR-0020 treated HoneyHub in the Agents stand-up.

### `catalogs/grid-health.json` — `honeydrunk-knowledge` block

Replace existing stub:

```json
{
  "id": "honeydrunk-knowledge",
  "name": "HoneyDrunk.Knowledge",
  "sector": "AI",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["Scaffold packet (Knowledge#NN — packet 03 of adr-0021-knowledge-standup) not yet executed", "Hard cross-initiative dependency on adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold — packet 03 will not file until the AI scaffold packet's GitHub Issue exists"],
  "notes": "ADR-0021 standup ADR Proposed 2026-04-19. Catalog surface registered (3 interfaces + 1 record per D3: IKnowledgeStore, IDocumentIngester, IRetrievalPipeline, KnowledgeSource). IKnowledgeSource interface promoted to KnowledgeSource record per the grid-wide naming rule. Awaiting scaffold: HoneyDrunk.Knowledge.Abstractions, HoneyDrunk.Knowledge runtime (default store, ingester, retrieval pipeline composing AI's IEmbeddingGenerator), HoneyDrunk.Knowledge.Providers.InMemory backend, Standards wiring, CI with contract-shape canary scoped to all 4 surfaces. Providers.AzureAISearch and Providers.PostgresVector deferred to follow-up packets."
}
```

### `catalogs/nodes.json` — `honeydrunk-knowledge` block

**(a) `grid_relationship`.** Replace with:

> `"grid_relationship": "Consumes Kernel (context, telemetry), Data (IRepository for knowledge-source storage), AI (IEmbeddingGenerator for chunk and query embeddings per ADR-0021 D5). Emits ingestion / retrieval / store-mutation telemetry consumed by Pulse — no runtime dependency on Pulse (ADR-0021 D10). Content NEVER appears in telemetry — metadata only. Consumed by Lore (wiki compilation), Sim (scenario-driven retrieval against deterministic fixtures), Agents (grounded-context retrieval), Evals (retrieval-quality suites), HoneyHub (when live, prose-only at stand-up)."`

**(b) `roadmap_focus`.** Reconcile against D3 — name `KnowledgeSource` not `IKnowledgeSource`.

### `constitution/ai-sector-architecture.md` — Knowledge section

Update Key Contracts list — three interfaces + `KnowledgeSource` (record). Add Depends-on / Emits-to split. Note the embedding-model coherence rule (D6) and the "Knowledge content never appears in telemetry" rule (D10).

### `repos/HoneyDrunk.Knowledge/overview.md`

Replace `IKnowledgeSource` references with `KnowledgeSource`. Add row for `HoneyDrunk.Knowledge.Providers.InMemory` to the Packages table. Add a note about the embedding-model coherence rule and the source attribution guarantee.

### `repos/HoneyDrunk.Knowledge/integration-points.md` — new file

Create matching the `repos/HoneyDrunk.Agents/integration-points.md` template:

```markdown
# HoneyDrunk.Knowledge — Integration Points

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `IOperationContext`, `INodeContext` | Every ingestion and retrieval operation runs inside a Grid context. |
| **Kernel** | `IStartupHook`, `IShutdownHook` | Knowledge store initialization at startup; graceful drain on shutdown. |
| **Kernel** | `ITelemetryActivityFactory` | Emits ingestion / retrieval / mutation activities. Pulse consumes. |
| **AI** | `IEmbeddingGenerator` | Chunk embedding at ingest; query embedding at retrieval. ADR-0016 D3 / ADR-0021 D5. |
| **Data** | `IRepository`, `IUnitOfWork` | Knowledge-source and chunk persistence (when not in-memory).

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IKnowledgeStore` | Lore (wiki storage), Sim (fixture seeding) | Storage-facing surface; provider packages implement.
| `IDocumentIngester` | Lore, Sim, application Nodes | Parse + chunk + embed.
| `IRetrievalPipeline` | Agents (grounded-context), Lore, Evals, HoneyHub when live | RAG entry point.
| `KnowledgeSource` | All consumers | Record. Travels with retrieved chunks for attribution.

## Emits (no runtime dependency)

| Signal | Consumer | Notes |
|--------|----------|-------|
| Ingest / retrieve / mutate activities (metadata only) | **Pulse** | Per ADR-0021 D10. Content NEVER appears in telemetry.

## Canary Coverage Required

- `Knowledge.Canary` → Kernel: `IGridContext` flow through ingestion + retrieval.
- `Knowledge.Canary` → AI: `IEmbeddingGenerator` invocation at ingest and retrieval; mismatched embedding-model errors per D6.
- `Knowledge.Canary` → Data: persistence round-trips through `IRepository`.
- `Knowledge.Canary` → contract-shape: CI canary fails on shape drift to `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, `KnowledgeSource` (ADR-0021 D12 / canary invariant — number assigned at acceptance).

## Dependency Order for Bring-Up

Knowledge cannot be scaffolded until:
1. Kernel (Live)
2. AI Abstractions (must publish `IEmbeddingGenerator`)
3. Data (Live)

Knowledge is a hard prerequisite for: Lore, Sim, Evals, Agents (retrieval), HoneyHub when live.
```

### `repos/HoneyDrunk.Knowledge/active-work.md` — new file (matching the Agents template)

### `initiatives/active-initiatives.md` — new entry

Standard format. Initiative `adr-0021-knowledge-standup`.

### `CHANGELOG.md` (Architecture repo)

Append: `Architecture: Register ADR-0021 standup decisions in catalogs (contracts.json promotes IKnowledgeSource interface → KnowledgeSource record per the grid-wide naming rule; relationships.json updates exposes.contracts, packages, and consumed_by_planned to add honeydrunk-agents and honeydrunk-evals; grid-health.json gets the standup block; nodes.json grid_relationship widens to reflect ADR-0021 D5/D10; ai-sector-architecture.md and repos/HoneyDrunk.Knowledge/overview.md adopt KnowledgeSource record; new integration-points.md and active-work.md filed; active-initiatives.md gets the new initiative block).`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Knowledge/overview.md`
- `repos/HoneyDrunk.Knowledge/integration-points.md` (new)
- `repos/HoneyDrunk.Knowledge/active-work.md` (new)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] `IKnowledgeSource` → `KnowledgeSource` rename applies the grid-wide naming rule.
- [x] D3 contract surface preserved (three interfaces + one record).
- [x] No code changes; metadata + docs only.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-knowledge` block lists exactly four surfaces: three interfaces + `KnowledgeSource` (record, `kind: "type"`). No `IKnowledgeSource` interface.
- [ ] `catalogs/relationships.json` `honeydrunk-knowledge.exposes.contracts` matches the same four surfaces.
- [ ] `catalogs/relationships.json` `honeydrunk-knowledge.exposes.packages` includes `HoneyDrunk.Knowledge.Providers.InMemory`.
- [ ] `catalogs/relationships.json` `honeydrunk-knowledge.consumed_by_planned` includes `honeydrunk-agents` and `honeydrunk-evals` alongside existing entries.
- [ ] `catalogs/grid-health.json` `honeydrunk-knowledge` block reflects standup.
- [ ] `catalogs/nodes.json` `honeydrunk-knowledge.grid_relationship` reflects D5/D10 phrasing.
- [ ] `constitution/ai-sector-architecture.md` Knowledge section reads `KnowledgeSource` not `IKnowledgeSource`; Depends-on / Emits-to split present.
- [ ] `repos/HoneyDrunk.Knowledge/overview.md` reads `KnowledgeSource`; Packages table includes `Providers.InMemory`.
- [ ] `repos/HoneyDrunk.Knowledge/integration-points.md` and `active-work.md` exist.
- [ ] `initiatives/active-initiatives.md` includes new entry.
- [ ] `CHANGELOG.md` Unreleased updated.
- [ ] `rg -n "IKnowledgeSource" catalogs/ repos/HoneyDrunk.Knowledge/ constitution/` returns zero matches.
- [ ] `rg -n "honeydrunk-honeyhub" catalogs/relationships.json` returns zero matches inside the `honeydrunk-knowledge` block's `consumed_by_planned` array (HoneyHub stays prose-only per ADR-0021 framing).
- [ ] ADR-0021 NOT modified — Status stays Proposed.

## Human Prerequisites
None.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 11:** One repo per Node.

## Referenced ADR Decisions

**ADR-0021 D3:** Four surfaces — three interfaces + `KnowledgeSource` record.

**ADR-0021 D5:** Embedding calls compose AI's `IEmbeddingGenerator`.

**ADR-0021 D6:** `KnowledgeSource` records ingest-time embedding-model identifier; retrieval against mismatched model errors.

**ADR-0021 D7:** Source attribution mandatory.

**ADR-0021 D10:** Knowledge content NEVER in telemetry.

## Dependencies
None.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0021`

## Agent Handoff

**Objective:** Align catalogs with ADR-0021 D3. Promote `IKnowledgeSource` interface → `KnowledgeSource` record. Add missing consumer edges.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Constraints:**
- **Records drop `I` prefix; interfaces keep it.** `KnowledgeSource` is a record (no `I`). The three interfaces keep `I`.
- **`kind: "type"` for the record, `kind: "interface"` for the three interfaces.** No `kind: "record"` anywhere.
- **No code; catalog + docs only.**
- **No ADR Status flip.**

**Key Files:** All listed above.

**Contracts:** None authored. Catalog-only.
