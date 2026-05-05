---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0017"]
dependencies: []
adrs: ["ADR-0017"]
wave: 1
initiative: adr-0017-honeydrunk-capabilities-standup
node: honeydrunk-capabilities
---

# Chore: Register HoneyDrunk.Capabilities's standup decisions in Architecture catalogs

## Summary
Reflect ADR-0017's stand-up decisions in the canonical Architecture catalogs and the AI sector architecture doc. Reconcile `contracts.json` to drop the placeholder `ICapability` and `ICapabilityPermission` entries and add the four D3 contracts (`ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard`); update `relationships.json` exposes; refresh `grid-health.json` to reflect the standup; refresh `nodes.json` and `constitution/ai-sector-architecture.md` so Capabilities's contract list matches D3 (the existing `ICapabilityDescriptor` interface entry is replaced by `CapabilityDescriptor` record per the Grid-wide naming rule); refresh `repos/HoneyDrunk.Capabilities/overview.md` for the same naming rule; and add a new `repos/HoneyDrunk.Capabilities/integration-points.md` matching the template used by `repos/HoneyDrunk.Agents/integration-points.md`.

ADR-0017 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes, per the user's standing ADR acceptance workflow. This packet's body does not edit the ADR header.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0017 establishes the Capabilities Node's exposed contracts, package families, downstream-coupling rule, and the four invariants the scope agent finalizes at acceptance. None of that has reached the catalogs yet. Until it does, every downstream consumer (Agents, Operator, Memory, Knowledge, Evals) and every domain Node planning to register a callable tool reads stale or inconsistent metadata when scoping their own work.

Five specific drift items must be resolved in this packet:

1. **`contracts.json` lists `ICapability` and `ICapabilityPermission` as placeholders.** ADR-0017 D3 supersedes them with four separated surfaces — `ICapabilityRegistry`, `CapabilityDescriptor` (record, no `I` prefix), `ICapabilityInvoker`, `ICapabilityGuard`. The placeholder entries must be removed; the four D3 entries must be added.
2. **`catalogs/relationships.json`** currently lists `honeydrunk-capabilities`'s `exposes.contracts` as four entries: `ICapabilityRegistry`, `ICapabilityDescriptor` (interface form), `ICapabilityInvoker`, `ICapabilityGuard`. The middle entry must change to `CapabilityDescriptor` (record form, no `I` prefix). The downstream `honeydrunk-agents` entry's `consumes_detail.honeydrunk-capabilities` array must be re-checked against the new names.
3. **`catalogs/grid-health.json`** has a `honeydrunk-capabilities` block but only as a stub (`active_blockers: ["Repo not yet scaffolded"]`, `notes: "Tool registry, discovery, permissioning, versioning."`). It should reflect the standup ADR with the scaffold packet noted as the active blocker, the integration-points doc as filed, and the four D3 contracts as registered surface.
4. **`constitution/ai-sector-architecture.md`** Capabilities section (line 219+) lists `ICapabilityDescriptor` (interface) as a Key Contract. That must be replaced by `CapabilityDescriptor` (record) to match D3 and the Grid-wide naming rule.
5. **`repos/HoneyDrunk.Capabilities/overview.md`** lists `ICapabilityDescriptor` as a Key Interface. Same rename to `CapabilityDescriptor` (record).

In addition this packet:

- Adds a new `repos/HoneyDrunk.Capabilities/integration-points.md` because ADR-0017's "If Accepted" checklist explicitly requires it. The template is the existing `repos/HoneyDrunk.Agents/integration-points.md`.
- Updates `initiatives/active-initiatives.md` to add an "ADR-0017 HoneyDrunk.Capabilities Standup" entry under "In Progress".

The strict-Abstractions stance for `HoneyDrunk.Capabilities.Abstractions` (zero `HoneyDrunk.*` references; only `Microsoft.Extensions.*`) is already in the ADR text — D2 line 43 was edited directly to read `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.` before this packet was filed, and `repos/HoneyDrunk.Capabilities/invariants.md:5` already declares the same rule locally. No ADR amendment is needed here.

The ADR Status flip (Proposed → Accepted) is intentionally **not** in this packet. Per the user's standing ADR acceptance workflow, the scope agent flips Status only after the entire initiative's PRs have merged. This is a separate housekeeping step that runs after packets 01 / 02 / 03 / 04 are all closed — not a line-edit on this packet.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-capabilities` block

The current block (lines 209-217 of `catalogs/contracts.json`) reads:

```json
{
  "node": "honeydrunk-capabilities",
  "node_name": "HoneyDrunk.Capabilities",
  "package": "HoneyDrunk.Capabilities.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "ICapabilityRegistry", "kind": "interface", "description": "Discover and resolve available tools by name and version." },
    { "name": "ICapability", "kind": "interface", "description": "A registered tool — schema, version, executor, permission requirements." },
    { "name": "ICapabilityPermission", "kind": "interface", "description": "Authorization gate for a capability — checked before execution." }
  ]
}
```

Replace the `interfaces` array with exactly the four D3 contracts. Records lose the `I` prefix; interfaces keep it (Grid-wide naming rule). The block becomes:

```json
{
  "node": "honeydrunk-capabilities",
  "node_name": "HoneyDrunk.Capabilities",
  "package": "HoneyDrunk.Capabilities.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "ICapabilityRegistry", "kind": "interface", "description": "Register, discover, and resolve tool descriptors by `(name, version)`. Versioning is required (ADR-0017 D6); registry lookup is version-aware." },
    { "name": "CapabilityDescriptor", "kind": "type", "description": "Record. Machine-readable tool metadata — name, version, parameter schema, return schema, owning Node, permission requirements. Value type, no `I` prefix per the Grid-wide naming rule." },
    { "name": "ICapabilityInvoker", "kind": "interface", "description": "Dispatch a resolved capability invocation to its implementing Node and return the result. The invoker is gated by `ICapabilityGuard` before dispatch." },
    { "name": "ICapabilityGuard", "kind": "interface", "description": "Authorization gate — checked by the invoker before dispatch. Default implementation delegates to `HoneyDrunk.Auth` policy (ADR-0017 D5/D10); Capabilities does not maintain an independent permission model." }
  ]
}
```

Two surface-level changes vs current state:

- **Remove** `ICapability` and `ICapabilityPermission` (placeholder entries superseded by D3).
- **Add** `CapabilityDescriptor` (record) and `ICapabilityInvoker` (interface) and `ICapabilityGuard` (interface). `ICapabilityRegistry` stays but its description tightens to mention versioning per D6.

### `catalogs/relationships.json` — `honeydrunk-capabilities` block

Two edits to the block at lines 198-212.

**(a) `exposes.contracts` array (line 205).** Currently reads:

```json
"contracts": ["ICapabilityRegistry", "ICapabilityDescriptor", "ICapabilityInvoker", "ICapabilityGuard"]
```

Replace with:

```json
"contracts": ["ICapabilityRegistry", "CapabilityDescriptor", "ICapabilityInvoker", "ICapabilityGuard"]
```

The single-character change is the I-prefix drop on the descriptor record. The other three entries stay byte-for-byte identical.

**(b) `exposes.packages` array (line 206).** Currently reads:

```json
"packages": ["HoneyDrunk.Capabilities.Abstractions", "HoneyDrunk.Capabilities"]
```

Replace with:

```json
"packages": ["HoneyDrunk.Capabilities.Abstractions", "HoneyDrunk.Capabilities", "HoneyDrunk.Capabilities.Testing"]
```

This adds the `Testing` fixture package (ADR-0017 D2) — a separate NuGet artifact, not a `Providers.*` slot. Production composition references the runtime package; test projects reference `Testing` for the in-memory registry/dispatcher fixture per D9.

**(c) Downstream consumer entry — `honeydrunk-agents.consumes_detail.honeydrunk-capabilities`.** At line 226 the array currently reads:

```json
"honeydrunk-capabilities": ["ICapabilityRegistry", "ICapabilityInvoker", "HoneyDrunk.Capabilities.Abstractions"]
```

Verify it stays consistent with the four D3 contracts. The Agents Node does not necessarily consume `CapabilityDescriptor` directly (Agents consumes `IToolInvoker` from its own `Agents.Abstractions`, which internally resolves through `ICapabilityRegistry` per `repos/HoneyDrunk.Agents/integration-points.md`). No edit required to this array unless a future audit shows Agents reaches `CapabilityDescriptor` directly — that is a follow-up concern, not in scope for this packet.

### `catalogs/grid-health.json` — `honeydrunk-capabilities` block

The current block (lines 217-227) reads:

```json
{
  "id": "honeydrunk-capabilities",
  "name": "HoneyDrunk.Capabilities",
  "sector": "AI",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["Repo not yet scaffolded"],
  "notes": "Tool registry, discovery, permissioning, versioning."
}
```

Replace with:

```json
{
  "id": "honeydrunk-capabilities",
  "name": "HoneyDrunk.Capabilities",
  "sector": "AI",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["GitHub repo not yet created (Architecture#NN — packet 03 of adr-0017-honeydrunk-capabilities-standup)", "Scaffold packet (Capabilities#NN — packet 04 of adr-0017-honeydrunk-capabilities-standup) not yet executed"],
  "notes": "ADR-0017 standup ADR Proposed 2026-04-19 (Status flip to Accepted is a separate post-merge housekeeping step after the initiative completes). Catalog surface registered (4 contracts per D3: ICapabilityRegistry, CapabilityDescriptor, ICapabilityInvoker, ICapabilityGuard). Integration-points doc filed at repos/HoneyDrunk.Capabilities/integration-points.md. Awaiting GitHub repo creation (human-only) and scaffold execution: HoneyDrunk.Capabilities.Abstractions (4 contracts, zero HoneyDrunk dependencies), HoneyDrunk.Capabilities runtime (default registry, invoker, Auth-backed guard), HoneyDrunk.Capabilities.Testing (in-memory registry/dispatcher fixture), Standards wiring, CI with contract-shape canary scoped to Abstractions (D8)."
}
```

The `summary.blocked_nodes` list at lines 269-270 keeps `honeydrunk-capabilities` (it stays blocked until the scaffold packet executes) — no edit needed there, just confirm the entry remains.

### `catalogs/nodes.json` — `honeydrunk-capabilities` block

Two edits to this block.

**(a) `tags` (line 630).** Current text:

> `"tags": ["tools", "registry", "permissions", "discovery", "agent-tools", "versioning"],`

Replace with:

> `"tags": ["tools", "registry", "permissions", "discovery", "agent-tools", "versioning", "dispatch", "guard"],`

The `dispatch` and `guard` tokens reflect the D3 surface — the Node owns dispatch (`ICapabilityInvoker`) and authorization gating (`ICapabilityGuard`), not just registry and permissions.

**(b) `grid_relationship` (line 647).** Current text:

> `"grid_relationship": "Consumes Kernel (context, identity), Auth (authorization policies). Consumed by Agents (tool invocation).",`

Replace with:

> `"grid_relationship": "Consumes Kernel (context, identity) and Auth (authorization policy via ICapabilityGuard's default implementation). Emits registration/resolution/invocation telemetry consumed by Pulse — no runtime dependency on Pulse (ADR-0017 D7). Consumed by Agents (tool invocation), Operator (gating decisions before agent actions), Evals (deterministic test tools via HoneyDrunk.Capabilities.Testing), and any domain Node that registers a callable tool (Data, Notify, Vault, etc.).",`

Do not edit any line that describes telemetry as a value prop — the dependency-direction rule applies to `grid_relationship`, not to value-prop strings about what telemetry does.

### `constitution/ai-sector-architecture.md` — Capabilities section (lines 219-243)

Two edits to the Capabilities Node Definition.

**(a) Key Contracts list (lines 235-239).** Current block:

```
- `ICapabilityRegistry` — register, discover, resolve tools
- `ICapabilityDescriptor` — tool schema (name, parameters, return type, permissions)
- `ICapabilityInvoker` — execute a tool invocation
- `ICapabilityGuard` — permission check before invocation
```

Replace with:

```
- `ICapabilityRegistry` — register, discover, resolve tool descriptors by `(name, version)` (versioning required per ADR-0017 D6)
- `CapabilityDescriptor` — record. Tool schema (name, version, parameter schema, return schema, owning Node, permission requirements). Value type, no `I` prefix per the Grid-wide naming rule.
- `ICapabilityInvoker` — dispatch a resolved capability invocation to its implementing Node, gated by `ICapabilityGuard` before dispatch
- `ICapabilityGuard` — authorization gate. Default implementation delegates to `HoneyDrunk.Auth` policy; Capabilities does not maintain an independent permission model
```

**(b) Depends on phrasing (line 241).** Current text:

> `**Depends on:** Kernel (context, identity for permission checks), Auth (authorization policies)`

Replace with:

> `**Depends on:** Kernel (context, identity), Auth (authorization policy — `ICapabilityGuard`'s default delegates here per ADR-0017 D5/D10)`
>
> `**Emits to (no runtime dependency):** Pulse (registration, resolution, and invocation telemetry via Kernel's `ITelemetryActivityFactory` — ADR-0017 D7)`

Same one-way emission split as the AI sector doc applies to AI per ADR-0016 D7.

### `repos/HoneyDrunk.Capabilities/overview.md` — Key Interfaces table (lines 21-25)

Current block:

```
- `ICapabilityRegistry` — Register, discover, resolve tools
- `ICapabilityDescriptor` — Tool schema (name, parameters, return type, permissions)
- `ICapabilityInvoker` — Execute a tool invocation
- `ICapabilityGuard` — Permission check before invocation
```

Replace with:

```
- `ICapabilityRegistry` — Register, discover, resolve tool descriptors by `(name, version)`
- `CapabilityDescriptor` — Record. Tool metadata (name, version, parameter schema, return schema, owning Node, permission requirements). Value type, no `I` prefix.
- `ICapabilityInvoker` — Dispatch a resolved capability invocation to its implementing Node
- `ICapabilityGuard` — Authorization gate. Default implementation delegates to `HoneyDrunk.Auth` policy.
```

Also rename the section heading on line 19 from `## Key Interfaces` to `## Key Contracts` — the section now mixes interfaces and one record.

The Packages table (lines 13-17) currently lists two packages:

```
| `HoneyDrunk.Capabilities.Abstractions` | Abstractions | Zero-dependency tool contracts |
| `HoneyDrunk.Capabilities` | Runtime | Registry, discovery, dispatch, permission enforcement |
```

Add a third row for the `Testing` fixture package:

```
| `HoneyDrunk.Capabilities.Testing` | Testing fixture | Opt-in NuGet package — in-memory registry and dispatcher for downstream Nodes' deterministic unit and integration tests. Never composed into production hosts. |
```

The Design Notes paragraph at line 26 also mentions `IToolInvoker` (which lives in `Agents.Abstractions`, not Capabilities). That phrasing is correct as written — leave it alone.

### `repos/HoneyDrunk.Capabilities/integration-points.md` — new file

Create this file matching the template used by `repos/HoneyDrunk.Agents/integration-points.md`. The full content:

```markdown
# HoneyDrunk.Capabilities — Integration Points

How Capabilities connects to the rest of the Grid. Every item here represents a cross-Node boundary that requires a canary test.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `INodeContext`, `IOperationContext` | Every registry, resolution, and invocation operation runs inside a Grid context. CorrelationId flows through dispatch. |
| **Kernel** | `IStartupHook`, `IShutdownHook` | Registry initialization at startup; graceful drain on shutdown. |
| **Kernel** | `ITelemetryActivityFactory` | Emits per-call activities for registration, resolution, and invocation. Pulse consumes these — see Emits below. |
| **Auth** | `IAuthorizationPolicy`, `AuthorizationDecision` | The default `ICapabilityGuard` implementation delegates allow/deny decisions to Auth policy. Capabilities does not maintain an independent permission model.

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `ICapabilityRegistry` | Agents, Operator, Evals, domain Nodes registering tools | Register descriptors at startup; resolve by `(name, version)` at agent runtime. |
| `CapabilityDescriptor` | All consumers | Record carrying tool metadata. Travels through the registry, the invoker, and the guard. |
| `ICapabilityInvoker` | Agents (via `IToolInvoker`), Operator | Dispatch a resolved invocation. The default invoker checks `ICapabilityGuard` before dispatching. |
| `ICapabilityGuard` | Agents, Operator | Authorization gate. Production composition uses the Auth-backed default; tests use the `HoneyDrunk.Capabilities.Testing` in-memory permissive guard. |

## Emits (no runtime dependency)

| Signal | Consumer | Notes |
|--------|----------|-------|
| Registration / resolution / invocation activities | **Pulse** | Emitted via Kernel's `ITelemetryActivityFactory`. Capabilities has no runtime dependency on Pulse — direction is one-way by contract. |

## Canary Coverage Required

Before any Capabilities code can be considered production-ready:

- `Capabilities.Canary` → Kernel: verifies `IGridContext` flows through registry/resolver/invoker, CorrelationId is propagated to invoked tools.
- `Capabilities.Canary` → Auth: verifies `ICapabilityGuard`'s default implementation rejects when Auth policy denies, allows when Auth policy permits.
- `Capabilities.Canary` → contract-shape: contract-shape canary in CI fails the build if `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, or `ICapabilityGuard` change shape without a version bump (ADR-0017 D8 / invariant — number assigned at acceptance).

## Dependency Order for Bring-Up

Capabilities cannot be scaffolded until these Nodes have published their Abstractions packages:

1. Kernel (already Live — `HoneyDrunk.Kernel.Abstractions` stable)
2. Auth (already Live — `HoneyDrunk.Auth.Abstractions` stable)

Capabilities is itself a hard prerequisite for:

1. Agents (`HoneyDrunk.Agents.Abstractions` — Seed, blocked on Capabilities for `ICapabilityRegistry` resolution from `IToolInvoker`)
2. Operator (`HoneyDrunk.Operator.Abstractions` — Seed, blocked on Capabilities for guard composition)
3. Evals (`HoneyDrunk.Evals.Abstractions` — Seed, blocked on Capabilities for `Testing`-based deterministic tool fixtures)
4. Memory, Knowledge — soft prerequisite (each may register their query surfaces as tools post-stand-up)
5. Domain Nodes (Data, Notify, Vault) — soft prerequisite (each may register agent-callable tools post-stand-up)
```

The exact `_meta` layout, header levels, and table format mirror `repos/HoneyDrunk.Agents/integration-points.md` so the two files are diff-readable side-by-side.

### `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` — no edit in this packet

The ADR file is **not** edited in this packet:

- D2 line 43 already reads `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.` — that edit landed directly on the ADR file before this packet was filed (rationale: cleaner to fix the still-Proposed ADR text in place than to carry a one-line amendment in a catalog packet).
- The Status flip (Proposed → Accepted) is **not** part of this packet. Per the user's standing rule, the scope agent flips Status only after the entire initiative's PRs have merged. That is a separate post-merge housekeeping step. ADR-0017 stays Proposed throughout this run.

### `adrs/README.md` — no edit

The Status flip lands in a separate post-merge step, so the index needs no update from this packet either. If the index does carry a per-ADR Status column, the post-merge housekeeping step that flips the ADR file to Accepted also updates the index in the same commit.

### `initiatives/active-initiatives.md` — new entry

Add a new entry under `## In Progress`, immediately after the "ADR-0010 Observation Layer & AI Routing — Phase 1" block (so it sits next to the other in-progress AI-sector standup). The entry:

```markdown
### ADR-0017 HoneyDrunk.Capabilities Standup
**Status:** In Progress
**Scope:** Architecture, HoneyDrunk.Capabilities (new repo)
**Initiative:** `adr-0017-honeydrunk-capabilities-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Capabilities` as the AI sector's tool-registry and dispatch substrate per ADR-0017. Catalog reconciliation (drop placeholder `ICapability`/`ICapabilityPermission`, add four D3 contracts), four new invariants for D9 / D6 / D5+D10 / D8, human-only repo creation, and the scaffold packet (three packages: `Abstractions`, runtime, `Testing` fixture). Unblocks Agents, Operator, Memory, Knowledge, Evals, and any domain Node that registers a callable tool.

**Tracking:**
- [ ] Architecture#NN: Catalog registration + integration-points (packet 01)
- [ ] Architecture#NN: Add four new invariants for D9 / D6 / D5+D10 / D8 (packet 02)
- [ ] Architecture#NN: Create HoneyDrunk.Capabilities GitHub repo (human-only — packet 03)
- [ ] Capabilities#NN: Scaffold HoneyDrunk.Capabilities — solution, three packages, contracts, CI, in-memory testing fixture (packet 04)

> **Sync (2026-MM-DD):** Initiative scoped today. Packets 01-03 ready to file in Wave 1/2; packet 04 (Capabilities scaffold) parked on packets 02 + 03 landing — packet 02 because the scaffold body cites assigned invariant numbers, packet 03 because the repo must exist before file-packets.sh can target it.
```

Replace `2026-MM-DD` in the sync line with the date this packet's PR merges.

### `CHANGELOG.md` (Architecture repo)

Append to the Unreleased section:

`Architecture: Register ADR-0017 standup decisions in catalogs (contracts.json drops placeholder ICapability/ICapabilityPermission and adds four D3 contracts; relationships.json swaps ICapabilityDescriptor → CapabilityDescriptor and adds HoneyDrunk.Capabilities.Testing to exposes.packages; grid-health.json gets the standup block; nodes.json grid_relationship gets one-way Pulse phrasing per D7; ai-sector-architecture.md Capabilities section gets D3 contract names + emits-to split; repos/HoneyDrunk.Capabilities/overview.md adopts CapabilityDescriptor record; new repos/HoneyDrunk.Capabilities/integration-points.md filed; active-initiatives.md gets the new initiative block). ADR-0017 stays Proposed in this packet — the Status flip is a separate post-merge housekeeping step.`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Capabilities/overview.md`
- `repos/HoneyDrunk.Capabilities/integration-points.md` (new file)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

`adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` is **not** edited by this packet. Its D2 line 43 strict-Abstractions phrasing is already in the file (edited directly before filing). Its Status header stays `Proposed` — the flip is a separate post-merge housekeeping step.

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits are inside the `HoneyDrunk.Architecture` repo.
- [x] No code changes anywhere; metadata only.
- [x] No contract bodies invented in this packet — only catalog registration of ADR-0017's already-decided D3 surface.
- [x] The `ICapabilityDescriptor` (interface) → `CapabilityDescriptor` (record) rename is a deliberate Grid-wide-naming-rule alignment, not a new design choice.
- [x] No edits to `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` in this packet. The Status flip is a separate post-merge housekeeping step per the user's standing ADR acceptance workflow.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-capabilities` block lists exactly the four D3 contracts (`ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, `ICapabilityGuard`) — no `ICapability`, no `ICapabilityPermission`.
- [ ] `CapabilityDescriptor` is recorded with `kind: "type"` (record), not `kind: "interface"`.
- [ ] `catalogs/relationships.json` `honeydrunk-capabilities` `exposes.contracts` array contains `CapabilityDescriptor` (no `I` prefix); other three entries unchanged.
- [ ] `catalogs/relationships.json` `honeydrunk-capabilities` `exposes.packages` array includes `HoneyDrunk.Capabilities.Testing` as the third entry.
- [ ] `catalogs/grid-health.json` `honeydrunk-capabilities` block reflects the standup ADR with the GitHub repo creation and the scaffold packet noted as the active blockers; `notes` field names the four D3 contracts and references `integration-points.md`.
- [ ] `catalogs/nodes.json` `honeydrunk-capabilities.tags` includes `dispatch` and `guard`.
- [ ] `catalogs/nodes.json` `honeydrunk-capabilities.grid_relationship` field describes the Auth dependency via `ICapabilityGuard`'s default and emits to Pulse one-way per D7; consumers list includes Operator, Evals, and "any domain Node that registers a callable tool".
- [ ] `constitution/ai-sector-architecture.md` Capabilities section Key Contracts list reads with `CapabilityDescriptor` (record), not `ICapabilityDescriptor` (interface).
- [ ] `constitution/ai-sector-architecture.md` Capabilities section dependency phrasing split into "Depends on" (no Pulse) and "Emits to (no runtime dependency): Pulse" lines per D7.
- [ ] `repos/HoneyDrunk.Capabilities/overview.md` Key Contracts section reads with `CapabilityDescriptor` (record); section heading changed from "Key Interfaces" to "Key Contracts"; Packages table includes a third row for `HoneyDrunk.Capabilities.Testing`.
- [ ] `repos/HoneyDrunk.Capabilities/integration-points.md` exists and matches the structure of `repos/HoneyDrunk.Agents/integration-points.md` (Consumes / Exposes / Emits / Canary Coverage Required / Dependency Order for Bring-Up).
- [ ] `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` is **not** modified by this packet. (Verify the file is unchanged in the diff. D2 line 43's strict-Abstractions phrasing is already in place from a pre-filing direct edit; the Status flip is deferred to post-merge housekeeping.)
- [ ] `initiatives/active-initiatives.md` includes a new "ADR-0017 HoneyDrunk.Capabilities Standup" block under `## In Progress`.
- [ ] `CHANGELOG.md` Unreleased section updated with the catalog reconciliations. The CHANGELOG entry must **not** claim a Status flip — the ADR stays Proposed in this packet's diff.
- [ ] PR body explicitly notes the catalog drift reconciled: drop placeholder `ICapability`/`ICapabilityPermission` in favor of the four D3 contracts (with `CapabilityDescriptor` as a record per the Grid-wide naming rule). PR body also explicitly notes that ADR-0017 stays at `Status: Proposed` in this packet — the flip is a separate post-merge housekeeping step.
- [ ] No file under `catalogs/` or `repos/HoneyDrunk.Capabilities/` references `ICapability` or `ICapabilityPermission` after the edits — verify with `grep -nr "ICapabilityPermission\|ICapability\b" catalogs/ repos/HoneyDrunk.Capabilities/ constitution/ai-sector-architecture.md` and confirm zero matches (note: `ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard`, `ICapabilityDescriptor` are different names; the `\b` boundary in `ICapability\b` excludes them. Manually re-verify if any tooling does word-boundary differently).

## Human Prerequisites
None. ADR-0017's D2 line 43 strict-Abstractions phrasing is already in the file (pre-filing direct edit). The Status flip is deferred to post-merge housekeeping.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why ADR-0017 D2 line 43 already reads `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.` (pre-filing direct edit) and why the catalog `package` field on the `honeydrunk-capabilities` `contracts.json` entry stays `HoneyDrunk.Capabilities.Abstractions`.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Capabilities consumes Kernel and Auth; nothing in `HoneyDrunk.Capabilities.*` is referenced back from Kernel or Auth.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Capabilities is its own Node, hence its own repo (created by packet 03).

## Referenced ADR Decisions

**ADR-0017 D2 (Package families):** Three package families — `HoneyDrunk.Capabilities.Abstractions`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Capabilities.Testing`. The `Testing` package is a separate NuGet artifact (not a `Providers.*` slot) carrying the in-memory registry/dispatcher fixture for downstream Nodes' deterministic tests. The `relationships.json exposes.packages` array reflects all three.

**ADR-0017 D3 (Exposed contracts):** Four contracts form the Capabilities Node's public boundary — `ICapabilityRegistry`, `CapabilityDescriptor` (record), `ICapabilityInvoker`, `ICapabilityGuard`. The existing `ICapability` and `ICapabilityPermission` placeholder entries are superseded. Records drop the `I`; interfaces keep it.

**ADR-0017 D5 (Authorization through Auth):** `ICapabilityGuard` resolves authorization decisions by consulting Auth policy via the already-established `HoneyDrunk.Auth` contracts. No new edge in `relationships.json` is added; the Capabilities → Auth dependency already exists. The catalog edits here align the descriptions to call this out explicitly.

**ADR-0017 D7 (Telemetry direction):** Capabilities emits registration, resolution, and invocation telemetry via Kernel's `ITelemetryActivityFactory`. Pulse consumes downstream. **Capabilities has no runtime dependency on Pulse.** The catalog edits in this packet bring `nodes.json` and `ai-sector-architecture.md` into alignment with that direction — same one-way phrasing as ADR-0016 D7 applied to AI.

**ADR-0017 D9 (Downstream coupling):** Downstream Nodes compile only against `HoneyDrunk.Capabilities.Abstractions`. The `package` field on the `contracts.json` entry stays at `Abstractions` — never the runtime or the `Testing` fixture.

## Dependencies
None. This packet is the foundation of the initiative — it can land before the scaffold packet exists, because the catalog surface is design-decided already in ADR-0017. Packets 02, 03, and 04 reference this one as `packet:01`.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0017`

## Agent Handoff

**Objective:** Bring `HoneyDrunk.Architecture` catalogs into alignment with ADR-0017 D3, D5, D7, D9 — without inventing any new design choices. Add the new `integration-points.md`. Add the initiative entry to `active-initiatives.md`. **Do not edit `adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` in this packet** — its D2 line 43 amendment is already in place (pre-filing direct edit), and the Status flip is a separate post-merge housekeeping step.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Catalog drift is the bottleneck that blocks downstream AI-sector Nodes (Agents, Operator, Memory, Knowledge, Evals) and tool-registering domain Nodes from scoping their own work. This packet removes the drift introduced by ADR-0017's acceptance.
- Feature: ADR-0017 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0017 (this packet implements the catalog half of "If Accepted").

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this packet runs first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why D2 line 43 must read `Microsoft.Extensions.*` only and why the catalog `package` field on the `honeydrunk-capabilities` `contracts.json` entry stays `HoneyDrunk.Capabilities.Abstractions`.
- **Invariant 11:** One repo per Node. — Capabilities is a separate Node and gets its own repo. Packet 03 creates it.
- **D3 is canonical.** Drop `ICapability` and `ICapabilityPermission` (placeholders). Add `ICapabilityRegistry` (description tightened to mention versioning), `CapabilityDescriptor` (record, no `I`), `ICapabilityInvoker`, `ICapabilityGuard` (default delegates to Auth).
- **Records drop `I`; interfaces keep it.** `CapabilityDescriptor` is a record. The other three contracts are interfaces. Apply the rename across `contracts.json`, `relationships.json`, `ai-sector-architecture.md`, and `repos/HoneyDrunk.Capabilities/overview.md`. Verify with grep that no remaining `ICapabilityDescriptor` (with the I prefix) exists in `catalogs/`, `constitution/ai-sector-architecture.md`, or `repos/HoneyDrunk.Capabilities/` after edits.
- **Strict Abstractions stance is already in the ADR text.** ADR-0017 D2 line 43 already reads `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.` (pre-filing direct edit). `repos/HoneyDrunk.Capabilities/invariants.md:5` declares the same rule locally. Do **not** modify the ADR file in this packet.
- **Auth is a first-class runtime dependency.** ADR-0017 D10 makes this explicit. The catalog already has the edge; no new edge to add. The `nodes.json grid_relationship` and `ai-sector-architecture.md Depends on` text describe the dependency in terms of `ICapabilityGuard`'s default delegating to Auth — that is the precise framing.
- **Pulse is one-way.** Same direction rule as ADR-0016 D7 applied to AI. Edit `grid_relationship` and `ai-sector-architecture.md` accordingly. Do not add Pulse to `consumes` or `consumes_detail` in `relationships.json`.
- **No ADR Status flip in this packet.** ADR-0017 stays at `Status: Proposed`. The flip is a separate post-merge housekeeping step the scope agent runs after the entire initiative completes, per the user's standing ADR acceptance workflow. Do not edit the ADR header in this PR.
- **Naming-collision note (D4).** Two collisions are disambiguated: ADR-0004's `capabilities:` YAML frontmatter on agent definition files, and HoneyDrunk.Actions (Ops Node for CI/CD). Neither is a code change. While editing `repos/HoneyDrunk.Capabilities/`, do not introduce the word "actions" to mean tool invocations and do not borrow the `capabilities:` frontmatter word for runtime concepts.

**Key Files:**
- `catalogs/contracts.json` — replace the `honeydrunk-capabilities` block's interfaces array
- `catalogs/relationships.json` — line 205 `exposes.contracts` (rename `ICapabilityDescriptor` → `CapabilityDescriptor`); line 206 `exposes.packages` (add `HoneyDrunk.Capabilities.Testing`)
- `catalogs/grid-health.json` — replace the `honeydrunk-capabilities` block (lines 217-227)
- `catalogs/nodes.json` — edit line 630 (`tags`) and line 647 (`grid_relationship`)
- `constitution/ai-sector-architecture.md` — Capabilities section Key Contracts list (lines 235-239) and Depends-on phrasing (line 241)
- `repos/HoneyDrunk.Capabilities/overview.md` — Key Interfaces → Key Contracts heading + body (lines 19-25); add `Testing` row to Packages table (lines 13-17)
- `repos/HoneyDrunk.Capabilities/integration-points.md` — new file
- `initiatives/active-initiatives.md` — new entry under `## In Progress`
- `CHANGELOG.md` — Unreleased entry

`adrs/ADR-0017-stand-up-honeydrunk-capabilities-node.md` and `adrs/README.md` are explicitly **not** edited in this packet.

**Contracts:**
- This packet does not author any new contracts. It records the four D3 contracts in the catalog. Authoring of the actual `.cs` files happens in packet 04 (the scaffold).
