---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "catalog", "adr-0010", "wave-1"]
dependencies: []
adrs: ["ADR-0010"]
wave: 1
initiative: adr-0010-observe-ai-routing-phase-1
node: honeydrunk-architecture
---

# Feature: Accept ADR-0010 — register HoneyDrunk.Observe, wire AI routing contracts into catalogs, finalize invariants

## Summary
Execute the full "If Accepted" follow-up list from ADR-0010 in one Architecture-repo PR: register the new `HoneyDrunk.Observe` Node in every catalog, add the new observation and AI routing contract stubs, create the `repos/HoneyDrunk.Observe/` context folder, add Observe to the Ops sector table, finalize invariants 28–30 (remove Proposed qualifiers, add 29–30 full text), flip the ADR-0010 index row to Accepted, and register the Phase 1 initiative in the active-initiatives/roadmap trackers so Phase 2/3 stay visible.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0010 was drafted Proposed on 2026-04-12 and has remained parked because its "If Accepted" checklist was never translated into an execution packet. The Grid cannot route work to Observe or AI routing until catalogs, sectors, and invariants reflect them. This packet is the single atomic "accept ADR-0010" PR — it is authored to satisfy every bullet on the ADR's own follow-up list so nothing is left behind. Subsequent packets (repo creation, Observe Abstractions scaffold, AI routing contracts) depend on this catalog/boundary work landing first.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code. No secrets.

### Part A — Catalog registration

#### `catalogs/nodes.json`
Append a new entry for `honeydrunk-observe`. Use `honeydrunk-vault-rotation` as the closest style reference (Seed-tier, not yet done). Expected shape:

```json
{
  "id": "honeydrunk-observe",
  "type": "node",
  "name": "HoneyDrunk.Observe",
  "public_name": "HoneyDrunk.Observe",
  "short": "External project observation layer",
  "description": "Observation contracts and per-system connector packages for monitoring external projects (non-HoneyDrunk repos, third-party services) the way Pulse monitors internal Nodes. Single Node family with provider-slot connector packages.",
  "sector": "Ops",
  "signal": "Seed",
  "cluster": "observability",
  "energy": 0,
  "priority": 0,
  "flow": 0,
  "tags": ["observation", "external", "github", "azure", "http", "connectors", "events", "webhooks"],
  "links": { "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Observe" },
  "long_description": {
    "overview": "HoneyDrunk.Observe is the inbound observation layer of the Grid. It lets the Hive watch external projects — any codebase or service outside HoneyDrunk — with the same telemetry and health visibility that Pulse provides for internal Nodes. The Node ships observation contracts, a runtime that composes connectors and normalizes events, and a family of provider-slot connector packages (GitHub, Azure, HTTP) that adapt specific external systems.",
    "why_it_exists": "Pulse handles outbound telemetry (Grid → external sinks). Observe handles inbound event intake (external systems → Grid). Both are runtime pipelines, and until Observe exists the Grid cannot see projects it does not own — a prerequisite for HoneyHub's planning layer.",
    "primary_audience": "Grid operators wiring the Hive into external systems; HoneyHub (future) for external-project signals.",
    "value_props": [
      "Single canonical observation event model across heterogeneous external sources",
      "Provider-slot connector packages (GitHub, Azure, HTTP) shipped from one repo",
      "Vault-backed credential resolution for every connector",
      "Decoupled from HoneyHub — ships independently"
    ],
    "monetization_signal": "Internal-first.",
    "roadmap_focus": "Phase 1: contracts + repo scaffolding. Phase 2: GitHub connector as first useful increment. Phase 3: HoneyHub integration when HoneyHub Phase 1 is live.",
    "grid_relationship": "Consumes Kernel for context and lifecycle. Consumes Vault for connector credentials. Does not route to external sinks (that is Pulse, opposite direction).",
    "integration_depth": "medium",
    "demo_path": "Register an observation target → connector intakes external event → runtime normalizes to IObservationEvent → event visible in observation state.",
    "signal_quote": "See what the Hive does not own.",
    "stability_tier": "seed",
    "impact_vector": "external visibility"
  },
  "foundational": false,
  "strategy_base": 10,
  "tier": "none",
  "time_pressure": 0,
  "done": false,
  "cooldown_days": 14
}
```

The `honeydrunk-ai` entry's `long_description.value_props` already contains `"Model selection and routing based on capability requirements"` (nodes.json:599). No net-new addition to `value_props` is required — the Phase-1 line is present. Optionally refine `long_description.overview` with a one-sentence acknowledgement that routing flows through `IModelRouter`, but do not rewrite the paragraph. If the executor judges the existing wording sufficient, this catalog entry is a no-op touch beyond the new `honeydrunk-observe` addition.

#### `catalogs/relationships.json`

Add an entry for `honeydrunk-observe`:
```json
{
  "id": "honeydrunk-observe",
  "consumes": ["honeydrunk-kernel", "honeydrunk-vault"],
  "consumed_by": [],
  "consumed_by_planned": [],
  "blocked_by": [],
  "exposes": {
    "contracts": ["IObservationTarget", "IObservationConnector", "IObservationEvent"],
    "packages": ["HoneyDrunk.Observe.Abstractions"],
    "packages_planned": ["HoneyDrunk.Observe", "HoneyDrunk.Observe.Connectors.GitHub", "HoneyDrunk.Observe.Connectors.Azure", "HoneyDrunk.Observe.Connectors.Http"]
  },
  "consumes_detail": {
    "honeydrunk-kernel": ["IGridContext", "IOperationContext", "IStartupHook", "HoneyDrunk.Kernel"],
    "honeydrunk-vault": ["ISecretStore", "HoneyDrunk.Vault"]
  }
}
```

Update existing entries:
- `honeydrunk-kernel.consumed_by_planned` — add `honeydrunk-observe`
- `honeydrunk-vault.consumed_by_planned` — add `honeydrunk-observe`
- The ADR also envisions Observe feeding HoneyHub (future). HoneyHub is not in `nodes.json` yet, so do not add that edge. Leave `consumed_by` empty.

#### `catalogs/contracts.json`

Append a new contracts entry for `honeydrunk-observe`:
```json
{
  "node": "honeydrunk-observe",
  "node_name": "HoneyDrunk.Observe",
  "package": "HoneyDrunk.Observe.Abstractions",
  "status": "planned",
  "interfaces": [
    { "name": "IObservationTarget", "kind": "interface", "description": "Declares an external system to be observed — identity, connector selection, credential handle." },
    { "name": "IObservationConnector", "kind": "interface", "description": "Provider-slot interface. Connector implementations (GitHub, Azure, HTTP) intake external events and translate them to normalized observation events." },
    { "name": "IObservationEvent", "kind": "interface", "description": "Canonical observation event — normalized shape that crosses the Observe boundary regardless of source connector." }
  ]
}
```

Update the existing `honeydrunk-ai` contracts entry to append the three routing interfaces and change `status` if warranted:
```json
{ "name": "IModelRouter", "kind": "interface", "description": "Given a request with declared capability requirements, selects the appropriate model/provider. Replaces hardcoded provider selection in callers." },
{ "name": "IRoutingPolicy", "kind": "interface", "description": "Pluggable routing strategy (cost-first, capability-first, latency-first, compliance-first)." },
{ "name": "ModelCapabilityDeclaration", "kind": "type", "description": "Machine-readable declaration of what a model can do — context window, modalities, function calling support, cost tier." }
```

#### `catalogs/grid-health.json`

Append a new entry for `honeydrunk-observe`:
```json
{
  "id": "honeydrunk-observe",
  "name": "HoneyDrunk.Observe",
  "sector": "Ops",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["Repo not yet scaffolded", "Awaiting acceptance PR merge + repo creation chore"],
  "notes": "ADR-0010 Phase 1 Node. Contracts and connector provider-slot packages (GitHub, Azure, HTTP) will ship from the Observe repo; no separate connectors Node. Phase 2 first increment: GitHub connector."
}
```

Confirm there is no `honeydrunk-observe-connectors` entry present. If one exists from prior speculative work, remove it — ADR-0010 rejects a separate connectors Node.

#### `catalogs/modules.json`

Append a new package entry for the Phase-1 shipping package:
```json
{
  "id": "observe-abstractions",
  "nodeId": "honeydrunk-observe",
  "name": "HoneyDrunk.Observe.Abstractions",
  "type": "abstractions",
  "version": "0.1.0",
  "description": "Zero-dependency observation contracts — IObservationTarget, IObservationConnector, IObservationEvent"
}
```

Do not add runtime/connector packages here — they ship in Phase 2. `modules.json` enumerates shipped packages only.

#### Remaining catalog files — explicit audit (one acceptance checkbox each)

- `catalogs/services.json` — Phase 1 ships library packages only; no deployable services. **No entry required.** Confirm grep for `honeydrunk-observe` returns zero matches and this is intentional.
- `catalogs/signals.json` — Observation-specific signal events (observation-received, observation-normalized) are Phase 2 runtime concerns, not contract stubs. **Deferred to Phase 2.** Confirm no drive-by add.
- `catalogs/compatibility.json` — Verify whether the file structure enumerates Nodes or version pairs; if it enumerates Nodes, add a Seed entry for Observe with no compatibility matrix yet. If it is version-pair only, no entry required.
- `catalogs/flow_config.json` — Likely unrelated to contract stubs. Open the file; if it does not reference Node IDs for AI or Observe, **no entry required**; otherwise add a minimal Seed entry.
- `catalogs/flow_tiers.json` — Same rule as `flow_config.json`: audit then decide.

Each decision ("added / no entry required") must land as an acceptance-criteria checkbox so the review agent can verify the audit happened.

### Part B — Repo context folder

Create `repos/HoneyDrunk.Observe/` with the standard five files, matching the file set in `repos/HoneyDrunk.AI/` and `repos/HoneyDrunk.Vault.Rotation/`:

1. **`overview.md`** — Sector (Ops), Framework (.NET 10.0), Repo link, Purpose paragraph, Packages table listing Abstractions + runtime + the three Phase-2 connectors as planned, Key Interfaces (IObservationTarget, IObservationConnector, IObservationEvent), Design Notes paragraph.
2. **`boundaries.md`** — "What Observe Owns" / "What Observe Does NOT Own" sections mirroring the Decision → Owns / Does NOT own lists in the ADR body. Include the boundary decision tests: "Is this inbound event intake from an external system? → Observe. Is this outbound telemetry? → Pulse. Is this a plan adjustment? → HoneyHub."
3. **`invariants.md`** — Repo-local restatement of invariants 29 and 30 with short rationales (connector credential delegation to Vault; normalization-before-boundary-crossing).
4. **`active-work.md`** — "Phase 1 — Contracts and Stubs" entry pointing at this initiative folder. Leave placeholders for Phase 2 and Phase 3.
5. **`integration-points.md`** — Consumes: Kernel (context, lifecycle), Vault (ISecretStore for connector credentials). Consumed by: HoneyHub (future integration, not yet live).

### Part C — Constitution updates

#### `constitution/sectors.md`

**(1)** In the **Ops** sector table, add a row for Observe **directly after Pulse** (signal-grouped ordering — both Seed; keeps Seed rows adjacent, Live rows together):

```
| **Observe** | Seed | Inbound external-project observation — connectors, event normalization, observation state |
```

**(2)** In the **Dependency Flow (Real Nodes)** block at the bottom of `sectors.md`, append an `Observe` line under the existing tree. After packet 03 ships `HoneyDrunk.Observe.Abstractions`, Observe is a real shipped package; the block is only accurate once it appears there. Add:

```
└── Observe → Kernel, Vault
```

(Pick the final position — after Pulse — to preserve the existing visual grouping.)

#### `constitution/sector-interaction-map.md`

Update the Ops Sector section to list Observe alongside Pulse, Communications, Notify, Actions. Minimum edit: in the Ops diagram block (lines 65–72), add an `Observe` branch. Example:

```
             ├─ Observe: intakes events FROM external systems into the Grid
```

Add a short paragraph after the existing "Communications ↔ Notify split" callout describing the Pulse/Observe split: Pulse = outbound Grid → external sinks; Observe = inbound external systems → Grid. Same sector, opposite direction. This is an architectural boundary, not a hierarchy.

Also update the **Cross-Sector Change Classification** table to add:
```
| New observation connector | Ops (+ Vault dep) | 2 | Target repo (HoneyDrunk.Observe) |
```

Keep all existing rows intact.

#### `constitution/ai-sector-architecture.md`

Update the HoneyDrunk.AI Node definition block to add the three new routing contracts to its "Owns" list:
- `IModelRouter` — policy-driven model selection entry point
- `IRoutingPolicy` — pluggable routing strategy
- `ModelCapabilityDeclaration` — machine-readable model capability declaration

Do not rewrite the rest of the AI Node section. One short paragraph added under the existing "Owns" list is sufficient.

#### `constitution/agent-capability-matrix.md` — audit only

This file is agent-centric (scope, adr-composer, netrunner, etc.), not Node-centric. Audit for any references to Node taxonomy that would drift with Observe's addition. Expected result: **no edits required**. Document the audit outcome in this packet's PR body (one sentence: "Audited; no edits required").

#### `constitution/invariants.md`

- **Invariant 28:** **Do NOT remove the "Proposed" qualifier in this packet.** The surface it requires (`IModelRouter`) does not exist until packet 04 merges. Between packet 01 and packet 04, invariant 28 would read as a literal constraint pointing at a non-existent interface. The qualifier flip moves to packet 04's PR so the invariant becomes enforceable exactly when the contract surface exists. Leave invariant 28's text unchanged in this packet.
- **Add invariants 29 and 30 full text.** Replace the current placeholder block "_Invariants 29–30 are reserved for the Observation Layer (ADR-0010). They will be added here when ADR-0010 is accepted._" with:
  - **29. Observation connectors must delegate credential resolution to Vault.** No connector stores credentials directly. Connection secrets (webhook secrets, API tokens for external services) are resolved via `ISecretStore` at connection establishment. See ADR-0010.
  - **30. HoneyDrunk.Observe events must be normalized to the canonical observation format before routing out of the Observe boundary.** Raw external formats (GitHub webhook JSON, Azure alert schema) never cross the Observe boundary — only normalized `IObservationEvent` types. See ADR-0010.

### Part D — ADR index flip

In `adrs/README.md`, change the ADR-0010 row's Status from `Proposed` to `Accepted` and update the Impact text if the old line reads "Blocked on Observe vs Pulse boundary decision" — that boundary is resolved in the ADR body (Pulse = outbound, Observe = inbound). Proposed replacement Impact text:

> Establishes HoneyDrunk.Observe (Ops) with provider-slot connectors, and IModelRouter routing contracts in HoneyDrunk.AI. Phase 1 scoped. Invariants 28–30 live.

Also flip the `**Status:** Proposed` line in `adrs/ADR-0010-observation-layer.md` itself to `**Status:** Accepted`.

### Part E — Initiative + roadmap trackers

So Phase 2 and Phase 3 stay visible after Phase 1 closes:

#### `initiatives/active-initiatives.md`

Add a new **In Progress** entry:

```markdown
### ADR-0010 Observation Layer & AI Routing — Phase 1
**Status:** In Progress
**Scope:** Architecture, Observe (new), AI
**Initiative:** `adr-0010-observe-ai-routing-phase-1`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0010 and ship Phase 1 (contracts + stubs). Catalog registration for HoneyDrunk.Observe, repo scaffold, and routing contracts in HoneyDrunk.AI.Abstractions. Phase 2 (first GitHub connector + cost-first routing policy) and Phase 3 (HoneyHub integration, gated on HoneyHub Phase 1 being live) are tracked below so they do not get lost.
**Tracking (Phase 1):**
- [ ] Architecture#NN: Accept ADR-0010 — catalog/context/invariants/trackers (this packet)
- [ ] Architecture#NN: Create HoneyDrunk.Observe GitHub repo (human-only chore)
- [ ] Observe#1: Scaffold HoneyDrunk.Observe.Abstractions — IObservationTarget/IObservationConnector/IObservationEvent
- [ ] AI#NN: Add IModelRouter / IRoutingPolicy / ModelCapabilityDeclaration to HoneyDrunk.AI.Abstractions
**Next (Phase 2 — not yet scoped):**
- Implement HoneyDrunk.Observe.Connectors.GitHub (webhook receiver, repo health checks)
- Implement cost-first IRoutingPolicy in HoneyDrunk.AI
- Wire routing policies to App Configuration per ADR-0005
**Deferred (Phase 3 — blocked on HoneyHub Phase 1):**
- Route normalized IObservationEvent into HoneyHub's knowledge graph
- Allow HoneyHub to read routing policy outcomes as plan signals
```

#### `initiatives/roadmap.md`

Add a Q2 2026 bullet (below the existing HoneyDrunk.AI bullet):
- [ ] **ADR-0010 Phase 1 (Observe + AI Routing contracts)** — HoneyDrunk.Observe repo + Abstractions, IModelRouter contracts in HoneyDrunk.AI.Abstractions, catalog registration

Add a Q3 2026 bullet:
- [ ] **ADR-0010 Phase 2 (first useful increment)** — HoneyDrunk.Observe.Connectors.GitHub, cost-first IRoutingPolicy, routing policies in App Configuration

Add a Future line (under HoneyNet/Cyberware or in a new stub):
- ADR-0010 Phase 3 — Observe → HoneyHub event routing and HoneyHub-consumed routing policy outcomes (gated on HoneyHub Phase 1 being live)

## Acceptance Criteria

### Catalogs
- [ ] `catalogs/nodes.json`: new `honeydrunk-observe` entry present; JSON valid; style matches `honeydrunk-vault-rotation`; `honeydrunk-ai` value_props already contains the routing line (nodes.json:599) — **no double-write**; only optional overview refinement
- [ ] `catalogs/relationships.json`: new `honeydrunk-observe` entry with correct consumes/exposes (Abstractions in `packages`, connectors in `packages_planned`); `honeydrunk-kernel` and `honeydrunk-vault` `consumed_by_planned` arrays include `honeydrunk-observe`; graph remains a DAG (invariant 4)
- [ ] `catalogs/contracts.json`: new `honeydrunk-observe` entry with the three observation interfaces; `honeydrunk-ai` entry extended with IModelRouter/IRoutingPolicy/ModelCapabilityDeclaration
- [ ] `catalogs/grid-health.json`: new `honeydrunk-observe` entry with `signal: "Seed"` and the listed active_blockers
- [ ] `catalogs/modules.json`: new `observe-abstractions` entry (nodeId `honeydrunk-observe`, type `abstractions`, version `0.1.0`)
- [ ] `catalogs/services.json`: audited — **no entry added** (Phase 1 ships no deployable services); decision documented in PR body
- [ ] `catalogs/signals.json`: audited — **no entry added** (observation signal kinds are Phase 2 runtime); decision documented in PR body
- [ ] `catalogs/compatibility.json`: audited — entry added if file enumerates Nodes, else no entry; decision documented in PR body
- [ ] `catalogs/flow_config.json`: audited — entry added if file references Node IDs for AI/Observe, else no entry; decision documented in PR body
- [ ] `catalogs/flow_tiers.json`: audited — entry added if file references Node IDs for AI/Observe, else no entry; decision documented in PR body
- [ ] No `honeydrunk-observe-connectors` entry exists anywhere (confirm grep shows zero matches — this is a defensive no-op today, but guards against drift)

### Repo context folder
- [ ] `repos/HoneyDrunk.Observe/` created with five files (overview, boundaries, invariants, active-work, integration-points); format matches `repos/HoneyDrunk.AI/`

### Constitution
- [ ] `constitution/sectors.md`: Ops sector table has an Observe row placed directly after Pulse (signal-grouped ordering)
- [ ] `constitution/sectors.md`: Dependency Flow (Real Nodes) block includes the `Observe → Kernel, Vault` line
- [ ] `constitution/sector-interaction-map.md`: Ops diagram block lists Observe; a Pulse/Observe split paragraph added; Cross-Sector Change Classification table has a new-observation-connector row
- [ ] `constitution/ai-sector-architecture.md`: HoneyDrunk.AI "Owns" list now includes IModelRouter, IRoutingPolicy, ModelCapabilityDeclaration
- [ ] `constitution/agent-capability-matrix.md`: audited — **no edits required** expected; audit outcome documented in PR body
- [ ] `constitution/invariants.md`: invariant 28 text is **unchanged** in this packet (qualifier flip moved to packet 04's PR); invariants 29 and 30 now have full rule text (not placeholders)

### ADR flip
- [ ] `adrs/README.md`: ADR-0010 row Status flipped to Accepted; Impact text refreshed
- [ ] `adrs/ADR-0010-observation-layer.md`: `**Status:** Proposed` flipped to `**Status:** Accepted`

### Trackers
- [ ] `initiatives/active-initiatives.md`: new "ADR-0010 Observation Layer & AI Routing — Phase 1" entry added with Phase 1 tracking, Phase 2 Next, Phase 3 Deferred sections (already authored by scope agent on 2026-04-18; verify present and accurate)
- [ ] `initiatives/roadmap.md`: Q2 2026 Phase 1 bullet; Q3 2026 Phase 2 bullet; Future Phase 3 line (already authored by scope agent on 2026-04-18; verify present)

### General
- [ ] Repo-level `CHANGELOG.md` (if Architecture repo has one next to `.slnx`) appends an entry describing ADR-0010 acceptance; otherwise skip (invariant 12 — Architecture is docs-only, changelog practice may differ)
- [ ] No ADR IDs appear in the new context folder's README-style prose sections (ADR IDs stay in frontmatter/metadata, out of narrative body text)

## Affected Packages
None. Docs and JSON only.

## NuGet Dependencies
None. No .NET changes in this packet.

## Boundary Check
- [x] Catalog registration, invariant edits, sector updates, and ADR index maintenance live in `HoneyDrunk.Architecture` — correct repo per routing rules
- [x] No code changes to any other repo
- [x] Observe sector assignment (Ops) matches the ADR's explicit boundary decision (Pulse = outbound, Observe = inbound)
- [x] `relationships.json` DAG invariant preserved (new edges are `observe → kernel` and `observe → vault`, both existing roots; no cycles introduced)

## Human Prerequisites
None. This packet is a pure Architecture-repo edit and does not require any portal or GitHub org actions. The separate `02-architecture-create-observe-repo.md` chore handles the human-only repo-creation step.

## Dependencies
None. This is the Wave-1 foundation packet.

## Downstream Unblocks
- `02-architecture-create-observe-repo.md` — human-only repo creation can proceed in parallel but operates on the catalog identity this packet establishes
- `03-observe-abstractions-scaffold.md` — Observe scaffold consumes the `repos/HoneyDrunk.Observe/` context folder produced here
- `04-ai-add-routing-contracts.md` — parked pending HoneyDrunk.AI standup ADR. This packet records the AI routing contracts in `catalogs/contracts.json` so the surface is catalogued even while the Abstractions package is unscaffolded; packet 04 becomes fileable when a separate standup initiative ships `HoneyDrunk.AI.Abstractions`.

## Referenced ADR Decisions

**ADR-0010 (Observation Layer and AI Routing):**
- **§Layer 1 / New Node:** One Node `HoneyDrunk.Observe` owns both observation contracts and per-system connector packages (`HoneyDrunk.Observe.Connectors.*`), same provider-slot pattern as Vault and Transport. First-wave connector slots: GitHub, Azure, HTTP.
- **§Owns / Does NOT own:** Observe owns contracts, event normalization, observation state, connector implementations. It does not own outbound telemetry (Pulse), plan adjustment (HoneyHub), internal Grid telemetry (stays in Pulse), or HoneyHub routing (integration point, not a connector concern).
- **§Sector assignment:** Observe is Ops. Pulse = outbound telemetry (Grid → external sinks). Observe = inbound event intake (external systems → Grid). Both runtime pipelines, both Ops.
- **§Layer 2:** AI routing is an extension of HoneyDrunk.AI, not a new Node. New contracts: `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`. Routing policies live in Azure App Configuration (ADR-0005); no policies hardcoded in application code.
- **§If Accepted:** The full checklist at the top of ADR-0010 is the definition-of-done for this packet.

## Referenced Invariants

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.

> **Invariant 28:** Application code must never hardcode a model name or provider. All model selection goes through IModelRouter in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. *(This packet leaves the "Proposed" qualifier intact. The qualifier flip is in packet 04, which ships `IModelRouter` — the surface the invariant requires. Flipping here would leave the invariant transiently unsatisfiable.)*

> **Invariant 29 (new):** Observation connectors must delegate credential resolution to Vault. No connector stores credentials directly. Connection secrets (webhook secrets, API tokens for external services) are resolved via ISecretStore at connection establishment.

> **Invariant 30 (new):** HoneyDrunk.Observe events must be normalized to the canonical observation format before routing out of the Observe boundary. Raw external formats (GitHub webhook JSON, Azure alert schema) never cross the Observe boundary — only normalized IObservationEvent types.

## Constraints

- **Do not write ADR IDs in README-style prose in the new `repos/HoneyDrunk.Observe/` context files.** User preference: ADR IDs stay in frontmatter/metadata only; body narrative uses the decision text, not its ID.
- **Minimal edits to the `honeydrunk-ai` node entry.** Acknowledge the routing layer in `long_description.value_props` — do not rewrite the existing overview.
- **No speculative connectors.** Do not add Connectors.Linear, Connectors.PagerDuty, etc. to any catalog. ADR-0010 names GitHub, Azure, HTTP as first-wave only.
- **Do not add HoneyHub edges.** HoneyHub is not in `nodes.json`. The Phase 3 integration is a future commitment, not a current catalog edge.
- **No package downgrade or workflow-file changes.** This is docs and catalog only.
- **DAG discipline** (invariant 4): verify `relationships.json` forms a DAG after edits. Observe edges are to Kernel and Vault (both roots), so no cycle is possible — confirm anyway.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `catalog`, `adr-0010`, `wave-1`

## Agent Handoff

**Objective:** Execute the full "If Accepted" checklist in ADR-0010 as a single atomic Architecture-repo PR so the ADR can flip to Accepted and downstream Wave-2 packets can run.

**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Move ADR-0010 from Proposed to Accepted by doing the Architecture-side work it requires (catalogs, repo context, sectors, invariants, trackers, index flip)
- Feature: ADR-0010 Phase 1 — Observation Layer and AI Routing contracts
- ADRs: ADR-0010 (primary), ADR-0005 (App Configuration context for routing policies), ADR-0008 (initiative/packet conventions)

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- See "Constraints" section above — inlined for agent consumption
- Invariant 4 DAG: confirm after edits
- No ADR IDs in narrative body of new context files
- Minimal-footprint edits to existing catalog entries (honeydrunk-ai, honeydrunk-kernel, honeydrunk-vault)

**Key Files:**
- `catalogs/nodes.json`
- `catalogs/relationships.json`
- `catalogs/contracts.json`
- `catalogs/grid-health.json`
- `catalogs/modules.json`
- `catalogs/services.json` (audit only, typically no edit)
- `catalogs/signals.json` (audit only, typically no edit)
- `catalogs/compatibility.json` (audit; maybe entry)
- `catalogs/flow_config.json` (audit; maybe entry)
- `catalogs/flow_tiers.json` (audit; maybe entry)
- `repos/HoneyDrunk.Observe/overview.md` (new)
- `repos/HoneyDrunk.Observe/boundaries.md` (new)
- `repos/HoneyDrunk.Observe/invariants.md` (new)
- `repos/HoneyDrunk.Observe/active-work.md` (new)
- `repos/HoneyDrunk.Observe/integration-points.md` (new)
- `constitution/sectors.md`
- `constitution/sector-interaction-map.md`
- `constitution/ai-sector-architecture.md`
- `constitution/agent-capability-matrix.md` (audit only, likely no edit)
- `constitution/invariants.md`
- `adrs/README.md`
- `adrs/ADR-0010-observation-layer.md`
- `initiatives/active-initiatives.md` (scope-agent pre-wrote on 2026-04-18; verify)
- `initiatives/roadmap.md` (scope-agent pre-wrote on 2026-04-18; verify)

**Contracts:** None directly created in this packet — only registered as stubs in `contracts.json`. Package-level scaffolding happens in `03-observe-abstractions-scaffold.md` and `04-ai-add-routing-contracts.md`.
