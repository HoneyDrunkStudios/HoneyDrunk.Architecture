---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0022"]
dependencies: []
adrs: ["ADR-0022", "ADR-0020"]
accepts: ADR-0022
wave: 1
initiative: adr-0022-memory-standup
node: honeydrunk-memory
---

# Chore: Register HoneyDrunk.Memory's standup decisions in Architecture catalogs + fix short-term-memory ownership drift

## Summary

Reflect ADR-0022 in catalogs. Confirm three-interface contract set in `contracts.json` (no records at stand-up). Widen Memory→AI `consumes_detail` to include `IChatClient` alongside `IEmbeddingGenerator` per D5. Add `honeydrunk-agents` to `consumed_by_planned` (coordinated with ADR-0020 Agents→Memory edge). Refresh `grid-health.json` and `nodes.json`. **Fix the short-term-memory ownership drift** in `repos/HoneyDrunk.Memory/overview.md`, `repos/HoneyDrunk.Memory/boundaries.md`, and the Memory section of `constitution/ai-sector-architecture.md` — those previously describe Memory as owning short-term memory, but Position A from ADR-0022 D4/D7 (aligned with ADR-0020 D8) places short-term memory on `IAgentExecutionContext` (Agents-owned). Memory owns long-term only. Add `integration-points.md` and `active-work.md`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0022 establishes Memory's contract surface (D3) and Position A for the short-term/long-term boundary. Drift items:

1. **`contracts.json`** already lists three interfaces. Verify alignment; tighten descriptions per D5/D6.
2. **`relationships.json` Memory→AI `consumes_detail`** currently lists `IEmbeddingGenerator` alone; needs widening to include `IChatClient` (summarization path per D5).
3. **`relationships.json` `consumed_by_planned`** missing `honeydrunk-agents`.
4. **`repos/HoneyDrunk.Memory/overview.md`** lists short-term memory as Memory-owned. Per ADR-0022 D4/D7 (Position A) and ADR-0020 D8, that's wrong — short-term lives on `IAgentExecutionContext`.
5. **`repos/HoneyDrunk.Memory/boundaries.md`** same drift.
6. **`constitution/ai-sector-architecture.md`** Memory section same drift.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-memory` block

Verify and tighten:

```json
{
  "node": "honeydrunk-memory",
  "node_name": "HoneyDrunk.Memory",
  "package": "HoneyDrunk.Memory.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IMemoryStore", "kind": "interface", "description": "Write, read, search, delete, and supersede memory entries. The storage-facing surface that provider packages implement. Supersession is a D10-driven mechanism (re-embedding under a new model is supersession), introduced at scaffold per ADR-0022 D10. ADR-0022 D3 / D8 / D10." },
    { "name": "IMemoryScope", "kind": "interface", "description": "Scoped memory access — an agent only sees its authorized memories through a resolved scope. Gates cross-scope access via the Auth policy path per ADR-0022 D6. Escalate() routes through Auth's IAuthorizationPolicy." },
    { "name": "IMemorySummarizer", "kind": "interface", "description": "Compress memory entries beyond a configured threshold. Delegates embedding generation to IEmbeddingGenerator and summarization inference to IChatClient (both from HoneyDrunk.AI per ADR-0022 D5). Public so consumers can swap the summarization strategy." }
  ]
}
```

No records at stand-up per D3. The `MemoryEntry` record (carrying the per-entry embedding-model identifier per D10) is deferred to the scaffold packet.

### `catalogs/relationships.json` — `honeydrunk-memory` block

**(a) `consumes_detail.honeydrunk-ai`.** Replace with:

```json
"honeydrunk-ai": ["IEmbeddingGenerator", "IChatClient", "HoneyDrunk.AI.Abstractions"]
```

(IChatClient added — Memory's summarizer uses chat completion per D5.)

**(b) `consumes`.** Confirm includes `honeydrunk-auth` (for scope escalation per D6). If missing, add. Also add per-edge `consumes_detail`:

```json
"honeydrunk-auth": ["IAuthorizationPolicy", "IAuthenticatedIdentityAccessor", "HoneyDrunk.Auth.Abstractions"]
```

**(c) `consumed_by_planned`.** Add `honeydrunk-agents` per ADR-0020 D6:

```json
"consumed_by_planned": ["honeydrunk-agents", "honeydrunk-flow", "honeydrunk-sim", "honeydrunk-evals", "honeydrunk-lore"]
```

`consumed_by_planned` is a list of node names. **No `consumes_detail` block is added for the planned consumers under ADR-0023/0024/0025**, because those ADRs are still Proposed — their D-shaped detail will land in their own standup packets, not this catalog edit. The list stays at:

```json
"consumed_by_planned": ["honeydrunk-agents", "honeydrunk-flow", "honeydrunk-sim", "honeydrunk-evals", "honeydrunk-lore"]
```

Agents is the only `consumed_by_planned` consumer with a coordinated edge live today (ADR-0020 is Accepted; the open ADR-0020 Agents→Memory follow-up edge lands the Agents-side `consumes_detail` entry). Flow / Sim / Evals add their own `consumes_detail` blocks when their respective standup ADRs accept.

**(d) `exposes.packages`.** Confirm:

```json
"packages": ["HoneyDrunk.Memory.Abstractions", "HoneyDrunk.Memory", "HoneyDrunk.Memory.Providers.InMemory"]
```

### `catalogs/grid-health.json` — `honeydrunk-memory` block

Replace stub with standup-aware version naming the scaffold packet as blocker, the three D3 interfaces, the three packages, and the deferred `Providers.SqlServer` / `Providers.CosmosDB`.

### `catalogs/nodes.json` — `honeydrunk-memory` block

**(a) `grid_relationship`.** Replace with:

> `"grid_relationship": "Consumes Kernel (context, telemetry, TenantId / ProjectId strong types per ADR-0026 D1/D2), AI (IEmbeddingGenerator for similarity, IChatClient for summarization per ADR-0022 D5), Auth (IAuthorizationPolicy for IMemoryScope.Escalate() per ADR-0022 D6), Data (IRepository for non-in-memory persistence). Emits write / read / summarize / supersede telemetry consumed by Pulse — no runtime dependency on Pulse. Content NEVER appears in telemetry. Consumed by Agents (IAgentMemory composition), Flow (indirectly through Agents — no direct edge planned), Sim (fixture composition), Evals (fixture composition), Lore (persistent curation context). Short-term memory is owned by Agents's IAgentExecutionContext, NOT Memory (Position A from ADR-0022 D4/D7)."`

### `constitution/ai-sector-architecture.md` — Memory section

**(a) Key Contracts list** — three interfaces.

**(b) Depends-on:**

> `**Depends on:** Kernel (context, telemetry), AI (IEmbeddingGenerator + IChatClient per D5), Auth (IAuthorizationPolicy for scope escalation per D6), Data (IRepository for non-in-memory persistence)`
>
> `**Emits to (no runtime dependency):** Pulse (write / read / summarize / supersede metadata-only telemetry per D9 — content NEVER carried)`

**(c) Short-term-memory ownership note.** Add or update text to explicitly state:

> `**Short-term memory ownership:** Short-term, execution-scoped memory (in-progress conversation turns, current tool-call sequence, ephemeral context) lives on Agents's IAgentExecutionContext per ADR-0020 D8 and ADR-0022 D4/D7 (Position A). Memory owns long-term agent-generated content that must survive the end of an execution. Conversation transcripts that must persist across executions are written as MemoryEntry records through IMemoryStore.`

### `repos/HoneyDrunk.Memory/overview.md`

Remove any text describing Memory as owning short-term memory. Replace with the long-term-only statement above. Add a row for `HoneyDrunk.Memory.Providers.InMemory` to the Packages table.

### `repos/HoneyDrunk.Memory/boundaries.md`

Same short-term-memory ownership fix. Add a "What Memory does not own" subsection clarifying short-term lives on `IAgentExecutionContext`.

### `repos/HoneyDrunk.Memory/integration-points.md` — new file

Matching the template:

```markdown
# HoneyDrunk.Memory — Integration Points

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `IOperationContext`, telemetry | Context flow.
| **Kernel** | `TenantId`, `ProjectId` (strong types from `Kernel.Abstractions.Identity`) | Scope coordinates on `IMemoryScope` and `MemoryEntry` per ADR-0026 D1/D2. `Abstractions`-level consumption — Memory.Abstractions takes a NuGet ref on Kernel.Abstractions per invariant 1's allow-list.
| **AI** | `IEmbeddingGenerator` | Embedding for similarity-search at write and at read.
| **AI** | `IChatClient` | Summarization inference per D5.
| **Auth** | `IAuthorizationPolicy`, `IAuthenticatedIdentityAccessor` | Scope escalation per D6.
| **Data** | `IRepository`, `IUnitOfWork` | Non-in-memory persistence.

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IMemoryStore` | Agents, Sim, Evals, Lore | Storage-facing surface; providers implement.
| `IMemoryScope` | Agents | Authorization-window primitive. Escalate() routes through Auth.
| `IMemorySummarizer` | Agents (when configured) | Public so consumers swap summarization strategy.

## Emits (no runtime dependency)

| Signal | Consumer | Notes |
|--------|----------|-------|
| Write / read / summarize / supersede activities (metadata only) | **Pulse** | Per ADR-0022 D9. Content NEVER carried.

## Canary Coverage Required

- `Memory.Canary` → Kernel: `IGridContext` flow.
- `Memory.Canary` → AI: `IEmbeddingGenerator` + `IChatClient` invocation; embedding-model coherence per D10.
- `Memory.Canary` → Auth: scope-escalation rejection / approval through `IAuthorizationPolicy`.
- `Memory.Canary` → Data: persistence round-trip.
- `Memory.Canary` → contract-shape: canary on `IMemoryStore`, `IMemoryScope`, `IMemorySummarizer`.

## Dependency Order for Bring-Up

1. Kernel (Live)
2. AI Abstractions (must publish `IEmbeddingGenerator`, `IChatClient`)
3. Auth (Live)
4. Data (Live)

Memory is a hard prerequisite for: Agents (`IAgentMemory` composition), Sim / Evals (fixture composition), Lore (curation persistence).
```

### `repos/HoneyDrunk.Memory/active-work.md` — new file

### `initiatives/active-initiatives.md` — new entry

Standard format. Note the short-term-memory ownership fix and the coordinated edge with ADR-0020.

### `CHANGELOG.md` (Architecture repo)

Append: `Architecture: Register ADR-0022 standup decisions in catalogs (verify three-interface contract surface; widen Memory→AI consumes_detail to include IChatClient per D5; add Auth edge per D6; add honeydrunk-agents to consumed_by_planned; refresh grid-health.json and nodes.json; fix short-term-memory ownership drift in repos/HoneyDrunk.Memory/overview.md + boundaries.md + ai-sector-architecture.md per Position A from D4/D7 and ADR-0020 D8; new integration-points.md and active-work.md; active-initiatives.md gets the new initiative block). ADR-0022 stays Proposed.`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Memory/overview.md`
- `repos/HoneyDrunk.Memory/boundaries.md`
- `repos/HoneyDrunk.Memory/integration-points.md` (new)
- `repos/HoneyDrunk.Memory/active-work.md` (new)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] D3 three-interface surface preserved.
- [x] Position A (short-term in Agents, long-term in Memory) applied across all three docs.
- [x] `IMemoryScope` is Memory-owned (per D3).
- [x] AI edge widened to include IChatClient + IEmbeddingGenerator per D5.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-memory` block lists exactly the three D3 interfaces with descriptions tightened per D5/D6. `IMemoryStore` description names supersession as the D10-driven fifth operation. No records.
- [ ] `catalogs/relationships.json` `honeydrunk-memory.consumes_detail.honeydrunk-ai` includes both `IEmbeddingGenerator` and `IChatClient`.
- [ ] `catalogs/relationships.json` `honeydrunk-memory.consumes` includes `honeydrunk-auth`.
- [ ] `catalogs/relationships.json` `honeydrunk-memory.consumed_by_planned` includes `honeydrunk-agents`.
- [ ] `catalogs/relationships.json` `honeydrunk-memory.exposes.packages` includes `HoneyDrunk.Memory.Providers.InMemory`.
- [ ] `catalogs/grid-health.json` `honeydrunk-memory` reflects standup.
- [ ] `catalogs/nodes.json` `honeydrunk-memory.grid_relationship` includes the Position A note and the IChatClient widening.
- [ ] `constitution/ai-sector-architecture.md` Memory section reads Position A (short-term in Agents); Depends-on / Emits-to split present.
- [ ] `repos/HoneyDrunk.Memory/overview.md` does NOT claim Memory owns short-term memory. Carries the Position A statement.
- [ ] `repos/HoneyDrunk.Memory/boundaries.md` does NOT claim Memory owns short-term memory. Carries the "What Memory does not own" subsection.
- [ ] `repos/HoneyDrunk.Memory/integration-points.md` and `active-work.md` exist.
- [ ] `initiatives/active-initiatives.md` includes new entry.
- [ ] `CHANGELOG.md` Unreleased updated.
- [ ] `adrs/ADR-0022-stand-up-honeydrunk-memory-node.md` NOT modified — Status stays Proposed.

## Human Prerequisites
None.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 11:** One repo per Node.

## Referenced ADR Decisions

**ADR-0022 D3:** Three interfaces; no records at stand-up.

**ADR-0022 D4 / D7 (Position A):** Short-term memory on `IAgentExecutionContext`; Memory owns long-term only.

**ADR-0022 D5:** Embedding + summarization compose AI's `IEmbeddingGenerator` and `IChatClient`.

**ADR-0022 D6:** Scope escalation gated by Auth.

**ADR-0022 D9:** Content NEVER in telemetry.

**ADR-0020 D8 (referenced):** Execution-scope state lives on `IAgentExecutionContext`.

**ADR-0026 D1 / D2 (Accepted):** `TenantId` is a non-nullable ULID `readonly record struct` in `HoneyDrunk.Kernel.Abstractions.Identity`. Memory.Abstractions consumes the strong type for `IMemoryScope.TenantId` and `MemoryEntry.TenantId`. `ProjectId` follows the same pattern. `AgentId` stays `string` at scaffold pending Kernel-side strong type.

## Dependencies
None.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0022`

## Agent Handoff

**Objective:** Align catalogs with ADR-0022 D3-D9. Fix short-term-memory ownership drift across overview.md / boundaries.md / ai-sector-architecture.md.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Constraints:**
- **Position A is canonical.** Short-term memory lives on `IAgentExecutionContext` (Agents per ADR-0020 D8). Memory owns long-term only. Apply across all three docs.
- **AI edge widening is mandatory.** Both `IEmbeddingGenerator` (similarity) and `IChatClient` (summarization) per D5.
- **Auth edge is real.** `IAuthorizationPolicy` for scope escalation per D6.
- **No ADR Status flip.**
- **Coordinate with ADR-0020 Agents→Memory edge.** Both sides of the edge land in one reconciliation pass.

**Key Files:** All listed above.

**Contracts:** None authored.
