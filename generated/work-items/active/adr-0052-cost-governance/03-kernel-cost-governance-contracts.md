---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "ops", "adr-0052", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0052", "ADR-0026", "ADR-0030"]
accepts: ["ADR-0052"]
wave: 2
initiative: adr-0052-cost-governance
node: honeydrunk-kernel
---

# Add the cost-governance contract surface to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0052 cost-governance contract surface to `HoneyDrunk.Kernel.Abstractions` per D7: the `ICostLedger` interface (five members — `RecordCostAsync`, `GetMonthToDateAsync`, `IsHardCapBreachedAsync`, `GetActiveOverrideAsync`, `QueryAsync`), the `CostEvent` record, the `CostCategory` discriminator, the `BudgetExceededException` exception type, the `BudgetOverride` record, the `IBudgetConfigProvider` interface, and the supporting records (`BudgetConfig`, `CostQuery`, `CostSource` discriminated union). All pure contracts — zero HoneyDrunk runtime dependencies. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution in this initiative.

## Context
ADR-0052 D7 commits the cost-governance contract to `HoneyDrunk.Kernel.Abstractions`, the zero-dependency contract layer every Node already consumes. The v1 implementation lives in `HoneyDrunk.AI` (packets 05/06), not Kernel, per the Kernel-thin-shell principle. The split keeps Kernel free of the Cosmos dependency the AI-side implementation requires; every consumer (AI, future Operator aggregator, future Billing Node) compiles against the Kernel contract.

**Relocation context — read first.** An `ICostLedger` interface already exists in `HoneyDrunk.AI.Abstractions/ICostLedger.cs` (two members: `RecordAsync(InferenceCost)`, `GetSummaryAsync(scope, since)`). It is the inference-only ledger surface from ADR-0016 D5. ADR-0052 D7 is **wider** — the new contract is category-scoped (the five D1 categories: AI inference, Azure infra, SaaS, domain/cert, GitHub Actions), the event shape is multi-source (`CostSource` discriminated union covering inference + Azure + SaaS + CI + domain), and the kill-switch read (`IsHardCapBreachedAsync`) is a first-class method, not a derived call. This packet ships the **new** contract in `HoneyDrunk.Kernel.Abstractions`; packet 04 reconciles the existing AI-side `ICostLedger` against the new Kernel contract (removes or wraps the AI-side version, points providers at Kernel). **Do not delete or rename anything in `HoneyDrunk.AI.Abstractions` from this packet** — packet 04 is the AI-side packet that handles the relocation, in its own repo, on its own commit.

**Repo state at edit time.** `HoneyDrunk.Kernel` is a live Node. Packets 02/04/07 of the `adr-0042-idempotency` initiative also target `HoneyDrunk.Kernel` and bump the solution `0.7.0` → `0.8.0` for the idempotency contract surface. **The order matters.** Check at edit time which initiative's Kernel packets have landed:
- If ADR-0042's Kernel packets are merged and `HoneyDrunk.Kernel` is at the released `0.8.0`, **this packet bumps the solution** to `0.9.0` (minor — additive new contract surface, no break).
- If an ADR-0042 Kernel version bump is still in-progress (unreleased), **this packet appends** to that in-progress version entry and does not bump again (invariant 27).
Record the case in the PR. The expected case is "ADR-0042's Kernel work is released" — ADR-0042 is sequenced before this initiative — but verify at execution time.

**Kernel package layout.** `HoneyDrunk.Kernel` has two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). **This packet only touches `HoneyDrunk.Kernel.Abstractions`** — no runtime code lands here. The v1 implementation lives in `HoneyDrunk.AI` (packets 05/06), not in `HoneyDrunk.Kernel` runtime. The runtime package is still version-bumped (alignment, invariant 27) if this packet is the bumping packet; per invariant 12/27 it gets no per-package CHANGELOG entry on an alignment-only bump.

> **Implementation-home note for the executor.** ADR-0052 D7 is explicit: the **interface** is in Kernel; the **v1 implementation** is in `HoneyDrunk.AI`. Do not implement `ICostLedger` in `HoneyDrunk.Kernel`. The runtime base classes for AI to consume the contract (e.g., a `BudgetExceededException` derivation, a small `CostEvent.Validate()` extension method) are acceptable in `HoneyDrunk.Kernel.Abstractions` only if they have zero HoneyDrunk runtime dependency (invariant 1) and zero Cosmos / Azure SDK reference; otherwise they belong in `HoneyDrunk.AI` with the implementation.

This packet adds only public abstraction types. No App Insights SDK, no Cosmos SDK, no Azure type — those are packet 05's concern.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract types:
  - `ICostLedger` (interface) — the five-member contract per ADR-0052 D7 preview.
  - `CostEvent` (record) — the canonical cost-event shape; carries `Category`, `Amount`, `Timestamp`, `Source`, optional `TenantId`/`AgentId`/`AgentRunId`, `Environment`, `CorrelationId`.
  - `CostCategory` (enum) — the five D1 categories.
  - `CostSource` (record / discriminated union) — `LlmInferenceSource`, `AzureInfraSource`, `SaasSource`, `CiSource`, `DomainSource`.
  - `BudgetExceededException` (sealed exception) — the kill-switch synchronous throw per D4.
  - `BudgetOverride` (record) — operator override per D11.
  - `IBudgetConfigProvider` (interface) — abstracts reading the budget config.
  - `BudgetConfig` (record) — the resolved per-category soft/hard caps and anomaly thresholds, plus the dev overlay (D12).
  - `CostQuery` (record) — the `QueryAsync` input shape.
  - `CostEnvironment` (enum) — `Prod`, `Dev`, `Staging`, `Local` (D12).
- Unit tests for the records (construction, equality, `BudgetExceededException` sealedness / non-transient contract).
- Both `.csproj` files in the solution version-bumped per the version-state check (Context above).
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` updated.

## Proposed Implementation
1. **`CostCategory`** — a plain `enum` with five values: `AiInference`, `AzureInfrastructure`, `ThirdPartySaas`, `DomainCertRegistrar`, `GitHubActionsMinutes`. Order is the D1 table order. XML-doc each value with the D1 scope description ("Container Apps, Application Insights, Vault, Cosmos, Storage, Front Door, Service Bus, Functions" for `AzureInfrastructure`, etc.).
2. **`CostEnvironment`** — a plain `enum`: `Prod`, `Dev`, `Staging`, `Local` (D12). Local events are recorded but exempt from caps; the kill-switch check ignores `Local` events per D12.
3. **`CostSource`** — per the Grid naming rule (records drop `I`), this is a `record` base or discriminated-union root. Two acceptable shapes (pick the one matching `HoneyDrunk.Kernel.Abstractions` existing convention):
   - A `record` base with derived records `LlmInferenceSource(string Provider, string ModelId, int InputTokens, int OutputTokens)`, `AzureInfraSource(string ResourceId, string MeterName, string SubscriptionId?)`, `SaasSource(string VendorId, string LineItem)`, `CiSource(string Workflow, string RunId)`, `DomainSource(string Domain, string Registrar)`.
   - A sealed discriminated-union via C# pattern matching — adjust to what `HoneyDrunk.Kernel.Abstractions` already does. Look at the existing `CostSource` / discriminated-union conventions in the abstractions surface; if none exist, pick the record-base shape (most consistent with the broader Kernel record style).
   The source is a structured payload carrying only the dimensions needed for forensics — no secrets, no PII (invariant 8 binds).
4. **`CostEvent`** — `record` (drops the `I`). Fields:
   - `CostCategory Category`
   - `decimal Amount` (USD; the currency lives in the config — the event records the value)
   - `DateTimeOffset Timestamp`
   - `CostSource Source`
   - `CostEnvironment Environment`
   - `string CorrelationId`
   - `TenantId? TenantId` (ADR-0026 primitive — reuse the existing Kernel `TenantId` type; if not yet defined as a Kernel primitive, fall back to `string?` and XML-doc it as "opaque tenant identifier per ADR-0026")
   - `string? AgentId` (D6 — reuse the ADR-0051 identifier shape if it exists in Kernel; otherwise `string?`)
   - `string? AgentRunId` (D6)
   Constructor validates non-zero `Amount` (allow zero for placeholder events but never negative); validates non-empty `CorrelationId`. XML-doc the `(TenantId, AgentId)` cross-product invariant from D6 ("a single event is attributed to exactly one tenant and exactly one agent run; sum across the cross-product equals the category total").
5. **`BudgetExceededException`** — `public sealed class BudgetExceededException : Exception`. Constructor takes `CostCategory category`, `decimal hardCap`, `decimal monthToDate`, `string correlationId`. Properties expose all four. Override `Message` to include the category, the cap, and the actual. XML-doc the **non-transient contract**: callers must NOT retry; catching this exception and retrying within the same billing window is a defect detected by the `review` agent. Decorate with `[Serializable]` if the existing Kernel exceptions follow that pattern (check at edit time).
6. **`BudgetOverride`** — `record`. Fields: `CostCategory Category`, `string OperatorPrincipalId` (reuse the Kernel `PrincipalId` if it exists; otherwise `string`), `string Reason`, `DateTimeOffset IssuedAt`, `DateTimeOffset ExpiresAt`, `DateTimeOffset? RevokedAt`. XML-doc: "An override is time-bounded; expiration is automatic; permanent overrides do not exist (ADR-0052 D11)."
7. **`BudgetConfig`** — `record`. Carries:
   - `IReadOnlyDictionary<CostCategory, BudgetCategoryConfig> Categories`
   - `IReadOnlyDictionary<CostCategory, BudgetCategoryConfig> DevOverlay`
   - `IReadOnlyDictionary<CostCategory, string> Owners`
   Plus a nested `BudgetCategoryConfig` record: `decimal? SoftCap`, `decimal? HardCap`, `string KillSwitch` (the kill-switch posture string — `"in_process"`, `"azure_suspend"`, `"github_native"`, `"none"` per D4), `decimal AnomalyHourOverHour`, `decimal AnomalyDayOverDay`. Nullable caps for the soft-only categories (SaaS, domain/cert).
8. **`IBudgetConfigProvider`** — interface. Single member: `ValueTask<BudgetConfig> GetAsync(CancellationToken cancellationToken)`. XML-doc: "Reads `business/context/cost-budgets.json` at startup and on configuration-change events; the implementation is expected to surface from Azure App Configuration via Vault's `IConfigProvider` per ADR-0016 D5, with the JSON file as the source-of-truth committed in the Architecture repo."
9. **`CostQuery`** — `record`. Fields: `CostCategory? Category`, `DateTimeOffset From`, `DateTimeOffset To`, `string? TenantId`, `string? AgentId`. Defaults: `null` for filters means "all," date range is required. XML-doc: "Inputs to `ICostLedger.QueryAsync`; returns events matching every non-null filter."
10. **`ICostLedger`** — interface with five members exactly per ADR-0052 D7 preview:
    ```
    ValueTask RecordCostAsync(CostEvent evt, CancellationToken ct);
    ValueTask<decimal> GetMonthToDateAsync(CostCategory category, CancellationToken ct);
    ValueTask<bool> IsHardCapBreachedAsync(CostCategory category, CancellationToken ct);
    ValueTask<BudgetOverride?> GetActiveOverrideAsync(CostCategory category, CancellationToken ct);
    IAsyncEnumerable<CostEvent> QueryAsync(CostQuery query, CancellationToken ct);
    ```
    XML-doc the **hot-path contract** on `IsHardCapBreachedAsync`: "Called on every `ILlmDispatcher` invocation; the implementation must serve this read from an in-memory cache (refresh every 30 seconds per D8), not from durable storage. Sub-microsecond expected latency at v1 LLM call volume." XML-doc the **non-cross-subsidy contract** on `GetMonthToDateAsync`: "Returns the month-to-date for the queried category only; categories do not cross-subsidize (ADR-0052 D1)."
11. All public types get full XML documentation (invariant 13).
12. **Version-state check.** Per invariant 27, check the `HoneyDrunk.Kernel` solution's in-progress version state at edit time. If ADR-0042's Kernel packets have all merged and the solution is at the released `0.8.0`, this packet bumps the solution `0.8.0` → `0.9.0` and adds new `[0.9.0]` entries to the repo-level `CHANGELOG.md` and `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`. If an ADR-0042 bump is still unreleased, append to that in-progress entry (no new bump). Record which case applied in the PR.
13. **CHANGELOG.** Repo-level `CHANGELOG.md` updated. Per-package `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` entry — this package has an actual change. `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry in this packet (alignment-only bump if this packet is the bumping packet — invariant 12/27). `HoneyDrunk.Kernel.Abstractions/README.md` updated to document the new cost-governance contracts in the public-API section.
14. **Unit tests.** Record-equality / construction tests; `BudgetExceededException` sealedness test (assert the type is `sealed`); a "no-retry contract" test that verifies the exception is not derived from any transient-error marker the Grid uses (e.g., not `IsTransient`). The `review` agent's catch-and-retry check is added in packet 08 (`.claude/agents/review.md` update) — this packet ensures the type-level signal exists so that agent's check can read it.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files (one per type per the repo's existing file-per-type convention).
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump (if this packet is the bumping packet).
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump (alignment, if this packet is the bumping packet).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`.
- Repo-level `CHANGELOG.md`.
- `HoneyDrunk.Kernel.Abstractions.Tests` (or the repo's equivalent unit-test project).

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions; the new contract uses only BCL types (`DateTimeOffset`, `IAsyncEnumerable`, `Exception`, `ValueTask`). `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`, invariant 26).
- **`HoneyDrunk.Kernel`** — no new `PackageReference` (the runtime package is alignment-bumped only; the v1 implementation lives in `HoneyDrunk.AI`, packet 05).
- The unit-test project follows the repo's existing test stack (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet per ADR-0047 D1); no new packages introduced by this packet beyond what the test project already references.

## Boundary Check
- [x] `ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery`, `CostSource`, `CostEnvironment` are Kernel contracts per ADR-0052 D7. Routing rule "context, ... contracts every Node consumes → HoneyDrunk.Kernel" and the ADR's explicit placement both map here.
- [x] No dependency on `HoneyDrunk.Transport`, `HoneyDrunk.Data`, `HoneyDrunk.AI`, or any other HoneyDrunk runtime package — the dependency graph is Kernel-at-the-root, never the reverse (invariant 4, DAG).
- [x] Contracts only; the v1 implementation (packet 05) and the dispatcher-side kill-switch wiring (packet 06) live in `HoneyDrunk.AI`.
- [x] The existing `HoneyDrunk.AI.Abstractions.ICostLedger` is NOT touched from this packet (the AI repo's reconciliation is packet 04).

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `ICostLedger` with exactly the five members `RecordCostAsync`, `GetMonthToDateAsync`, `IsHardCapBreachedAsync`, `GetActiveOverrideAsync`, `QueryAsync` (ADR-0052 D7 signatures)
- [ ] `IsHardCapBreachedAsync` XML-docs the hot-path contract (cache-served, 30-second refresh window, sub-microsecond latency expected)
- [ ] `GetMonthToDateAsync` XML-docs the no-cross-subsidy rule (D1)
- [ ] `CostEvent` is a record carrying `Category`, `Amount`, `Timestamp`, `Source`, `Environment`, `CorrelationId`, optional `TenantId` / `AgentId` / `AgentRunId`; validates non-negative `Amount` and non-empty `CorrelationId`
- [ ] `CostCategory` enum has exactly five values matching ADR-0052 D1: `AiInference`, `AzureInfrastructure`, `ThirdPartySaas`, `DomainCertRegistrar`, `GitHubActionsMinutes`
- [ ] `CostEnvironment` enum has `Prod` / `Dev` / `Staging` / `Local` (D12); XML-docs that `Local` events are exempt from caps
- [ ] `CostSource` is the multi-source discriminated shape (record base with derived sources, or the convention `HoneyDrunk.Kernel.Abstractions` already uses) — `LlmInferenceSource`, `AzureInfraSource`, `SaasSource`, `CiSource`, `DomainSource`
- [ ] `BudgetExceededException` is `public sealed class`, derives from `Exception`, carries `Category`/`HardCap`/`MonthToDate`/`CorrelationId`, XML-docs the non-transient / no-retry contract
- [ ] `BudgetOverride` is a record carrying `Category`, `OperatorPrincipalId`, `Reason`, `IssuedAt`, `ExpiresAt`, optional `RevokedAt`; XML-docs the time-bounded contract
- [ ] `IBudgetConfigProvider` is a single-member interface returning `ValueTask<BudgetConfig>`; XML-docs the Vault `IConfigProvider` source path
- [ ] `BudgetConfig` is a record carrying `Categories`, `DevOverlay`, `Owners` dictionaries keyed by `CostCategory`; nested `BudgetCategoryConfig` carries nullable `SoftCap`/`HardCap`, `KillSwitch` posture string, and anomaly thresholds
- [ ] `CostQuery` is a record with nullable filters and a required date range
- [ ] Records drop the `I` prefix; interfaces (`ICostLedger`, `IBudgetConfigProvider`) keep it (Grid naming rule)
- [ ] `HoneyDrunk.Kernel.Abstractions` takes no new HoneyDrunk runtime dependency and no Azure / Cosmos / App Insights SDK (invariant 1)
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] Unit tests cover record construction and equality, `BudgetExceededException` sealedness, and `CostEvent.Amount` non-negative validation; tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] The version-state check on the `HoneyDrunk.Kernel` solution was performed; either this packet bumps `0.8.0` → `0.9.0` or appends to an in-progress ADR-0042 entry; the decision is recorded (invariant 27)
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has an entry; `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry on alignment-only bump (invariant 12/27); repo-level `CHANGELOG.md` updated
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents the new cost-governance contracts in the public-API section
- [ ] The solution builds; the existing unit tests pass; the `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None. Abstraction code; no Azure resource, no portal step.

## Referenced ADR Decisions
**ADR-0052 D7 — Cost ledger implementation home.** Interface in `HoneyDrunk.Kernel.Abstractions`; v1 implementation in `HoneyDrunk.AI`. Kernel-thin-shell preserved (no Cosmos dependency in Kernel). Five-member preview shape: `RecordCostAsync(CostEvent)`, `GetMonthToDateAsync(category)`, `IsHardCapBreachedAsync(category)`, `GetActiveOverrideAsync(category)`, `QueryAsync(query)`. The write path is separated from the read path so the read can be served from cache while writes go through to durable storage. `IsHardCapBreachedAsync` is a first-class method (not synthesized from `GetMonthToDateAsync` + config lookup) so the implementation can collapse the read into a single cache hit.

**ADR-0052 D1 — Five cost categories.** AI inference, Azure infrastructure, third-party SaaS, domain/cert/registrar, GitHub Actions minutes. No cross-subsidy: hitting the AI inference hard cap does not free up budget for Azure infra. The total Grid budget is the sum, not a fungible pool.

**ADR-0052 D4 — Kill-switches per category.** AI inference is in-process: `ILlmDispatcher` checks `IsHardCapBreachedAsync` before each call; throws `BudgetExceededException` synchronously if breached. The exception carries category / cap / actual / correlation id. `BudgetExceededException` is **sealed** and **non-transient** — callers must not retry; the exception means "this category is closed for the rest of the billing window or until an operator override engages." A retry loop that swallows the exception and tries again is a defect.

**ADR-0052 D5 — Per-tenant attribution.** Every `CostEvent` carries an optional `TenantId` (ADR-0026's opaque primitive). Where the cost originates from a tenant-scoped operation, `TenantId` is set; where the cost is Grid-internal / Studio operations, `TenantId` is null and the cost rolls up as "platform overhead." Untagged events on commercial traffic are a defect detected by the daily roll-up's unattributed-cost check.

**ADR-0052 D6 — Per-agent attribution.** AI inference events additionally carry `AgentId` and `AgentRunId`. `AgentId` is the stable identifier from the agent definition (ADR-0051 registry); `AgentRunId` is the per-invocation correlation. The aggregation rule: a single event is attributed to exactly one tenant and exactly one agent run; sum across the (tenant, agent) cross-product equals the category total. Carrying both is cheap; carrying only one would force operators into multi-step queries.

**ADR-0052 D11 — Operator unlock policy.** Override is time-bounded (default 24h). Permanent overrides do not exist — re-engagement is the safer default. The override does not raise the cap retroactively. Audited via `IAuditLog` per ADR-0030, with `sensitive=audit` tagging.

**ADR-0052 D12 — Test and dev environment treatment.** Dev caps are separate and smaller. Production caps do not include dev burn. Every `CostEvent` carries an `Environment` field; `Local` events are recorded but exempt from caps.

**ADR-0026 — Tenant primitive.** `TenantId` is an opaque identifier; the cost ledger does not coin new tenant identifiers, it consumes the canonical one. Reuse the Kernel `TenantId` type if it exists; otherwise fall back to `string?` and XML-doc the ADR-0026 contract.

**ADR-0030 — Audit substrate.** Override events are audited via `IAuditLog` (invariant 47); the cost ledger itself is NOT the audit substrate (different retention shape, different append semantics — the cost ledger supports updates for retroactive reconciliation, Audit does not).

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `HoneyDrunk.Kernel.Abstractions` takes only `Microsoft.Extensions.*` abstractions. No App Insights SDK, no Cosmos SDK, no Azure type, no Sentry SDK in `ICostLedger` or its model types. The v1 implementation in `HoneyDrunk.AI` (packet 05) takes those dependencies.

> **Invariant 4 — the dependency graph is a DAG; Kernel is at the root.** Do not reference `HoneyDrunk.AI`, `HoneyDrunk.Transport`, `HoneyDrunk.Data`, or any other HoneyDrunk runtime package.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** `CostSource` carries only structured forensics data — provider id, model id, token counts, resource id, meter name. No prompt text, no completion text, no API key. The XML docs must state this on `CostSource`.

> **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment-only bump if this packet is the bumping packet) gets none.

> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.

> **Invariant 15 — Unit tests never depend on external services.** Record construction and exception sealedness tests run in-process.

> **Invariant 27 — All projects in a solution share one version and move together.** Perform the version-state check; either bump `0.8.0` → `0.9.0` across both `.csproj` files in one commit, or append to an in-progress ADR-0042 entry. Partial bumps are forbidden.

> **Invariant 51 — Tests do not use `Thread.Sleep` (ADR-0047 D6).** None of the tests in this packet need a clock; use `TimeProvider` injection if a future test needs one.

- **Grid naming rule.** Records drop the `I`: `CostEvent`, `CostSource`, `BudgetOverride`, `BudgetConfig`, `CostQuery`. Interfaces keep it: `ICostLedger`, `IBudgetConfigProvider`. Enums (`CostCategory`, `CostEnvironment`) follow the standard enum naming.
- **No invented members.** `ICostLedger` is the five-member D7 shape — do not add or rename.
- **Do not touch `HoneyDrunk.AI.Abstractions`.** The AI-side `ICostLedger` reconciliation is packet 04, in the AI repo. This packet only adds new types to Kernel.
- **`BudgetExceededException` is sealed and non-transient.** Document the no-retry contract explicitly.

## Labels
`feature`, `tier-2`, `core`, `ops`, `adr-0052`, `wave-2`

## Agent Handoff

**Objective:** Add the ADR-0052 D7 cost-governance contract surface to `HoneyDrunk.Kernel.Abstractions` — `ICostLedger`, `CostEvent`, `CostCategory`, `CostSource`, `CostEnvironment`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery` — and either bump the `HoneyDrunk.Kernel` solution `0.8.0` → `0.9.0` (if the ADR-0042 Kernel work is released) or append to that in-progress version.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the cost-governance contracts every other packet in this initiative compiles against, and that every downstream Node consuming the cost ledger will compile against.
- Feature: ADR-0052 Cost Governance rollout, Wave 2.
- ADRs: ADR-0052 D1/D4/D5/D6/D7/D11/D12 (primary), ADR-0026 (`TenantId`), ADR-0030 (override audit), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0052 Accepted and the three invariants live before the contracts are built against them.
- `work-item:01` — Catalog registration of the Kernel contract surface lands first so the catalog mirrors the code.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). No reference to `HoneyDrunk.AI`, `HoneyDrunk.Transport`, `HoneyDrunk.Data`.
- `ICostLedger` is the five-member D7 shape — no invented members.
- `BudgetExceededException` is `public sealed class`, non-transient, with XML docs stating the no-retry contract.
- Records drop the `I`; interfaces keep it.
- Do not touch `HoneyDrunk.AI.Abstractions` — packet 04 handles the AI-side relocation.
- Perform the invariant-27 version-state check; either bump `0.8.0` → `0.9.0` or append to an unreleased ADR-0042 entry; record the decision.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- Both `.csproj` files for the version bump.

**Contracts:**
- `ICostLedger` (new interface) — five-member D7 shape.
- `CostEvent`, `CostSource`, `BudgetOverride`, `BudgetConfig`, `CostQuery` (new records).
- `CostCategory`, `CostEnvironment` (new enums).
- `BudgetExceededException` (new sealed exception).
- `IBudgetConfigProvider` (new interface, single member).
