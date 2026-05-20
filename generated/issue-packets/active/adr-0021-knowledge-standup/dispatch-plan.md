# Dispatch Plan — ADR-0021 HoneyDrunk.Knowledge Standup

**Initiative:** `adr-0021-knowledge-standup`
**Sector:** AI
**Governing ADR:** [ADR-0021 — Stand Up the HoneyDrunk.Knowledge Node](../../../../adrs/ADR-0021-stand-up-honeydrunk-knowledge-node.md) (Proposed 2026-04-19; flips to Accepted after this initiative's PRs merge).
**Trigger:** ADR-0021 in the Proposed queue. Sim, Lore, Agents (for grounded-context retrieval), HoneyHub when live, and Evals are blocked on `HoneyDrunk.Knowledge.Abstractions` existing.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Knowledge`)
**Site sync required:** No.
**Rollback plan:** Pre-tag `git revert`; post-tag prefer fix-forward as 0.1.1.

## Summary

ADR-0021 is the standup ADR for `HoneyDrunk.Knowledge`. It decides what the Node owns (D1), three package families (`Abstractions`, runtime, `Providers.InMemory` — no separate `Testing`) (D2), four exposed contracts — three interfaces and one record (D3 — `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, `KnowledgeSource`), boundary against AI/Memory/Lore/Sim/Agents (D4), embedding calls compose AI's `IEmbeddingGenerator` from `HoneyDrunk.AI.Abstractions` (D5 — the explicit accepted Abstractions-to-Abstractions edge), embedding-model coherence rule (D6 — `KnowledgeSource` records ingest-time model identifier; retrieval errors on mismatch), mandatory source attribution (D7 — elevated to Grid invariant), mandatory confidence scores (D8 — elevated to Grid invariant alongside D7 for consistency), state-boundary (D9 — Knowledge holds ingestion + retrieval state only), telemetry direction with content-never-in-telemetry rule (D10), content-safety deferred to Operator's `ISafetyFilter` on output side (D11), contract-shape canary on all four surfaces (D12).

Promotes `IKnowledgeSource` interface → `KnowledgeSource` record per the grid-wide naming rule.

Four packets land the work:

1. **Architecture catalog registration + integration-points** — promote `IKnowledgeSource` to `KnowledgeSource` record across `contracts.json` and `relationships.json`; reconcile prose-vs-edges drift (nodes.json mentions Agents + HoneyHub; relationships.json only lists Sim + Lore — add `honeydrunk-agents` to `consumed_by_planned`); refresh `grid-health.json`; align repo overview and AI sector doc to the four D3 surfaces; add `integration-points.md` and `active-work.md`.
2. **Constitution invariants** — six new invariants from D2, D7, D6, D8, D10, D12 at the next six free numbers (default band 57-62, above the bands claimed by ADR-0020 Agents standup at 48-54 and ADR-0027 Notify Cloud standup at 51-56; collision-check at edit time is authoritative). D8 (mandatory confidence scores) is elevated from Node-local to Grid-level for consistency with D7's treatment.
2b. **Verify `HoneyDrunk.Knowledge` repo + local clone (human-only)** — repo and clone exist; verify branch protection, labels, OIDC.
3. **HoneyDrunk.Knowledge scaffold** — empty repo to first-shippable. Solution, three packages (`Abstractions`, runtime, `Providers.InMemory`), four contracts in Abstractions, default `IKnowledgeStore` / `IDocumentIngester` / `IRetrievalPipeline` implementations in runtime that compose AI's `IEmbeddingGenerator`, in-memory backend in Providers.InMemory, five CI workflow files with the canary scoped to `HoneyDrunk.Knowledge.Abstractions`.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-knowledge-catalog-registration
   └─ Architecture: 02-architecture-knowledge-invariants
       Blocked by: 01

Wave 2: Verify repo + clone (human)
   └─ Architecture: 02b-architecture-verify-knowledge-repo
       Blocked by: 01

Wave 3: Knowledge repo scaffold
   └─ HoneyDrunk.Knowledge: 03-knowledge-node-scaffold
       Blocked by: 01, 02, 02b, adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold
```

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + IKnowledgeSource→KnowledgeSource promotion + integration-points](./01-architecture-knowledge-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add six new invariants for D2 / D7 / D6 / D8 / D10 / D12](./02-architecture-knowledge-invariants.md) | Architecture | 1 | Agent | 01 |
| 02b | [Verify HoneyDrunk.Knowledge repo + clone (human-only)](./02b-architecture-verify-knowledge-repo.md) | Architecture | 2 | Human | 01 |
| 03 | [Stand up `HoneyDrunk.Knowledge` — solution, three packages, contracts, CI, InMemory provider](./03-knowledge-node-scaffold.md) | HoneyDrunk.Knowledge | 3 | Agent | 01, 02, 02b, `adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold` |

## Filing-order rule

Packet 03 hard-codes invariant numbers (defaults 57-62) and carries a hard cross-initiative dependency on `adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold` (because Knowledge's Abstractions compiles against `HoneyDrunk.AI.Abstractions` per ADR-0021 D5). Packet 02 must merge first; if its collision-check shifts the band, packet 03 source file is amended in lockstep before filing (pre-filing carve-out per invariant 24). `file-packets.yml` will not file packet 03 until the AI scaffold packet's GitHub Issue exists.

## What This Initiative Does **NOT** Deliver

- Sim, Lore, Agents (retrieval composition), HoneyHub, Evals are not delivered.
- `Providers.AzureAISearch` and `Providers.PostgresVector` packages are **not first-wave**. They follow as separate packets once `Providers.InMemory` has exercised the slot shape and a real consumer drives the production-backend choice.
- Ingest-time content-safety scanning is deferred per D11 (Operator's `ISafetyFilter` on output side covers the immediate need).
- Level (c) router-level embedding-model pinning is deferred to ADR-0010's `IModelRouter` per D6.
- Pulse signal ingress into Knowledge is deferred (emit-only per D10).
- No separate `HoneyDrunk.Knowledge.Testing` package — `Providers.InMemory` plays that role per D2.

## AI-sector standup wave sequencing

Knowledge requires `HoneyDrunk.AI.Abstractions` for `IEmbeddingGenerator` consumption. Recommended landing order: AI → Capabilities → Operator → **Knowledge** + Memory (parallel) → Agents (depends on Knowledge, Memory) → Evals + Flow + Sim.

## Status flip

ADR-0021 stays Proposed for the duration; scope agent flips after all packets close.

## Filing

`file-packets.yml` auto-files on push.

## Archival

Per ADR-0008 D10, post-completion archive to `archive/adr-0021-knowledge-standup/`.
