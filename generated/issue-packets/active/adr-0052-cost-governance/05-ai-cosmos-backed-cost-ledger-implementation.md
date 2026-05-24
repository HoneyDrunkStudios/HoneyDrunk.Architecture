---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "ops", "adr-0052", "wave-4"]
dependencies: ["packet:02", "packet:04"]
adrs: ["ADR-0052", "ADR-0016", "ADR-0036"]
accepts: ["ADR-0052"]
wave: 4
initiative: adr-0052-cost-governance
node: honeydrunk-ai
---

# Implement the v1 Cosmos-backed ICostLedger in HoneyDrunk.AI

## Summary
Replace the Phase-1 stub `DefaultCostLedger` (from packet 04) with the v1 Cosmos-backed implementation per ADR-0052 D7 / D8: Cosmos persistence with `(category, year-month)` partition key, in-memory cache for hot-path reads refreshed every 30 seconds, the `IBudgetConfigProvider` consumer that reads `business/context/cost-budgets.json` (via Vault's `IConfigProvider` per ADR-0016 D5), and the per-tenant / per-agent attribution dimensions on writes. The dispatcher kill-switch wiring is **packet 06** — this packet ships the storage and the cap-check read; the wiring to `ILlmDispatcher` lands next.

## Context
ADR-0052 D7 commits the v1 ledger implementation to `HoneyDrunk.AI`. ADR-0052 D8 commits Cosmos as the persistence layer:
- **Partition key:** `(category, year-month)` — single-digit-ms writes regardless of total table size.
- **Row key:** event timestamp + optional tenant id + optional agent id.
- **Single region** at v1 — the ledger is tier-2 per ADR-0036 (loss is recoverable from upstream APIs over 24–48h by re-polling Azure Cost Management / vendor APIs / GitHub).
- **In-memory cache** for the hot-path `IsHardCapBreachedAsync` read — refreshed every 30 seconds; the cache stores the current-month roll-up per category.
- **Retention:** rolling 13 months (current + 12 trailing). Older data exported to cold storage per ADR-0036 backup pattern before deletion.
- **Cosmos cost** is itself a line item in the Azure infra category; the aggregator (D14 Phase 2, gated on Operator standup) captures it back into the ledger.

The in-memory cache is **non-negotiable**: a kill-switch that checks asynchronously after the bill has been incurred is not a kill-switch. The hot-path read is a dictionary lookup (sub-microsecond) at v1 LLM call volume. The cache miss path reads Cosmos (single-digit ms). Cache invalidation on cap-config change is event-driven; cache invalidation on aggregator writes is on the 30-second tick.

**Repo-state gate.** This packet requires the AI Node to be scaffolded enough to host a Cosmos client, a `HostedService` (for the cache refresh), and the `IBudgetConfigProvider` consumption. As of edit time, `HoneyDrunk.AI` is at seed status — the ADR-0016 Phase-1 scaffold packet has not been executed. **This packet is gated on the AI Node scaffold; it cannot land before ADR-0016's scaffold work completes.** The dispatch plan flags this as the initiative's biggest gate.

**Package placement.** The Cosmos client and the implementation live in **`HoneyDrunk.AI`** (the runtime package), not in a new `HoneyDrunk.AI.Cost.Cosmos` provider package. Rationale: ADR-0052 D7 explicitly says "the concrete implementation lives in `HoneyDrunk.AI` for v1" — co-located with the dispatcher. A future promotion to `HoneyDrunk.CostLedger` Node (D7 promotion path) lifts the implementation out of AI; until then it lives in the runtime. If `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/` does not yet exist, this packet creates it; if `DefaultCostLedger` was added in packet 04 as a stub, this packet replaces its body.

**`IBudgetConfigProvider` source.** ADR-0016 D5 commits operator-configurable rates "sourced from Azure App Configuration via Vault's `IConfigProvider`." The budget config (`business/context/cost-budgets.json` per ADR-0052 D2) is the source-of-truth; in production, the file's contents are mirrored to App Configuration (or the file is read directly from the repo by the deployable, depending on the deploy pattern). This packet implements `BudgetConfigProvider` to read either source:
- **Phase-1 source (this packet):** read `business/context/cost-budgets.json` from the application's working directory or a configured path. The file is committed in the Architecture repo (packet 02); deployables either bundle a copy at build time or mount the Architecture repo as a sidecar. Document the chosen pattern in the implementation.
- **Phase-2 source (future):** Vault `IConfigProvider` → App Configuration → JSON content. Refactor when the operator-configurable-rates pipeline (ADR-0016 D5) is built end-to-end.

The implementation is forward-compatible: `BudgetConfigProvider` consumes an injected source abstraction so the Phase-1 file source can be swapped for App Configuration later without touching call sites.

**Cosmos provisioning.** A new Cosmos database + container is provisioned per environment (dev, prod). This is a Human Prerequisite (portal click — see Memory note on portal-over-CLI preference). The container is sized per ADR-0052 D8's storage projection: ~2.6 GB at the upper bound (100K events/month × 13 months × 2KB), RU/s well under the 400 RU/s autoscale floor. Choose the **cheapest viable tier** (per the Memory `feedback_default_cheapest_azure_tier` note): Cosmos serverless is appropriate for dev (pay-per-request, no minimum); for prod, autoscale 400 RU/s is the floor. Show $ before clicking Create — at projected volume the prod tier is single-digit-dollars / month.

**Kill-switch enablement is NOT in this packet.** Packet 06 wires `ILlmDispatcher` to call `IsHardCapBreachedAsync` and throw `BudgetExceededException`. This packet ships the read with `IsHardCapBreachedAsync` returning a correct answer per the cache state, but no LLM call site checks it yet — until packet 06 lands, the kill-switch is inert. This is the deliberate ADR-0052 D14 Phase 1 posture: ship the ledger first, validate it under real load with **loose caps** (Phase 1 explicit: "initial caps are intentionally loose ($5000 / $10000 across all categories) so the kill-switch does not fire spuriously while baselines are being established"), only then turn enforcement on (Phase 4 — packet 06 in this initiative + a follow-up flip).

**Phase-1 loose caps.** This packet's runtime reads the D2 defaults from `cost-budgets.json` (committed in packet 02) — those are the **final-state** caps, not the Phase-1 loose caps. The Phase-1 loose-cap behaviour is delivered by **a config-time override**: a `BudgetConfigPhaseOneMultiplier` setting on `BudgetConfigProvider` (default 10x in dev; 1x in prod) multiplies the configured caps until the operator explicitly flips it off. The multiplier is documented in the implementation; the flip happens after Phase 3 (D14) and is named in the playbook (packet 09). Until the flip, dev environments effectively run at 10x the D2 caps — the kill-switch is non-spurious, and prod runs at the D2 caps from the start (prod is exposed to fewer test-only spikes, so Phase 1 caution there is less acute).

## Scope
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/` — replace the stub `DefaultCostLedger` with the v1 implementation:
  - `CostLedger` (or replace `DefaultCostLedger`'s body) — implements `ICostLedger`; Cosmos writes; in-memory cache for the hot-path read.
  - `BudgetConfigProvider` — implements `IBudgetConfigProvider`; reads `cost-budgets.json`; applies the Phase-1 multiplier.
  - `CostLedgerCacheRefreshService` — `IHostedService` that refreshes the in-memory cache every 30 seconds.
  - `CostLedgerCosmosOptions` — configuration record (Cosmos endpoint, key/Managed Identity, database name, container name).
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — register `CostLedger` for `ICostLedger`; register `BudgetConfigProvider` for `IBudgetConfigProvider`; register `CostLedgerCacheRefreshService` as a `HostedService`.
- Cosmos container provisioning Bicep / IaC where the AI Node keeps its infra-as-code, if such a folder exists. If the AI Node does not yet have an `infra/` directory, create one with a brief README and the Cosmos Bicep file; the actual Azure provisioning is a Human Prerequisite (portal click). Match the conventions of other Nodes that have shipped infra-as-code at edit time.
- Unit tests for `CostLedger` against a Cosmos test double or the InMemory pattern (ADR-0047 Tier-1: unit tests do not depend on external services per invariant 15).
- Integration tests against a real Cosmos emulator (Tier-2a per ADR-0047 D4) if the repo has the Testcontainers / Cosmos-emulator pattern wired; otherwise gate the integration test behind a `[Fact(Skip="...")]` and name the gate clearly.
- The AI solution version-bumped (the second packet on the AI solution in this initiative; appends to the in-progress version entry started by packet 04 — does NOT bump again, per invariant 27).
- Per-package CHANGELOG entries for the AI runtime; no entries on other packages.
- Repo-level `CHANGELOG.md`.

## Proposed Implementation
1. **`CostLedger` class** — implements the five `ICostLedger` members from `HoneyDrunk.Kernel.Abstractions`:
   - `RecordCostAsync(CostEvent evt, ct)` — write the event to Cosmos with partition key `$"{evt.Category}|{evt.Timestamp:yyyy-MM}"`. Atomically update the in-memory month-to-date counter for `evt.Category` (`Interlocked.Add` on a `Dictionary<CostCategory, long>` of cents, or the equivalent for `decimal`). `Local`-environment events are written to Cosmos for visibility (D12: "I burned $40 of AI inference yesterday debugging the dispatcher") but **do not update the cap-check cache** — they are exempt from caps.
   - `GetMonthToDateAsync(category, ct)` — return the cache value. Cache miss path: read Cosmos for the current month's events, sum, populate cache, return. Cache TTL is the 30-second refresh tick.
   - `IsHardCapBreachedAsync(category, ct)` — return `GetMonthToDateAsync(category) >= hardCap` for that category. Read the hard cap from `BudgetConfigProvider`. If the category has an active `BudgetOverride` (read via `GetActiveOverrideAsync`), return `false` until the override expires. Apply the dev overlay if the current environment is `Dev`. Apply the Phase-1 multiplier on `BudgetConfigProvider` for the effective cap.
   - `GetActiveOverrideAsync(category, ct)` — read the active `BudgetOverride` for the category from Cosmos (a separate small container, or a sentinel row in the same container with a known partition key — pick the cheaper option). Return `null` if no override is active or the active override has expired.
   - `QueryAsync(query, ct)` — issue a Cosmos query against the partition matching `query.Category` and `query.From..query.To`; yield results matching every non-null filter. Use `IAsyncEnumerable` (Cosmos supports streaming pagination).
2. **`BudgetConfigProvider` class** — implements `IBudgetConfigProvider.GetAsync`. Reads `business/context/cost-budgets.json` (or the App Configuration source in a future variant). Applies the Phase-1 multiplier (`CostLedgerCosmosOptions.PhaseOneMultiplier`, default 10x in `Dev`/`Staging`, 1x in `Prod`). Returns the resolved `BudgetConfig`. Cache the result for a configurable interval (e.g., 60 seconds) so config changes are picked up but the JSON file is not re-parsed on every cap check.
3. **`CostLedgerCacheRefreshService` class** — `IHostedService` (or `BackgroundService`) that loops every 30 seconds, calls into `CostLedger` to refresh its month-to-date cache from Cosmos. Use `TimeProvider` so tests do not require `Thread.Sleep` (invariant 51). On `StopAsync`, exit cleanly.
4. **`CostLedgerCosmosOptions`** — configuration record: `string Endpoint`, `string Database`, `string Container`, `string OverrideContainer` (or a single container with sentinel rows — decide at implementation time and document), `decimal? PhaseOneMultiplierDev`, `decimal? PhaseOneMultiplierStaging`, `decimal? PhaseOneMultiplierProd`. Authentication: Managed Identity preferred (consumes the `DefaultAzureCredential` chain); never store the Cosmos primary key in source. If a key is needed for `Local` development, source it from Vault (`IConfigProvider`) per the Grid pattern.
5. **DI registration.** In `ServiceCollectionExtensions`:
   ```csharp
   services.AddSingleton<ICostLedger, CostLedger>();
   services.AddSingleton<IBudgetConfigProvider, BudgetConfigProvider>();
   services.AddHostedService<CostLedgerCacheRefreshService>();
   services.AddOptions<CostLedgerCosmosOptions>().Bind(configuration.GetSection("CostLedger"));
   ```
   Keep the registration idempotent — packet 04 already registered `ICostLedger -> DefaultCostLedger`; this packet replaces it with `ICostLedger -> CostLedger`. The stub is removed (or kept as `DefaultCostLedger` with an `[Obsolete]` attribute and a follow-up to delete).
6. **Cosmos provisioning IaC.** A Bicep file (or the convention the AI Node uses for IaC at edit time) declaring the Cosmos account, database, and container. Tagging per the Memory `feedback_lean_azure_tags` note: `env` (always), `node=ai`. No `initiative` tag. Choose the cheapest viable tier (serverless for dev, autoscale 400 RU/s for prod) per the Memory cheapest-tier preference. Document the dollar projection in the Bicep header comment so the operator sees the cost before clicking Create.
7. **Unit tests.** Cover:
   - `CostLedger.RecordCostAsync` writes correctly partitioned events to a fake Cosmos client (use a test double).
   - `CostLedger.IsHardCapBreachedAsync` returns `true` when month-to-date exceeds the cap and `false` when within bounds.
   - `IsHardCapBreachedAsync` returns `false` while a `BudgetOverride` is active and unexpired, even when month-to-date exceeds the cap.
   - `IsHardCapBreachedAsync` returns the strict cap behaviour again after the override expires.
   - `Local`-environment events do not affect the cap-check cache.
   - The dev overlay applies in `Dev` and not in `Prod`.
   - Phase-1 multiplier inflates the effective cap as expected.
   No external services in unit tests (invariant 15); no `Thread.Sleep` (invariant 51) — use `TimeProvider` injection.
8. **Integration tests** (Tier-2a per ADR-0047 D4) — only if the AI Node already has the Testcontainers / Cosmos-emulator pattern wired. If not, name a `[Fact(Skip="Tier-2a: requires Cosmos emulator harness — gated on AI Node integration-test wiring.")]` with the exact Skip reason; the test code is still ready for activation. Verify the partition-key shape, the retention policy, and a full claim-record-query roundtrip.
9. **Solution-wide append-only version handling.** This packet is the second packet on the `HoneyDrunk.AI` solution in this initiative (packet 04 was the first). Per invariant 27, this packet appends to the in-progress version entry started by packet 04 — it does NOT bump again. The `[X.Y.Z]` CHANGELOG line is the same one packet 04 created; append the v1-implementation entries under it. Repo-level `CHANGELOG.md` is also appended (not a new top-level entry).
10. **Per-package CHANGELOG hygiene.** `HoneyDrunk.AI/CHANGELOG.md` gets an entry: "`DefaultCostLedger` Phase-1 stub replaced with the Cosmos-backed v1 implementation per ADR-0052 D7/D8. Hot-path cap-check read served from a 30-second-refresh in-memory cache. `BudgetConfigProvider` reads `business/context/cost-budgets.json`. Kill-switch enforcement is wired in packet 06 — until then, the cap check returns the correct answer but no call site consumes it." No CHANGELOG entries on other packages (alignment-only bumps).

## Affected Files
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostLedger.cs` (or replaces `DefaultCostLedger.cs`)
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/BudgetConfigProvider.cs` (new)
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostLedgerCacheRefreshService.cs` (new)
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostLedgerCosmosOptions.cs` (new)
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — DI registration update
- `HoneyDrunk.AI/infra/cost-ledger.bicep` (or the convention the AI Node uses for IaC; new file)
- Tests under the AI test project(s)
- `HoneyDrunk.AI/CHANGELOG.md`; repo-level `CHANGELOG.md`

## NuGet Dependencies
- **`HoneyDrunk.AI`** (runtime) — adds:
  - `Microsoft.Azure.Cosmos` (Cosmos .NET SDK) at the current stable major.
  - `Azure.Identity` (for `DefaultAzureCredential`) if not already referenced.
  - `Microsoft.Extensions.Hosting.Abstractions` for `IHostedService` if not already pulled in.
  - `Microsoft.Extensions.Options` for the options pattern.
  - All packages are subject to the Grid's pinning policy.
- **Test project** — adds whatever Cosmos test-double / fake-client pattern the repo uses (NSubstitute is the Grid mock library per ADR-0047 D1; build a test double manually rather than mocking Cosmos SDK types directly).
- Confirm at edit time that none of the above are forbidden by the AI Node's existing standards / boundaries.

## Boundary Check
- [x] All edits in `HoneyDrunk.AI`. ADR-0052 D7 explicitly places the v1 implementation here.
- [x] No new HoneyDrunk runtime dependency — the implementation consumes `HoneyDrunk.Kernel.Abstractions` (additive-abstraction reference allowed per invariant 4 DAG: AI depends on Kernel).
- [x] Cosmos persistence is the AI Node's first persistence dependency. Standup work must include the Cosmos provisioning step (Human Prerequisite below).
- [x] The dispatcher kill-switch wiring is **not** in this packet (packet 06).
- [x] No edit to the Architecture-repo catalog or budget config from this packet — they are committed in packets 01/02.

## Acceptance Criteria
- [ ] `CostLedger` implements the five Kernel `ICostLedger` members; the implementation file is at `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostLedger.cs` (or named consistently with the stub it replaces)
- [ ] `RecordCostAsync` writes to Cosmos with partition key `(category, year-month)`
- [ ] `IsHardCapBreachedAsync` is served from an in-memory cache (no Cosmos read on the hot path); cache refreshes on a 30-second tick via `CostLedgerCacheRefreshService`
- [ ] An active `BudgetOverride` causes `IsHardCapBreachedAsync` to return `false` for that category until the override expires
- [ ] `Local` events are written to Cosmos but do not affect the cap-check cache (D12)
- [ ] The dev overlay (D12) applies when `Environment == Dev`; production caps do not include dev burn
- [ ] The Phase-1 multiplier inflates the effective cap when configured (default 10x in dev/staging, 1x in prod); the multiplier is operator-configurable and named in the playbook as the Phase-3 flip target
- [ ] `BudgetConfigProvider` reads `business/context/cost-budgets.json` (or the configured source); the resolution is cached for a short interval (60 seconds default) so config changes are picked up without per-call file I/O
- [ ] Cosmos authentication uses Managed Identity (`DefaultAzureCredential`) in non-`Local` environments; no Cosmos primary key in source or app settings
- [ ] The Cosmos provisioning Bicep file exists under the AI Node's infra-as-code convention (or `infra/` if no convention exists yet); tagged `env`, `node=ai`; choosing the cheapest viable tier per the Grid Azure preference
- [ ] Unit tests cover record / hot-path-cache / override / dev overlay / Phase-1 multiplier / `Local`-exemption behaviour; no external services, no `Thread.Sleep`
- [ ] If an integration test is added, it is Tier-2a per ADR-0047 D4 and either runs against a Cosmos emulator harness or is `[Fact(Skip="...")]` with the gate documented
- [ ] The `HoneyDrunk.AI` solution version is the same as packet 04's bump (this packet appends; invariant 27 — no second bump)
- [ ] `HoneyDrunk.AI/CHANGELOG.md` has an appended entry under the in-progress version; no per-package CHANGELOG entries on other packages (alignment-only); repo-level `CHANGELOG.md` appended
- [ ] The solution builds; tests pass; the DI registration replaces the stub with `CostLedger` (the stub class may remain marked `[Obsolete]` for one release before deletion, or may be deleted in this PR — pick at edit time and document)

## Human Prerequisites
- [ ] **Wave-3 → Wave-4 human release tag on `HoneyDrunk.AI` for packet 04.** This packet appends to packet 04's in-progress version; verify the version is correctly in-progress (not released) before this packet builds. Agents merge code but never tag or publish.
- [ ] **Cosmos account provisioning per environment (dev, prod).** Portal click: create the Cosmos account, database, and container per the Bicep file. Choose the cheapest viable tier (serverless for dev, autoscale 400 RU/s for prod). Tag `env=dev|prod`, `node=ai`. Show $ before clicking Create — at projected volume (~2.6 GB across 13 months, well under 400 RU/s) the prod cost is single-digit-dollars / month. Cross-link to the cost-budgets.json file so the operator notes that this provisioning itself counts against the Azure infra category.
- [ ] **Cosmos endpoint configuration in App Configuration / Vault.** The endpoint URL and database/container names land in App Configuration so the AI deployable resolves them at startup via the Grid's `IConfigProvider` (ADR-0016 D5). No primary keys — Managed Identity is the auth path. Seed the App Configuration key `CostLedger:Endpoint`, `CostLedger:Database`, `CostLedger:Container` in each environment.
- [ ] **RBAC: grant the AI Container App's Managed Identity `Cosmos DB Built-in Data Contributor` on the cost-ledger database.** This is the data-plane RBAC role that lets Managed Identity write events without a primary key. Apply in each environment.
- [ ] **App Configuration values for the Phase-1 multiplier per environment.** `CostLedger:PhaseOneMultiplier:Dev` = 10 (or whatever the operator chooses); `CostLedger:PhaseOneMultiplier:Prod` = 1. Document the chosen values in the deployment notes for the Phase-3 flip (named in packet 09).

## Referenced ADR Decisions
**ADR-0052 D7 — V1 implementation in `HoneyDrunk.AI`.** Co-located with the dispatcher so the kill-switch read is in-process. Non-AI categories (Azure infra, SaaS, CI, domain) are externally sourced via an Operator aggregator (D14 Phase 2, future) writing the same `ICostLedger` shape. Promotion path: when non-AI categories grow material or a second writer Node appears, `HoneyDrunk.CostLedger` graduates to its own Node — the interface in Kernel is unchanged.

**ADR-0052 D8 — Persistence and retention.** Cosmos DB, single-region (write-mostly workload). Partition key `(category, year-month)`. Row key includes timestamp + optional tenant id + optional agent id. In-memory cache of current-month roll-up per category, refreshed every 30 seconds. Cosmos is the durable store; the cache is the latency-critical surface. Retention is rolling 13 months. Tier 2 per ADR-0036 (loss is recoverable from upstream APIs over 24–48 hours).

**ADR-0052 D5 / D6 — Attribution dimensions on writes.** Every event carries optional `TenantId`; AI inference events additionally carry `AgentId` / `AgentRunId`. The implementation must preserve these on the wire to Cosmos so `QueryAsync` can later filter by them. Backfilling unattributed historical events is impossible — the contract is "attribute at write time or never."

**ADR-0052 D11 — Override semantics.** Active overrides cause `IsHardCapBreachedAsync` to return `false` until expiry. Overrides are time-bounded (default 24h); permanent overrides do not exist. Override writes are NOT performed by this packet — the `hd cost unlock` CLI on Operator (future, gated on ADR-0018) is the only sanctioned override path (invariant 92). This packet only **reads** overrides via `GetActiveOverrideAsync`.

**ADR-0052 D12 — Test and dev environment treatment.** Dev caps on a separate subscription or tagged resource group. Production caps do not include dev burn. Every `CostEvent` carries `Environment`; `Local` events are recorded but exempt from caps.

**ADR-0052 D14 Phase 1 — Loose initial caps.** Initial caps are deliberately permissive while baselines are established. This packet ships the runtime with the operator-configurable Phase-1 multiplier (default 10x in dev/staging, 1x in prod). The flip to D2 final-state values happens after Phase 3; named in the playbook (packet 09).

**ADR-0016 D5 — Operator-configurable rates.** The budget config is sourced via Vault's `IConfigProvider`. The Phase-1 source in this packet is the JSON file directly; the Phase-2 source is App Configuration via Vault.

**ADR-0036 (tier-2 backup).** The ledger inherits the tier-2 RTO/RPO; loss is recoverable from upstream APIs over 24–48 hours by re-polling Azure Cost Management / vendor APIs / GitHub.

## Constraints
> **Invariant 1 — Abstractions zero-dependency.** `HoneyDrunk.AI.Abstractions` (which packet 04 already aligned) does NOT take a Cosmos SDK dependency. The Cosmos SDK lives only in the runtime package (`HoneyDrunk.AI`).

> **Invariant 4 — DAG.** `HoneyDrunk.AI` depends on `HoneyDrunk.Kernel`. Do not invert.

> **Invariant 8 — Secrets never in telemetry.** Cosmos primary keys never appear in logs, traces, or exceptions. Managed Identity is the auth path; if a key is unavoidable for `Local`, source it from Vault and never log it.

> **Invariant 12 / 27 — CHANGELOG hygiene + one-solution-one-version.** This packet appends to packet 04's in-progress version; no new bump. Only `HoneyDrunk.AI/CHANGELOG.md` gets an entry (the runtime has the real change); other packages get no entry on the alignment-only bump.

> **Invariant 15 — Unit tests no external services.** The Cosmos client is mocked / faked in unit tests.

> **Invariant 47 (referenced) — Audit substrate.** Override writes (which this packet does NOT perform) are audited via `IAuditLog`; the read path here just retrieves the current override state.

> **Invariant 51 — No `Thread.Sleep` in tests.** Use `TimeProvider` for the cache-refresh timing in tests.

> **Invariant 91 (this initiative, packet 00) — `ILlmDispatcher` checks the cap on the hot path.** This invariant is satisfied by **packet 06**, not this one. This packet ships the cap-check method; packet 06 wires the dispatcher to call it.

- **Phase-1 stub replacement, not a parallel implementation.** Replace `DefaultCostLedger`'s body; do not keep both. (Keeping the stub as `[Obsolete]` for one release is acceptable; a parallel implementation in scope is not.)
- **No kill-switch enforcement from this packet.** The cap-check answer is correct; no call site consumes it until packet 06. ADR-0052 D14 Phase 1's "Daily roll-up email enabled; threshold pings disabled until Phase 3" is partially honoured here (this packet does not wire the daily roll-up — that is also gated on the Operator standup); threshold pings are deferred (named in packet 09).
- **Cheapest viable Cosmos tier.** Serverless for dev; autoscale 400 RU/s for prod. The Memory note `feedback_default_cheapest_azure_tier` applies — Standard/Premium only with a concrete justification.
- **Managed Identity over key auth.** Use `DefaultAzureCredential` for Cosmos in every non-`Local` environment.

## Labels
`feature`, `tier-2`, `ai`, `ops`, `adr-0052`, `wave-4`

## Agent Handoff

**Objective:** Implement the v1 Cosmos-backed `ICostLedger` in `HoneyDrunk.AI`, replacing the Phase-1 stub. Hot-path `IsHardCapBreachedAsync` served from a 30-second-refresh in-memory cache; writes partitioned by `(category, year-month)`. The kill-switch is **not** wired to the dispatcher in this packet (packet 06).

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Ship the durable ledger that backs every cost-event write and serves the kill-switch read. The dispatcher integration is packet 06; the Operator-side aggregator / CLI / dashboard wait on ADR-0018.
- Feature: ADR-0052 Cost Governance rollout, Wave 4.
- ADRs: ADR-0052 D5/D6/D7/D8/D11/D12/D14 (primary), ADR-0016 D5 (operator-configurable rates source), ADR-0036 (tier-2 backup).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `business/context/cost-budgets.json` exists and is the canonical source.
- `packet:04` — `HoneyDrunk.AI.Abstractions` is reconciled against the Kernel contract; the stub `DefaultCostLedger` exists for this packet to replace.

**Constraints:**
- Replace the stub, do not run a parallel implementation.
- No kill-switch enforcement on call sites — packet 06.
- Cheapest viable Cosmos tier; Managed Identity, never primary keys.
- One-solution-one-version: append to packet 04's in-progress version, do not re-bump.
- Phase-1 multiplier is operator-configurable and named for the Phase-3 flip in the playbook.

**Key Files:**
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostLedger.cs`, `BudgetConfigProvider.cs`, `CostLedgerCacheRefreshService.cs`, `CostLedgerCosmosOptions.cs`
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`
- `HoneyDrunk.AI/infra/cost-ledger.bicep` (or the convention the AI Node uses for IaC)
- AI test project(s)
- `HoneyDrunk.AI/CHANGELOG.md`; repo-level `CHANGELOG.md`

**Contracts:** No new contracts. Consumes `ICostLedger`, `IBudgetConfigProvider`, `CostEvent`, `CostCategory`, `BudgetOverride`, `BudgetConfig`, `CostQuery`, `CostEnvironment` from `HoneyDrunk.Kernel.Abstractions`.
