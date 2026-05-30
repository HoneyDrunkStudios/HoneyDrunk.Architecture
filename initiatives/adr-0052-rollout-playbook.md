# ADR-0052 Cost Governance — Rollout Playbook

**Initiative:** `adr-0052-cost-governance`
**Purpose:** Record the deferred Phase 2–7 work so a future `scope` agent can re-decompose it into packets when each gating event fires — without re-reading ADR-0052 end to end. The playbook is a rollout-stagger map, not an issue tracker; do **not** file the deferred items as issues now (that creates noise against Nodes that don't yet exist).

## Status

**Landed this pass (Architecture-side governance substrate):**

- ADR-0052 Accepted; cost-governance invariants **104** (every cost op → `CostEvent`), **105** (dispatch chokepoint checks the cap on the hot path), **106** (operator overrides audited).
- `business/context/cost-budgets.json` — the D2 default caps + D10 anomaly thresholds + D12 dev overlay — and `cost-budgets-tuning-policy.md`.
- `generated/cost-reports/_format.md` + worked example — the canonical monthly report shape.
- `.claude/agents/review.md` `cost-config` + `cost-kill-switch-retry` categories (mapped in `copilot/pr-review-rules.md`).

**Deferred — the contract + implementation packets (not just Operator surfaces):**

- **Catalog registration** (packet 01) — deferred to pair with the Kernel code (packet 03), so `catalogs/contracts.json` never claims contracts the Kernel package doesn't yet expose.
- **Kernel contracts** (packet 03) — `ICostLedger` / `CostEvent` / `CostCategory` / `CostSource` / `CostEnvironment` / `BudgetExceededException` / `BudgetOverride` / `IBudgetConfigProvider` / `BudgetConfig` / `CostQuery` in `HoneyDrunk.Kernel.Abstractions`. Couples with the ADR-0042 Kernel version line; needs a human NuGet release tag before packet 04.
- **AI relocation** (packet 04) — blocked on the human Kernel release.
- **AI Cosmos ledger** (packet 05) + **dispatcher kill-switch** (packet 06) — **hard-blocked**: `HoneyDrunk.AI` is at seed v0.1.0; the ADR-0016 Phase-1 scaffold was never executed, so there is no scaffolded Node to host a Cosmos client or interceptor. Packet 05 also needs human Cosmos provisioning; packet 06 expects ADR-0045's `IErrorReporter` (still Proposed; structured-log fallback documented in the packet).

**The actual kill-switch is therefore not yet live.** This pass lands the *policy* (the cheap insurance ADR-0052 argues for); *enforcement* turns on when the AI Node scaffolds (ADR-0016 Phase 1) and the Kernel contracts release.

## Gating events

- **Gate 0** — anytime. Per-provider API-key spending limits; operator override pattern docs.
- **Gate 1: ADR-0018 Accepted + Operator scaffold executed.** Unblocks every Operator-side surface (aggregator, CLI, dashboard, auto-suspend).
- **Gate 2: ADR-0040 Accepted + App Insights provisioned.** Unblocks the App Insights anomaly-alert Bicep (D10).
- **Gate 3: one month of Phase-1 baseline data in the ledger.** Unblocks the Phase-3 multiplier flip and cap tuning.
- **Gate 4: ADR-0037 Accepted + Billing Node scaffolded.** Unblocks the per-tenant query API.
- **Gate K (this initiative's own blocker): ADR-0016 Phase-1 AI scaffold executed + Kernel contracts released.** Unblocks this initiative's own code packets 03–06.

## Deferred follow-up table

| # | Surface | Target Node | Gating Event | ADR-0052 Decision |
|---|---|---|---|---|
| 1 | Aggregator job (Azure Cost Management / GitHub Actions / vendor APIs → `CostEvent`s; 90-day backfill; drift > 5% vs bill is a defect) | `HoneyDrunk.Operator` | Gate 1 | D7, D14 Phase 2 |
| 2 | Container Apps auto-suspend (non-prod only on Azure-infra hard-cap breach; prod never auto-suspended) | `HoneyDrunk.Operator` | Gate 1 | D4 |
| 3 | `hd cost status` CLI | `HoneyDrunk.Operator` | Gate 1 | D11 |
| 4 | `hd cost unlock` CLI (writes `IAuditLog` event per invariant 47 + `BudgetOverride`; 24h default; no permanent option) | `HoneyDrunk.Operator` | Gate 1 | D11; invariant 106 |
| 5 | `hd cost report` CLI (manual `YYYY-MM.md` writer) | `HoneyDrunk.Operator` | Gate 1 | D9 |
| 6 | Monthly report aggregator (1st-of-month cron → `generated/cost-reports/YYYY-MM.md` per `_format.md`) | `HoneyDrunk.Operator` | Gate 1 | D9 |
| 7 | Operator "Cost" dashboard view (real-time per-category MTD, top-N agents/tenants, anomaly indicators) | `HoneyDrunk.Operator` | Gate 1 | D9 |
| 8 | App Insights anomaly-alert rules as Bicep (HoH 5x, DoD 3x; per-tenant + per-agent variants) | `HoneyDrunk.Observe` / Operator | Gate 2 | D10 |
| 9 | Communications + Notify alert wiring (08:00 daily roll-up; 50/75/90/100% pings; hard-cap push + `IErrorReporter` `HoneyDrunk.Cost.HardCapBreach`; anomaly alerts) | `HoneyDrunk.Communications` + `HoneyDrunk.Notify` | Gate 1 | D3 |
| 10 | Phase-1 multiplier flip (`CostLedger:PhaseOneMultiplier:Dev` 10 → 1 in App Configuration; observe a week before prod) | `HoneyDrunk.Operator` + App Config | Gate 3 | D14 Phase 3 |
| 11 | Per-provider API-key spending limits (OpenAI / Anthropic per-key limit ~$1700/mo, just above the $1500 hard cap — defense-in-depth) | Manual portal | Gate 0 | Alternatives Considered |
| 12 | Dev/prod Azure resource separation (separate subscriptions or distinctly-tagged RGs; the aggregator needs the split) | Manual portal + IaC | Gate 1 (lighter earlier) | D12 |
| 13 | Operator override pattern docs (emergency / investigative / planned, with CLI examples) | `HoneyDrunk.Architecture` `business/context/` | Gate 0 | D11; Follow-up Work |
| 14 | Per-tenant query API for the Billing Node (wraps `QueryAsync` with `TenantId` filter) | `HoneyDrunk.AI` / future `HoneyDrunk.CostLedger` | Gate 4 | D5; ADR-0037 |
| 15 | Structured JSON sidecar (`YYYY-MM.json`) for the monthly report | `HoneyDrunk.Operator` aggregator | Gate 1 | D9; Follow-up Work |

## Recommended sequencing (once Gate 1 fires)

1. Aggregator + `hd cost status` + manual report CLI — read-side visibility first.
2. `hd cost unlock` + override pattern docs — the emergency-response path before kill-switches fire.
3. Communications + Notify alert wiring — daily roll-up + threshold pings.
4. Container Apps auto-suspend + App Insights anomaly Bicep + dashboard view — complete the kill-switch posture across categories.
5. Phase-1 multiplier flip — after a month of baseline.
6. Per-tenant query API — when the Billing Node arrives.

## Re-scope guidance for a future agent

- Treat each numbered surface as a candidate single packet, but check for cross-Node coupling (#9 spans Communications + Notify — likely two packets).
- Use this playbook as the cross-reference; do not re-discover the deferred items by re-reading ADR-0052 end to end.
- Carry forward the gating-event language to keep upstream dependencies explicit.
- **Before the Operator-side work, the initiative's own Gate K must clear** — file/execute the ADR-0016 Phase-1 AI scaffold, then packets 03 (Kernel) → 04 → 05 → 06, with the human Kernel release tag at the Wave 2→3 boundary.

## Pointers to existing artifacts

- `business/context/cost-budgets.json` + `cost-budgets-tuning-policy.md` (the caps and the change policy).
- `generated/cost-reports/_format.md` (the monthly report shape).
- `constitution/invariants.md` invariants 104 / 105 / 106 (the cost-governance discipline).
- `.claude/agents/review.md` `cost-config` + `cost-kill-switch-retry` (the review gates).
- `catalogs/contracts.json` (the Kernel cost-governance contracts — registered when packet 01 lands alongside the Kernel code).
