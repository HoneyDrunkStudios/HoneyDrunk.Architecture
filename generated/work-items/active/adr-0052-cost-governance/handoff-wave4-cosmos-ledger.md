# Handoff — Wave 3 → Wave 4: the Cosmos-backed v1 ledger

**Initiative:** `adr-0052-cost-governance`
**Wave transition:** Wave 3 (AI-side `ICostLedger` relocation + Phase-1 stub) → Wave 4 (Cosmos-backed v1 implementation)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Waves 1–3 landed

- **Wave 1 (packets 00 / 01 / 02 / 07 / 08).** ADR-0052 Accepted. Three invariants (90, 91, 92) live. Cost-governance contracts registered under `honeydrunk-kernel` in the catalog. `business/context/cost-budgets.json` exists with D2 defaults / D10 anomaly thresholds / D12 dev overlay. `generated/cost-reports/_format.md` ships the canonical monthly report format. `.claude/agents/review.md` carries the `cost-config` and `cost-kill-switch-retry` review categories.
- **Wave 2 (packet 03).** `HoneyDrunk.Kernel.Abstractions` ships `ICostLedger` (five members), `CostEvent`, `CostCategory`, `CostSource` (discriminated union), `CostEnvironment` (enum with `Local` exempt-from-caps), `BudgetExceededException` (sealed, non-transient), `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery`. `HoneyDrunk.Kernel` solution bumped (or appended to the in-progress ADR-0042 version — record which case applied).
- **Wave 3 (packet 04).** `HoneyDrunk.AI.Abstractions/ICostLedger.cs`, `InferenceCost.cs`, `CostSummary.cs` deleted. `HoneyDrunk.AI.Abstractions` references `HoneyDrunk.Kernel.Abstractions` at the version that ships packet 03. Every AI provider package (`OpenAI`/`Anthropic`/`AzureOpenAI`/`InMemory`) has migrated from `RecordAsync(InferenceCost)` to `RecordCostAsync(CostEvent)` with `CostSource = new LlmInferenceSource(provider, model, inputTokens, outputTokens)` and `Category = CostCategory.AiInference`. `DefaultCostLedger` is a Phase-1 **non-durable stub** — `RecordCostAsync` logs at Debug, `IsHardCapBreachedAsync` returns `false`, `GetActiveOverrideAsync` returns `null`, `QueryAsync` returns empty. The `HoneyDrunk.AI` solution bumped `0.1.0` → `0.2.0` (additive minor — no out-of-repo consumer of the old seed contract).

Wave 4 (packet 05) replaces the Phase-1 stub with the Cosmos-backed v1 implementation and ships the in-memory cache that serves the hot-path cap check.

## What Wave 4 must deliver (packet 05)

Replace `DefaultCostLedger`'s body (or add a `CostLedger` class that takes over the registration) in `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/` with the durable Cosmos backing per ADR-0052 D7 / D8:

- **`CostLedger`** — implements all five `ICostLedger` members. `RecordCostAsync` writes to Cosmos with partition key `(category, year-month)`. `IsHardCapBreachedAsync` is served from an in-memory cache, never from Cosmos on the hot path. The cache stores the current-month roll-up per category and is refreshed every 30 seconds by `CostLedgerCacheRefreshService`. `Local`-environment events are written to Cosmos for visibility but do not update the cap-check cache (D12).
- **`BudgetConfigProvider`** — reads `business/context/cost-budgets.json`. Applies the Phase-1 multiplier per environment (`Dev`/`Staging` 10x, `Prod` 1x by default). Caches the resolved config for ~60 seconds.
- **`CostLedgerCacheRefreshService`** — `IHostedService` that loops every 30 seconds and refreshes the cache from Cosmos. Use `TimeProvider` (invariant 51 — no `Thread.Sleep`).
- **`CostLedgerCosmosOptions`** — config record (endpoint, database, container, phase-1 multipliers).
- **Cosmos provisioning Bicep** — at the AI Node's IaC convention (if no such convention exists, create `HoneyDrunk.AI/infra/`).

## Hot-path contract — non-negotiable

`IsHardCapBreachedAsync` runs on every LLM call (per packet 06 in Wave 5). It MUST be served from the in-memory cache — sub-microsecond at v1 LLM call volume. The cache miss path reads Cosmos (single-digit ms) and populates the cache. A read that goes to Cosmos on every invocation defeats the kill-switch's "fast circuit-breaker" posture (ADR-0052 D4).

The cache TTL is the 30-second refresh tick. A 30-second lag between a write and a cache update is acceptable — the cap is a monthly aggregate; a 30-second window of stale data near the cap will at worst over-spend by the volume that 30 seconds of LLM traffic produces, which is small relative to the cap.

## Override priority — read first

`IsHardCapBreachedAsync` returns `false` when an active `BudgetOverride` covers the queried category, regardless of month-to-date. The check sequence:
1. Read the active override for the category from Cosmos (a small dedicated container or sentinel rows — choose at implementation time).
2. If an override exists with `ExpiresAt > now` and `RevokedAt is null`, return `false`.
3. Otherwise, compare cache value against the configured hard cap (with dev overlay + Phase-1 multiplier applied) and return the comparison.

The dispatcher (packet 06) does NOT separately query overrides — one `IsHardCapBreachedAsync` call answers "can this call go through."

## Phase-1 multiplier — operator-tunable

ADR-0052 D14 Phase 1 names "intentionally loose initial caps" so the kill-switch does not fire spuriously during baseline. Implementation: `CostLedger:PhaseOneMultiplier:Dev` / `:Staging` / `:Prod` in App Configuration. Defaults: 10 (dev), 10 (staging), 1 (prod). The effective cap is `BudgetCategoryConfig.HardCap * PhaseOneMultiplier[Environment]`.

The Phase-3 flip (D14) sets dev/staging to 1 — an operator-driven App Configuration change, not a code change. The flip narrative lives in packet 09's playbook. Document the multiplier behaviour in the implementation file and the PR.

## Cosmos persistence shape

- **Partition key:** `$"{category}|{timestamp:yyyy-MM}"` — `(category, year-month)`.
- **Row key / item id:** something unique per event. Recommend `Guid.NewGuid().ToString()` for the item id; carry the timestamp / tenant id / agent id as item fields, not part of the row key (the row key is for uniqueness; the dimensions are for query).
- **Retention:** 13 months (current + 12 trailing). The retention sweep is a separate concern — either Cosmos TTL on individual items (set `_ts`-relative TTL of ~400 days) or a scheduled cleanup job. ADR-0052 D8 commits the retention; the **mechanism** is the implementer's choice. Document which path.
- **Override storage:** a separate container `cost-overrides` (or sentinel rows in the same container, partitioned by `"overrides|active"`) — pick the cheaper option and document.
- **Storage cost:** ~2.6 GB at upper bound (100K events/month × 13 × 2KB). RU/s well under the 400 RU/s autoscale floor. Single-digit-dollars/month in prod; serverless is even cheaper in dev.

## Cosmos auth — Managed Identity, not keys

The Cosmos client uses `DefaultAzureCredential` for the data-plane role `Cosmos DB Built-in Data Contributor` in every non-`Local` environment. Primary keys are NOT placed in source or app settings; for `Local` development, the key is sourced from Vault (`IConfigProvider`) and never logged (invariant 8). The Human Prerequisites on packet 05 include the per-environment RBAC grant.

## DI composition

In `ServiceCollectionExtensions`:
```csharp
services.AddSingleton<ICostLedger, CostLedger>();          // replaces the Phase-1 stub
services.AddSingleton<IBudgetConfigProvider, BudgetConfigProvider>();
services.AddHostedService<CostLedgerCacheRefreshService>();
services.AddOptions<CostLedgerCosmosOptions>().Bind(configuration.GetSection("CostLedger"));
```

Keep the registration idempotent — packet 04 already registered `ICostLedger -> DefaultCostLedger`; packet 05 replaces it with `ICostLedger -> CostLedger`. The stub class may stay marked `[Obsolete]` for one release, or be deleted in this PR (pick at edit time).

## What packet 05 does NOT deliver

- **Dispatcher kill-switch wiring** — that is packet 06. This packet ships a correct `IsHardCapBreachedAsync` answer; no call site consumes it until packet 06.
- **Daily roll-up email / threshold pings / breach push** — gated on ADR-0018 Operator standup (packet 09 playbook).
- **Container Apps auto-suspend** — gated on ADR-0018.
- **App Insights anomaly Bicep** — gated on ADR-0040 + ADR-0018.
- **External-source aggregator (Azure Cost Management, GitHub Actions, vendor APIs)** — gated on ADR-0018.

## Human Prerequisites at the Wave 3 → Wave 4 boundary

The packet 05 packet body names these explicitly; surfaced here for completeness:

1. **Wave 2 → Wave 3 release tag on `HoneyDrunk.Kernel`** — done before packet 04 builds; verify by inspecting the NuGet feed for the new `HoneyDrunk.Kernel.Abstractions` version at edit time.
2. **`HoneyDrunk.AI` solution version state** — packet 05 appends to packet 04's in-progress version entry; do NOT bump again in this initiative (invariant 27).
3. **Cosmos account provisioning per environment** — portal click; cheapest viable tier (serverless dev, autoscale 400 RU/s prod); tag `env=...`, `node=ai`; show $ before clicking Create per the Memory note `feedback_default_cheapest_azure_tier`.
4. **Managed Identity RBAC** — grant the AI Container App's Managed Identity `Cosmos DB Built-in Data Contributor` on the cost-ledger database, per environment.
5. **App Configuration values** — `CostLedger:Endpoint`, `CostLedger:Database`, `CostLedger:Container`, `CostLedger:OverrideContainer` (if separate), `CostLedger:PhaseOneMultiplier:Dev` = 10, `CostLedger:PhaseOneMultiplier:Staging` = 10, `CostLedger:PhaseOneMultiplier:Prod` = 1.

## Invariants binding Wave 4

- **Invariant 1** — the new Cosmos / Azure dependencies land in the **runtime** `HoneyDrunk.AI` package; `HoneyDrunk.AI.Abstractions` stays Cosmos-free.
- **Invariant 4** — DAG. AI depends on Kernel.Abstractions; do not invert.
- **Invariant 8** — Cosmos primary keys never in logs, traces, or exceptions. Managed Identity is the auth path.
- **Invariant 15** — unit tests do not depend on external services; mock the Cosmos client.
- **Invariant 27** — `HoneyDrunk.AI` solution version unchanged from packet 04; append, do not bump.
- **Invariant 47** — Audit substrate (referenced). Override writes are NOT performed by this packet; the read path here just retrieves current override state. Override writes happen in the future `hd cost unlock` CLI on Operator (packet 09 playbook).
- **Invariant 51** — no `Thread.Sleep` in tests. Use `TimeProvider` for cache-refresh tests.
- **Invariant 91** (this initiative, packet 00) — satisfied by **packet 06**, not this one. Packet 05 ships the cap-check method; packet 06 wires the dispatcher.

## Acceptance gate for Wave 4

Packet 05's PR builds. `CostLedger` implements all five `ICostLedger` members. The hot-path cap check is served from the in-memory cache, refreshed every 30 seconds. `BudgetConfigProvider` resolves caps from `cost-budgets.json` with the Phase-1 multiplier applied. Cosmos auth uses Managed Identity. Unit tests cover cap-not-breached / cap-breached / override-active / override-expired / dev-overlay / Phase-1-multiplier / `Local`-exempt behaviour. The Cosmos provisioning Bicep is at the AI Node's IaC convention. The repo-level + per-package CHANGELOGs append to the in-progress AI version entry — no second solution-wide bump.

Wave 5 (packet 06) wires the dispatcher to call `IsHardCapBreachedAsync` and ships the kill-switch canary; packet 09 ships the Operator-side rollout playbook.
