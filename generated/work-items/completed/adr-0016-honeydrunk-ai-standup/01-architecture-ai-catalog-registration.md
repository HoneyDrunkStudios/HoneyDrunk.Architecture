---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0016"]
dependencies: []
adrs: ["ADR-0016", "ADR-0010"]
wave: 1
initiative: adr-0016-honeydrunk-ai-standup
node: honeydrunk-ai
---

# Chore: Register HoneyDrunk.AI's standup decisions in Architecture catalogs

## Summary
Reflect ADR-0016's stand-up decisions in the canonical Architecture catalogs and the AI sector architecture doc. Update `contracts.json` to match D3's seven-contract surface, register `honeydrunk-ai` in `grid-health.json`, tighten the loose "depends on Pulse" phrasing in both `nodes.json` and `constitution/ai-sector-architecture.md` to reflect the one-way telemetry direction set by D7, and complete the stale `Providers.Local` → `Providers.InMemory` rename in catalogs and AI repo docs (D2 lists `InMemory` as the fourth provider slot — `Local`/ONNX has been retired from D2).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0016 establishes the AI Node's exposed contracts, package families, and downstream-coupling rule. None of that has reached the catalogs yet. Until it does, every downstream consumer (Capabilities, Operator, Agents, Memory, Knowledge, Evals) reads stale or inconsistent metadata when scoping their own work.

Five specific drift items must be resolved in this work-item:

1. **`contracts.json` lists `IInferenceResult` but ADR-0016 D3 lists `ICostLedger`.** ADR-0016's "If Accepted" checklist also lists `IInferenceResult` — that is a discrepancy in the ADR itself. Per the user's explicit instruction during scoping, the **D3 table is canonical**: drop `IInferenceResult` from the catalog and add `ICostLedger`. Flag the "If Accepted" checklist as needing reconciliation in a follow-up.
2. **`catalogs/grid-health.json`** has `honeydrunk-ai` but no per-contract surface entries. Other Live nodes have full per-Node entries; AI's is currently a stub blocked on "Repo not yet scaffolded".
3. **`nodes.json` (line 603)** says `"Consumes Kernel (context, telemetry), Vault (API keys), Pulse (inference telemetry). Consumed by Agents, Memory, Knowledge, Evals, Sim."` — the "Pulse (inference telemetry)" phrasing implies a runtime dependency. Per ADR-0016 D7, **AI emits telemetry consumed by Pulse; there is no runtime dependency on Pulse**. The same drift exists in `constitution/ai-sector-architecture.md` ~line 114.
4. **Stale `HoneyDrunk.AI.Providers.Local` references** appear across catalogs and AI repo docs. ADR-0016 D2 lists the fourth provider slot as **`HoneyDrunk.AI.Providers.InMemory`** (deterministic test double for Evals and CI). The previous `Local`/ONNX framing has been retired. Replace `Providers.Local` with `Providers.InMemory` everywhere it appears in catalogs/ and `repos/HoneyDrunk.AI/`. The corresponding `local`/`onnx` value-prop strings in `nodes.json` are also revised away from local/ONNX language toward the InMemory/test-double role.
5. **ADR-0016 D2 line 42 contains its own drift** — it says `HoneyDrunk.AI.Abstractions` carries "Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions." Repo-local invariant 1 at `repos/HoneyDrunk.AI/invariants.md:5` says zero HoneyDrunk dependencies, only `Microsoft.Extensions.*` abstractions allowed. Per the user's resolution during scoping, **the strict stance wins**: `HoneyDrunk.AI.Abstractions` ships with zero `HoneyDrunk.*` references. Kernel reference lives in the `HoneyDrunk.AI` runtime package, not Abstractions. ADR-0016 D2 line 42 is amended in this packet to match.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-ai` block

Replace the existing seven-entry interfaces array with exactly the seven contracts from ADR-0016 D3, in this order. Records lose the `I` prefix; interfaces keep it (per the Grid-wide naming rule).

```json
{
  "node": "honeydrunk-ai",
  "node_name": "HoneyDrunk.AI",
  "package": "HoneyDrunk.AI.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IChatClient", "kind": "interface", "description": "Canonical chat completion entry point. Shape-compatible with Microsoft.Extensions.AI but a distinct type under HoneyDrunk.AI.Abstractions (ADR-0016 D6)." },
    { "name": "IEmbeddingGenerator", "kind": "interface", "description": "Canonical embedding entry point. Shape-compatible with Microsoft.Extensions.AI but a distinct type under HoneyDrunk.AI.Abstractions (ADR-0016 D6)." },
    { "name": "IModelProvider", "kind": "interface", "description": "Provider-slot interface — implement per inference backend (OpenAI, Anthropic, Azure OpenAI, InMemory)." },
    { "name": "IModelRouter", "kind": "interface", "description": "Capability-driven model selection. Routes inference requests to the most appropriate provider based on policy, capability, cost, and runtime constraints." },
    { "name": "IRoutingPolicy", "kind": "interface", "description": "Pluggable routing strategy — cost-first, capability-first, latency-first, compliance-first. Sourced from Azure App Configuration via Vault's IConfigProvider." },
    { "name": "ModelCapabilityDeclaration", "kind": "type", "description": "Record. Machine-readable model capability metadata used by IModelRouter to match requests to supported providers." },
    { "name": "ICostLedger", "kind": "interface", "description": "Per-call token and cost accounting surface. Cost-rate tables sourced from Azure App Configuration via Vault's IConfigProvider — never hardcoded." }
  ]
}
```

Two surface-level changes vs current state:

- **Remove** the `IInferenceResult` entry (ADR-0016 D3 does not list it). Document in the PR description that this is the deliberate D3-canonical resolution of the ADR-0016 "If Accepted" vs D3 discrepancy.
- **Add** the `ICostLedger` entry with the App-Config-sourced rate-table description (D5).

### `catalogs/relationships.json` — `honeydrunk-ai` block

Two edits to this block.

**(a) `exposes.contracts` array.** Currently reads:

```json
"contracts": ["IChatClient", "IEmbeddingGenerator", "IModelProvider", "IInferenceResult", "IModelRouter", "IRoutingPolicy", "ModelCapabilityDeclaration"]
```

Replace with:

```json
"contracts": ["IChatClient", "IEmbeddingGenerator", "IModelProvider", "IModelRouter", "IRoutingPolicy", "ModelCapabilityDeclaration", "ICostLedger"]
```

Same swap: drop `IInferenceResult`, add `ICostLedger`.

**(b) `exposes.packages` array (line 191).** Currently reads:

```json
"packages": ["HoneyDrunk.AI.Abstractions", "HoneyDrunk.AI", "HoneyDrunk.AI.Providers.OpenAI", "HoneyDrunk.AI.Providers.Anthropic", "HoneyDrunk.AI.Providers.AzureOpenAI", "HoneyDrunk.AI.Providers.Local"]
```

Replace `"HoneyDrunk.AI.Providers.Local"` with `"HoneyDrunk.AI.Providers.InMemory"`:

```json
"packages": ["HoneyDrunk.AI.Abstractions", "HoneyDrunk.AI", "HoneyDrunk.AI.Providers.OpenAI", "HoneyDrunk.AI.Providers.Anthropic", "HoneyDrunk.AI.Providers.AzureOpenAI", "HoneyDrunk.AI.Providers.InMemory"]
```

This aligns with ADR-0016 D2 line 48 — the fourth provider slot is `InMemory`, not `Local`.

### `catalogs/grid-health.json` — `honeydrunk-ai` block

Replace the existing stub block with one that reflects ADR-0016 acceptance:

```json
{
  "id": "honeydrunk-ai",
  "name": "HoneyDrunk.AI",
  "sector": "AI",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["Scaffold packet (AI#NN — packet 03 of adr-0016-honeydrunk-ai-standup) not yet executed"],
  "notes": "ADR-0016 standup ADR Proposed 2026-04-19. Catalog surface registered (7 contracts per D3). Awaiting scaffold execution: HoneyDrunk.AI.Abstractions (7 contracts), HoneyDrunk.AI runtime, four provider-slot packages (OpenAI/Anthropic/AzureOpenAI/InMemory), Standards wiring, CI with api-compatibility canary scoped to Abstractions (D8), InMemory provider for Evals/CI determinism."
}
```

Update the `summary.blocked_nodes` list to keep `honeydrunk-ai` (it stays blocked until the scaffold packet executes) — no change needed there, just confirm the entry remains.

### `catalogs/nodes.json` — `honeydrunk-ai` block

Three edits to this block.

**(a) `grid_relationship` field (line 603).** Current text:

> `"grid_relationship": "Consumes Kernel (context, telemetry), Vault (API keys), Pulse (inference telemetry). Consumed by Agents, Memory, Knowledge, Evals, Sim."`

Replace with:

> `"grid_relationship": "Consumes Kernel (context, telemetry) and Vault (API keys + App Configuration for routing policies and cost-rate tables). Emits inference telemetry consumed by Pulse — no runtime dependency on Pulse. Consumed by Agents, Memory, Knowledge, Evals, Sim, Lore."`

The Lore addition reflects existing relationships.json data (`honeydrunk-lore` is in `consumed_by_planned`).

**(b) `value_props` line 596.** Current text:

> `"Pluggable provider adapters (OpenAI, Anthropic, Azure OpenAI, local/ONNX)",`

Replace with:

> `"Pluggable provider adapters (OpenAI, Anthropic, Azure OpenAI, InMemory)",`

This matches ADR-0016 D2's first-wave provider list. `local/ONNX` has been retired from the D2 surface.

**(c) `tags` line 586.** Current text:

> `"tags": ["inference", "llm", "embeddings", "providers", "openai", "anthropic", "azure-openai", "telemetry"],`

The tag list as it stands has no `local` or `onnx` token to drop, but it is missing `inmemory`. Add it:

> `"tags": ["inference", "llm", "embeddings", "providers", "openai", "anthropic", "azure-openai", "inmemory", "telemetry"],`

If at edit time the tag list contains `local` or `onnx` (drift may have appeared since this packet was authored), drop those tokens in the same edit.

Do **not** edit the line that reads `"Automatic token/latency/cost telemetry via Pulse"` (also a `value_props` entry) or line 605 (the demo path) — those describe what the telemetry does, not a dependency direction.

### `constitution/ai-sector-architecture.md` — two edits

**(a) Provider Slot Pattern table (lines 104–112).** Current block:

```
HoneyDrunk.AI.Abstractions          → contracts
HoneyDrunk.AI                       → runtime, routing, telemetry
HoneyDrunk.AI.Providers.OpenAI      → OpenAI adapter
HoneyDrunk.AI.Providers.Anthropic   → Anthropic adapter
HoneyDrunk.AI.Providers.AzureOpenAI → Azure OpenAI adapter
HoneyDrunk.AI.Providers.Local       → local/ONNX models
```

Replace the `Local` row only:

```
HoneyDrunk.AI.Providers.InMemory    → deterministic test double for Evals and CI
```

Verify the rest of the block is consistent with ADR-0016 D2 — the four runtime/abstractions/providers rows above the InMemory row should remain as they are.

**(b) Line 114 — dependency phrasing.** Current text:

> `**Depends on:** Kernel (context, telemetry), Vault (API keys), Pulse (inference telemetry)`

Replace with:

> `**Depends on:** Kernel (context, telemetry), Vault (API keys + App Configuration for routing policies and cost-rate tables)`
>
> `**Emits to (no runtime dependency):** Pulse (inference telemetry per call — token counts, latency, model identifiers, cost estimates)`

Do not change the surrounding "Note:" block about Microsoft.Extensions.AI alignment — ADR-0016 D6 keeps the alignment commitment in place.

### `repos/HoneyDrunk.AI/overview.md` — line 21

Replace:

> `| `HoneyDrunk.AI.Providers.Local` | Provider | Local/ONNX model adapter |`

with:

> `| `HoneyDrunk.AI.Providers.InMemory` | Provider | Deterministic test double for Evals and CI |`

### `repos/HoneyDrunk.AI/boundaries.md` — line 7 (provider list drift)

Current text on line 7 (under `## What AI Owns`):

> `- Provider adapters (OpenAI, Anthropic, Azure OpenAI, local models)`

Replace with:

> `- Provider adapters (OpenAI, Anthropic, Azure OpenAI, InMemory test double)`

The same "Providers.Local → Providers.InMemory" rationale that applies elsewhere applies here. The "local models" framing is retired from D2.

### `repos/HoneyDrunk.AI/invariants.md` — cross-references and packaging clarification

Two surface edits to keep this file aligned with the constitutional invariants packet 02 lands and with ADR-0016 D2/D7.

**(a) Cross-reference the new constitutional invariants (44/45/46).** This file is repo-scoped (lives under `repos/HoneyDrunk.AI/`) and supplements `constitution/invariants.md`. Add a one-line note immediately after the existing list of seven repo-scoped invariants pointing readers at the constitutional invariants that govern AI behavior:

> `_Constitutional invariants 28, 44, 45, 46 (in `constitution/invariants.md`) also apply — hardcoded model names forbidden (28); downstream-only Abstractions coupling (44); App-Config-sourced rates and policies (45); contract-shape canary in CI (46)._`

**(b) Tighten invariant 6 to localize GridContext propagation in the runtime package.** Current invariant 6:

> `6. **GridContext is propagated on every inference call.**`
> `   CorrelationId and CausationId flow through to provider requests for end-to-end tracing.`

Replace with:

> `6. **GridContext is propagated on every inference call — by the AI runtime package, not by Abstractions.**`
> `   CorrelationId and CausationId flow through to provider requests for end-to-end tracing. Implementation lives in HoneyDrunk.AI runtime (specifically InferenceTelemetry); HoneyDrunk.AI.Abstractions stays HoneyDrunk-dependency-free per invariant 1.`

This makes the dependency-clean Abstractions stance explicit at the repo-scoped level.

### `repos/HoneyDrunk.AI/active-work.md` — lines 22–26

The existing list reads:

```
- Provider adapters: OpenAI, Anthropic, Azure OpenAI (each as separate package, provider slot pattern)
  - `HoneyDrunk.AI.Providers.OpenAI`
  - `HoneyDrunk.AI.Providers.Anthropic`
  - `HoneyDrunk.AI.Providers.AzureOpenAI`
  - `HoneyDrunk.AI.Providers.Local` (ONNX — deferred)
```

Replace the trailing `Local` line so the list reads:

```
- Provider adapters: OpenAI, Anthropic, Azure OpenAI, InMemory (each as separate package, provider slot pattern)
  - `HoneyDrunk.AI.Providers.OpenAI`
  - `HoneyDrunk.AI.Providers.Anthropic`
  - `HoneyDrunk.AI.Providers.AzureOpenAI`
  - `HoneyDrunk.AI.Providers.InMemory` (deterministic test double for Evals and CI)
```

### Stale `Providers.Local` sweep

Before opening the PR, grep `catalogs/` and `repos/HoneyDrunk.AI/` for any remaining `Providers.Local` or `local/ONNX` or `local models` strings the explicit fix list above missed. None should remain after this packet. The grep is a hard check, not a best-effort.

### `relationships.json` honeydrunk-ai dependency direction — verify, don't edit

`catalogs/relationships.json` line 185 currently reads `"consumes": ["honeydrunk-kernel", "honeydrunk-vault"]` for `honeydrunk-ai`. Per ADR-0016 D7, this is correct as-is — `honeydrunk-pulse` must NOT appear in the `consumes` array. As an acceptance check (verify-don't-edit):

- Open `catalogs/relationships.json`, find the `honeydrunk-ai` block (around line 184).
- Confirm `consumes` is exactly `["honeydrunk-kernel", "honeydrunk-vault"]` — no `honeydrunk-pulse`.
- If `honeydrunk-pulse` is present, remove it. Otherwise no edit is needed; this is a confirmation only.

The integration-points doc at `repos/HoneyDrunk.AI/integration-points.md` already states the Pulse row as "no runtime dependency" — also verify-don't-edit; if drift is present, fix it in the same PR.

### `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` — `If Accepted` checklist correction (line 12)

The checklist on line 12 of the ADR currently reads:

> `- [ ] Add entries to \`catalogs/contracts.json\` for the seven exposed contracts: \`IChatClient\`, \`IEmbeddingGenerator\`, \`IInferenceResult\`, \`IModelProvider\`, \`IModelRouter\`, \`IRoutingPolicy\`, \`ModelCapabilityDeclaration\``

Replace `IInferenceResult` with `ICostLedger` so the checklist matches the canonical D3 surface this packet lands:

> `- [ ] Add entries to \`catalogs/contracts.json\` for the seven exposed contracts: \`IChatClient\`, \`IEmbeddingGenerator\`, \`IModelProvider\`, \`IModelRouter\`, \`IRoutingPolicy\`, \`ModelCapabilityDeclaration\`, \`ICostLedger\``

Same correction may also be needed on line 15 of the ADR (the canary obligation lists `IChatClient`, `IEmbeddingGenerator`, `IInferenceResult`, `IModelProvider`). Per D8, the four hot-path contracts are `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IModelRouter` — replace `IInferenceResult` with `IModelRouter` on line 15:

> `- [ ] Wire the contract-shape canary into Actions (freezes \`IChatClient\`, \`IEmbeddingGenerator\`, \`IModelProvider\`, \`IModelRouter\` shapes)`

Document both line corrections in the PR body alongside the D2 line 42 amendment.

### `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` — D2 line 42 amendment

Current text (line 42):

> `- `HoneyDrunk.AI.Abstractions` — all interfaces, request/response shapes, capability declarations, cost records. Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions.`

Replace with:

> `- `HoneyDrunk.AI.Abstractions` — all interfaces, request/response shapes, capability declarations, cost records. Zero runtime dependencies beyond `Microsoft.Extensions.*` abstractions.`

Rationale: repo-local invariant 1 at `repos/HoneyDrunk.AI/invariants.md:5` is the strict stance ("zero HoneyDrunk dependencies. Only `Microsoft.Extensions.*` abstractions are allowed"). Per the user's resolution during scoping, the strict stance wins — `HoneyDrunk.AI.Abstractions` ships with zero `HoneyDrunk.*` references, including no `HoneyDrunk.Kernel.Abstractions`. The Kernel reference lives in the `HoneyDrunk.AI` runtime package, not Abstractions. This ADR-internal drift is reconciled in the same packet that reconciles the `IInferenceResult`/`ICostLedger` checklist drift.

Document this in the PR body as the **third** "ADR drift reconciled" item alongside the existing checklist correction and the `IInferenceResult` → `ICostLedger` swap.

### `CHANGELOG.md` (Architecture repo)
Append to the Unreleased section a line: `Architecture: Register ADR-0016 standup decisions in catalogs (contracts.json swaps IInferenceResult for ICostLedger per D3; grid-health.json gets full honeydrunk-ai block; nodes.json + ai-sector-architecture.md tighten Pulse dependency phrasing per D7; Providers.Local → Providers.InMemory completed across catalogs and repos/HoneyDrunk.AI; ADR-0016 D2 line 42 amended to strict "Microsoft.Extensions.* only" Abstractions stance).`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json` (verify `consumes` does not include `honeydrunk-pulse`; edit `exposes.contracts` and `exposes.packages`)
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.AI/overview.md`
- `repos/HoneyDrunk.AI/active-work.md`
- `repos/HoneyDrunk.AI/boundaries.md` (line 7 — drop "local models" → "InMemory test double")
- `repos/HoneyDrunk.AI/invariants.md` (cross-reference invariants 28/44/45/46; tighten invariant 6)
- `repos/HoneyDrunk.AI/integration-points.md` (verify-don't-edit; ensure Pulse row says "no runtime dependency")
- `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` (D2 line 42 amendment + line 12 / line 15 checklist contract-name fixes)
- `CHANGELOG.md`

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits are inside the `HoneyDrunk.Architecture` repo.
- [x] No code changes anywhere; metadata only.
- [x] No contract bodies invented in this packet — only catalog registration of ADR-0016's already-decided surface.
- [x] The `IInferenceResult` → `ICostLedger` swap is a deliberate alignment to D3 (the canonical decision body), not a new design choice.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-ai` block lists exactly the 7 contracts from ADR-0016 D3 (no `IInferenceResult`; `ICostLedger` present). The `IModelProvider` description reads `"Provider-slot interface — implement per inference backend (OpenAI, Anthropic, Azure OpenAI, InMemory)."` (no `local`).
- [ ] `catalogs/relationships.json` `honeydrunk-ai` `exposes.contracts` array matches the same 7-contract surface (no `IInferenceResult`; `ICostLedger` present).
- [ ] `catalogs/relationships.json` `honeydrunk-ai` `exposes.packages` array no longer contains `HoneyDrunk.AI.Providers.Local`; contains `HoneyDrunk.AI.Providers.InMemory` instead.
- [ ] `catalogs/grid-health.json` `honeydrunk-ai` block reflects the standup ADR with the scaffold packet noted as the active blocker.
- [ ] `catalogs/nodes.json` `honeydrunk-ai.grid_relationship` field no longer says "Pulse (inference telemetry)" as a dependency; phrased as one-way emission per D7.
- [ ] `catalogs/nodes.json` `honeydrunk-ai.long_description.value_props` no longer references `local/ONNX`; references `InMemory` instead.
- [ ] `catalogs/nodes.json` `honeydrunk-ai.tags` includes `inmemory` and contains no `local`/`onnx` tokens.
- [ ] `constitution/ai-sector-architecture.md` Provider Slot Pattern block has the `HoneyDrunk.AI.Providers.Local → local/ONNX models` row replaced with `HoneyDrunk.AI.Providers.InMemory → deterministic test double for Evals and CI`.
- [ ] `constitution/ai-sector-architecture.md` line ~114 split into "Depends on" (no Pulse) and "Emits to (no runtime dependency): Pulse" lines.
- [ ] `repos/HoneyDrunk.AI/overview.md` line 21 reads the new `Providers.InMemory` row instead of `Providers.Local`.
- [ ] `repos/HoneyDrunk.AI/active-work.md` lines 22–26 list `InMemory` (deterministic test double for Evals and CI) as the fourth provider slot — no `Local` (ONNX — deferred) bullet.
- [ ] `repos/HoneyDrunk.AI/boundaries.md` line 7 reads `Provider adapters (OpenAI, Anthropic, Azure OpenAI, InMemory test double)` — no `local models`.
- [ ] `repos/HoneyDrunk.AI/invariants.md` carries a one-line cross-reference to constitutional invariants 28/44/45/46 and invariant 6 reads as the runtime-localized GridContext propagation rule.
- [ ] `grep -nr "Providers.Local\|local/ONNX\|local models" catalogs/ repos/HoneyDrunk.AI/` returns no matches after edits.
- [ ] `catalogs/relationships.json` `honeydrunk-ai.consumes` is `["honeydrunk-kernel", "honeydrunk-vault"]` exactly — no `honeydrunk-pulse`. (Verify; edit only if drift is present.)
- [ ] `repos/HoneyDrunk.AI/integration-points.md` Pulse row reads "no runtime dependency". (Verify; edit only if drift is present.)
- [ ] `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` D2 line 42 amended from `Zero runtime dependencies beyond \`HoneyDrunk.Kernel\` abstractions.` to `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.`
- [ ] `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` line 12 `If Accepted` checklist item updated: `IInferenceResult` → `ICostLedger` so the seven contracts match D3.
- [ ] `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` line 15 `If Accepted` canary item updated: `IInferenceResult` → `IModelRouter` so the four frozen contracts match D8.
- [ ] `CHANGELOG.md` Unreleased section updated with all drift reconciliations called out.
- [ ] PR body explicitly notes the four "ADR drift reconciled" items: (1) D3-canonical resolution of the `IInferenceResult` vs `ICostLedger` checklist mismatch (line 12 + line 15), (2) `Providers.Local` → `Providers.InMemory` rename completing D2's first-wave provider list, (3) D2 line 42 amendment from `HoneyDrunk.Kernel`-allowed to `Microsoft.Extensions.*`-only Abstractions stance, (4) `repos/HoneyDrunk.AI/{boundaries.md, invariants.md}` aligned to D2 (provider-list) and D7 (runtime-vs-Abstractions GridContext propagation).

## Human Prerequisites
- [ ] Confirm the D2 line 42 amendment in this packet (Kernel-abstractions → `Microsoft.Extensions.*` only) is the intended stance before merge — this is the user's explicit scoping resolution but it is also the kind of decision that benefits from a final eye before it lands in the canonical ADR.
- [ ] Confirm the line 12 / line 15 `IInferenceResult` corrections in the ADR's `If Accepted` checklist match the user's understanding of D3 (the seven exposed contracts) and D8 (the four frozen-shape contracts) — both edits are mechanical drift fixes, but ADR Consequences edits warrant a quick eye.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why `HoneyDrunk.AI.Abstractions` is the only thing downstream Nodes compile against.

> **Invariant 28:** Application code must never hardcode a model name or provider. All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. — Reinforces D5 and the role of `ICostLedger`/`IRoutingPolicy` as App-Config-sourced.

## Referenced ADR Decisions

**ADR-0016 D3 (Exposed contracts):** Seven contracts form the AI Node's public boundary — `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` (record), `ICostLedger`. Records drop the `I`; interfaces keep it. **This packet treats D3 as canonical** because the user explicitly resolved the ADR-internal discrepancy with D3 in scoping.

**ADR-0016 D5 (Routing policy source):** Routing policies, cost-rate tables, and capability declarations live in Azure App Configuration and are read through `IConfigProvider` from the Vault Node per ADR-0005. The `ICostLedger` description in `contracts.json` reflects this.

**ADR-0016 D7 (Telemetry emission):** AI emits telemetry to Pulse via Kernel's `ITelemetryActivityFactory`. AI has **no runtime dependency on Pulse**. The catalog edits in this packet bring `nodes.json` and `ai-sector-architecture.md` into alignment with that direction.

**ADR-0016 D9 (Downstream coupling):** Downstream AI-sector Nodes compile only against `HoneyDrunk.AI.Abstractions`. The `package` field on the `contracts.json` entry stays at `HoneyDrunk.AI.Abstractions` — never `HoneyDrunk.AI` or any provider package.

## Dependencies
None. This packet is the foundation of the initiative — it can land before the scaffold packet exists, because the catalog surface is design-decided already in ADR-0016. Packets 02 and 03 reference this one as `work-item:01`.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0016`

## Agent Handoff

**Objective:** Bring `HoneyDrunk.Architecture` catalogs into alignment with ADR-0016 D3, D5, D7 — without inventing any new design choices.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Catalog drift is the bottleneck that blocks downstream AI Nodes from scoping their own work. This packet removes the drift introduced by ADR-0016's acceptance.
- Feature: ADR-0016 standup initiative.
- ADRs: ADR-0016 (this packet implements the catalog half of "If Accepted"); ADR-0010 (already-accepted source of `IModelRouter`/`IRoutingPolicy`/`ModelCapabilityDeclaration`).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this packet runs first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. Reinforces why the `package` field on the `honeydrunk-ai` `contracts.json` entry stays `HoneyDrunk.AI.Abstractions` — that is what downstream Nodes compile against.
- **Invariant 28:** Application code must never hardcode a model name or provider. All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. Reinforces D5 and the inclusion of `IRoutingPolicy` and `ICostLedger` in the catalog surface.
- **D3 is canonical.** The ADR's "If Accepted" checklist lists `IInferenceResult`; D3 lists `ICostLedger`. Per the user's scoping instruction, the D3 table wins. Drop `IInferenceResult` from `contracts.json` and `relationships.json`. Add `ICostLedger`.
- **D2 first-wave provider list is canonical.** The fourth provider slot is `HoneyDrunk.AI.Providers.InMemory` (deterministic test double for Evals and CI). `Providers.Local` / local-ONNX framing is retired. Apply the rename across `catalogs/relationships.json:191`, `catalogs/contracts.json` (the `IModelProvider` description), `catalogs/nodes.json` (value_props line 596 and tags line 586), `constitution/ai-sector-architecture.md` (Provider Slot Pattern block at line 111), `repos/HoneyDrunk.AI/overview.md:21`, and `repos/HoneyDrunk.AI/active-work.md:22-26`. Final grep over `catalogs/` and `repos/HoneyDrunk.AI/` must show zero `Providers.Local` and zero `local/ONNX` matches.
- **Strict Abstractions stance.** The repo-local invariant 1 (`repos/HoneyDrunk.AI/invariants.md:5`) and ADR-0016 D2 line 42 disagree as written; the strict stance wins. `HoneyDrunk.AI.Abstractions` ships with zero `HoneyDrunk.*` references. Amend D2 line 42 in this packet from `Zero runtime dependencies beyond \`HoneyDrunk.Kernel\` abstractions.` to `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.` Packet 03 keeps Abstractions HoneyDrunk-free; Kernel reference lives in the `HoneyDrunk.AI` runtime package.

**Key Files:**
- `catalogs/contracts.json` — replace the `honeydrunk-ai` block's interfaces array; drop `local` from `IModelProvider` description
- `catalogs/relationships.json` — verify `consumes` does not include `honeydrunk-pulse`; swap `IInferenceResult` for `ICostLedger` in `exposes.contracts`; swap `Providers.Local` for `Providers.InMemory` in `exposes.packages` (line 191)
- `catalogs/grid-health.json` — replace the `honeydrunk-ai` block
- `catalogs/nodes.json` — edit line 603 (`grid_relationship` field), line 596 (`value_props` adapters string), line 586 (`tags` — add `inmemory`, drop any `local`/`onnx` tokens)
- `constitution/ai-sector-architecture.md` — edit Provider Slot Pattern block (line 111 row replacement) and dependency phrasing line ~114
- `repos/HoneyDrunk.AI/overview.md` — edit line 21 provider table row
- `repos/HoneyDrunk.AI/active-work.md` — edit lines 22–26 provider list bullets
- `repos/HoneyDrunk.AI/boundaries.md` — edit line 7 (drop "local models" → "InMemory test double")
- `repos/HoneyDrunk.AI/invariants.md` — add cross-reference to constitutional invariants 28/44/45/46; tighten invariant 6 to localize GridContext propagation in runtime
- `repos/HoneyDrunk.AI/integration-points.md` — verify Pulse row reads "no runtime dependency"
- `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` — amend D2 line 42 (`HoneyDrunk.Kernel` abstractions → `Microsoft.Extensions.*` abstractions); fix line 12 `If Accepted` contracts list (`IInferenceResult` → `ICostLedger`); fix line 15 `If Accepted` canary contracts list (`IInferenceResult` → `IModelRouter`)
- `CHANGELOG.md` — Unreleased entry

**Contracts:**
- This packet does not author any new contracts. It records the seven D3 contracts in the catalog. Authoring of the actual `.cs` files happens in packet 03 (the scaffold).
