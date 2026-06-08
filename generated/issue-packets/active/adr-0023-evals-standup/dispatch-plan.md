# Dispatch Plan — ADR-0023 HoneyDrunk.Evals Standup

**Initiative:** `adr-0023-evals-standup`
**Sector:** AI
**Governing ADR:** [ADR-0023 — Stand Up the HoneyDrunk.Evals Node](../../../../adrs/ADR-0023-stand-up-honeydrunk-evals-node.md) (Proposed 2026-04-19; flips to Accepted after merge).
**Trigger:** ADR-0023 in the Proposed queue. Agents (agent-behavior suites), Knowledge (retrieval-quality), Memory (memory-workflow), Flow (workflow-level), Sim, Lore, HoneyHub when live all need a shared evaluation substrate.
**Consumer driver (2026-06-07 — pulled forward):** [ADR-0093 Loop Engineering](../../../../adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md) D4 names Evals the **Tier-B loop-autonomy gate** — the automated gate a loop's worker cannot game by editing its own output, which is what lets loops run without the operator as the per-step bottleneck (the parallel-products unlock). This is the forcing function that pulls Evals' standup ahead of the other eight AI Nodes (`initiatives/current-focus.md` #5; `initiatives/roadmap.md` Q3). The loop gate is a **consumer** of the existing D3 contracts (`IEvaluator` / `IEvalScorer` / `IEvalSuite` / `IEvalTarget` + `EvalCase` / `EvalReport`), **not** a contract change — no packet below changes shape for it; ADR-0093 wires the first loop gate against this substrate as separate follow-up work.
**Type:** Multi-repo (3 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Evals` creation chore + `HoneyDrunk.Evals` scaffold)
**Site sync required:** No.
**Rollback plan:** Pre-tag revert; post-tag fix-forward.

## Summary

ADR-0023 is the standup ADR for `HoneyDrunk.Evals`. Owns evaluation primitives — `IEvaluator`, `IEvalScorer`, `IEvalSuite`, `IEvalTarget`, `EvalCase`, `EvalReport`. **Six surfaces, four interfaces + two records, reconciles three-way drift** between `contracts.json` (three interfaces with wrong names), `relationships.json` (four interfaces with wrong types), repo overview (same four with wrong types). The D3 definitive set lands here.

Three packages (`Abstractions`, runtime, `Providers.InMemory`). Composes AI (`IChatClient` + `IEmbeddingGenerator` + `IModelProvider` + `ModelCapabilityDeclaration` for `ChatTarget` + model-as-judge scorer) per D5. Composes Operator (`ISafetyFilter`, `ICostGuard`, `IAuditLog`) as observation-only scoring signals per D7. Router-bypass through `IEvalTarget` per D6 — `IEvalTarget` pins `ModelCapabilityDeclaration` for reproducible regression testing. Content-in-telemetry **carve-out** per D10 (eval signals may carry prompts and outputs unless the suite declares sensitive — deliberate carve-out from Knowledge/Memory's no-content rule for regression diagnosis). `EvalReport` durable per D13 (storage substrate deferred). Canary on four hot-path surfaces per D14.

**The `HoneyDrunk.Evals` repo does NOT exist on GitHub yet.** A human-only **create + clone** chore is required (pattern matches ADR-0017 packet 03).

Four packets land the work:

1. **Architecture catalog registration + integration-points** — RECONCILE three-way drift: rename `IEvalRunner` → `IEvaluator`; rename `IEvalDataset` → `IEvalSuite`; promote `IEvalReport` → `EvalReport` record; add `EvalCase` record; add `IEvalTarget` interface. Update `relationships.json` to widen `consumes` (add Kernel, Agents, Capabilities, Operator, Knowledge, Memory; widen AI `consumes_detail`); update `exposes.contracts` to the D3 six-surface set. Reconcile `nodes.json` `roadmap_focus`. Refresh `grid-health.json`. Align `repos/HoneyDrunk.Evals/overview.md` (the Architecture-side repo doc; the GitHub repo does not exist yet). Align `constitution/ai-sector-architecture.md` Evals section. Add `integration-points.md` and `active-work.md` under `repos/HoneyDrunk.Evals/`.
2. **Constitution invariants** — seven new invariants from D8, D11, D12, D13, D10, D6, D14.
3. **Create the `HoneyDrunk.Evals` GitHub repo (human-only)** — org-admin action. Same pattern as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` — but ALSO clones it locally so packet 04 has a working tree.
4. **HoneyDrunk.Evals scaffold** — empty repo to first-shippable. Solution, three packages (`Abstractions`, runtime, `Providers.InMemory`), four interfaces + two records, default runtime with `ChatTarget` shape (router-bypass), `Providers.InMemory` backend for `EvalReport` persistence + suite fixtures, five CI workflow files with canary scoped to Abstractions.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-evals-catalog-registration
   └─ Architecture: 02-architecture-evals-invariants
       Blocked by: 01

Wave 2: Create + clone repo (human)
   └─ Architecture: 03-architecture-create-evals-repo
       Blocked by: 01

Wave 3: Evals repo scaffold
   └─ HoneyDrunk.Evals: 04-evals-node-scaffold
       Blocked by: 01, 02, 03
```

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + three-way drift reconciliation + integration-points](./01-architecture-evals-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add seven new invariants for D8 / D11 / D12 / D13 / D10 / D6 / D14](./02-architecture-evals-invariants.md) | Architecture | 1 | Agent | 01 |
| 03 | [Create `HoneyDrunk.Evals` GitHub repo + clone locally (human-only)](./03-architecture-create-evals-repo.md) | Architecture | 2 | Human | 01 |
| 04 | [Stand up `HoneyDrunk.Evals` — solution, three packages, six surfaces, CI, InMemory provider](./04-evals-node-scaffold.md) | HoneyDrunk.Evals | 3 | Agent | 01, 02, 03 |

## Filing-order rule

Packet 04 hard-codes invariant numbers. **Packet 02 must merge first.** Packet 03 must close (repo exists) before packet 04 can be filed. Pre-filing amendment to packet 04 source permitted under invariant 24.

**Packet 04 cannot be filed before packet 03 is closed** — `file-packets.sh` cannot create an issue on a repo that does not exist.

## What This Initiative Does **NOT** Deliver

- Downstream consumers not delivered.
- Concrete `IEvalTarget` shapes (`AgentTarget`, `RetrievalTarget`, `MemoryTarget`) deferred to follow-up packets per D3.
- `EvalReport` durable-storage **substrate** deferred per D13 (durability *principle* pinned; substrate choice — Data, Pulse-backed, dedicated provider — follows when a real production consumer drives shape).
- Pulse signal ingress deferred (emit-only per D10).
- Monte Carlo / N-trial distribution surfaces deferred per scaffold (D3 / D14).
- Sensitivity-flag concrete shape on `IEvalSuite` is a scaffold decision (carve-out principle pinned at ADR).
- No separate `HoneyDrunk.Evals.Testing` — `Providers.InMemory` plays that role per D2.

## AI-sector standup wave sequencing

Evals composes AI + Agents + Capabilities + Operator + Knowledge + Memory at the runtime level. Recommended order: AI → Capabilities → Operator → Knowledge + Memory → Agents → **Evals** + Flow → Sim. Evals's packet 04 cannot compile if any upstream Abstractions is missing — placeholder no-ops + follow-up packets bridge the gap.

## Status flip

ADR-0023 auto-flips to **Accepted** when packet 01's issue closes — packet 01 carries `accepts: ["ADR-0023"]`, so `hive-sync` flips it per ADR-0014 D7 (the AI-sector pattern: acceptance = decision + catalog reconciliation; the scaffold in packet 04 is downstream). The scope agent assigns final invariant numbers at flip per the ADR-0023 follow-up checklist. *(Normalized 2026-06-07: the frontmatter already carried `accepts:`; this prose was corrected to match.)*

## Filing

`file-packets.yml` auto-files. Packet 04 filing is gated on packet 03's repo creation (handled by the Next-Steps script inside packet 03).

## Archival

Per ADR-0008 D10, archive post-completion.
