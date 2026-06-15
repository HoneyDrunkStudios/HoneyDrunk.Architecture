# ADR-0052: Cost Governance, Budget Alerts, and Kill-Switches

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

The Grid spends real money in five distinct categories — Azure infrastructure, AI inference, third-party SaaS, recurring infra (domains/certs/registrar), and CI minutes — and today there is **no programmatic ceiling** on any of them. The studio is a bootstrapped, solo-developer operation; a runaway agent loop, a misconfigured retry, or a malicious tenant could surface a five-figure Azure or OpenAI bill that is a **material event** for the LLC. There is no investor pool absorbing overruns and there is no AP team noticing the bill before it lands.

The proximate forcing functions:

- **ADR-0041 (AI model registry, Proposed)** introduces a model approval workflow that gates *which* models can be used, but does not gate *how much* of any approved model gets spent. A model can be approved and still be the line item that produces a runaway loop.
- **ADR-0016 (HoneyDrunk.AI, Accepted)** D5 mandates operator-configurable token cost rates and an `ICostLedger` abstraction. The abstraction is named but the policy surface around it — caps, alerts, enforcement — is not. The ledger without policy is a passive accounting record; the policy turns it into a control plane.
- **ADR-0040 (telemetry, Proposed)** pivoted from Grafana Cloud + Sentry to Azure Monitor + Application Insights specifically because it is **cost-aware** (existing Azure relationship, no new vendor, free-tier-friendly). That pivot established the precedent that cost is a first-class architectural concern in this Grid, not an afterthought.
- **`initiatives/drift-report.md`** explicitly flags that `business/context/` has no AI-spend ledger and no vendor cost tables. The drift report is a deliberate inventory of missing surfaces; this gap is one of them.
- **The AI-sector standup wave** (nine new Nodes coming online per ADR-0016 through ADR-0025) is the single largest cost-risk increase the Grid has ever shipped. Each AI Node multiplies the surface where token spend can leak. Standing them up without a cost-control substrate is the same posture as standing up Audit without retention rules — the bill arrives anyway, just without warning.
- **Codex and cloud agents** are already running today. Every agent run produces token spend. There is no per-run cap; a misconfigured `while true` in an agent script today routes directly to API spend.

The decision pressure: **of the cross-cutting ADRs in this batch (0048–0052), this one is the most urgent.** Error tracking can wait a sprint; testing patterns can land Node-by-Node; cost governance failure is a one-shot, irrecoverable event. The first runaway loop is too late to introduce the policy.

This ADR commits the cost categories, the budget tiers and alert thresholds, the alert channels, the kill-switch mechanics (in-process for AI inference, infra-suspend for Azure, GitHub-native for CI), the per-tenant and per-agent attribution shape, the cost ledger implementation home, the persistence and reporting surfaces, the anomaly detection layer, the operator unlock policy, and the dev/prod treatment split.

## Decision

### D1 — Cost categories and budget owners

Five named cost categories. Each has one human owner (Oleg) today; the structure exists so ownership can be delegated when the team grows. The owner is **accountable** for the category — they receive the daily roll-up, they approve overrides, they sign off on the budget tuning. Owner is not necessarily the operator of every line item; they are the human whose name goes on the cap-breach incident.

| Category | Scope | v1 owner |
|----------|-------|----------|
| **Azure infrastructure** | Container Apps, Application Insights, Vault, Cosmos DB / Azure SQL, Storage, Front Door, Service Bus, Functions | Oleg |
| **AI inference** | OpenAI API, Anthropic API, future provider APIs, broken out per model per provider | Oleg |
| **Third-party SaaS** | All vendor bills per BDR records (iPostal1, registered agent, accounting SaaS, etc.) | Oleg |
| **Domain / cert / registrar** | Recurring infra: domain registrations, TLS certs (where not Azure-provided), DNS provider | Oleg |
| **GitHub Actions minutes** | CI consumption — meaningful now that the AI-sector standup wave is landing | Oleg |

Each category has its own budget configuration, its own alert thresholds, and its own kill-switch posture (D4). Categories do not cross-subsidize: hitting the AI inference hard cap does not free up budget for Azure infra. The total Grid budget is the sum, not a single fungible pool. The no-cross-subsidy rule is load-bearing — fungible budgets would let a runaway in one category quietly consume the safety margin of another, defeating the per-category enforcement entirely.

The categorization is deliberately coarse. Finer breakouts (per-Node Azure cost, per-agent AI cost) are **attribution dimensions** (D5, D6) under each category, not separate categories. Attribution serves forensics and per-tenant billing; categorization serves enforcement. The two surfaces have different consumers: attribution drives the operator dashboard and per-tenant invoicing; categorization drives the kill-switch. Conflating them would force the kill-switch to enumerate every possible attribution combination, which is unmaintainable.

Categories that **could exist but don't at v1**: per-region Azure cost (deferred — single-region operations make this redundant), per-environment cost (covered by D12's dev/prod separation rather than as a separate category axis), and per-product cost (deferred until multiple commercial products exist; today only Notify Cloud is on the runway). These are noted so future ADRs that add them know the v1 shape they are extending.

### D2 — Budget tiers and alert thresholds

Per category, two thresholds: a **soft cap** (alerting only, no enforcement) and a **hard cap** (alerting plus kill-switch per D4). All values are **monthly**.

| Category | Soft cap | Hard cap | Notes |
|---|---|---|---|
| AI inference | $500 | $1500 | Grid-wide across all models and providers; the dominant variable cost. |
| Azure infrastructure | $300 | $800 | Sum across all Container Apps, App Insights, Vault, storage, etc. |
| Third-party SaaS | $200 (soft only) | — | Mostly fixed monthly subscriptions; no hard cap because we cannot programmatically suspend a SaaS subscription mid-month. Soft cap detects budget creep. |
| Domain / cert / registrar | $25 (soft only) | — | Annual renewals amortized; soft cap detects unexpected charges. |
| GitHub Actions minutes | $50 | $150 | GitHub-native spending limit (D4) enforces; this is the policy-side mirror. |
| **Grid total (soft)** | **$1,075** | — | Sum of soft caps. |
| **Grid total (hard)** | **$2,475** | — | Sum of hard caps (where defined). |

**These are defaults. The Studio operator must tune them.** The numbers are starting points calibrated to a single-developer studio in pre-revenue mode; they are not market research. Tuning happens via the operator-configurable rates per ADR-0016 D5 and via this ADR's reporting surface (D9) which surfaces actuals vs caps each month.

The dollar values live in `business/context/cost-budgets.json` (new file, sibling to the vendor list referenced in the drift report). Changes to the file are tracked by git, reviewed via the standard PR flow, and (per D11) audited. The PR flow is the **slow path** for changing caps — it preserves a permanent record of "the cap was raised on this date, by this PR, with this reasoning." The fast path (D11 override CLI) is for emergencies; the PR flow is for considered policy changes. Mixing them by allowing CLI to mutate `cost-budgets.json` directly would erode the audit trail and is explicitly forbidden.

The split between soft and hard cap is intentional: soft is a warning, hard is an action. The 3x gap (e.g., $500 → $1500 for AI inference) gives the operator a meaningful window between "pay attention" and "the kill-switch fires," which preserves agency. A tighter gap (e.g., $500 → $600) would trigger the kill-switch too often on benign variance; a wider gap (e.g., $500 → $5000) would defeat the kill-switch's purpose. The 3x ratio is a heuristic, not a derived constant; per-category tuning is expected as actuals accumulate.

**Calibration rationale for the defaults:** The AI inference $500/$1500 numbers are sized assuming roughly 250M–750M tokens/month at current blended rates across approved models (GPT-4 class roughly $0.005/1K input + $0.015/1K output blended, Claude class roughly $0.003/1K + $0.015/1K). At single-developer scale running internal agents plus Codex plus a handful of standup canaries, the lower bound (~$500) is comfortably above expected steady-state burn. The upper bound (~$1500) is the "something went wrong but is recoverable" ceiling. Azure infra $300/$800 is sized against current Container Apps + App Insights + Vault + small-scale Cosmos consumption; Notify Cloud GA will move this number. CI $50/$150 reflects the current GitHub Actions consumption pattern with the AI-sector standup wave landing — the standup wave noticeably increased CI minutes. These are starting positions, not target steady states.

### D3 — Alert channels and cadence

Alerts flow through **HoneyDrunk.Communications** (the decision/orchestration Node per ADR-0019) into **HoneyDrunk.Notify** (intake/delivery), targeting the operator's configured channels (email primary, push secondary, escalation TBD). The pattern matches every other operator-facing alert in the Grid; cost alerts are not a special channel.

Cadence:

- **Daily roll-up email at 08:00 operator-local-time.** Yesterday's actuals per category, month-to-date totals, percentage of soft cap consumed, projected end-of-month at current burn rate. Sent unconditionally regardless of threshold state — the daily roll-up is the operator's "I am still solvent" signal.
- **Threshold pings on soft-cap consumption:** 50%, 75%, 90%, 100%. Sent once per threshold crossed per month; not re-sent if the actual oscillates back under the threshold.
- **Hard-cap breach:** Fires both (a) a structured error event through `IErrorReporter` per ADR-0045 (visible in the App Insights Failures blade, problem-grouped as `Honeydrunk.Cost.HardCapBreach`) **and** (b) a Notify push at maximum priority. The duplication is intentional: the error event lands in the same surface the operator already monitors for production incidents; the push is for cases where the operator is not at a screen.
- **Anomaly alerts (D10):** Sent on detection, independent of threshold state.

The 08:00 cadence is configurable per-operator via the Notify channel config; the threshold pings are not (they fire on event, not on schedule). The hard-cap alert is configured at maximum priority because by the time it fires, the kill-switch has already engaged — the alert is "the cap is enforcing right now," not "the cap might enforce later."

**Why structured error event in addition to push:** The push reaches the operator's pocket; the structured event reaches the operator's incident-review queue. The two surfaces serve different timescales — the push for "do something in the next 10 minutes," the structured event for "include this in the weekly review." Hard-cap breaches deserve both because they are both immediate operational concerns and long-tail policy signals (a recurring breach is evidence the cap is mis-tuned, not just that this month was unusual). The push goes away once acknowledged; the structured event persists in App Insights with full context for the next month's retrospective.

**Alert suppression and noise control:** Threshold pings are de-duplicated per (category, threshold, month) — the 50% ping for AI inference in May 2026 fires once even if month-to-date oscillates around 50% repeatedly. The de-duplication state lives in the ledger itself (a `ThresholdAck` row per breach) so it survives process restarts. Without de-duplication, a category hovering near a threshold would page the operator dozens of times per day; with it, each threshold is a discrete event. Operator-initiated reset (e.g., "I tuned the cap, re-arm the pings") is available via the `hd cost` CLI.

### D4 — Kill-switches per category

The hard cap is **enforcing**, not advisory. Per category, the enforcement mechanism is different because the cost source is different. Naming the per-category mechanism explicitly is necessary because "kill-switch" is a single word that hides four meaningfully different actions; conflating them in operator documentation would lead to incorrect expectations during the first real breach event.

**AI inference (in-process):** The `ILlmDispatcher` interface (HoneyDrunk.AI per ADR-0016) checks `ICostLedger.GetMonthToDate(CostCategory.AiInference)` against the configured hard cap before each call. If the month-to-date is at or above the hard cap, the dispatcher throws `BudgetExceededException` synchronously — the LLM call is never made. The exception carries the category, the cap, the actual, and a correlation id so the caller's error surface (per ADR-0045) clusters them under one problem id.

The cost ledger read is on the hot path of every LLM call. Performance impact is discussed in Consequences; the short version is "single-digit ms on a hot ledger" via in-memory aggregation with a write-behind to Cosmos. The read is non-negotiable: a kill-switch that checks asynchronously after the bill has been incurred is not a kill-switch.

The `BudgetExceededException` is **not** a transient error. Callers must not retry; the exception means "this category is closed for the rest of the billing window or until an operator override engages." Retry loops that swallow this exception and try again immediately would defeat the kill-switch. The exception type is `sealed` and the documentation calls out the no-retry contract; the `review` agent (per ADR-0044) gains a category check for "code catches `BudgetExceededException` and retries" as a defect.

**Caller behavior on `BudgetExceededException`:** Most callers should propagate the exception. Specific call sites (e.g., a long-running agent loop) may want to halt cleanly with a checkpoint rather than crash; the convention is to catch the exception only at the top-level loop, log the budget breach as a structured event, write any in-flight state to Audit for resumption, and exit. No call site should catch it within a tight loop and retry.

The kill-switch is **per-category, Grid-wide**, not per-model or per-agent. A misbehaving agent burning the AI inference cap halts **all** agents, not just the offender. This is deliberate: per-agent caps are a refinement (D6 names the attribution dimension; future ADR can add per-agent enforcement on top), and at v1 the simpler "halt the category, the operator decides what to do" semantics avoids the complexity of partial-halt failure modes.

**Azure infrastructure (out-of-process):** No in-process kill-switch — application code cannot programmatically refuse to consume Azure resources mid-request. Instead, a Container Apps revision auto-suspend job runs as part of HoneyDrunk.Operator (per ADR-0018) that **automatically suspends non-production Container Apps revisions** when the Azure infra hard cap is breached. Production Container Apps are **not** auto-suspended (suspending production would itself be a customer-impacting incident; the operator must consciously trigger that). The auto-suspend targets the `dev` and ephemeral environments first, which are also where runaway-cost incidents are most likely to originate.

The Azure-infra suspend logic depends on Azure Cost Management API as the source of truth (in-process metering doesn't see Azure resource cost directly). Azure Cost Management has a known propagation lag (typically 8–24 hours for line-item data). The lag is acknowledged — the in-process AI inference kill-switch is the **fast** circuit-breaker; the Azure-infra suspend is the **slow** circuit-breaker. Both layers exist because both failure modes exist.

**GitHub Actions minutes (GitHub-native):** GitHub provides a per-organization spending limit for Actions; set this to the hard cap value ($150/month). GitHub enforces it without further configuration. The ADR-level policy mirrors the GitHub-side setting so the two stay in sync; the daily roll-up (D3) surfaces GitHub-reported actuals so drift between the policy file and the GitHub config is visible.

**Third-party SaaS and Domain/cert:** No kill-switch. These are subscription or renewal billing models without a programmatic interrupt. Soft cap alerting only; if a soft cap fires, the operator decides whether to cancel a SaaS subscription manually. The absence of a kill-switch here is not a gap — it is a recognition that these line items are *contractually committed*. Cancelling a SaaS subscription mid-month does not refund the bill; suspending a domain registration breaks the customer-facing surface. The control point for these categories is **at the moment of subscribing**, not at the moment of paying. That is the BDR (Business Decision Record) layer's job, not this ADR's.

**Layered failure-mode reasoning:** The three enforcement tiers (fast in-process for AI, slow Azure-API for infra, GitHub-native for CI) reflect a deliberate **defense in depth** posture. No single layer is sufficient. The AI in-process check is precise but only sees what flows through `ILlmDispatcher` — direct HTTP calls to OpenAI from non-dispatcher code (which is forbidden but possible if a developer bypasses the abstraction) would not be caught by the in-process check. The Azure-side aggregator catches that case but with lag. The GitHub-native limit catches CI exhaustion that neither of the others would see. The combined posture is "every cost source has *some* layer watching it, and the most expensive sources have the fastest layer."

**Partial-halt versus full-halt:** The v1 kill-switch is full-halt per category. A partial-halt model (e.g., "halt non-priority agents but allow priority traffic") is conceptually sound but operationally complex — it requires every call site to declare priority, a priority schema everyone agrees on, and a tie-breaking rule when priority is ambiguous. None of this exists at v1. Full-halt is the simpler default; partial-halt is named as a possible future amendment if breach incidents become common enough that the operator regrets the all-or-nothing semantics.

### D5 — Per-tenant attribution

Every cost event recorded in the ledger carries an optional `TenantId` dimension per ADR-0026's primitives. Where the cost originates from a tenant-scoped operation (a Notify Cloud send for tenant X, an agent run for tenant Y), the `TenantId` is set; where the cost originates from Grid-internal infrastructure or Studio operations, `TenantId` is null and the cost rolls up as "platform overhead."

The per-tenant roll-up enables two downstream surfaces:

- **NovOutbox billing reconciliation** (per ADR-0037 Payments boundary) — the cost attributed to a tenant is the input to the per-tenant invoice; Payments/product subscription logic applies pricing on top of cost. A tenant whose attributed cost exceeds their revenue is a tenant the operator needs to renegotiate or offboard.
- **Abuse detection** — a tenant whose attributed AI inference cost suddenly 10x's relative to their baseline is a likely abuse case (compromised credentials, runaway integration, intentional misuse). The anomaly detection (D10) operates per-tenant for this reason.

`TenantId` is **not PII** (per ADR-0045 D7 it is allowed as a dimension on telemetry); the cost ledger reuses the same opaque identifier shape. No tenant data beyond the id and the cost value lives in the ledger.

**Untagged events:** Some cost events have no natural tenant scope — a nightly canary run, a Studio-internal agent invocation, an Architecture-repo automation task. These events carry `TenantId = null` and roll up as "platform overhead" in reporting. The platform overhead category is monitored separately; if it grows disproportionately, the operator investigates whether agent activity is being mis-attributed. Operating practice should be that every customer-facing cost event has a `TenantId`; missing tenant attribution on commercial traffic is a defect detected by the daily roll-up's unattributed-cost check.

### D6 — Per-agent attribution

AI inference cost events additionally carry `AgentId` and `AgentRunId` dimensions. `AgentId` is the stable identifier from the agent definition (per ADR-0051's agent registry); `AgentRunId` is the per-invocation correlation id.

The per-agent roll-up enables "which agent burned the budget" forensics: when the hard cap fires, the operator needs to know within seconds whether the cause is the `review` agent on a runaway PR, the `scope` agent in an infinite-decomposition loop, or a Codex run that retried without backoff. Without this dimension, the kill-switch fires but the post-mortem takes hours. The forensic surface is the Operator dashboard's "top-N agents by spend last 24h" panel, which is the first place the operator looks after a hard-cap breach notification.

`AgentRunId` is the dimension that enables per-run rollback: an over-budget run can be identified, halted, and its spend retrospectively attributed. The retention shape (D8) keeps per-run granularity for the rolling 13-month window so the operator can pull "what did this specific run cost" months later if an incident review demands it.

The dimension structure is forward-compatible with per-agent enforcement (not implemented at v1 per D4 rationale). A future ADR can add `ICostLedger.GetMonthToDate(AgentId)` and a per-agent cap without changing the storage shape.

**Why both `AgentId` and `AgentRunId`:** `AgentId` is the stable identity of the agent definition (e.g., `"review"`, `"scope"`, `"hive-sync"`) and is the dimension a per-agent cap would aggregate against. `AgentRunId` is the per-invocation correlation, which is the dimension for tracing a single agent execution end-to-end through cost events, log events, and trace events. The two answer different questions: "which agent costs the most this month" (`AgentId`) vs "this specific run cost $20 — what did it do" (`AgentRunId`). Carrying both is cheap; carrying only one would force operators into multi-step queries that the v1 reporting (D9) cannot easily express.

**Cross-link with ADR-0051 (agent registry):** The `AgentId` dimension reuses the same opaque identifier ADR-0051 commits for the agent registry. This is not coincidental — the cost ledger and the agent registry share the identifier so per-agent cost queries can join against per-agent capability metadata without a translation table. The ADR-0051 commitment is therefore a hard upstream dependency for D6's attribution to be useful; if ADR-0051 lands with a different identifier shape, this ADR's attribution dimension migrates accordingly.

**Agent-on-behalf-of-tenant case:** When an agent runs on behalf of a specific tenant (e.g., a Notify Cloud workflow that triggers a Studio-internal `summarize` agent for that tenant's content), both `TenantId` and `AgentId` are populated. Reporting can then ask "what did agent X cost across all tenants" and "what did tenant Y cost across all agents" from the same event stream without double-counting. The aggregation rule: a single event is attributed to exactly one tenant and exactly one agent run; sum across the (tenant, agent) cross-product equals the category total. This invariant is verified by a contract test against the ledger backing.

### D7 — Cost ledger implementation home

`ICostLedger` lives in **HoneyDrunk.Kernel** (the abstraction only — interface, event shape, exception types, configuration record). This is consistent with the Kernel-thin-shell principle: Kernel owns the contract every Node consumes, no concrete implementation.

The concrete implementation lives in **HoneyDrunk.AI for v1** rather than a dedicated `HoneyDrunk.CostLedger` Node. The reasoning:

- **AI inference is the dominant cost line.** AI Node already owns the dispatcher (`ILlmDispatcher`), the model registry (per ADR-0041), and the token-rate configuration (per ADR-0016 D5). Co-locating the ledger means the kill-switch read happens in-process with the dispatcher, no cross-Node call on the hot path.
- **Non-AI categories are externally-sourced.** Azure infra cost comes from Azure Cost Management API (a poll loop, not an in-process write); SaaS cost is manually entered or pulled from vendor APIs; CI cost from GitHub API. These do not need a Kernel-level write hop, just a daily aggregator that reads the external APIs and writes the same `ICostLedger` shape.
- **Standing up a dedicated Node has fixed costs.** A new Node requires its own repo, CI pipeline, package publish, canary, and standup ADR. Co-locating in AI avoids that overhead for v1.

The promotion path: **when non-AI categories grow material, or when a second Node needs to write cost events directly (not just AI Node), `HoneyDrunk.CostLedger` graduates to its own Node.** The interface in Kernel is unchanged; the implementation moves from AI to the new Node and AI takes a dependency on it. This is the same shape as ADR-0030's Audit promotion path.

For cost sources outside in-process AI calls (Azure infra, SaaS, CI), an **aggregator job in HoneyDrunk.Operator** polls the external APIs daily and writes the events into the ledger. The aggregator pattern keeps the ledger as the single source of truth without coupling every external API to the AI Node.

**The interface shape (preview, not final):**

```
ValueTask RecordCostAsync(CostEvent evt, CancellationToken ct);
ValueTask<decimal> GetMonthToDateAsync(CostCategory category, CancellationToken ct);
ValueTask<bool> IsHardCapBreachedAsync(CostCategory category, CancellationToken ct);
ValueTask<BudgetOverride?> GetActiveOverrideAsync(CostCategory category, CancellationToken ct);
IAsyncEnumerable<CostEvent> QueryAsync(CostQuery query, CancellationToken ct);
```

`CostEvent` carries the category, the cost amount, the timestamp, the source (a discriminated union of `LlmInferenceSource`, `AzureInfraSource`, `SaasSource`, `CiSource`, etc.), and the optional `TenantId` / `AgentId` / `AgentRunId` dimensions. The interface deliberately separates the write path (`RecordCostAsync`) from the read path (`GetMonthToDateAsync`, `IsHardCapBreachedAsync`) so the read path can be served from cache while writes go through to durable storage. The `IsHardCapBreachedAsync` call is the kill-switch check; making it a first-class method (rather than synthesizing it from `GetMonthToDateAsync` plus config lookup) lets the implementation collapse the read into a single cache hit.

Final method names and shapes are finalized in the implementing PR; this preview exists so reviewers can sanity-check the surface area before standup work begins.

### D8 — Persistence and retention

The ledger persists to **Cosmos DB**, single-region (write-mostly workload; reads are operator-facing dashboards and per-call kill-switch checks). The partition key is `(category, year-month)`; the row key includes the event timestamp, the tenant id (if present), and the agent id (if present).

Single-region is acceptable for v1 because:

- The ledger is **write-mostly** — most operations are append, not read.
- The hot-path kill-switch read uses an **in-memory cache** of the current-month roll-up per category, refreshed every 30 seconds, not a per-call Cosmos read. Cosmos is the durable store; the cache is the latency-critical surface.
- Cross-region availability is governed by ADR-0036's DR tiering; the cost ledger is tier 2 (loss is recoverable from source APIs over 24–48 hours by re-polling Azure Cost Management / vendor APIs / GitHub) and does not warrant multi-region writes.

Retention is **rolling 13 months** (current month plus 12 trailing months). 13 months because (a) year-over-year comparison requires more than 12 (you need this month and the same month last year), and (b) annual contract reviews and budgeting cycles need a full year of history. Older data is exported to cold storage (per ADR-0036 backup pattern) before deletion; the operator can re-hydrate from cold storage if a deeper forensic window is needed.

Per-event size is small (single-digit KB per cost event including all attribution dimensions); v1 monthly write volume is bounded by AI inference event count (estimated 10K–100K events/month at current AI usage scale). Cosmos cost for the ledger is itself within the Azure infra category and is well under the soft cap.

**Recursion check:** The cost ledger writes to Cosmos; Cosmos writes are themselves an Azure infra cost; that cost is captured by the aggregator and written back to the ledger. This is fine — the loop closes at the aggregator's polling cadence (daily) rather than per-write, so there is no infinite recursion. The ledger's own cost is a line item in the Azure infra category and counts against its cap like any other Azure consumption.

**Why Cosmos rather than Azure SQL or Postgres:** The write pattern (high-volume append, partitioned by `(category, year-month)`) is a natural Cosmos workload — partition-key writes are flat-cost regardless of total table size, and the data model is document-shaped (the `CostEvent` carries variable attribution dimensions depending on source). SQL/Postgres would require either a wide table with many nullable columns or a normalized schema with joins on every query. Cosmos' single-region pricing at this write volume is also cheaper than the equivalent Azure SQL or Postgres tier. The trade is: Cosmos lacks rich ad-hoc query (no SQL `JOIN` between cost events and external tables), which the v1 reporting (D9) does not need.

**Storage size projection:** At the upper bound of 100K events/month, 13-month retention, and 2KB per event, the ledger size is 100,000 * 13 * 2KB = ~2.6 GB. Cosmos storage at this size is on the order of dollars per month — comfortably within the Azure infra category. RU/s sizing for the cache-refresh read pattern (every 30 seconds across categories) plus the write-behind pattern from the dispatcher is well under the 400 RU/s autoscale floor. The persistence layer is not the dominant cost contribution of the ledger itself; the dominant cost is the LLM calls being measured.

### D9 — Reporting surfaces

Two surfaces:

- **Operator Node (per ADR-0018) — "Cost" view.** Real-time per-category month-to-date, threshold consumption percentages, top-N agents by spend, top-N tenants by spend, anomaly indicators (D10). This is the operator's live dashboard.
- **Architecture repo — generated monthly cost report at `generated/cost-reports/YYYY-MM.md`.** Auto-generated by an aggregator job on the 1st of each month, summarizing the prior month: per-category actuals vs caps, soft/hard cap events fired, kill-switch engagements, per-tenant cost (anonymized aggregates for any future shared reporting; full detail for operator-only reports), per-agent cost. The generated file is committed to the Architecture repo so the historical record is git-tracked.

The Architecture-repo report is the operator's monthly review surface; the Operator-Node view is the real-time control surface. Both read from the same Cosmos ledger; neither is a separate accounting system.

The cost report format is canonical so future automated comparisons (this month vs last month, this Q vs last Q) can parse it without bespoke logic. The format lives in `generated/cost-reports/_format.md` (added as part of the implementing work).

**Report contents (canonical sections):**

1. **Executive summary** — single sentence per category ("AI inference: $487 of $500 soft cap, 97% — within bounds, no breaches"); single sentence for the Grid total.
2. **Per-category actuals vs caps table** — month-to-date actual, soft cap, hard cap, % of soft, % of hard, count of threshold pings fired, count of hard-cap breaches.
3. **Per-tenant cost breakdown** — for Notify Cloud and any tenant-scoped Nodes; sorted by cost descending; truncated to top 25 with an "other" row aggregating the rest.
4. **Per-agent cost breakdown** (AI inference category only) — sorted by cost descending; includes a `cost per run` and `runs this month` column so the per-run cost trend is visible.
5. **Override log** — every override issued in the month, with operator, reason, duration, and whether the override expired naturally or was revoked early.
6. **Anomaly events** — every anomaly that fired in the month, with the triggering category, the magnitude (e.g., "8.2x hour-over-hour"), and the disposition (false positive vs real event).
7. **Trend appendix** — sparkline-style ASCII per category showing month-over-month for the trailing 13 months.

The format is intentionally **human-first** — Markdown that reads naturally in a code review and renders cleanly on GitHub. Machine consumers parse the canonical sections via heading anchors. A future structured JSON sidecar (`YYYY-MM.json`) is named as follow-up work for the case where automated cost analysis tools want a richer surface.

**Why commit the report to the Architecture repo:** The repo is the historical record of the Grid; git commit history is the cheapest audit trail available. A cost report that lives in an external dashboard is a cost report that disappears when the vendor relationship changes; a cost report that lives in git survives. The added storage cost is trivial (single-digit KB per month).

### D10 — Anomaly detection

Threshold-based caps fire **after** a meaningful amount has been spent. A runaway loop can burn most of the daily budget in minutes; waiting for the 50% threshold ping leaves a wide window of unmitigated spend. Anomaly detection is the **second layer** that catches the burn rate, not the absolute level.

Two triggers, both implemented as **Application Insights alert rules** per ADR-0040:

- **Hour-over-hour 5x spike** in cost-event volume or summed cost value within a category. Fires an alert (D3 channel) and writes a structured event to `IErrorReporter` for triage. Does **not** trigger a kill-switch — the spike is suggestive, not conclusive (a legitimate operator-initiated batch job can produce a 5x hourly spike).
- **Day-over-day 3x spike** in summed cost value within a category. Same posture — alert plus error event, no kill-switch.

The thresholds (5x hour-over-hour, 3x day-over-day) are starting points and configurable per-category. AI inference has higher natural variance than Azure infra; the operator can tighten Azure thresholds and loosen AI thresholds based on observed behavior.

Anomaly alerts operate **per-tenant** (per D5) and **per-agent** (per D6) in addition to per-category. A tenant whose hourly spend 5x's relative to their rolling baseline fires a per-tenant anomaly even if the Grid-wide category is nowhere near its threshold. This is the abuse-detection surface; D5 names it, D10 implements it.

The App Insights alert rules are defined as Bicep/IaC (per the broader Infrastructure-as-Code commitment) so they version-track with the Operator Node; ad-hoc click-ops alert configuration is explicitly out of scope.

**False-positive tolerance:** Anomaly detection at these thresholds will produce occasional false positives — a legitimate large batch job, a test run, a one-off model evaluation. The acceptance posture is "an alert that requires the operator to glance at the report and dismiss is cheap; an alert that catches a real runaway is invaluable." The 5x/3x thresholds are deliberately on the loose side of typical anomaly-detection literature so the false-positive rate is bounded. If the operator finds the false-positive rate intolerable in practice, the per-category configurability (named above) allows tuning without a new ADR.

**Why not a learned anomaly model:** Considered. Azure provides ML-backed anomaly detection. Rejected for v1 because (a) the cost-event volume is too low for the model to train reliably without months of history, (b) the operator's mental model of "spike vs not" is precise enough at this scale that a learned model adds unexplained behavior without obvious gain, and (c) the simpler threshold rule is auditable and tunable in a way the learned model is not. Revisit when monthly event volume exceeds 10M (which would correspond to roughly 100x current AI activity — well into commercial-product territory).

### D11 — Operator unlock policy

When the hard cap fires and the kill-switch engages, the operator can override. The override is **explicit and audited**.

The mechanism: a CLI command on HoneyDrunk.Operator (`hd cost unlock <category> --reason "<text>" --duration <hours>`) that:

1. Writes an audit event (per ADR-0030) capturing the category, the operator identity, the reason, the duration, and the timestamp.
2. Sets a `BudgetOverride` record in the ledger with an expiration timestamp.
3. The `ILlmDispatcher` kill-switch check honors the override: while the override is active and unexpired, the cap check returns "permitted" with a flag indicating the call is consuming override budget.

The override is **time-bounded** (default 24 hours, configurable per invocation). After expiration, the cap re-engages automatically. There is no "permanent" override option — re-engagement is the safer default. If the operator genuinely needs a higher cap permanently, the path is to edit `business/context/cost-budgets.json` and PR the change (which itself is audited via git).

The override **does not raise the cap retroactively**. Spend incurred before the override engaged is still attributed to the category at its original cap; the override just permits new spend through the kill-switch. The Grid total for the month reflects the actual spend, not the cap.

Audit events for overrides are tagged `sensitive=audit` per ADR-0045 D7 and follow the 730-day retention from ADR-0040 D3 — overrides are exactly the kind of decision that needs a long-retention trail for post-incident review.

**Override pattern catalog:**

- **Emergency override** — operator needs to continue operations through a cap breach for a customer-facing reason; issues with reason like `"customer-demo-in-progress, kill-switch blocking, raising for 4h"`; expires automatically.
- **Investigative override** — operator suspects a runaway is the cause of the cap breach and wants to keep limited capacity while triaging; issues with reason like `"investigating high burn, allow tier-1 traffic only for 2h"`; the override is *partial* in spirit but the v1 mechanism is all-or-nothing (a per-tier override is named as future work).
- **Planned override** — operator knows an expensive operation is coming (e.g., a full eval run across all approved models) and pre-issues the override; reason includes the planned operation; expiration set to cover the planned window.

The audit record captures all three patterns identically (category, operator, reason, duration); the distinction is purely in the reason text. Future work may introduce structured override types if operators want pattern-level reporting (e.g., "how many emergency overrides did we issue this quarter").

**Why time-bounded by default:** Permanent overrides are the most dangerous configuration because they look like the system is working when in fact the safety control is disabled. A time-bounded override that re-engages forces the operator to either (a) accept the cap and engage the work, (b) issue a follow-on override (audited again), or (c) PR the budget config (audited via git). All three are recoverable; a forgotten permanent override is not. The 24-hour default is long enough to handle any reasonable in-flight incident, short enough that "I forgot to revert it" cannot turn into chronic disablement.

### D12 — Test and dev environment treatment

Dev environments have **separate, smaller caps** on a separate Azure subscription (or, if cost segregation is not warranted, a separate resource group with cost-attribution tags). Production caps **do not include dev burn**.

Suggested defaults:

| Category | Dev soft | Dev hard |
|---|---|---|
| AI inference (dev) | $50 | $100 |
| Azure infrastructure (dev) | $25 | $50 |
| GitHub Actions (dev) | $25 | $50 |

The split is necessary because:

- A dev environment running a runaway agent against production caps would consume the entire production budget. The operator should be free to experiment in dev without risking production.
- Dev burn is mostly developer-attributable; production burn is mostly customer-attributable. Mixing them obscures the per-customer cost signal that drives Notify Cloud billing (D5).
- The Azure Cost Management API supports cost-by-subscription and cost-by-resource-group splits natively; the aggregator job (D7) can pull either shape.

The dev caps follow the same enforcement posture (D4) — hard cap fires the kill-switch, alerts go through the same Notify channel, overrides require the same audit. The only difference is the absolute values and the resource scope.

**Environment identification on cost events:** Every `CostEvent` carries an `Environment` field (`prod`, `dev`, `staging`, `local`) so the ledger naturally partitions by environment for reporting and enforcement. The field is derived from the application's runtime environment configuration; misclassification (e.g., a dev process tagging events as `prod`) would be a defect detected by the cap-vs-actual sanity check in the daily roll-up.

**Local development:** A developer running against real APIs on their workstation produces cost events tagged `local`. Local events do **not** count against any cap (the developer's machine is not running production workloads), but they **are** recorded in the ledger for visibility — "I burned $40 of AI inference yesterday debugging the dispatcher" is information the operator wants. The intent is to make personal usage visible without imposing a cap on it.

### D13 — Relationship to ADR-0016, ADR-0037, ADR-0041, and ADR-0045

- **ADR-0016 D5 (operator-configurable token cost rates and `ICostLedger`)** — this ADR is the policy layer ADR-0016 references. ADR-0016 names the abstraction; this ADR defines its caps, alerts, kill-switches, attribution, persistence, and reporting. The implementation home in `HoneyDrunk.AI` (D7) is consistent with ADR-0016's standup scope.
- **ADR-0037 (Payments Node)** — per-tenant cost attribution (D5) is the upstream input to payment invoice generation. This ADR commits the attribution dimension; ADR-0037's implementation consumes it. Decoupled by the ledger interface.
- **ADR-0041 (AI model registry)** — model approval is the gate on *what runs*; this ADR is the gate on *how much runs*. Both are necessary; neither replaces the other. An approved model still respects the AI inference cap; a denied model is rejected before the cap check.
- **ADR-0045 (error tracking)** — hard-cap breaches and anomaly detections both flow through `IErrorReporter` for surface consistency. The operator sees cost events in the same App Insights Failures blade they see application errors, problem-grouped distinctly so cost incidents don't drown application incidents.
- **ADR-0030 (Audit substrate)** — operator overrides (D11) write audit events; the cost ledger itself is **not** the audit substrate (different retention shape, different append semantics — the cost ledger supports updates for retroactive reconciliation, Audit does not).
- **ADR-0018 (Operator Node)** — Operator hosts the `hd cost` CLI surface, the aggregator job, the Container Apps auto-suspend job, and the "Cost" dashboard view. The operator surface is the human control plane for the entire cost-governance system; without Operator, the ledger has no control loop.
- **ADR-0036 (DR / backup tiers)** — the cost ledger is tier 2 (loss is recoverable from upstream APIs over 24–48h). Backup schedule and recovery objectives inherit from ADR-0036's tier 2 commitments. Audit events for overrides inherit the stricter Audit retention (tier 1) regardless of which Node emits them, per ADR-0030.
- **ADR-0026 (TenantId primitives)** — the `TenantId` dimension on cost events uses the ADR-0026 opaque identifier shape unchanged. The cost ledger does not coin new tenant identifiers; it consumes the canonical one.
- **BDR-0001 (mailbox service)** — example of the BDR pattern that this ADR explicitly extends to vendor cost commitments. New SaaS subscriptions follow BDR-0001's record shape and additionally update `business/context/cost-budgets.json` to reflect the new line item.

### D14 — Phased rollout

The substrate is non-trivial; landing it in phases reduces the risk of the rollout itself introducing the runaway it is meant to prevent.

- **Phase 1 (Week 1–2) — Ledger substrate.** Add `ICostLedger` and supporting types to `HoneyDrunk.Kernel.Abstractions`. Implement the v1 Cosmos-backed ledger in `HoneyDrunk.AI` with the in-memory cache and the kill-switch check. Wire `ILlmDispatcher` to call `IsHardCapBreachedAsync` before each call. **Initial caps are intentionally loose** ($5000 / $10000 across all categories) so the kill-switch does not fire spuriously while baselines are being established. Daily roll-up email enabled. Threshold pings disabled until Phase 3.
- **Phase 2 (Week 3–4) — Aggregator and external sources.** Author the Operator aggregator job to pull Azure Cost Management, GitHub Actions, and known vendor APIs. Backfill the prior 90 days where each API supports historical query. Validate the aggregator's totals against the actual Azure / GitHub bills for the most recent closed month — drift greater than 5% is a defect.
- **Phase 3 (Week 5–6) — Threshold tuning and ping activation.** With one month of baseline actuals from Phase 1/2, tune the per-category caps to the D2 defaults (or to the operator's adjusted values based on observed behavior). Enable threshold pings. Validate that the 50%/75%/90% pings fire correctly by intentionally setting a low test cap and exercising the dispatcher.
- **Phase 4 (Week 7–8) — Kill-switch enablement.** Switch the kill-switch from "log a warning" to "throw `BudgetExceededException`." This is the highest-risk single change in the rollout because it changes runtime behavior. Pilot on the AI inference category first; observe for one week; extend to Azure infra (Container Apps auto-suspend) and validate GitHub-native CI limit. Hard-cap breach alerts wired through Notify Communications.
- **Phase 5 (Week 9–10) — Anomaly detection.** Author the App Insights alert rules per D10. Tune thresholds based on observed false-positive rates over a two-week observation window.
- **Phase 6 (Month 3+) — Per-tenant and per-agent attribution surfaces.** Per-tenant cost view in Operator. Per-agent cost breakdown in the monthly report. The dimensions are captured from Phase 1; the surfaces consuming them are built here.
- **Phase 7 (Ongoing) — Dev/prod separation per D12.** Azure resource reorganization where needed; dev caps activated.

Each phase is a discrete go/no-go. Phase 4 is the explicit "this is the dangerous one" phase; the rollout is structured so that a defect in the kill-switch logic is detected (via Phase 4's one-week observation) before it can produce a customer-impacting halt.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel** — gains `ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, and the configuration record types in the abstractions surface. Interface only; no implementation.
- **HoneyDrunk.AI** — primary affected Node. Hosts the v1 `ICostLedger` implementation, the in-memory cache for hot-path reads, the Cosmos persistence layer, the per-call dispatcher integration that performs the kill-switch check, and the token-rate configuration that converts inference events into cost values.
- **HoneyDrunk.Operator** — gains the `hd cost` CLI command surface (unlock, status, report), the Container Apps auto-suspend job for the Azure infra category, the aggregator job that polls Azure Cost Management / GitHub Actions / vendor APIs and writes events to the ledger, and the "Cost" view in the Operator UI.
- **HoneyDrunk.Communications + HoneyDrunk.Notify** — receive the daily roll-up, threshold pings, hard-cap breach pushes, and anomaly alerts as new alert categories. No new contracts; the existing alert pipeline is reused.
- **HoneyDrunk.Observe + HoneyDrunk.Observe.AzureMonitor** — App Insights alert rules for D10 anomaly detection are defined as Bicep within the Observe-adjacent IaC.
- **HoneyDrunk.Audit** — receives override events per D11 with `sensitive=audit` tagging.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains `ICostLedger` under Kernel's published contracts; `business/context/cost-budgets.json` is added as the configuration file; `generated/cost-reports/` directory is added with the format spec and the first auto-generated report.
- **All AI-sector Seed Nodes (per ADR-0016–0025)** — every Node consuming `ILlmDispatcher` inherits the kill-switch behavior transparently; no per-Node change required beyond the dependency on the updated HoneyDrunk.AI version.
- **HoneyDrunk.Payments Node (per ADR-0037)** — consumes the per-tenant cost roll-up from the ledger.
- **Future HoneyDrunk.CostLedger Node** — promotion path per D7; not created at v1.

### Invariants

Adds three:

- **Invariant: every cost-producing operation in the Grid is recorded as a `CostEvent` in the cost ledger.** Operations that bypass the ledger have undefined kill-switch and attribution behavior and are forbidden. CI check: dispatcher and aggregator code paths must produce a `CostEvent` for every dollar of external spend.
- **Invariant: `ILlmDispatcher` checks the cost ledger against the hard cap before each call.** The check is on the hot path; failure to short-circuit when the cap is breached is a budgeting failure and a defect. Integration test required per ADR-0047 D4.
- **Invariant: operator overrides of cost caps are audited.** Overrides without a corresponding audit event are an audit-substrate violation per ADR-0030 and a cost-governance violation per this ADR. The override CLI surface is the only sanctioned override path; direct database writes to `BudgetOverride` are forbidden.

(Final invariant numbers assigned at constitution-update time; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **Every `ILlmDispatcher` call now reads the cost ledger.** The read is served from an in-memory cache refreshed every 30 seconds, so the hot-path cost is a dictionary lookup (sub-microsecond). The cache miss path reads Cosmos (single-digit ms). Cache invalidation on cap-config change is event-driven; cache invalidation on aggregator writes is on the 30-second tick. The performance impact at v1 LLM call volume is below the noise floor of the LLM call itself; called out for transparency, not as a blocker.
- **Operator must approve cap overruns explicitly.** This is slower in an emergency than "no cap exists" — there is a real scenario where a customer-impacting workload is halted by the kill-switch and the operator has to issue an override. The cost of that scenario is bounded by the override turnaround time (CLI command, seconds); the cost of *not* having the kill-switch is unbounded. The trade is the right way around for a bootstrapped studio.
- **The cost ledger introduces a Cosmos dependency for HoneyDrunk.AI.** AI Node currently has no persistence dependency beyond what model registry / agent state already require. The Cosmos addition is incremental but real; standup work must include the Cosmos provisioning step.
- **The Azure Cost Management API has propagation lag.** The aggregator's view of Azure infra cost is 8–24 hours behind reality. The kill-switch for Azure infra therefore lags by the same window. This is acknowledged; the alternative (faster cost source) does not exist. The fast circuit-breaker is the in-process AI inference check; the slow circuit-breaker is the Azure infra suspend. Both layers are necessary because the failure modes are different.
- **BDR-style records become expected for vendor cost commitments.** Adding a new SaaS subscription that contributes to the third-party SaaS category should produce a BDR (per BDR-0001's pattern) before the subscription is signed, so the soft cap config is updated in the same change. The drift report's note about missing vendor cost tables is partially closed by this expectation; the rest is closed by the actual table additions to `business/context/`.
- **Per-tenant cost attribution is a precondition for Notify Cloud billing.** ADR-0037 cannot ship without D5 in place. This ADR's timing is therefore upstream of Notify Cloud GA, not parallel to it.
- **Dev environment cost separation requires Azure resource organization work.** If the studio's current Azure subscription mixes dev and prod resources, the dev caps (D12) cannot be enforced cleanly until the resources are reorganized into separate subscriptions or distinctly-tagged resource groups. The reorganization is recorded as follow-up work.
- **The `business/context/cost-budgets.json` file becomes a production-critical configuration.** A mis-edit could disable the kill-switch (raise the hard cap to infinity) or trigger spurious shutdowns (drop the hard cap below current month-to-date). The file's PR review is therefore a production-config review; the `review` agent (per ADR-0044) should treat it accordingly.
- **Cost data is now a privacy-adjacent surface.** Per-tenant cost attribution reveals usage volume; per-agent attribution reveals what work was done. Neither is PII by itself, but aggregates can become inferential about tenant behavior. The 13-month retention plus the operator-only access to per-tenant detail (D9) bounds the exposure, but the surface should be treated with the same care as any tenant-data store. Any future external sharing of cost data (e.g., a public usage page) must be anonymized aggregates only.
- **The kill-switch creates a new failure mode: false breach.** If the ledger's accounting is wrong (a duplicate write, a wrong-category event, a stuck-zero rate config), the kill-switch can fire when no actual budget is exceeded. The Phase 2 reconciliation (aggregator totals vs actual bill) is the structural defense; the override (D11) is the emergency recovery. The false-breach failure mode is mitigated but not eliminated by these layers; operators should know it can happen.
- **First-month behavior is intentionally permissive.** Phase 1's loose initial caps ($5000/$10000) means the kill-switch will almost certainly not fire during the first month; the trade is "we accept some risk of an actual runaway in the first month in exchange for not breaking operations on a defect in the ledger itself." The risk window is bounded; the alternative (tight caps from day one with a defective ledger) is operationally worse.

### Follow-up Work

- Add `ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, configuration record types to `HoneyDrunk.Kernel.Abstractions`.
- Implement the v1 ledger in `HoneyDrunk.AI` per D7: Cosmos persistence, in-memory cache, dispatcher integration.
- Author the aggregator job in `HoneyDrunk.Operator` for Azure Cost Management, GitHub Actions, and vendor APIs.
- Author the `hd cost` CLI surface in `HoneyDrunk.Operator` (status, unlock, report).
- Author the Container Apps auto-suspend job for the Azure infra hard-cap breach.
- Define App Insights alert rules for D10 anomaly detection as Bicep; deploy via Operator IaC.
- Wire the daily roll-up, threshold pings, hard-cap breach pushes, and anomaly alerts into HoneyDrunk.Communications + HoneyDrunk.Notify.
- Create `business/context/cost-budgets.json` with the D2 defaults; document the tuning policy in `business/context/`.
- Create `generated/cost-reports/_format.md` and the directory; wire the monthly auto-generation aggregator.
- Add `IIdempotencyStore`-style contract tests for `ICostLedger` per ADR-0047 D4.
- Update `catalogs/contracts.json` with `ICostLedger` under Kernel.
- Update the `review` agent (per ADR-0044 D3) with a "cost-config change" review category for `business/context/cost-budgets.json` edits.
- Reorganize Azure resources into dev/prod separation per D12 (if not already separated).
- Author the per-tenant cost roll-up query API consumed by Payments (per ADR-0037).
- Document the override audit pattern in `business/context/` so operators know the procedure before they need it.
- Add a `cost-config` review category to `.claude/agents/review.md` per ADR-0044 D3, covering the production-critical nature of `business/context/cost-budgets.json` changes.
- Set per-provider API key spending limits (OpenAI, Anthropic) at slightly above the corresponding Grid hard cap, as the defense-in-depth net per the Alternatives Considered section.
- Document the operator override patterns (emergency, investigative, planned) in `business/context/` with concrete CLI examples so the first real override is not the operator's first attempt.
- Add an integration test for the `BudgetExceededException` no-retry contract — verify that the exception type is sealed, that the default retry policies do not retry it, and that the `review` agent's category check catches catch-and-retry patterns.
- Author the canonical structured JSON sidecar (`generated/cost-reports/YYYY-MM.json`) format for machine consumers of the monthly report.

## Alternatives Considered

### "Just trust the team"

Considered. The "team" today is one developer; the trust model would be "Oleg watches the bill." Rejected on three grounds:

- **Attention is not a control.** A runaway loop in an agent script burns $10K before the operator's email notification arrives, let alone before the operator reads it. Manual attention is a detection mechanism, not a prevention mechanism.
- **Solo-developer operations have no second-pair-of-eyes safety.** Larger orgs have CFOs, AP teams, FinOps functions watching spend. The bootstrapped studio does not; the kill-switch substrate is the substitute.
- **The cost of being wrong is asymmetric.** Spending two weeks building the cost governance substrate is bounded; eating a $10K surprise Azure or OpenAI bill is bounded by the studio's runway, which is itself bounded.

The "trust the team" model is appropriate for orgs with FinOps oversight, mature billing review processes, and investor runway. None of those apply here.

### Azure Budgets alone (no in-process kill-switch)

Considered. Azure provides native budget alerts (and, on supported subscription types, automated actions like shutting down resources). Rejected because:

- **Azure Budgets cannot intervene in AI inference flow.** OpenAI and Anthropic API spend is not Azure spend; Azure Budgets has no visibility. AI inference is the dominant cost line; a control layer that doesn't see it is structurally inadequate.
- **Azure Budgets' enforcement actions are coarse.** "Shut down this resource group" is not the same as "decline this specific LLM call." The in-process check provides the precision that an external budget tool cannot.
- **Cross-vendor cost (AI providers, SaaS, GitHub Actions) needs unified aggregation.** Azure Budgets only sees Azure. A Grid-level ledger sees everything.

Azure Budgets is **complementary** — it remains in place as the Azure-native secondary control. The Container Apps auto-suspend (D4) integrates with Azure Cost Management, not Azure Budgets directly, but the two are adjacent. Azure Budgets fires its own alerts which the operator may treat as additional signal.

### Per-call hard cap (every LLM call has a max dollar value)

Considered. A simpler model: "no single LLM call can cost more than $X." Rejected because:

- **The runaway loop scenario is many small calls, not one large call.** A `while true` calling a $0.001 endpoint a million times defeats a per-call cap entirely. The category-level monthly cap catches the loop; the per-call cap does not.
- **Per-call caps would interfere with legitimate large-context calls.** A long-context summarization call may legitimately cost $5; a per-call cap that low would block it.
- **Per-call caps are an attribution surface, not an enforcement surface.** Logging per-call cost is valuable for forensics (D6 supports it); enforcing per-call cost is not.

Per-call cost is captured as a dimension on every `CostEvent`; per-call enforcement is not adopted.

### Daily caps instead of monthly caps

Considered. Smaller window, tighter control. Rejected because:

- **Monthly is the natural billing window** for every external cost source (Azure, OpenAI, Anthropic, GitHub Actions, SaaS subscriptions). Reconciling against the bill requires monthly aggregation.
- **Daily caps are too brittle.** A legitimate weekend batch job that 10x's normal daily spend would fire the kill-switch on Saturday morning and disrupt operations until the operator notices.
- **Anomaly detection (D10) provides the sub-monthly signal.** Hour-over-hour and day-over-day spikes fire alerts on the timescale daily caps would, without the rigidity of a hard daily ceiling.

The monthly cap plus anomaly detection covers the same ground as daily caps without the brittleness.

### Stripe-style "metered billing" model with pre-authorized credits

Considered. Customer pre-funds a credit pool; spend draws against it; pool exhaustion halts service. Rejected as the v1 cost-governance model because:

- **It's a customer-billing model, not a cost-control model.** ADR-0037 is the home for customer-side billing semantics. This ADR's scope is Grid-internal spend control.
- **It doesn't address Studio-internal cost.** A pre-funded pool model would still leave Studio-side agents (Codex, internal Claude agents) burning unmetered budget.

The per-tenant attribution (D5) feeds Payments, which may implement a pre-authorized credit model for tenants. That is a separate decision; this ADR enables it but does not implement it.

### Co-locate the ledger in HoneyDrunk.Kernel directly

Considered. Putting the implementation in Kernel rather than just the interface would centralize the substrate. Rejected because:

- **Kernel is a thin-shell Node.** Per the consistent pattern across the Grid, Kernel hosts abstractions, not implementations. Putting a Cosmos-dependent implementation in Kernel would force every Kernel consumer (which is every Node) to take a transitive Cosmos dependency. Unacceptable for the Kernel posture.
- **AI Node already has the Cosmos posture** and is the dominant cost producer. Co-locating the implementation there is incremental cost; standing it up in Kernel is structural cost on every consumer.

The interface-in-Kernel / implementation-in-AI split (D7) preserves the Kernel principle and minimizes added surface.

### Stand up `HoneyDrunk.CostLedger` as its own Node from day one

Considered. A dedicated Node would be the textbook answer: clean separation of concerns, no AI-Node coupling, independent versioning. Rejected for v1 because:

- **Standup overhead is real.** Per ADR-0011 and the standup ADR pattern, a new Node requires its own repo, CI, packaging, canary, integration tests, and standup ADR. Adopting that overhead for v1 when AI Node can host the implementation incrementally is a poor cost trade.
- **The promotion path is explicit (D7).** When non-AI categories grow material or a second writer Node appears, the implementation graduates without API breakage. Solo-dev studios optimize for "ship the smallest viable thing first, promote when justified."

The dedicated-Node option remains the v2 path; D7 documents the promotion trigger.

### Skip per-tenant and per-agent attribution at v1

Considered. The attribution dimensions add storage cost and code complexity. Rejected because:

- **Per-tenant attribution is a Notify Cloud GA precondition.** ADR-0037 cannot ship without it; this ADR is upstream. Delaying attribution to v2 delays Notify Cloud, which is the studio's first revenue surface.
- **Per-agent attribution is forensics-critical.** Without it, a kill-switch firing produces "the budget is breached" with no signal about *which agent caused it*. Post-incident triage time becomes hours instead of minutes.

The dimensions are small (two opaque ids per event); the cost of carrying them from day one is low. Backfilling them later would be impossible — historical events without attribution stay unattributed forever.

### Skip anomaly detection at v1

Considered. Threshold-based caps cover the slow-burn case; anomaly detection adds the spike case. Rejected because the spike case is the **dangerous** case — a runaway loop produces a spike, not a slow burn. Cap-only governance lets a runaway burn 90% of the cap before the first threshold ping. Anomaly detection is the cheapest layer that addresses this.

The implementation cost is small (App Insights alert rules, declarative; no application code needed beyond emitting the cost metric for the rules to query). The detection sensitivity can be tuned post-launch based on observed false-positive rates.

### Defer until after the AI-sector standup wave (ADR-0016 through ADR-0025)

Considered. The standup wave is large; piling cost governance on top adds scope. Rejected because:

- **The standup wave is the cost-risk increase.** Each new AI Node adds a new spend surface. Standing up nine Nodes without a cost-control substrate is the highest-risk posture in the Grid's history.
- **Retrofitting `ICostLedger` after the fact is harder than embedding it from the start.** Standup ADRs commit Node shapes; cost-ledger consumption is one of those shapes. Adding it later means revisiting every standup ADR.
- **The first runaway loop is too late.** A bootstrapped studio can absorb one $10K surprise bill once, maybe twice. The governance must precede the risk, not chase it.

This ADR is positioned **inside** the standup wave specifically so the AI Nodes consume the cost-ledger from day one of their standup. Defer-and-retrofit is the worse posture.

### Cap on dollar value of single API key rather than per-category

Considered. Many SaaS billing tools support per-API-key spending limits (OpenAI itself supports this). Configure the OpenAI key with a $1500/month limit; let OpenAI enforce. Rejected because:

- **Per-key limits do not aggregate across providers.** A $1500 OpenAI cap plus a $1500 Anthropic cap equals $3000 effective AI inference spend, not $1500. The Grid-level cap is the property that matters.
- **Per-key limits do not have soft-cap behavior.** OpenAI's limit is "stop at this number"; there is no equivalent of the 50%/75%/90% pings.
- **Per-key limits cannot do per-tenant or per-agent attribution.** The breakdown happens at the in-process call site; the provider has no visibility into which agent or tenant initiated the call.

Per-key limits are **adopted as a safety net layer** — set each provider's per-key limit to slightly above the corresponding Grid hard cap (e.g., $1700 OpenAI cap when the Grid AI inference hard cap is $1500). This catches the case where the in-process ledger is somehow bypassed; the provider's limit will still halt spend before it spirals. Defense in depth.

### Use Azure Cost Management's native budget actions instead of a custom kill-switch

Considered. Azure Cost Management supports budget-action automation (run a runbook, suspend a resource group) on threshold breach. Rejected for the AI inference category (Azure doesn't see non-Azure spend); adopted for the Azure infrastructure category (D4's Container Apps auto-suspend job triggers from Azure Cost Management). The two coexist; this ADR doesn't reject Azure's native capabilities, it scopes their use to the cases they cover.

### Tie cost caps to revenue (e.g., "AI inference cap is 30% of monthly recurring revenue")

Considered as a future evolution. At v1 the studio is pre-revenue, so a revenue-tied cap evaluates to zero, which is wrong. Rejected for v1; named as a possible future ADR amendment once Notify Cloud has consistent MRR. The cap structure (D2) is forward-compatible with a revenue-tied tuning policy.

### Open-source cost aggregation tools (OpenCost, Kubecost, Infracost)

Considered. Mature OSS tools exist. Rejected because (a) most are Kubernetes-native and the Grid is Container Apps, not AKS, (b) none address AI inference cost which is the dominant line, and (c) operating an OSS tool adds operational surface that a solo-dev studio cannot afford. The custom aggregator in Operator (D7) is small (a few hundred LOC) and targets exactly the data sources the Grid uses; the open-source tools target a much broader problem domain at a much higher operational cost.

### Skip the audit requirement on overrides

Considered. The audit pass adds friction to emergency overrides. Rejected because the override is exactly the action that needs a long-retention trail — the post-incident question "why did we exceed the cap last month" is unanswerable without the override record. The friction is small (one CLI flag); the audit value is large.

### Use a third-party FinOps platform (Cloudability, CloudHealth, Apptio)

Considered. The FinOps SaaS market has mature offerings with rich dashboards, anomaly detection, and budget alerting out of the box. Rejected because (a) per-seat pricing is prohibitive for a solo-dev studio, (b) none integrate cleanly with in-process LLM cost which is the dominant line, and (c) they introduce another vendor relationship at exactly the moment this ADR is trying to reduce vendor proliferation. Reconsidered if the studio grows to multiple developers with materially different cost-attribution needs.

### Per-PR cost budget for CI

Considered. Cap the GitHub Actions cost any single PR can consume; halt the PR if it exceeds. Rejected because (a) Actions don't natively support per-PR billing — the bill rolls up per repo, (b) most PR cost is bounded by job timeouts already, and (c) the operational overhead of attributing cost back to a specific PR is high relative to the value. The org-level GitHub Actions limit per D4 catches the runaway case; per-PR controls are not justified at v1 scale.

### Store the budget config in Vault rather than the Architecture repo

Considered. Vault is the canonical secret store and the config does affect production behavior. Rejected because (a) the budget config is not secret — it's policy that should be visible to anyone reviewing how the Grid operates, (b) the git-tracked version history is the audit feature, which Vault does not provide, and (c) the PR-review flow on `business/context/cost-budgets.json` changes is the human gate, which Vault writes bypass. Vault is the wrong tool; the right answer is a tracked, reviewed, version-controlled file.

### Implement the kill-switch via a circuit-breaker library (Polly)

Considered. Polly's circuit breaker is the right pattern for transient-failure handling. Rejected because the budget kill-switch is not a transient circuit — it does not "recover" after a back-off window the way a 5xx-driven breaker does. The cap is closed for the rest of the billing window (or until an override). Using Polly's circuit-breaker abstraction would suggest the wrong mental model to readers; a purpose-built check (`IsHardCapBreachedAsync`) is clearer about its non-transient semantics. Polly remains the right tool for the per-call retry/backoff layer **inside** an LLM call; the budget check sits outside that layer.
