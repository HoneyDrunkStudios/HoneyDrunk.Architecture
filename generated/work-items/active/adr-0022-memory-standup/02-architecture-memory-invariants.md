---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0022", "constitution"]
dependencies: ["work-item:01"]
adrs: ["ADR-0022"]
accepts: ADR-0022
wave: 1
initiative: adr-0022-memory-standup
node: honeydrunk-memory
---

# Chore: Add ADR-0022's seven new invariants to the Grid constitution

## Summary

Add seven new invariants from ADR-0022: downstream-coupling (D2), no-Agent-state-outside-IMemoryStore (D7 + ADR-0020 D8), content-only-through-IMemoryStore (D8), embedding-model coherence at similarity retrieval (D10), content-never-in-telemetry (D9), scope-escalation gated by Auth + bulk-reads through Operator (D6), contract-shape canary on three surfaces (D12).

Default numbers **60, 61, 62, 63, 64, 65, 66** (assumes ADR-0018 + ADR-0020 + ADR-0021 have landed claiming 44-59; collision check decides).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Proposed Implementation

### `constitution/invariants.md` — append seven new entries

```markdown
## AI Sector — Memory Invariants

60. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Memory.Abstractions`.**
    Composition against `HoneyDrunk.Memory` and any `HoneyDrunk.Memory.Providers.*` package is a host-time concern. See ADR-0022 D2 (Proposed — this invariant takes effect when ADR-0022 is accepted).

61. **Agents never persist agent-generated state outside `IMemoryStore` and `IMemoryScope`.**
    Execution-scope state stays on `IAgentExecutionContext` per ADR-0020 D8 and is disposed when the execution ends. Anything that must survive the execution is written through Memory's surface. This includes cross-execution conversation transcripts — each turn is a `MemoryEntry`. See ADR-0022 D7 (Proposed — this invariant takes effect when ADR-0022 is accepted).

62. **Memory content never leaves the Node except through `IMemoryStore`.**
    Provider packages may not expose raw database handles, direct query surfaces, or any escape hatch that bypasses `IMemoryScope`. Every production path for reading or writing a memory goes through `IMemoryStore`, and `IMemoryStore` is the single surface where the scope check is applied. See ADR-0022 D8 (Proposed — this invariant takes effect when ADR-0022 is accepted).

63. **Every `MemoryEntry` records the embedding-model identifier used at write time, and similarity retrieval against a mismatched model errors or returns empty.**
    Memory never produces a cross-model similarity score. Re-embedding an entry under a new model is treated as supersession — the old entry is superseded and a new entry with the new identifier is written. See ADR-0022 D10 (Proposed — this invariant takes effect when ADR-0022 is accepted).

64. **Memory content never appears in telemetry.**
    Only metadata — scope coordinates, entry identity, entry size, query latency, result count, model identifier — may cross the telemetry boundary. Memory payload contents, query text, and retrieved entry contents are NEVER carried in Pulse signals. The separation is structural, not advisory. See ADR-0022 D9 (Proposed — this invariant takes effect when ADR-0022 is accepted).

65. **`IMemoryScope.Escalate()` is gated by Auth; bulk operational reads are gated by Operator's `IApprovalGate`.**
    Two distinct authorization paths for cross-scope access: scope escalation from within an agent path runs through `HoneyDrunk.Auth`'s `IAuthorizationPolicy` (synchronous, agent-runtime concern); bulk operational reads from outside an agent path raise an `ApprovalRequest` through `HoneyDrunk.Operator`'s `IApprovalGate` (asynchronous, human-policy concern). No escape path crosses scope without one of the two authorization paths. See ADR-0022 D6 (Proposed — this invariant takes effect when ADR-0022 is accepted).

66. **The HoneyDrunk.Memory Node CI must include a contract-shape canary that fails the build on shape drift to `IMemoryStore`, `IMemoryScope`, or `IMemorySummarizer` without a corresponding version bump.**
    These three are the hot path for every consumer that reads or writes agent memory. Memory's boundary is narrow — all three surfaces in the canary from stand-up. When the `MemoryEntry` record lands at scaffold, its shape is added to the canary the same way `KnowledgeSource` is in ADR-0021 D12. See ADR-0022 D12 (Proposed — this invariant takes effect when ADR-0022 is accepted).
```

### Collision check

Default 60-66. Shift on collision; update ADR-0022 Consequences + packet 03 source in lockstep. `rg` only.

### Lockstep update list (packet 03 cross-references on number shift)

If the seven invariants land at numbers other than 60-66, every cross-reference inside packet 03 must shift in the same commit. The complete cross-reference list in packet 03 is named below so nothing is missed during the lockstep edit. Each item is keyed by the **named invariant** (which never shifts) so the editor can find every callsite regardless of which number eventually lands:

| Named invariant | Default | Callsites in packet 03 |
|---|---|---|
| Memory downstream-coupling | 60 | Referenced Invariants block (`(default 60)` token) |
| Memory no-Agent-state-outside-`IMemoryStore` | 61 | Referenced Invariants block (`(default 61)` token) |
| Memory content-only-through-`IMemoryStore` | 62 | Boundary Check line ("number assigned by packet 02, default 62"); Referenced Invariants block (`(default 62)` token) |
| Memory embedding-coherence | 63 | Boundary Check line ("default 63"); Referenced Invariants block (`(default 63)` token) |
| Memory content-never-in-telemetry | 64 | Boundary Check line ("default 64"); Referenced Invariants block (`(default 64)` token) |
| Memory scope-escalation-gated | 65 | Referenced Invariants block (`(default 65)` token) |
| Memory contract-shape canary | 66 | Referenced Invariants block (`(default 66)` token) |

On shift, run `rg "default 6[0-6]"` and `rg "(invariant 6[0-6]|invariants? 6[0-6])"` against `generated/work-items/active/adr-0022-memory-standup/03-memory-node-scaffold.md` and ADR-0022 to confirm every callsite is rewritten. The named-token style (e.g., "Memory embedding-coherence invariant — number assigned by packet 02, default 63") keeps the text grammatical at both pre-shift and post-shift readings.

### `CHANGELOG.md`

Append: `Architecture: Add invariants 60-66 (Memory downstream coupling, no-direct-Agent-state-writes, content-only-through-IMemoryStore, embedding-coherence at similarity retrieval, content-never-in-telemetry, scope-escalation gated by Auth + bulk-reads gated by Operator, Memory contract-shape canary) per ADR-0022 D2/D7/D8/D10/D9/D6/D12.`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0022-stand-up-honeydrunk-memory-node.md` (only on shift)
- `generated/work-items/active/adr-0022-memory-standup/03-memory-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

## Acceptance Criteria
- [ ] Seven invariants present, matching ADR-0022.
- [ ] Numbers verified; default 60-66.
- [ ] `(Proposed — this invariant takes effect when ADR-0022 is accepted)` qualifier on each.
- [ ] On shift, ADR-0022 Consequences + packet 03 updated in lockstep.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0022 D2, D6, D7, D8, D9, D10, D12.** Sources for invariants 60-66.

## Dependencies
- `work-item:01`

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0022`, `constitution`

## Agent Handoff

**Objective:** Seven new invariants. Default 60-66. Shift on collision; lockstep updates.

**Constraints:** `(Proposed)` qualifier each. `rg` for collision checks.

**Key Files:** `constitution/invariants.md`; conditional ADR-0022 + packet 03; `CHANGELOG.md`.

**Contracts:** None.
