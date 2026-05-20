---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0021", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0021"]
accepts: ADR-0021
wave: 1
initiative: adr-0021-knowledge-standup
node: honeydrunk-knowledge
---

# Chore: Add ADR-0021's six new invariants to the Grid constitution

## Summary

Add six new invariants derived from ADR-0021: downstream-coupling (D2), source-attribution-mandatory (D7), embedding-model-coherence (D6), confidence-scores-mandatory (D8), content-never-in-telemetry (D10), contract-shape-canary on all four surfaces (D12).

D8 (mandatory confidence scores) is elevated from Node-local to Grid-level for consistency with D7's treatment — both are interface-contract guarantees on `IRetrievalPipeline` results, and consumers (Lore, Sim, Agents, Evals) need to know the score contract is stable across providers and across the substrate's lifetime. Without elevation, providers could in principle ship without scores or with caller-opaque score semantics, defeating consumer-side thresholding. Treating D8 the same way D7 is treated (interface-contract guarantee → Grid invariant) keeps the contract surface coherent.

Default assigned numbers **57, 58, 59, 60, 61, 62** (next-actually-free band above current invariants.md high-water mark of 46 and above the bands already claimed by ADR-0020 Agents standup at 48-54 and ADR-0027 Notify Cloud standup at 51-56). Collision-check at edit time is still authoritative — see the section below.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Six rules govern Knowledge's first-shipping behavior:

- **Downstream coupling.** Composition against runtime / providers is host-time.
- **Source attribution mandatory.** Every retrieved chunk carries the `KnowledgeSource` identity, position, version. No anonymous retrieval.
- **Embedding-model coherence (level b).** Every `KnowledgeSource` records ingest-time model; retrieval against mismatched model errors or returns empty. Knowledge never produces cross-model similarity scores.
- **Confidence scores mandatory.** Every `IRetrievalPipeline` result carries a per-chunk relevance/confidence score. Knowledge does not threshold; consumers do.
- **Content never in telemetry.** Only metadata crosses the Pulse boundary.
- **Canary on all four surfaces.** Knowledge has a narrow boundary; all four are hot-path.

## Proposed Implementation

### `constitution/invariants.md` — append six new entries

Default 57-62. Use Option A (new `## AI Sector — Knowledge Invariants` section) or Option B (append to `## AI Invariants`). Mark each `(Proposed — this invariant takes effect when ADR-0021 is accepted)`.

```markdown
## AI Sector — Knowledge Invariants

57. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Knowledge.Abstractions`.**
    Composition against `HoneyDrunk.Knowledge` and any `HoneyDrunk.Knowledge.Providers.*` package is a host-time concern. See ADR-0021 D2 (Proposed — this invariant takes effect when ADR-0021 is accepted).

58. **Every retrieved chunk carries source attribution — the `KnowledgeSource` identity, the chunk's position within the source, and the source version.**
    The `IRetrievalPipeline` interface contract guarantees this; provider packages that cannot preserve attribution cannot implement `IKnowledgeStore`. No mode, flag, or provider returns an unattributed chunk. See ADR-0021 D7 (Proposed — this invariant takes effect when ADR-0021 is accepted).

59. **Every `KnowledgeSource` records the embedding-model identifier used at ingest time, and a retrieval against a mismatched model errors or returns empty.**
    Knowledge never produces a cross-model similarity score. Re-ingesting a source under a new embedding model is treated as a new version. See ADR-0021 D6 (Proposed — this invariant takes effect when ADR-0021 is accepted).

60. **Every `IRetrievalPipeline` result carries a per-chunk relevance/confidence score; Knowledge applies no cutoff threshold.**
    Thresholding is a consumer concern (Lore, Sim, Agents, Evals each pick their own cutoff). Provider packages that cannot expose a stable score for every returned chunk cannot implement `IKnowledgeStore` or back `IRetrievalPipeline`. The score contract is part of the interface so consumer-side thresholding is portable across providers. See ADR-0021 D8 (Proposed — this invariant takes effect when ADR-0021 is accepted).

61. **Knowledge content never appears in telemetry.**
    Only metadata — source id, chunk count, query latency, result count, model identifier — may cross the telemetry boundary. Document text, chunk contents, query text, and retrieved chunk contents are NEVER carried in Pulse signals. The separation is structural, not advisory: the telemetry activity factory never receives content payloads from Knowledge code paths. See ADR-0021 D10 (Proposed — this invariant takes effect when ADR-0021 is accepted).

62. **The HoneyDrunk.Knowledge Node CI must include a contract-shape canary that fails the build on shape drift to `IKnowledgeStore`, `IDocumentIngester`, `IRetrievalPipeline`, or `KnowledgeSource` without a corresponding version bump.**
    These four are the hot path for every downstream consumer. Knowledge's boundary is narrow — all four surfaces are in the canary from stand-up because there is no lower-traffic tier to carve out. See ADR-0021 D12 (Proposed — this invariant takes effect when ADR-0021 is accepted).
```

### Collision check

The current high-water mark in `constitution/invariants.md` is **46** (`## AI Invariants` ends there). However, two in-flight standup initiatives have already claimed bands above 46:

- **ADR-0020 (Agents standup) — claims 48-54.** Packet 02 of `adr-0020-agents-standup` lands seven invariants. Confirmed in that packet's body and ADR-0020 Consequences.
- **ADR-0027 (Notify Cloud standup) — claims 51-56.** Packet 02 of `adr-0027-notify-cloud-standup` lands six invariants. The 51-56 band overlaps with Agents 48-54 — Notify Cloud's packet 02 explicitly notes the race and resolves via runtime collision-check at filing time.

To stay clear of both bands regardless of which lands first, **Knowledge's default band is 57-62** (six invariants). If at edit time either of the above has landed at different numbers, recompute against the actual high-water mark by running:

```bash
rg -nP '^\d+\.\s\*\*' constitution/invariants.md | tail -10
```

Then claim the next six free numbers. If the band shifts, update ADR-0021 Consequences + packet 03 source file in lockstep (pre-filing amendment carve-out per invariant 24).

### `CHANGELOG.md`

Append: `Architecture: Add invariants 57 (Knowledge downstream coupling), 58 (mandatory source attribution), 59 (embedding-model coherence at retrieval boundary), 60 (mandatory confidence scores on retrieval results), 61 (Knowledge content NEVER in telemetry), 62 (Knowledge contract-shape canary on all four surfaces) per ADR-0021 D2/D7/D6/D8/D10/D12.` (If the collision-check at edit time shifted the band, substitute the actual six numbers.)

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0021-stand-up-honeydrunk-knowledge-node.md` (only on shift)
- `generated/issue-packets/active/adr-0021-knowledge-standup/03-knowledge-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

## Acceptance Criteria
- [ ] Six invariants present, matching ADR-0021 D2/D7/D6/D8/D10/D12.
- [ ] D8 (mandatory confidence scores) is elevated to a Grid-level invariant alongside D7.
- [ ] Numbers verified via `rg -nP '^\d+\.\s\*\*' constitution/invariants.md | tail -10` and do not collide with bands claimed by other in-flight initiatives (ADR-0020 Agents 48-54, ADR-0027 Notify Cloud 51-56).
- [ ] `(Proposed — this invariant takes effect when ADR-0021 is accepted)` qualifier on each.
- [ ] On shift, ADR-0021 Consequences + packet 03 source file updated in lockstep (pre-filing amendment per invariant 24).
- [ ] `CHANGELOG.md` Unreleased updated.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0021 D2, D7, D6, D8, D10, D12.** Sources for invariants 57-62 respectively (default — collision-check at edit time is authoritative).

## Dependencies
- `packet:01`

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0021`, `constitution`

## Agent Handoff

**Objective:** Land six new ADR-0021-derived invariants (D2, D7, D6, D8, D10, D12). D8 is elevated to a Grid-level invariant alongside D7 for consistency in interface-contract guarantees on `IRetrievalPipeline` results.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Constraints:** Default 57-62; collision-check at edit time against ADR-0020 (Agents, 48-54) and ADR-0027 (Notify Cloud, 51-56). If the band shifts, update ADR-0021 Consequences + packet 03 source file in lockstep before filing (pre-filing amendment per invariant 24). `(Proposed — this invariant takes effect when ADR-0021 is accepted)` qualifier on each.

**Key Files:** `constitution/invariants.md`; conditional ADR-0021 + packet 03; `CHANGELOG.md`.

**Contracts:** None.
