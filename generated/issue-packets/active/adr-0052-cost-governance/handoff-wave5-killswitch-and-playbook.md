# Handoff — Wave 4 → Wave 5: dispatcher kill-switch + Operator-side playbook

**Initiative:** `adr-0052-cost-governance`
**Wave transition:** Wave 4 (Cosmos-backed ledger v1) → Wave 5 (dispatcher kill-switch wiring + rollout playbook)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 4 landed

- **Packet 05** — `HoneyDrunk.AI`'s `CostLedger` is the Cosmos-backed v1 implementation. Writes are partitioned `(category, year-month)`. `IsHardCapBreachedAsync` is served from a 30-second-refresh in-memory cache. `BudgetConfigProvider` resolves caps from `business/context/cost-budgets.json` with the Phase-1 multiplier applied per environment. Active `BudgetOverride`s cause `IsHardCapBreachedAsync` to return `false` until expiry. `Local`-environment events are written to Cosmos for visibility but do not affect the cap-check cache (D12). Cosmos auth is Managed Identity. The Cosmos provisioning Bicep is at the AI Node's IaC convention; the operator has provisioned the Cosmos account, granted the AI Container App's Managed Identity `Cosmos DB Built-in Data Contributor`, and seeded the App Configuration values per environment.

**The cap-check returns a correct answer.** No call site consumes it yet — until packet 06 lands, the kill-switch is inert.

## What Wave 5 must deliver

**Two packets in parallel** (packet 06 is AI-only; packet 09 is Architecture-only):

### Packet 06 — Dispatcher kill-switch wiring

Wire the AI dispatcher chokepoint to call `IsHardCapBreachedAsync(CostCategory.AiInference)` before every LLM call. On breach (and no active override), throw `BudgetExceededException` synchronously — the inner provider is never invoked. Capture the breach via `IErrorReporter` (problem group `Honeydrunk.Cost.HardCapBreach`) for the operator's incident-review surface (ADR-0045). Ship the kill-switch canary in `HoneyDrunk.AI.Tests.Canaries` that asserts: throw on breach; type is `sealed`; provider never called; `IErrorReporter` capture happened; default retry policy did NOT retry; override honoured.

### Packet 09 — Operator-side rollout playbook + catalog cleanup

Author the playbook (`initiatives/adr-0052-rollout-playbook.md`) cataloguing the 15 deferred Operator-side surfaces (aggregator, auto-suspend, CLI, dashboard, anomaly Bicep, Communications + Notify alert wiring, Phase-1 multiplier flip, per-tenant query API, JSON sidecar, dev/prod resource separation, override pattern docs, per-provider API key spending limits). Each surface is gated on one of four upstream events (ADR-0018 standup is the dominant gate). The playbook is the re-decomposition map a future scope agent uses. Conditionally remove the AI-side `ICostLedger` entry from `catalogs/contracts.json` (gated on packet 04 having merged — defer the cleanup if not).

## Critical context for Wave 5 execution

### Pick the AI dispatcher chokepoint once

ADR-0052 D4 calls the cost-checking seam `ILlmDispatcher`. The AI Node's existing abstraction layer is `IChatClient` / `IEmbeddingGenerator` (aligned with `Microsoft.Extensions.AI`) routed through `IModelRouter` into provider packages. The chokepoint should be **one seam** that catches every LLM call:

- **Recommended:** a decorator over `IModelRouter` (or the routing implementation `DefaultModelRouter` if it exists at edit time). One decorator catches every call regardless of provider.
- **Acceptable alternative:** decorators over `IChatClient` and `IEmbeddingGenerator` at the abstraction layer. Two decorators but the abstraction layer is the cleanest seam if `IModelRouter` is split or absent.

Pick at edit time based on what the AI Node has built; document the choice in the implementation file header.

### `BudgetExceededException` is sealed, non-transient, propagated

The interceptor catches nothing. On breach:
1. Call `IErrorReporter.CaptureException(new BudgetExceededException(...))` with problem group `Honeydrunk.Cost.HardCapBreach`, attribution dimensions, correlation id.
2. Throw the exception.

The exception propagates to the caller. The `review` agent's `cost-kill-switch-retry` category (from packet 08) gates code that catches and retries. The only sanctioned catch is the top-level loop carve-out (ADR-0052 D4): a long-running agent loop may catch at the top level, write checkpoint state to Audit, exit cleanly. The reviewer agent's category description (packet 08) documents this carve-out.

### `IErrorReporter` cross-initiative dependency

`IErrorReporter` ships in ADR-0045's initiative (`adr-0045-grid-wide-error-tracking`). At packet 06's edit time:
- If `HoneyDrunk.AI`'s `HoneyDrunk.Telemetry.Abstractions` reference includes the version that ships `IErrorReporter`, use it.
- If not (ADR-0045 hasn't landed), use the structured-log fallback: `_logger.LogError("Hard-cap breach: category={Category} cap=${Cap} actual=${Actual} correlationId={CorrelationId}", category, cap, actual, correlationId)` and propagate the exception. Document the gap in the PR description and flag a follow-on packet to wire `IErrorReporter` once ADR-0045 ships.

### Recommended deploy sequence (Phase 4 pilot)

ADR-0052 D14 Phase 4 is the dangerous phase — runtime behaviour changes from logging to throwing. The PR description for packet 06 captures the recommended deploy sequence:
1. Deploy to **dev** with the Phase-1 multiplier at 10 (from packet 05). The effective dev cap is 10x the D2 dev cap; false breaches expected to be near-zero.
2. Observe one week.
3. Flip the App Configuration value `CostLedger:PhaseOneMultiplier:Dev` to 1. The dev cap is now D2-final. False breaches now indicate either a real budget event (good — the system works) or a defect.
4. Observe one week.
5. Deploy to **prod**. Prod is at the D2 caps from day one. Real breaches in prod are the system doing its job.

The `CostLedger:KillSwitch:Enabled` App Configuration setting is a safety hatch: `false` bypasses the interceptor without a code revert.

### What Wave 5 does NOT deliver

- **Container Apps auto-suspend job** — Azure-infra kill-switch; gated on ADR-0018 Operator standup; named in packet 09 playbook entry #2.
- **GitHub-native CI limit policy mirror** — manual GitHub org setting; named in packet 09.
- **Daily roll-up email / threshold pings / breach push** — Communications + Notify wiring; gated on ADR-0018 standup; named in packet 09 entry #9.
- **App Insights anomaly Bicep (D10)** — gated on ADR-0040 (App Insights provisioned) + ADR-0018 (Operator IaC); named in packet 09 entry #8.
- **Operator "Cost" dashboard view** — gated on ADR-0018; named in packet 09 entry #7.

## Per-call attribution audit

Packet 04 migrated provider call sites to record `CostEvent`. Packet 06 verifies every call site populates `TenantId`, `AgentId`, `AgentRunId` from ambient `IGridContext`. If any field is hardcoded to `null` because the standup didn't plumb the context through, fix it in packet 06. Attribution at write time or never — historical events cannot be backfilled (D5).

## Invariants binding Wave 5

- **Invariant 1** — packet 06 ships code in `HoneyDrunk.AI` runtime, not Abstractions. Packet 09 ships docs + catalog edits.
- **Invariant 15** — packet 06's interceptor unit tests use fake `ICostLedger` + counting test double for the inner provider. No external services.
- **Invariant 27** — packet 06 appends to the in-progress AI version entry (started by packet 04, continued by 05); no second bump.
- **Invariant 51** — no `Thread.Sleep` in tests; use `TimeProvider`.
- **Invariant 91** (this initiative, packet 00) — **packet 06 satisfies this invariant.** `ILlmDispatcher` checks the cost ledger against the hard cap before each LLM call. The canary is the integration test required per ADR-0047 D4.
- **Invariant 92** (this initiative, packet 00) — override writes are audited via `IAuditLog`. Packet 06 does NOT write overrides; the `hd cost unlock` CLI is named in packet 09's playbook entry #4. Invariant 92 stays partially-delivered (the rule exists; the override write path lands when ADR-0018 unblocks).

## Acceptance gate for Wave 5

Packet 06's PR:
- Interceptor at the documented chokepoint; one call to `IsHardCapBreachedAsync` per LLM call.
- `BudgetExceededException` propagates synchronously on breach; `IErrorReporter` capture happens before the throw.
- Active overrides honoured implicitly (no separate query in the interceptor).
- Provider attribution dimensions verified.
- Kill-switch canary in `HoneyDrunk.AI.Tests.Canaries` asserts all six behaviours (throw, sealed, provider-not-called, error-reporter-captured, default-retry-does-not-retry, override-honoured).
- AI solution version unchanged from packets 04/05 (appended; invariant 27).
- Repo-level + AI-runtime CHANGELOG appended to the in-progress version entry; no per-package CHANGELOG entries on other packages.

Packet 09's PR:
- Playbook ships under `initiatives/` (or the existing playbook convention) with the four gating events, 15-entry deferred follow-up table, recommended sequencing, re-scope guidance, pointers to artifacts.
- AI-side `ICostLedger` entry removed from `catalogs/contracts.json` (gated on packet 04 having merged; defer if not, note in PR).
- Repo-level `CHANGELOG.md` updated.
- The per-provider API key spending limits Human Prerequisite is named (Gate-0; do at any time after this initiative ships).

## Initiative closeout

After packets 06 and 09 merge, the `adr-0052-cost-governance` initiative is **complete** at the foundation-layer scope. The follow-on initiatives the playbook names (Operator-side cost-governance, post-ADR-0018) are scoped from the playbook when ADR-0018 lands.

The cost ledger is durably writing events to Cosmos; the kill-switch is enforcing on AI inference; the operator has the budget config, the report format, the review-agent rules, the invariants, and the playbook. The Grid has its first programmatic ceiling on cost.
