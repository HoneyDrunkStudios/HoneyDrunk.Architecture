---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0024", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0024"]
accepts: ADR-0024
wave: 1
initiative: adr-0024-flow-standup
node: honeydrunk-flow
---

# Chore: Add ADR-0024's nine new invariants to the Grid constitution

## Summary

Add nine new invariants from ADR-0024: downstream-coupling (D2/D8), multi-step-coordination-loop-lives-in-Flow-only (D1+D4), Flow-holds-coordination-state-only (D9), no-direct-Flow-Memory-edge (D9), Flow-delegates-outbound-messaging-to-Communications (D8), approval-pause-durable-no-sync-block (D7), `IWorkflowState`-durable-not-ephemeral (D12), Flow-Abstractions-no-Operator-or-Communications-dependency (D2+D8), contract-shape-canary-on-four-hot-paths (D11).

Default numbers **74-82** (assumes prior AI-sector initiatives landed claiming 44-73; collision check decides).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Proposed Implementation

### `constitution/invariants.md` — append nine new entries

```markdown
## AI Sector — Flow Invariants

74. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Flow.Abstractions`.**
    Composition against `HoneyDrunk.Flow` and any `HoneyDrunk.Flow.Providers.*` package is a host-time concern. See ADR-0024 D2, D8 (Proposed — this invariant takes effect when ADR-0024 is accepted).

75. **The multi-step coordination loop lives in `HoneyDrunk.Flow` and nowhere else.**
    No other AI-sector Node may introduce an equivalent loop of "step 1 → pause → step 2 → human approval → step 3." This parallels the function-calling loop rule in `HoneyDrunk.Agents` per ADR-0020 D12 / invariant 52 — each major coordination loop lives in one Node. See ADR-0024 D1, D4 (Proposed — this invariant takes effect when ADR-0024 is accepted).

76. **Flow holds coordination state only.**
    Agent state lives on `IAgentExecutionContext` (Agents per ADR-0020 D8); long-term agent memory lives in Memory; audit trail lives in Operator (or Audit per the ADR-0030/0031 amendment); knowledge sources live in Knowledge; outbound message history lives in Communications (and Notify). Flow's `IWorkflowState` records only the pipeline's own shape — current step, step outputs, checkpoints, compensation log, correlation chain. See ADR-0024 D9 (Proposed — this invariant takes effect when ADR-0024 is accepted).

77. **There is no direct `honeydrunk-flow` → `honeydrunk-memory` edge in `catalogs/relationships.json`.**
    When a workflow step invokes an agent, that agent writes Memory during its own execution — Memory is on Agents's runtime edge, not on Flow's. Adding a direct Flow → Memory edge would either duplicate Memory writes Agents already owns (drift) or give Flow a second Memory-access path that sees scopes Agents does not see (boundary violation). The edge, where it exists functionally, is indirect through Agents. See ADR-0024 D9 (Proposed — this invariant takes effect when ADR-0024 is accepted).

78. **Flow delegates outbound messaging to Communications.**
    No workflow step invokes `INotificationSender` directly; all message steps compose `ICommunicationOrchestrator` from `HoneyDrunk.Communications.Abstractions`. Channel selection, recipient resolution, preference checking, and cadence policy belong to Communications per ADR-0019. Bypassing Communications would either re-implement those concerns or skip them entirely. See ADR-0024 D8 (Proposed — this invariant takes effect when ADR-0024 is accepted).

79. **Approval-gated workflows pause durably; no synchronous block on `IApprovalGate`.**
    A `while (!await approvalGate.HasDecision()) { ... }` path kills durable workflow semantics — the blocked thread cannot survive a process restart. The event-out resume pattern is the correct shape: Flow records the pause in `IWorkflowState`, releases the thread, subscribes to the approval-decision event Operator emits per ADR-0018 D8. When the event lands, the engine rehydrates state and resumes from the step after the approval gate. See ADR-0024 D7 (Proposed — this invariant takes effect when ADR-0024 is accepted).

80. **`IWorkflowState` is durable, not ephemeral telemetry.**
    A workflow that pauses for human approval can wait hours or days; the state must survive process restart, deployment, host failover. Pulse signals record *that* a lifecycle event happened; `IWorkflowState` is the full artifact that resume must rehydrate. The storage substrate is deferred to scaffold per D12; the durability principle is not. See ADR-0024 D12 (Proposed — this invariant takes effect when ADR-0024 is accepted).

81. **`HoneyDrunk.Flow.Abstractions` does not take compile-time dependencies on `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Communications.Abstractions`.**
    Both are runtime-only edges consumed inside the default `HoneyDrunk.Flow` runtime package. Consumers compiling against `HoneyDrunk.Flow.Abstractions` do not inherit Operator or Communications transitively. The Agents `Abstractions` edge IS permitted per D2 because agent-step shapes legitimately need `IAgent`. The split between "agent shape lives in Abstractions" and "Operator / Communications composition lives in runtime" is deliberate and load-bearing for the downstream coupling rule. See ADR-0024 D2, D8 (Proposed — this invariant takes effect when ADR-0024 is accepted).

82. **The HoneyDrunk.Flow Node CI must include a contract-shape canary that fails the build on shape drift to `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, or `ICompensation` without a corresponding version bump.**
    These four are the hot path for every real consumer (Lore wiki, HoneyHub dispatch, application pipelines, Sim read-only, Evals workflow-target). `IWorkflowState` is not in the canary at stand-up because its shape is expected to evolve as the production state store lands and reveals persistence-layer requirements; it becomes a canary candidate later. See ADR-0024 D11 (Proposed — this invariant takes effect when ADR-0024 is accepted).
```

### Collision check

Default 74-82. Run `rg "^[0-9]+\\." constitution/invariants.md` to enumerate existing numbers; if 74-82 are not free, shift this block to the next free run and update **all** downstream references in lockstep.

**Downstream references to fix on shift** (exact lines in packet 03 source — verify before editing):

In `generated/issue-packets/active/adr-0024-flow-standup/03-flow-node-scaffold.md`:
- Line 167 — body prose: `(invariant 81)`
- Line 187 — body prose: `Per D8 / invariant 78`
- Line 229 — NuGet table: `accepted compile-time transitive reference per invariant 81`
- Line 257 — Boundary Check: `invariant 81 (ADR-0024 D2)`
- Line 259 — Boundary Check: `(invariant 77)`
- Line 260 — Boundary Check: `(invariant 78)`
- Line 261 — Boundary Check: `(invariant 79)`
- Line 262 — Boundary Check: `(invariant 80; production substrate follow-up)`
- Line 263 — Boundary Check: `(invariant 75)`
- Line 314 — Referenced Invariants: `(default 74)`
- Line 316 — Referenced Invariants: `(default 75)`
- Line 318 — Referenced Invariants: `(default 76)`
- Line 320 — Referenced Invariants: `(default 77)`
- Line 322 — Referenced Invariants: `(default 78)`
- Line 324 — Referenced Invariants: `(default 79)`
- Line 326 — Referenced Invariants: `(default 80)`
- Line 328 — Referenced Invariants: `(default 81)`
- Line 330 — Referenced Invariants: `(default 82)`
- Line 379 — Agent Handoff Constraints: `Invariant 81 (ADR-0024 D2)`
- Line 382 — Agent Handoff Constraints: `Invariant 77`
- Line 383 — Agent Handoff Constraints: `Invariant 78`
- Line 384 — Agent Handoff Constraints: `Invariant 79`

(Line numbers are as of this packet's authoring; re-run `rg -n "invariant 7[4-9]|invariant 8[0-2]|default 7[4-9]|default 8[0-2]" generated/issue-packets/active/adr-0024-flow-standup/03-flow-node-scaffold.md` immediately before editing to pick up any drift.)

Also update ADR-0024 source (any `Invariant 74-82` text in the `ADR-0024-stand-up-honeydrunk-flow-node.md` body) in the same PR. `rg` only.

### `CHANGELOG.md`

Append: `Architecture: Add invariants 74-82 (Flow downstream coupling, multi-step coordination loop in Flow only, Flow holds coordination state only, no direct Flow→Memory edge, Flow delegates outbound to Communications, approval-pause durable no synchronous block, IWorkflowState durable, Abstractions stays Operator/Communications-free, Flow contract-shape canary on four hot-path surfaces) per ADR-0024.`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0024-stand-up-honeydrunk-flow-node.md` (only on shift)
- `generated/issue-packets/active/adr-0024-flow-standup/03-flow-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

## Acceptance Criteria
- [ ] Nine invariants present matching ADR-0024.
- [ ] Numbers verified; default 74-82.
- [ ] `(Proposed — this invariant takes effect when ADR-0024 is accepted)` qualifier on each.
- [ ] On shift, ADR-0024 + packet 03 updated lockstep.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0024 D1, D2, D4, D7, D8, D9, D11, D12.** Sources for invariants 74-82.

## Dependencies
- `packet:01`

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0024`, `constitution`

## Agent Handoff

**Objective:** Nine new invariants. Default 74-82.

**Constraints:** `(Proposed)` qualifier each. `rg` only.

**Key Files:** `constitution/invariants.md`; conditional ADR-0024 + packet 03; `CHANGELOG.md`.

**Contracts:** None.
