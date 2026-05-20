---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0023"]
dependencies: []
adrs: ["ADR-0023"]
accepts: ADR-0023
wave: 1
initiative: adr-0023-evals-standup
node: honeydrunk-evals
---

# Chore: Register HoneyDrunk.Evals's standup decisions in Architecture catalogs + reconcile three-way drift

## Summary

Reflect ADR-0023 in catalogs. **Reconcile a three-way drift** between `catalogs/contracts.json` (`IEvalRunner`, `IEvalScorer`, `IEvalSuite`), `catalogs/relationships.json` `exposes.contracts` (`IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport`), and `repos/HoneyDrunk.Evals/overview.md` (same four). Land the D3 definitive set: `IEvaluator`, `IEvalScorer`, `IEvalSuite`, `IEvalTarget`, `EvalCase`, `EvalReport` (four interfaces + two records).

Widen `consumes` to add seven missing edges (Kernel, Agents, Capabilities, Operator, Knowledge, Memory). Widen AI `consumes_detail`. Update `roadmap_focus` prose in `nodes.json`. Refresh `grid-health.json`. Align `constitution/ai-sector-architecture.md` Evals section. Add `integration-points.md` and `active-work.md` under `repos/HoneyDrunk.Evals/`.

ADR-0023 stays Proposed.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0023 establishes Evals's contract surface (D3) and reconciles a three-way drift across cataloged sources. Specific drift items:

1. **`contracts.json` lists three interfaces** (`IEvalRunner`, `IEvalScorer`, `IEvalSuite`) — none of which match D3.
2. **`relationships.json` `exposes.contracts` lists four interfaces** (`IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport`) — closer but `IEvalDataset` is wrong (should be `IEvalSuite`); `IEvalReport` should be a record (`EvalReport`); `IEvalTarget` is missing.
3. **`relationships.json` `consumes` lists only `honeydrunk-ai`** with limited `consumes_detail` — seven other edges missing per D4.
4. **`nodes.json roadmap_focus`** names `IEvaluator`, `IEvalDataset`, `IEvalScorer` — needs updating to D3 definitive set.
5. **`repos/HoneyDrunk.Evals/overview.md`** lists `IEvaluator`, `IEvalDataset`, `IEvalScorer`, `IEvalReport` — needs same updates.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-evals` block

Replace existing three-interface seed with the six D3 surfaces:

```json
{
  "node": "honeydrunk-evals",
  "node_name": "HoneyDrunk.Evals",
  "package": "HoneyDrunk.Evals.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IEvaluator", "kind": "interface", "description": "Run a suite of cases against a target, collect scored results, produce an EvalReport. The top-level orchestration surface. ADR-0023 D3." },
    { "name": "IEvalScorer", "kind": "interface", "description": "Scoring function over a case output. Automated (regex, schema validation, rubric) or model-as-judge (using IChatClient). Marked deterministic vs non-deterministic per the Node-local invariant. ADR-0023 D3 / D5." },
    { "name": "IEvalSuite", "kind": "interface", "description": "Named, versioned collection of EvalCases with a rubric specification. Replaces the previous IEvalDataset name. ADR-0023 D3." },
    { "name": "IEvalTarget", "kind": "interface", "description": "The thing being evaluated — a chat model, an agent, a retrieval pipeline, a memory-backed workflow. Abstracts over what the case is run against without binding Evals to any consumer's runtime surface. New in ADR-0023 D3 / D6 — router-bypass boundary." },
    { "name": "EvalCase", "kind": "type", "description": "Record. A single evaluation case — input, expected output or rubric criteria, per-case metadata (case identity, suite version, tags). ADR-0023 D3." },
    { "name": "EvalReport", "kind": "type", "description": "Record. Structured evaluation results — per-case scores, per-case inputs and outputs (subject to D10 sensitivity rules), rubric breakdown, run metadata (target identity, ModelCapabilityDeclaration identity, suite version, timestamp). Durable per D13. Previously IEvalReport interface — promoted to record per the grid-wide naming rule. ADR-0023 D3 / D12." }
  ]
}
```

Drop `IEvalRunner`, `IEvalDataset`, `IEvalReport` placeholder entries.

### `catalogs/relationships.json` — `honeydrunk-evals` block

**(a) `consumes` widening.** Currently `["honeydrunk-ai"]`. Replace with:

```json
"consumes": ["honeydrunk-kernel", "honeydrunk-ai", "honeydrunk-agents", "honeydrunk-capabilities", "honeydrunk-operator", "honeydrunk-knowledge", "honeydrunk-memory"]
```

**(b) `consumes_detail`.** Add per-edge entries:

```json
"consumes_detail": {
  "honeydrunk-kernel": ["IGridContext", "IOperationContext", "ITelemetryActivityFactory", "HoneyDrunk.Kernel.Abstractions"],
  "honeydrunk-ai": ["IChatClient", "IEmbeddingGenerator", "IModelProvider", "ModelCapabilityDeclaration", "HoneyDrunk.AI.Abstractions"],
  "honeydrunk-agents": ["IAgent", "HoneyDrunk.Agents.Abstractions"],
  "honeydrunk-capabilities": ["ICapabilityInvoker", "HoneyDrunk.Capabilities.Abstractions"],
  "honeydrunk-operator": ["ISafetyFilter", "ICostGuard", "IAuditLog", "HoneyDrunk.Operator.Abstractions"],
  "honeydrunk-knowledge": ["HoneyDrunk.Knowledge.Abstractions", "HoneyDrunk.Knowledge.Providers.InMemory"],
  "honeydrunk-memory": ["HoneyDrunk.Memory.Abstractions", "HoneyDrunk.Memory.Providers.InMemory"]
}
```

**(c) `exposes.contracts`.** Replace with:

```json
"contracts": ["IEvaluator", "IEvalScorer", "IEvalSuite", "IEvalTarget", "EvalCase", "EvalReport"]
```

**(d) `exposes.packages`.** Replace with:

```json
"packages": ["HoneyDrunk.Evals.Abstractions", "HoneyDrunk.Evals", "HoneyDrunk.Evals.Providers.InMemory"]
```

### `catalogs/grid-health.json` — `honeydrunk-evals` block

Replace with standup-aware block naming D3 contracts and scaffold packet as blocker.

### `catalogs/nodes.json` — `honeydrunk-evals` block

**(a) `roadmap_focus`.** Replace prose naming `IEvaluator`, `IEvalDataset`, `IEvalScorer` with the D3 six surfaces.

**(b) `grid_relationship`.** Update to reflect D4 — names every Node Evals composes (AI, Agents, Capabilities, Operator, Knowledge, Memory) and emit-to-Pulse-with-content-carve-out per D10.

**(c) `honeydrunk-ai` block — note model-pinning resolution.** Add a one-line entry to the AI Node's `nodes.json` block (e.g. into `notes` or `roadmap_focus`) recording that the ADR-0016 D3 model-pinning concern is now resolved by ADR-0023 D6: **the sanctioned router-bypass primitive is `IEvalTarget` in HoneyDrunk.Evals.Abstractions** — no other Node introduces an alternate inference path that pins a `ModelCapabilityDeclaration` outside the routing layer.

### `constitution/ai-sector-architecture.md` — Evals section

Update Key Contracts list to the D3 six surfaces. Note the eval-signal carve-out (D10) and the router-bypass via `IEvalTarget` (D6). Depends-on / Emits-to split:

> `**Depends on:** Kernel, AI (IChatClient, IEmbeddingGenerator, IModelProvider, ModelCapabilityDeclaration), Agents (IAgent — for AgentTarget when scaffolded), Capabilities (ICapabilityInvoker — for agent-target tool dispatch flowing through), Operator (ISafetyFilter, ICostGuard, IAuditLog — observation-only per ADR-0023 D7), Knowledge (Providers.InMemory for retrieval fixtures), Memory (Providers.InMemory for memory fixtures).`
>
> `**Emits to (no runtime dependency):** Pulse (eval-signal telemetry with content carve-out per ADR-0023 D10 — content carried unless suite declares sensitive).`

### `repos/HoneyDrunk.Evals/overview.md`

Rewrite Key Contracts section to the D3 six surfaces. Add Packages table including `HoneyDrunk.Evals.Providers.InMemory`. Note the `EvalReport` durability (D13), the router-bypass primitive (D6), and the eval-signal carve-out (D10).

### `repos/HoneyDrunk.Evals/integration-points.md` — new file

Standard template; reflect D4 and D7.

### `repos/HoneyDrunk.Evals/active-work.md` — new file

### `initiatives/active-initiatives.md` — new entry

Standard format. Note the three-way drift reconciliation.

### `CHANGELOG.md` (Architecture repo)

Append: `Architecture: Register ADR-0023 standup decisions in catalogs — RECONCILES three-way drift across contracts.json (renamed IEvalRunner→IEvaluator, IEvalDataset→IEvalSuite; promoted IEvalReport→EvalReport record; added IEvalTarget interface and EvalCase record); relationships.json widens consumes to add Kernel/Agents/Capabilities/Operator/Knowledge/Memory edges with consumes_detail, sets exposes.contracts to D3 six-surface set, adds Providers.InMemory to exposes.packages; nodes.json roadmap_focus updated to D3; grid-health.json gets standup block; ai-sector-architecture.md Evals section reflects D3 + D6 router-bypass + D10 carve-out; repos/HoneyDrunk.Evals/overview.md updated; new integration-points.md and active-work.md; active-initiatives.md gets new entry. ADR-0023 stays Proposed.`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json` (Evals block + AI block one-liner per S4)
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Evals/overview.md`
- `repos/HoneyDrunk.Evals/boundaries.md` (sweep for stale `IEvalDataset` / `IEvalRunner` / interface-form `IEvalReport`)
- `repos/HoneyDrunk.Evals/invariants.md` (same sweep)
- `repos/HoneyDrunk.Evals/integration-points.md` (new)
- `repos/HoneyDrunk.Evals/active-work.md` (new)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] D3 six-surface set is canonical — interfaces keep `I`, records drop it (`EvalCase`, `EvalReport`).
- [x] Three-way drift reconciled in a single PR.
- [x] No code changes; metadata + docs only.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-evals` block lists exactly the D3 six surfaces — four interfaces (`IEvaluator`, `IEvalScorer`, `IEvalSuite`, `IEvalTarget`) + two records (`EvalCase`, `EvalReport`). No `IEvalRunner`, no `IEvalDataset`, no `IEvalReport` (the interface).
- [ ] Records use `kind: "type"`.
- [ ] `catalogs/relationships.json` `honeydrunk-evals.consumes` includes Kernel, Agents, Capabilities, Operator, Knowledge, Memory alongside AI.
- [ ] `catalogs/relationships.json` `honeydrunk-evals.consumes_detail` has entries per edge.
- [ ] `catalogs/relationships.json` `honeydrunk-evals.exposes.contracts` matches D3 six surfaces.
- [ ] `catalogs/relationships.json` `honeydrunk-evals.exposes.packages` includes `HoneyDrunk.Evals.Providers.InMemory`.
- [ ] `catalogs/grid-health.json` `honeydrunk-evals` reflects standup.
- [ ] `catalogs/nodes.json` `honeydrunk-evals.roadmap_focus` reflects D3.
- [ ] `catalogs/nodes.json` `honeydrunk-evals.grid_relationship` reflects D4 + D10.
- [ ] `constitution/ai-sector-architecture.md` Evals section lists the D3 six surfaces; Depends-on / Emits-to split present; D6 router-bypass and D10 carve-out noted.
- [ ] `repos/HoneyDrunk.Evals/overview.md` updated to D3 six surfaces; Packages table includes `Providers.InMemory`.
- [ ] `repos/HoneyDrunk.Evals/integration-points.md` and `active-work.md` exist.
- [ ] `initiatives/active-initiatives.md` includes new entry.
- [ ] `CHANGELOG.md` Unreleased updated.
- [ ] `rg -n "IEvalRunner|IEvalDataset" catalogs/ repos/HoneyDrunk.Evals/ constitution/` returns zero matches.
- [ ] `rg -n "\bIEvalReport\b" catalogs/ repos/HoneyDrunk.Evals/ constitution/` returns zero matches (the interface name is gone; the record `EvalReport` remains).
- [ ] `rg -n "IEvalDataset|IEvalRunner|interface IEvalReport" repos/HoneyDrunk.Evals/` returns zero matches — catches stale references in `repos/HoneyDrunk.Evals/boundaries.md`, `invariants.md`, and any other repo-doc file under that subtree.
- [ ] ADR-0016 D3 model-pinning concern is documented as resolved by ADR-0023 D6 (one-line addition to `nodes.json` AI block noting that `IEvalTarget` is the sanctioned router-bypass primitive).
- [ ] `adrs/ADR-0023-stand-up-honeydrunk-evals-node.md` NOT modified — Status stays Proposed.

## Human Prerequisites
None.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 11:** One repo per Node.

## Referenced ADR Decisions

**ADR-0023 D3:** Six surfaces — four interfaces + two records (`EvalCase`, `EvalReport`).

**ADR-0023 D4:** Boundary decision test against every adjacent Node.

**ADR-0023 D5:** AI composition for chat-backed target + model-as-judge scorer.

**ADR-0023 D6:** Router bypass via `IEvalTarget`.

**ADR-0023 D7:** Operator composition as observation-only scoring signals.

**ADR-0023 D10:** Eval-signal content carve-out (deliberate — content permitted unless suite declares sensitive).

**ADR-0023 D12 / D13:** `EvalReport` provenance + durability.

## Dependencies
None.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0023`

## Agent Handoff

**Objective:** Reconcile three-way drift in catalogs. Land the D3 six-surface set across all four cataloged sources.

**Constraints:**
- **D3 is canonical.** Drop `IEvalRunner`, `IEvalDataset`, `IEvalReport` (interface). Add `IEvaluator`, `IEvalSuite`, `IEvalTarget`, `EvalCase`, `EvalReport` (record).
- **Records use `kind: "type"` in `contracts.json`, not `kind: "record"`.**
- **`consumes` widening.** Seven edges total (Kernel, AI, Agents, Capabilities, Operator, Knowledge, Memory). Each with `consumes_detail`.
- **No code; catalog + docs only.**
- **No ADR Status flip.**

**Key Files:** All listed above.

**Contracts:** None authored. Catalog-only.
