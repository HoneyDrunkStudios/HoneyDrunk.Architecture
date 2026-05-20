---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0020"]
dependencies: []
adrs: ["ADR-0020"]
accepts: ADR-0020
wave: 1
initiative: adr-0020-agents-standup
node: honeydrunk-agents
---

# Chore: Register HoneyDrunk.Agents's standup decisions in Architecture catalogs

## Summary

Reflect ADR-0020's stand-up decisions in the canonical Architecture catalogs and the AI sector architecture doc. Verify (and tighten descriptions on) the five-interface contract set in `contracts.json`; add the missing `honeydrunk-memory` and `honeydrunk-operator` edges to `relationships.json` `consumes`; add `honeydrunk-actions` to `consumed_by_planned`; refresh `grid-health.json` and `nodes.json`; fix `repos/HoneyDrunk.Agents/boundaries.md` (incorrectly lists `IMemoryScope` as Agents-owned); fix `repos/HoneyDrunk.Agents/integration-points.md` canary description (Agents→AI is `IChatClient` direct, not via `IToolInvoker`); add `repos/HoneyDrunk.Agents/active-work.md` if not present.

ADR-0020 stays at `Status: Proposed` for this packet.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0020 establishes the Agents Node's exposed contracts, package families, and seven new invariants. None of that has reached the catalogs fully. Specific drift items:

1. **`contracts.json` already lists five interfaces** (`IAgent`, `IAgentExecutionContext`, `IAgentLifecycle`, `IToolInvoker`, `IAgentMemory`). Verify alignment with D3; tighten descriptions to reflect D5/D6/D7 compositions.
2. **`relationships.json` `consumes` is missing `honeydrunk-memory` and `honeydrunk-operator`** per D4 / D6 / D7. Both edges are real at the default-implementation layer.
3. **`relationships.json` `consumed_by_planned` is missing `honeydrunk-actions`** per the cloud-agent trigger path (ADR-0020 Unblocks).
4. **`repos/HoneyDrunk.Agents/boundaries.md` lists `IMemoryScope` under Agents-owned contracts.** Per ADR-0020 D6 and ADR-0022 D4, `IMemoryScope` is Memory's, not Agents's. Drift error.
5. **`repos/HoneyDrunk.Agents/integration-points.md` canary description for Agents→AI says** "verifies `IChatClient` is resolved through `IToolInvoker` mechanism." That's wrong. `IChatClient` is consumed directly from AI; `IToolInvoker` routes tool calls to Capabilities, not inference to AI.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-agents` block

The current entry already lists the five interfaces from D3. Verify and tighten descriptions:

```json
{
  "node": "honeydrunk-agents",
  "node_name": "HoneyDrunk.Agents",
  "package": "HoneyDrunk.Agents.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IAgent", "kind": "interface", "description": "Core agent interface — identity, capability declarations, execution entry point. Per ADR-0020 D3 / D4." },
    { "name": "IAgentExecutionContext", "kind": "interface", "description": "Agents-owned execution context extending Kernel's IOperationContext with AI-specific bindings (memory references, tool bindings, inference binding). Holds execution-scope state only per ADR-0020 D8." },
    { "name": "IAgentLifecycle", "kind": "interface", "description": "Lifecycle hooks for agents: register → initialize → execute → complete → decommission. ADR-0020 D3 / D11." },
    { "name": "IToolInvoker", "kind": "interface", "description": "How agents call tools — resolves through Capabilities's ICapabilityRegistry and dispatches through ICapabilityInvoker. Authorization flows through Capabilities's ICapabilityGuard per ADR-0020 D5." },
    { "name": "IAgentMemory", "kind": "interface", "description": "Memory read/write from the agent's perspective — backed by Memory Node storage via IMemoryScope and IMemoryStore per ADR-0020 D6. No persistence semantics in Agents itself." }
  ]
}
```

No records are added at stand-up per D3. Confirm that the schema has not introduced any `kind: "record"` entries.

### `catalogs/relationships.json` — `honeydrunk-agents` block

**(a) `consumes` array.** Current value listed at line 230 is `["honeydrunk-kernel", "honeydrunk-ai", "honeydrunk-capabilities"]`. Replace with:

```json
"consumes": ["honeydrunk-kernel", "honeydrunk-ai", "honeydrunk-capabilities", "honeydrunk-operator", "honeydrunk-memory"]
```

**(b) `consumes_detail`.** Add per-edge entries:

```json
"consumes_detail": {
  "honeydrunk-kernel": ["IGridContext", "IOperationContext", "ITelemetryActivityFactory", "HoneyDrunk.Kernel.Abstractions"],
  "honeydrunk-ai": ["IChatClient", "IEmbeddingGenerator", "ModelCapabilityDeclaration", "HoneyDrunk.AI.Abstractions"],
  "honeydrunk-capabilities": ["ICapabilityRegistry", "ICapabilityInvoker", "ICapabilityGuard", "HoneyDrunk.Capabilities.Abstractions"],
  "honeydrunk-operator": ["IApprovalGate", "ICircuitBreaker", "HoneyDrunk.Operator.Abstractions"],
  "honeydrunk-memory": ["IMemoryStore", "IMemoryScope", "HoneyDrunk.Memory.Abstractions"]
}
```

**(c) `consumed_by_planned` array.** Current value lists `["honeydrunk-flow", "honeydrunk-sim", "honeydrunk-lore"]`. Add `honeydrunk-actions` (cloud-agent trigger path per Unblocks) and `honeydrunk-evals`:

```json
"consumed_by_planned": ["honeydrunk-flow", "honeydrunk-sim", "honeydrunk-lore", "honeydrunk-actions", "honeydrunk-evals"]
```

**(d) `exposes.packages` array.** Add `HoneyDrunk.Agents.Testing` if not already present:

```json
"packages": ["HoneyDrunk.Agents.Abstractions", "HoneyDrunk.Agents", "HoneyDrunk.Agents.Testing"]
```

### `catalogs/grid-health.json` — `honeydrunk-agents` block

Replace the existing stub with:

```json
{
  "id": "honeydrunk-agents",
  "name": "HoneyDrunk.Agents",
  "sector": "AI",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["Scaffold packet (Agents#NN — packet 03 of adr-0020-agents-standup) not yet executed", "Upstream Abstractions packages (AI, Capabilities, Operator, Memory) may not all be published — packet 03 ships placeholder no-op for any missing upstream"],
  "notes": "ADR-0020 standup ADR Proposed 2026-04-19 (Status flip is post-merge housekeeping). Catalog surface registered (5 interfaces per D3: IAgent, IAgentExecutionContext, IAgentLifecycle, IToolInvoker, IAgentMemory). No records at stand-up — deferred to scaffold or later ADRs per D3. Awaiting scaffold: HoneyDrunk.Agents.Abstractions, HoneyDrunk.Agents runtime (default IAgent harness, in-process registry, IToolInvoker composing Capabilities, IAgentMemory composing Memory, function-calling adapter per D12), HoneyDrunk.Agents.Testing fixture, Standards wiring, CI with contract-shape canary scoped to four hot-path interfaces (IAgent, IAgentExecutionContext, IToolInvoker, IAgentMemory)."
}
```

### `catalogs/nodes.json` — `honeydrunk-agents` block

**(a) `grid_relationship`.** Replace with:

> `"grid_relationship": "Consumes Kernel (context, lifecycle, telemetry), AI (IChatClient, IEmbeddingGenerator, ModelCapabilityDeclaration for inference), Capabilities (ICapabilityRegistry / ICapabilityInvoker / ICapabilityGuard for tool dispatch), Operator (IApprovalGate / ICircuitBreaker for safety-gate composition), Memory (IMemoryStore / IMemoryScope for IAgentMemory composition). Emits lifecycle, execution, tool-invocation, gate-outcome, and memory-access telemetry consumed by Pulse — no runtime dependency on Pulse (ADR-0020 D9). Consumed by Flow (workflow-step agent invocation), Sim (scenario-driven agent runs), Lore (lore-side content generation), HoneyDrunk.Actions (cloud-agent trigger path), HoneyHub (when live), Evals (agent-behavior suites)."`

**(b) `tags`.** Confirm includes `agent-runtime`, `lifecycle`, `tool-invocation`, `function-calling`, `execution-context`.

### `constitution/ai-sector-architecture.md` — Agents section

Update Key Contracts list to match D3 (five interfaces). Update Depends-on:

> `**Depends on:** Kernel (context, lifecycle, telemetry), AI (IChatClient, IEmbeddingGenerator, ModelCapabilityDeclaration), Capabilities (ICapabilityRegistry / ICapabilityInvoker / ICapabilityGuard), Operator (IApprovalGate / ICircuitBreaker), Memory (IMemoryStore / IMemoryScope)`
>
> `**Emits to (no runtime dependency):** Pulse (lifecycle / execution / tool-invocation / gate-outcome / memory-access telemetry per call via Kernel's ITelemetryActivityFactory — ADR-0020 D9)`

### `repos/HoneyDrunk.Agents/boundaries.md` — `IMemoryScope` ownership fix

Locate the "What Agents Owns" section. Remove `IMemoryScope` from any list. Add a clarifying note:

> `Agents consumes `IMemoryScope` from `HoneyDrunk.Memory.Abstractions` for its `IAgentMemory` composition (per ADR-0020 D6). Agents does NOT own `IMemoryScope` — that contract is Memory's. Resolved scope flows through `IAgentMemory`; the scope primitive itself is Memory's authorization-window abstraction.`

### `repos/HoneyDrunk.Agents/integration-points.md` — canary description fix + App Config edge

**(a) Canary description fix.** Locate the Agents→AI canary line. Replace any phrasing like "verifies `IChatClient` is resolved through `IToolInvoker` mechanism, inference result is returned" with:

> `Agents.Canary → AI: verifies IChatClient (and IEmbeddingGenerator) are resolved directly from HoneyDrunk.AI.Abstractions and produce inference results. IChatClient is Agents's direct dependency on AI; IToolInvoker is a separate path (Agents → Capabilities for tool dispatch, NOT for inference).`

**(b) Add `Agents → App Config` edge under `## Consumes`.** The function-calling adapter (D12) reads per-`ModelCapabilityDeclaration` translation rules from Azure App Configuration via Vault's `IConfigProvider` — no per-provider adapter code is compiled in. This is a runtime composition concern; the `.Abstractions` package itself takes no dependency on App Config. Add the row:

> `| **Vault** | `IConfigProvider` | The function-calling adapter (D12) reads per-model translation rules from App Configuration via Vault's `IConfigProvider` so per-provider payload shape handling is operator-configurable without a redeploy. No compile-time dependency on App Config from Agents.Abstractions — runtime composition only. |`

### `repos/HoneyDrunk.Agents/active-work.md` — verify or create

If the file exists, add the scaffold packet as the active work item. If not, create it matching the `repos/HoneyDrunk.Knowledge/` template (will exist once that initiative lands; otherwise mirror Capabilities's).

### `initiatives/active-initiatives.md` — new entry

Add under `## In Progress`:

```markdown
### ADR-0020 HoneyDrunk.Agents Standup
**Status:** In Progress
**Scope:** Architecture, HoneyDrunk.Agents
**Initiative:** `adr-0020-agents-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Agents` as the AI sector's agent-runtime substrate per ADR-0020. Catalog reconciliation (add Memory + Operator to consumes, fix boundaries.md IMemoryScope ownership drift, fix integration-points.md Agents→AI canary description), seven new invariants for D2/D5/D6/D5/D6/D12/D13/D10, human-only repo verification + clone confirmation, and the scaffold packet (three packages: Abstractions, runtime, Testing; five contracts; function-calling adapter per D12). Unblocks Flow, Sim, Lore, HoneyDrunk.Actions cloud-agent trigger, HoneyHub when live, Evals.

**Tracking:**
- [ ] Architecture#NN: Catalog registration + boundary/integration-points fixes (packet 01)
- [ ] Architecture#NN: Add seven new invariants (packet 02)
- [ ] Architecture#NN: Verify HoneyDrunk.Agents repo + clone (human-only — packet 02b)
- [ ] Agents#NN: Scaffold HoneyDrunk.Agents (packet 03)

> **Sync (2026-MM-DD):** Initiative scoped. Packets 01/02/02b ready to file; packet 03 parked on packet 02 + 02b landing + upstream AI/Capabilities/Operator/Memory Abstractions being available.
```

### `CHANGELOG.md` (Architecture repo)

Append to Unreleased: `Architecture: Register ADR-0020 standup decisions in catalogs (contracts.json descriptions tightened for D3 alignment; relationships.json adds Memory + Operator to consumes, adds Actions + Evals to consumed_by_planned, adds Testing package; grid-health.json gets the standup block; nodes.json grid_relationship reflects D4/D9; ai-sector-architecture.md updates Agents Depends-on; repos/HoneyDrunk.Agents/boundaries.md fixes IMemoryScope ownership drift per D6; repos/HoneyDrunk.Agents/integration-points.md fixes Agents→AI canary description; active-initiatives.md gets the new initiative block). ADR-0020 stays Proposed.`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Agents/boundaries.md`
- `repos/HoneyDrunk.Agents/integration-points.md`
- `repos/HoneyDrunk.Agents/active-work.md` (verify/create)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes; metadata + docs only.
- [x] D3 five-interface surface preserved; descriptions tightened only.
- [x] `IMemoryScope` ownership corrected — Memory owns it, Agents consumes it.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-agents` block has exactly the five D3 interfaces with descriptions reflecting D4-D9.
- [ ] `catalogs/relationships.json` `honeydrunk-agents.consumes` includes `honeydrunk-memory` and `honeydrunk-operator`.
- [ ] `catalogs/relationships.json` `honeydrunk-agents.consumes_detail` has entries for all five consumed Nodes.
- [ ] `catalogs/relationships.json` `honeydrunk-agents.consumed_by_planned` includes `honeydrunk-actions` and `honeydrunk-evals`.
- [ ] `catalogs/relationships.json` `honeydrunk-agents.exposes.packages` includes `HoneyDrunk.Agents.Testing`.
- [ ] `catalogs/grid-health.json` `honeydrunk-agents` block reflects the standup ADR with scaffold packet as blocker.
- [ ] `catalogs/nodes.json` `honeydrunk-agents.grid_relationship` reflects D4/D9.
- [ ] `constitution/ai-sector-architecture.md` Agents section Key Contracts list = five D3 interfaces; Depends-on split into "Depends on" + "Emits to (no runtime dependency)".
- [ ] `repos/HoneyDrunk.Agents/boundaries.md` does NOT list `IMemoryScope` under Agents-owned contracts; carries clarifying note that Memory owns it.
- [ ] `repos/HoneyDrunk.Agents/integration-points.md` Agents→AI canary description does NOT say "through IToolInvoker" — describes `IChatClient` as direct dependency.
- [ ] `repos/HoneyDrunk.Agents/integration-points.md` `## Consumes` table includes a new `Vault | IConfigProvider` row covering the function-calling adapter's per-model translation rules sourced from App Configuration (D12).
- [ ] `repos/HoneyDrunk.Agents/active-work.md` exists.
- [ ] `initiatives/active-initiatives.md` includes new "ADR-0020 HoneyDrunk.Agents Standup" block.
- [ ] `CHANGELOG.md` Unreleased updated.
- [ ] `adrs/ADR-0020-stand-up-honeydrunk-agents-node.md` is NOT modified — Status stays Proposed.

## Human Prerequisites
None.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 4:** No circular dependencies. Kernel is always at the root.

> **Invariant 11:** One repo per Node.

## Referenced ADR Decisions

**ADR-0020 D3:** Five interfaces. No records at stand-up.

**ADR-0020 D4:** Boundary decision test against AI / Capabilities / Operator / Memory / Flow.

**ADR-0020 D5:** Tool invocation composes upstream — `IToolInvoker` adapts Capabilities.

**ADR-0020 D6:** Memory access composes upstream — `IAgentMemory` adapts Memory. `IMemoryScope` is Memory-owned.

**ADR-0020 D7:** Safety gate composition with Operator — invoke, not emit.

**ADR-0020 D9:** Telemetry emission — Pulse consumes, Agents does not depend.

**ADR-0020 Unblocks:** Cloud-agent trigger path via HoneyDrunk.Actions — adds `consumed_by_planned` edge.

## Dependencies
None.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0020`

## Agent Handoff

**Objective:** Bring `HoneyDrunk.Architecture` catalogs into alignment with ADR-0020 D3, D4, D5, D6, D7, D9. Fix the two drift items in `repos/HoneyDrunk.Agents/` (boundaries.md `IMemoryScope` ownership, integration-points.md canary description).

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Catalog drift blocks Agents's downstream consumers (Flow, Sim, Lore, Actions cloud-agent path, HoneyHub, Evals).
- Feature: ADR-0020 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0020 (sole standup).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.
- **`IMemoryScope` is Memory's, not Agents's.** Fix the drift in `boundaries.md`.
- **`IChatClient` is Agents → AI, not Agents → IToolInvoker → AI.** Fix the canary description in `integration-points.md`.
- **D3 says five interfaces and zero records at stand-up.** Verify catalog reflects this; do not add records.
- **No ADR Status flip in this packet.**

**Key Files:**
- `catalogs/contracts.json` — verify + tighten descriptions on `honeydrunk-agents`
- `catalogs/relationships.json` — `consumes` widening + `consumes_detail` + `consumed_by_planned` widening + packages
- `catalogs/grid-health.json` — replace `honeydrunk-agents` block
- `catalogs/nodes.json` — `grid_relationship`, `tags`
- `constitution/ai-sector-architecture.md` — Agents section
- `repos/HoneyDrunk.Agents/boundaries.md` — `IMemoryScope` ownership fix
- `repos/HoneyDrunk.Agents/integration-points.md` — canary description fix
- `repos/HoneyDrunk.Agents/active-work.md` — verify/create
- `initiatives/active-initiatives.md` — new entry
- `CHANGELOG.md`

**Contracts:** None authored. Catalog-only.
