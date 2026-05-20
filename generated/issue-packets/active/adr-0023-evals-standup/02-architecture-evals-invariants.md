---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0023", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0023"]
accepts: ADR-0023
wave: 1
initiative: adr-0023-evals-standup
node: honeydrunk-evals
---

# Chore: Add ADR-0023's seven new invariants to the Grid constitution

## Summary

Add seven new invariants derived from ADR-0023: downstream-coupling (D8), read-only-observer (D11), `EvalReport` full-provenance (D12), `EvalReport` durable-not-ephemeral (D13), eval-signal content carve-out (D10), router-bypass via `IEvalTarget` only (D6), contract-shape canary on four hot-path surfaces (D14).

Default numbers **67, 68, 69, 70, 71, 72, 73** (assumes ADR-0018 + ADR-0020 + ADR-0021 + ADR-0022 have landed first; collision check decides).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Proposed Implementation

### `constitution/invariants.md` — append seven new entries

```markdown
## AI Sector — Evals Invariants

67. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Evals.Abstractions`.**
    Composition against `HoneyDrunk.Evals` and any `HoneyDrunk.Evals.Providers.*` package is a host-time concern. See ADR-0023 D8 (Proposed — this invariant takes effect when ADR-0023 is accepted).

68. **Evals is a read-only observer of targets.**
    No `IEvalTarget` implementation may mutate the target under test from the harness side; the target's own behavior is what the evaluation scores. The harness's behavior is not what is being evaluated. This extends `repos/HoneyDrunk.Evals/invariants.md` item 5 to the Grid level. See ADR-0023 D11 (Proposed — this invariant takes effect when ADR-0023 is accepted).

69. **Every `EvalReport` records the full run provenance — suite identity and version, target identity, `ModelCapabilityDeclaration` identity (when a model was pinned), timestamps, scorer set.**
    `EvalReport` without provenance is not a valid report. A quality signal months later that points to "model X caused regression on suite Y" depends on `EvalReport` having recorded the model-capability identity. See ADR-0023 D12 (Proposed — this invariant takes effect when ADR-0023 is accepted).

70. **`EvalReport` is durable, not ephemeral telemetry.**
    A Pulse signal records *that* a run happened (suite, top-line scores, regression flags); the `EvalReport` is the full artifact (per-case scores, inputs, outputs, rubric breakdown, run provenance) that a regression investigation reads months later when a signal fires. The two are complements, not substitutes. The specific storage substrate is deferred to scaffold per D13; the durability principle is not. See ADR-0023 D13 (Proposed — this invariant takes effect when ADR-0023 is accepted).

71. **Eval-signal telemetry may carry prompts and outputs unless the suite declares itself sensitive.**
    This is a deliberate carve-out from Knowledge's and Memory's content-never-in-telemetry rule, structurally necessary for regression diagnosis — a quality signal that case X dropped from 0.95 to 0.62 is useless for triage without the text of case X. Sensitive suites strip content from emitted signals (metadata only). The `IEvalSuite` sensitivity flag is the contract this carve-out rests on. See ADR-0023 D10 (Proposed — this invariant takes effect when ADR-0023 is accepted).

72. **Router bypass is permitted only through `IEvalTarget`.**
    No other Node introduces an alternate inference path that pins a `ModelCapabilityDeclaration` outside the routing layer. Evals's carve-out is narrow and auditable via `EvalReport` provenance per D12 — every bypass is recorded on the corresponding report's `ModelCapabilityDeclaration` identity. Sim has a parallel-but-distinct surface (`ISimulationTarget`) per ADR-0025 D8; the two do not share types. See ADR-0023 D6 (Proposed — this invariant takes effect when ADR-0023 is accepted).

73. **The HoneyDrunk.Evals Node CI must include a contract-shape canary that fails the build on shape drift to `IEvaluator`, `IEvalScorer`, `IEvalTarget`, `EvalReport`, or `IEvalSuite` without a corresponding version bump.**
    These five are the hot path for every real consumer (Agents ships agent-behavior suites, Knowledge ships retrieval suites, Memory ships memory-workflow suites, Flow / Sim / Lore / HoneyHub when live). Accidental shape drift on any of them breaks every Node that ships suites or consumes reports. `IEvalSuite` is in scope specifically because `IsSensitive` is first-pass as a boolean and expected to evolve to a graded enum (`SensitivityClassification`); the canary catches that change and forces a version bump. See ADR-0023 D14 (Proposed — this invariant takes effect when ADR-0023 is accepted).
```

### Collision check

Default 67-73. Shift on collision; update ADR-0023 Consequences + packet 04 source in lockstep. `rg` only.

**Cross-reference points in packet 04.** When invariant numbers shift, every line in `04-evals-node-scaffold.md` that names an invariant number must be updated in lockstep. The complete list of cross-reference sites — each must be re-pointed if the default 67-73 collides:

**Packet 04 — Boundary Check section (numbered list of checkbox lines):**

- `IEvalTarget` is the router-bypass boundary — **invariant 72** (router-bypass via `IEvalTarget`).
- `ChatTarget` composing `IModelProvider` is the sanctioned bypass — **invariant 72** (cross-reference, same number).
- Operator primitives composed observation-only — **invariant 68** (read-only observer).
- `EvalReport` provenance fields populated including typed `PinnedModelCapability` — **invariant 69** (`EvalReport` records full provenance).
- `EvalReport` is durable at stand-up via `Providers.InMemory` — **invariant 70** (`EvalReport` durable, not ephemeral).
- Content-carve-out flag honored — **invariant 71** (eval-signal content carve-out).
- Multi-tenant identity uses Kernel's `TenantId` strong type — does NOT bind to invariants 67-73; references ADR-0026. Stable across collision shifts.
- (Plus generic invariants 1, 3 — these are stable and do not shift with this packet.)

**Packet 04 — Acceptance Criteria section:**

- The `EvalsTelemetry` content-carve-out criterion cites **invariant 71** ("deliberate carve-out per D10 / invariant 71").

**Packet 04 — Referenced Invariants section (heading list):**

- Downstream-coupling — **invariant 67** ("Evals downstream-coupling invariant").
- Read-only observer — **invariant 68** ("Evals read-only-observer invariant").
- Provenance — **invariant 69** ("Evals provenance invariant").
- Durable-not-ephemeral — **invariant 70** ("Evals durable-not-ephemeral invariant").
- Content carve-out — **invariant 71** ("Evals content-carve-out invariant").
- Router-bypass — **invariant 72** ("Evals router-bypass invariant").
- Contract-shape canary — **invariant 73** ("Evals contract-shape canary invariant").

**Packet 04 — Agent Handoff Constraints section:**

- "**Invariant 71 (default):** Honor `IEvalSuite.IsSensitive` flag…" — re-point if 71 shifts.
- "**Invariant 72 (default):** `IEvalTarget` is the only router-bypass primitive…" — re-point if 72 shifts.

On collision, every line above (six in Boundary Check, one in Acceptance Criteria, seven in Referenced Invariants, two in Constraints) must be re-pointed in the same PR.

### `CHANGELOG.md`

Append: `Architecture: Add invariants 67-73 (Evals downstream coupling, read-only observer, EvalReport provenance, EvalReport durable-not-ephemeral, eval-signal content carve-out, router-bypass via IEvalTarget only, Evals contract-shape canary on four hot-path surfaces) per ADR-0023 D8/D11/D12/D13/D10/D6/D14.`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0023-stand-up-honeydrunk-evals-node.md` (only on shift)
- `generated/issue-packets/active/adr-0023-evals-standup/04-evals-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

## Acceptance Criteria
- [ ] Seven invariants present matching ADR-0023.
- [ ] Numbers verified; default 67-73.
- [ ] `(Proposed — this invariant takes effect when ADR-0023 is accepted)` qualifier on each.
- [ ] On shift, ADR-0023 + packet 04 updated lockstep.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0023 D6, D8, D10, D11, D12, D13, D14.** Sources for invariants 67-73.

## Dependencies
- `packet:01`

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0023`, `constitution`

## Agent Handoff

**Objective:** Seven new invariants. Default 67-73. Shift on collision; lockstep updates.

**Constraints:** `(Proposed)` qualifier each. `rg` only.

**Key Files:** `constitution/invariants.md`; conditional ADR-0023 + packet 04; `CHANGELOG.md`.

**Contracts:** None.
