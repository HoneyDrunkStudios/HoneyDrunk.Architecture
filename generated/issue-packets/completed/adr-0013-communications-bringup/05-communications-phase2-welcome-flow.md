---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "workflow", "adr-0013", "adr-0026", "wave-4"]
dependencies: ["04-communications-phase1-contracts.md"]
adrs: ["ADR-0013", "ADR-0026"]
wave: 4
initiative: adr-0013-communications-bringup
node: honeydrunk-communications
---

# Feature: Phase 2 — welcome email flow with in-memory stores and Notify integration

## Summary
Land Phase 2 of the Communications standup: implement the first end-to-end flow — the welcome email sequence (`UserSignedUp` business event → welcome email → 2-day follow-up if user has not activated). Add the concrete `CommunicationOrchestrator` runtime (which reads `gridContext.TenantId` typed-non-nullable per ADR-0026 D2 and threads it into every store call), in-memory `IPreferenceStore` and `ICadencePolicy` implementations (both keyed by `(TenantId, ...)` per ADR-0026), an in-memory append-only decision log (`DecisionLogEntry` carries `TenantId` as a first-class field from day one), the `WelcomeEmailIntent` concrete `IMessageIntent`, NuGet integration with `HoneyDrunk.Notify.Abstractions` for delivery delegation, unit tests (including a cross-tenant isolation test and an Internal-short-circuit test), a Canary test that verifies the Notify integration boundary, and a runtime publish workflow. Both projects bump from `0.2.0` to `0.3.0`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications`

## Motivation
Phase 1 (packet 04) shipped the contract surface. Phase 2 is "the first useful increment" per ADR-0013 — proving the contracts compose into a working flow against Notify as the delivery backend.

The welcome flow is intentionally narrow:

1. Business event `UserSignedUp` (carrying user identity + email address) fires; the request entered the Grid with an `X-Tenant-Id` header (or no header for internal traffic, in which case `GridContextMiddleware` defaults `IGridContext.TenantId` to `TenantId.Internal` per ADR-0026 D2)
2. Caller invokes `ICommunicationOrchestrator.SendAsync(new WelcomeEmailIntent(user))`
3. Orchestrator reads `tenantId = gridContext.TenantId` (typed `TenantId`, non-nullable per ADR-0026 D2) and resolves recipient (pass-through — recipient is in the intent)
4. **Internal short-circuit (ADR-0026 D4 / D6 pattern):** if `tenantId.IsInternal`, the orchestrator skips preference + cadence checks entirely and proceeds to step 6. This matches the contract `IPreferenceStore` and `ICadencePolicy` documented in Phase 1.
5. Otherwise, orchestrator checks `IPreferenceStore.GetAsync(tenantId, recipient)` — if user opted out or has welcome-kind suppression, return `MessageDecision { Outcome = SuppressedByPreference }`. Then orchestrator checks `ICadencePolicy.CheckAsync(tenantId, recipient, intent)` — Phase 2 cadence is simple ("no more than one welcome per `(tenantId, recipient)` lifetime"), so the second call within the same tenant returns `MessageDecision { Outcome = SuppressedByCadence }`. The same recipient hitting the welcome flow under a *different* tenantId is treated as a distinct cadence subject and is allowed.
6. If allow: orchestrator calls `INotificationSender.SendAsync(...)` (Notify) with a notification payload describing the welcome email. Notify handles rendering, provider routing, retries. (Notify itself enforces tenant rate-limits and emits billing events at its own intake gateway per ADR-0026 D7 — not Communications' concern.)
7. Orchestrator records the decision in the in-memory decision log as a `DecisionLogEntry` carrying `tenantId` as a first-class field. Internal-tenant entries record with `TenantId.Internal` so the audit trail still reflects every decision.
8. Orchestrator schedules a 2-day follow-up via a simple in-memory timer / `IStartupHook`-registered background `Task.Delay`. The scheduled follow-up captures `tenantId` so when it fires, the correct tenancy is supplied to the orchestrator (the original `IGridContext` is gone by then). **For Phase 2, the schedule is in-process — restarts lose pending follow-ups.** This is explicit and acceptable because Phase 2 has no persistence layer (Phase 3 brings Data-backed persistence and durable scheduling).
9. Follow-up handler re-invokes the orchestrator with a `WelcomeFollowupIntent` (same recipient, different intent kind) under the captured `tenantId` — preferences and cadence are checked again per the same rules, decision is logged.

The Phase 2 flow is the proof that the boundary between Communications (orchestration) and Notify (delivery) is clean. The Canary test exercises that boundary with a stub `INotificationSender`, asserting:
- Communications never references Notify provider packages (`HoneyDrunk.Notify.Providers.Email.Smtp`, `.Resend`, `HoneyDrunk.Notify.Providers.Sms.Twilio`)
- Communications never references Notify runtime (`HoneyDrunk.Notify`)
- Communications calls `INotificationSender` from `HoneyDrunk.Notify.Abstractions` only

## Scope

### Concrete `IMessageIntent` implementations

- `WelcomeEmailIntent` — record implementing `IMessageIntent`. Fields: `RecipientHandle Recipient`, `string TriggerEventId`, `IReadOnlyDictionary<string, string> Payload` (carries `displayName` and `accountUrl` for the template). Constant `IntentKind = "welcome-email"`.
- `WelcomeFollowupIntent` — record implementing `IMessageIntent`. Fields same as above plus `string OriginalDecisionCorrelationKey` linking to the welcome's decision entry. Constant `IntentKind = "welcome-followup"`.

Both records live in the runtime project (not Abstractions) — they are implementations of an Abstractions interface, not contracts themselves. Per the Grid-wide naming rule, they are records and drop the `I` prefix.

### `CommunicationOrchestrator` runtime

`src/HoneyDrunk.Communications/Internal/CommunicationOrchestrator.cs` — concrete implementation of `ICommunicationOrchestrator`. Responsibilities:

- `EvaluateAsync(intent, ct)` — reads `tenantId = gridContextAccessor.Current.TenantId` (typed, non-nullable per ADR-0026 D2); short-circuits past preference + cadence if `tenantId.IsInternal`; otherwise runs preference + cadence checks against the tenant-scoped stores; returns `MessageDecision`
- `SendAsync(intent, ct)` — runs evaluate (which captures the tenancy decision), then if allowed, calls `INotificationSender.SendAsync(...)`, records the decision (stamped with `tenantId`) in the log
- Constructor injects `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`, `INotificationSender`, `IDecisionLog`, `IGridContextAccessor`, `ITelemetryActivityFactory`
- Reads `TenantId` from `IGridContext.TenantId` (typed) at the top of every public method — never accepts a `string` tenant identifier on the public surface, never uses AsyncLocal (ADR-0026 D3)
- Wraps each decision in a Kernel-traced activity (`communications.evaluate`, `communications.send`) so the decision flow is observable via Pulse-bound telemetry. The activity tags include `tenant_id` (the ULID string form of `tenantId`) so downstream Pulse aggregation can group decisions per tenant — even though Phase 2 does not yet ship Pulse integration explicitly, the Kernel telemetry pipeline carries the spans wherever Pulse picks them up. (Per the ADR-0026 follow-up "Pulse packet": `tenant_id` is a low-cardinality tag — Communications respects that discipline by emitting it from a single canonical source.)

### In-memory store implementations

- `src/HoneyDrunk.Communications/Internal/InMemoryPreferenceStore.cs` — `IPreferenceStore` backed by `ConcurrentDictionary<(TenantId TenantId, string Identity), RecipientPreferences>`. Key is the tuple `(TenantId, RecipientHandle.Identity)` — never `Identity` alone — so the same human user across two tenants has independent preference rows (ADR-0026 conformance). Default preferences (when key not present) = `new RecipientPreferences(OptedOut: false, SuppressedIntentKinds: ImmutableHashSet<string>.Empty, QuietHoursStart: null, QuietHoursEnd: null, PreferredChannel: null)`. **Internal short-circuit:** when `tenantId.IsInternal` is true, `GetAsync` returns the default opted-in snapshot without consulting the dictionary, and `SetAsync` is a no-op (Internal traffic does not maintain preference state — there is one and only one Internal tenant Grid-wide and there is no meaningful per-recipient preference state to track for it).
- `src/HoneyDrunk.Communications/Internal/InMemoryCadencePolicy.cs` — `ICadencePolicy` backed by `ConcurrentDictionary<(TenantId TenantId, string Identity, string IntentKind), DateTimeOffset>` (last sent timestamp per `(tenant, recipient, intent-kind)` triple). Phase 2 rule: welcome-email allowed once per `(tenant, recipient)` lifetime (no second welcome ever within the same tenant — explicit Suppress outcome). welcome-followup allowed once per `(tenant, recipient)` lifetime, scheduled at +2 days from welcome decision time. Cross-tenant traffic is independent — the same recipient hitting the welcome flow under two distinct tenant IDs gets two welcomes (one per tenant). Other intent kinds default to Allow (Phase 2 does not exhaustively define cadence rules — it ships the welcome-flow rules and lets others pass through). **Internal short-circuit:** when `tenantId.IsInternal` is true, `CheckAsync` returns `CadenceVerdict(CadenceOutcome.Allow, DeferUntil: null, Reason: "internal-tenant-bypass")` without consulting the dictionary.
- `src/HoneyDrunk.Communications/Internal/InMemoryDecisionLog.cs` — append-only `IDecisionLog` (new contract — see below) backed by `ConcurrentBag<DecisionLogEntry>`. Append-only enforced by interface design: `Append(entry)` returns `void`, no `Update` or `Delete` methods. The log records every decision — including Internal-tenant decisions — so the audit trail is complete. `DecisionLogEntry.TenantId` is always populated (Internal entries carry `TenantId.Internal`).

`IDecisionLog` is a new internal-runtime contract for Phase 2. It is **not** added to Abstractions yet because the audit-log surface needs more design thinking before public contracts are committed (e.g., should it be queryable? persistent in Phase 3?). Phase 3 will lift it to Abstractions if appropriate. The Phase 2 in-memory shape is enough to validate the boundary and to seed the tenant-aware persistent shape Phase 3 will produce. For now it lives as an `internal` interface in the runtime project, surfaced via DI only inside the runtime. Suggested member: `void Append(DecisionLogEntry entry)` where `DecisionLogEntry` is a record:

```csharp
internal sealed record DecisionLogEntry(
    Guid Id,
    DateTimeOffset Timestamp,
    TenantId TenantId,        // first-class — present from day one per ADR-0026
    string IntentKind,
    RecipientHandle Recipient,
    MessageDecision Decision,
    string CorrelationId);
```

`TenantId` on `DecisionLogEntry` is non-nullable — there is no decision the orchestrator records without a tenant axis. Internal traffic populates this field with `TenantId.Internal`. The "add TenantId later" anti-pattern is explicitly avoided: when Phase 3 lifts persistence, the schema column already exists in the in-memory shape and the migration to a persistent table is mechanical, not a forced retrofit.

### Follow-up scheduler

- `src/HoneyDrunk.Communications/Internal/InMemoryFollowupScheduler.cs` — accepts `(TenantId, RecipientHandle, WelcomeFollowupIntent, DateTimeOffset scheduledFor)` and uses a background `IHostedService` (from `Microsoft.Extensions.Hosting.Abstractions`) to fire the follow-up at the scheduled time. The scheduler **must capture the tenancy** at scheduling time — the originating `IGridContext` is gone by the time the follow-up fires, so the scheduler entry carries the `TenantId` explicitly and synthesizes a fresh `IGridContext` (or uses an `IGridContextFactory`) seeded with the captured tenancy when re-invoking the orchestrator. Implementation detail: a single `Task` that wakes periodically (e.g., every 30 seconds in dev; 5 minutes in prod via `CommunicationsOptions.FollowupSchedulerInterval`) and invokes `ICommunicationOrchestrator.SendAsync` for any due follow-ups under the captured tenancy. **Restarts lose pending follow-ups** — this is explicit Phase 2 behavior. The README and `CHANGELOG.md` 0.3.0 entry must call this out so consumers do not assume durability.

### `CommunicationsServiceCollectionExtensions.AddCommunications` updates

Phase 1's `AddCommunications` registered Kernel integration only. Phase 2 extends it:

- Now registers `CommunicationOrchestrator` as the singleton `ICommunicationOrchestrator`
- Registers `DefaultRecipientResolver` (pass-through; resolves recipient from intent) as singleton `IRecipientResolver`
- Registers `InMemoryPreferenceStore` as singleton `IPreferenceStore` — **but only if no other `IPreferenceStore` is already registered** (consumers can override; default should be in-memory only when Communications is the sole registrant)
- Registers `InMemoryCadencePolicy` as singleton `ICadencePolicy` — same override rule
- Registers `InMemoryDecisionLog` as singleton `IDecisionLog`
- Registers `InMemoryFollowupScheduler` as `IHostedService`
- Replaces the Phase 1 no-op `IStartupHook` placeholder with one that warms up the in-memory stores and validates that an `INotificationSender` is registered (fail-fast at startup if Notify is not wired)
- Replaces the Phase 1 Healthy-default `IHealthContributor` with one that reports Healthy if the follow-up scheduler is running and Degraded if it has fallen behind by more than 2× the scheduler interval

### Notify integration

- Add NuGet reference: `HoneyDrunk.Notify.Abstractions` (latest stable). Pin to whatever Notify is currently published at — check `catalogs/grid-health.json` `honeydrunk-notify.version` (currently `0.1.0` per the grid-health entry; verify at packet execution time as Notify may have moved).
- `CommunicationOrchestrator` injects and calls `INotificationSender.SendAsync(...)`. The exact `INotificationSender` shape lives in `HoneyDrunk.Notify.Abstractions`; verify the current method signature when authoring the call site (the `INotificationSender` contract may have evolved between Notify 0.1.0 and whatever ships at packet execution time).
- **Do NOT** add references to: `HoneyDrunk.Notify` (runtime), `HoneyDrunk.Notify.Providers.Email.Smtp`, `HoneyDrunk.Notify.Providers.Email.Resend`, `HoneyDrunk.Notify.Providers.Sms.Twilio`, `HoneyDrunk.Notify.Queue.AzureStorage`, `HoneyDrunk.Notify.Queue.InMemory`, or any other Notify package beyond Abstractions. The Canary test enforces this.

### Tests

#### `tests/HoneyDrunk.Communications.Tests/HoneyDrunk.Communications.Tests.csproj`
Unit-test project. Tests cover decision branches:
- `OrchestratorEvaluatesPreferenceOptOut_ReturnsSuppressedByPreference`
- `OrchestratorEvaluatesIntentKindSuppression_ReturnsSuppressedByPreference`
- `OrchestratorEvaluatesCadence_SecondWelcomeReturnsSuppressedByCadence`
- `OrchestratorSendsAllowedIntent_CallsNotificationSender`
- `OrchestratorSendsAllowedIntent_AppendsDecisionToLog_StampedWithTenantId`
- `OrchestratorSchedulesFollowup_AfterWelcomeSent_CapturesTenantId`
- `InMemoryPreferenceStore_DefaultsToOptedIn`
- `InMemoryCadencePolicy_AllowsFirstWelcome_DeniesSecond_WithinSameTenant`

Tenancy-specific tests (ADR-0026 conformance — REQUIRED, not optional):
- `Orchestrator_ReadsTenantIdFromGridContext_NeverFromString` — fixture verifies the orchestrator reads `gridContext.TenantId` (typed) and never accepts a string parameter
- `Orchestrator_WhenTenantIdIsInternal_SkipsPreferenceAndCadenceChecks_StillCallsNotify_StillLogsDecision` — internal short-circuit branch; verifies the decision log entry carries `TenantId.Internal`
- `InMemoryPreferenceStore_WhenTenantIdIsInternal_ReturnsDefaultOptedIn_WithoutTouchingDictionary` — short-circuit canary on the store
- `InMemoryCadencePolicy_WhenTenantIdIsInternal_ReturnsAllow_WithoutTouchingDictionary` — short-circuit canary on the policy
- `CrossTenantIsolation_SameRecipient_DifferentTenants_HaveIndependentPreferenceState` — sets `OptedOut: true` for `(TenantA, recipient)`; verifies `(TenantB, recipient)` still reads opted-in. Fail this test, fail the packet.
- `CrossTenantIsolation_SameRecipient_DifferentTenants_HaveIndependentCadenceState` — sends a welcome to `(TenantA, recipient)`; verifies a welcome to `(TenantB, recipient)` is still allowed (not suppressed by cadence).
- `DecisionLogEntry_TenantIdField_IsAlwaysPopulated` — exhaustive: every test that produces a decision log entry asserts `entry.TenantId` is populated (either with a real tenant ULID or with `TenantId.Internal`, never default/empty).
- `WelcomeFollowupIntent_RunsThroughOrchestrator_AfterScheduledTime_UnderCapturedTenancy` — verifies the follow-up is invoked under the same `TenantId` the original welcome ran under, even though the originating `IGridContext` is gone.

Use `xunit` (or whatever the Grid's test framework convention is — check Notify's test project for the canonical choice). Use `Moq` or `NSubstitute` for the `INotificationSender` stub (check Notify's tests for the canonical mocking library). For test `IGridContext` setup, mint test-only `TenantId` values via `TenantId.NewId()` (do **not** hard-code ULID strings; do not invent custom tenancy primitives).

#### `tests/HoneyDrunk.Communications.Canary/HoneyDrunk.Communications.Canary.csproj`
Canary project (per invariant 14 — every Node that depends on another has a `.Canary` project verifying integration assumptions). Tests:
- `Communications_References_Only_NotifyAbstractions_NotRuntime` — uses `Assembly.GetReferencedAssemblies()` to verify the runtime assembly references `HoneyDrunk.Notify.Abstractions` and does NOT reference `HoneyDrunk.Notify` (runtime), nor any `HoneyDrunk.Notify.Providers.*` package
- `INotificationSender_ContractShape_MatchesExpectedMethods` — reflective check that the `INotificationSender` interface from `HoneyDrunk.Notify.Abstractions` has the methods the orchestrator calls (catches breaking-change drift at the boundary)
- `AddCommunications_FailsFast_WhenNoNotificationSenderRegistered` — integration test exercising the startup-hook fail-fast
- `IGridContext_TenantId_IsTypedTenantId_NotString` — reflective canary that the `HoneyDrunk.Kernel.Abstractions.Context.IGridContext.TenantId` property type is `TenantId` (non-nullable) per ADR-0026 D2. Detects regression if a future Kernel pin reverts the property to `string?`.
- `TenantId_Internal_SentinelExists_AndIsConsistent` — canary that `TenantId.Internal` exists, `TenantId.Internal.IsInternal` is true, and a freshly-minted `TenantId.NewId().IsInternal` is false. Pins the ADR-0026 D1 contract from Communications' side.

### Publish workflow for runtime

Add `.github/workflows/release-runtime.yml` triggered on tag push `runtime-v*`. Mirror the `release-abstractions.yml` workflow added in Phase 1 but pack the runtime project. Publish to the same NuGet feed.

### Version bump

Per invariant 27, both projects move together. Bump `HoneyDrunk.Communications.Abstractions` and `HoneyDrunk.Communications` from `0.2.0` to `0.3.0`. Update:
- Repo-level `CHANGELOG.md` — new `0.3.0` entry describing the welcome flow
- Per-package runtime `CHANGELOG.md` — `0.3.0` entry detailing welcome flow, in-memory stores, follow-up scheduler, Notify integration, restart-loses-followups caveat
- Per-package Abstractions `CHANGELOG.md` — `0.3.0` entry. The Abstractions package itself has **no API changes in Phase 2**, so the entry reads: `### Changed - Version bump for solution alignment (no API surface changes; Phase 2 implementations live in HoneyDrunk.Communications runtime).` Per invariant 27, this is one of the rare cases where an alignment-bump entry is acceptable because the per-package CHANGELOG must explain the version jump for consumers, but the entry must explicitly say "no API surface changes." Per invariant 12 / 27, do not add invented changes here.
- Per-package runtime `README.md` — add a "Welcome Flow Quickstart" section showing the registration + invocation pattern
- Per-package Abstractions `README.md` — no edits needed (no API changes)

## NuGet Dependencies

### `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj`

| Package | Notes |
|---|---|
| (no changes from Phase 1) | API surface unchanged in Phase 2 — only the version bumps for invariant 27 alignment. |

### `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | Already present. |
| `<ProjectReference Include="..\HoneyDrunk.Communications.Abstractions\..." />` | Already present. |
| `HoneyDrunk.Kernel.Abstractions` | Already present from Phase 1. |
| `HoneyDrunk.Kernel` | Already present from Phase 1. |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | Already present from Phase 1. |
| `HoneyDrunk.Notify.Abstractions` | NEW. Pin to current published version (verify against `catalogs/grid-health.json` `honeydrunk-notify.version` at packet execution time). |
| `Microsoft.Extensions.Hosting.Abstractions` | NEW. Required for `IHostedService` (the follow-up scheduler). |

### `tests/HoneyDrunk.Communications.Tests/HoneyDrunk.Communications.Tests.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"`. |
| `<ProjectReference Include="..\..\src\HoneyDrunk.Communications\..." />` | Test target. |
| `Microsoft.NET.Test.Sdk` | Test SDK. |
| `xunit` (or canonical Grid test framework — check Notify's test project) | Test framework. |
| `xunit.runner.visualstudio` | Test runner. |
| `Moq` (or canonical Grid mocking library — check Notify's test project) | For mocking `INotificationSender`. |

### `tests/HoneyDrunk.Communications.Canary/HoneyDrunk.Communications.Canary.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"`. |
| `<ProjectReference Include="..\..\src\HoneyDrunk.Communications\..." />` | Canary target. |
| `HoneyDrunk.Notify.Abstractions` | Boundary-check tests reflect on this assembly. |
| `Microsoft.NET.Test.Sdk` | Test SDK. |
| `xunit` (or canonical) | Test framework. |
| `xunit.runner.visualstudio` | Test runner. |

## Affected Files

### Runtime (`src/HoneyDrunk.Communications/`)
- `Internal/CommunicationOrchestrator.cs` (new)
- `Internal/InMemoryPreferenceStore.cs` (new)
- `Internal/InMemoryCadencePolicy.cs` (new)
- `Internal/InMemoryDecisionLog.cs` (new)
- `Internal/IDecisionLog.cs` (new — internal contract; may be lifted to Abstractions in Phase 3)
- `Internal/DecisionLogEntry.cs` (new — record)
- `Internal/InMemoryFollowupScheduler.cs` (new — `IHostedService`)
- `Internal/DefaultRecipientResolver.cs` (new — pass-through resolver)
- `Internal/CommunicationsStartupHook.cs` (replace Phase 1 no-op with real warmup + `INotificationSender` validation)
- `Internal/CommunicationsHealthContributor.cs` (replace Phase 1 Healthy-default with scheduler-aware logic)
- `Intents/WelcomeEmailIntent.cs` (new — record)
- `Intents/WelcomeFollowupIntent.cs` (new — record)
- `CommunicationsOptions.cs` (extend with `FollowupSchedulerInterval` etc.)
- `CommunicationsServiceCollectionExtensions.cs` (extend `AddCommunications` per Scope above)
- `HoneyDrunk.Communications.csproj` (version bump 0.2.0 → 0.3.0; add Notify.Abstractions + Hosting.Abstractions refs)
- `README.md` (add Welcome Flow Quickstart section)
- `CHANGELOG.md` (append `0.3.0` entry)

### Abstractions (`src/HoneyDrunk.Communications.Abstractions/`)
- `HoneyDrunk.Communications.Abstractions.csproj` (version bump 0.2.0 → 0.3.0; no API changes)
- `CHANGELOG.md` (append `0.3.0` entry — alignment bump only, no API surface changes — explicit per invariant 12 / 27)

### Tests
- `tests/HoneyDrunk.Communications.Tests/HoneyDrunk.Communications.Tests.csproj` (new)
- `tests/HoneyDrunk.Communications.Tests/CommunicationOrchestratorTests.cs` (new — covers decision branches + Internal short-circuit + `ReadsTenantIdFromGridContext_NeverFromString`)
- `tests/HoneyDrunk.Communications.Tests/InMemoryPreferenceStoreTests.cs` (new — includes Internal short-circuit branch)
- `tests/HoneyDrunk.Communications.Tests/InMemoryCadencePolicyTests.cs` (new — includes Internal short-circuit branch)
- `tests/HoneyDrunk.Communications.Tests/CrossTenantIsolationTests.cs` (new — REQUIRED — same recipient under two tenants, independent preference + cadence state)
- `tests/HoneyDrunk.Communications.Tests/WelcomeFollowupSchedulerTests.cs` (new — includes captured-tenancy test)
- `tests/HoneyDrunk.Communications.Canary/HoneyDrunk.Communications.Canary.csproj` (new)
- `tests/HoneyDrunk.Communications.Canary/NotifyBoundaryTests.cs` (new — reflective boundary checks)
- `tests/HoneyDrunk.Communications.Canary/StartupValidationTests.cs` (new)
- `tests/HoneyDrunk.Communications.Canary/TenancyContractTests.cs` (new — pins ADR-0026 D1 / D2 contracts from Communications' side)

### Repo-level
- `HoneyDrunk.Communications.slnx` (add the two test projects)
- `CHANGELOG.md` (append `0.3.0` entry)
- `.github/workflows/release-runtime.yml` (new — tag-driven runtime publish)

## Boundary Check

- [x] All work in `HoneyDrunk.Communications` repo
- [x] Abstractions API surface unchanged (Phase 2 ships runtime only)
- [x] Runtime adds `HoneyDrunk.Notify.Abstractions` reference; does NOT add Notify runtime or any Notify provider package (invariant 2; verified by Canary test)
- [x] `IDecisionLog` is internal-only (not lifted to Abstractions yet) — no public-API surface change beyond what Phase 1 shipped
- [x] `DecisionLogEntry` carries `TenantId` from day one (ADR-0026 conformance — avoids the "add tenancy column later" anti-pattern)
- [x] All in-memory stores keyed by `(TenantId, ...)` — no global-by-recipient state
- [x] Tenancy primitives consumed only — Communications does NOT define a parallel `TenantId`, does NOT introduce string tenant identifiers, does NOT use AsyncLocal (ADR-0026 D1 / D3)
- [x] Test projects live in `tests/` — invariant 16 honored (no test code in runtime packages)
- [x] No Azure resources, no per-Node Key Vault, no production deployment plumbing — that's Phase 3
- [x] Naming rule applied: `WelcomeEmailIntent`, `WelcomeFollowupIntent`, `DecisionLogEntry`, `DefaultRecipientResolver`, `InMemoryPreferenceStore`, `InMemoryCadencePolicy`, `InMemoryDecisionLog`, `InMemoryFollowupScheduler` are all records / classes (no `I` prefix); `IDecisionLog` is an interface (keeps `I`); `TenantId` is a record struct that drops `I` per the same rule (consumed from Kernel.Abstractions)

## Acceptance Criteria

### Welcome flow
- [ ] `WelcomeEmailIntent` record implementing `IMessageIntent` with `IntentKind = "welcome-email"` defined
- [ ] `WelcomeFollowupIntent` record implementing `IMessageIntent` with `IntentKind = "welcome-followup"` and `OriginalDecisionCorrelationKey` field defined
- [ ] `CommunicationOrchestrator` runtime implementing `ICommunicationOrchestrator` defined
- [ ] Orchestrator reads `tenantId` from `gridContextAccessor.Current.TenantId` (typed `TenantId`, non-nullable per ADR-0026 D2) at the top of every public method — never accepts a string tenant identifier
- [ ] When `tenantId.IsInternal` is true, orchestrator skips preference and cadence checks but still calls Notify and still records a decision log entry stamped with `TenantId.Internal` (Internal short-circuit per ADR-0026 D4 / D6 pattern; verified by unit test)
- [ ] `EvaluateAsync` runs preference + cadence checks (when not Internal), returns `MessageDecision` without calling Notify
- [ ] `SendAsync` runs evaluate, then if allowed calls `INotificationSender.SendAsync(...)` and appends decision (with `tenantId`) to log
- [ ] When recipient has `OptedOut = true` for the current tenant, `SendAsync` returns `MessageDecision { Outcome = SuppressedByPreference }` and does NOT call Notify (verified by unit test)
- [ ] When recipient has `welcome-email` in `SuppressedIntentKinds` for the current tenant, `SendAsync` returns `MessageDecision { Outcome = SuppressedByPreference }` and does NOT call Notify
- [ ] Second welcome email to same `(tenantId, recipient)` pair returns `MessageDecision { Outcome = SuppressedByCadence }` (Phase 2 cadence rule: welcome once per `(tenant, recipient)` lifetime)
- [ ] Welcome email to the same `recipient` under a *different* `tenantId` is allowed (cross-tenant isolation; verified by `CrossTenantIsolation_*` tests)
- [ ] After successful welcome, follow-up is scheduled +2 days out (configurable via `CommunicationsOptions`); the scheduler captures `tenantId` so the follow-up fires under the correct tenancy
- [ ] Follow-up runs through orchestrator with `WelcomeFollowupIntent` under the captured `tenantId` — preferences and cadence checked again per the same tenant-scoped rules

### In-memory stores
- [ ] `InMemoryPreferenceStore` keyed by `(TenantId, RecipientHandle.Identity)` — never by `Identity` alone
- [ ] `InMemoryPreferenceStore` defaults all `(tenant, recipient)` pairs to opted-in with no suppressions
- [ ] `InMemoryPreferenceStore` short-circuits on `tenantId.IsInternal` — `GetAsync` returns default opted-in without consulting the dictionary; `SetAsync` is a no-op
- [ ] `InMemoryCadencePolicy` keyed by `(TenantId, RecipientHandle.Identity, IntentKind)` — never by `(Identity, IntentKind)` alone
- [ ] `InMemoryCadencePolicy` enforces "welcome-email once per `(tenant, recipient)` lifetime" + "welcome-followup once per `(tenant, recipient)` lifetime" rules
- [ ] `InMemoryCadencePolicy` short-circuits on `tenantId.IsInternal` — returns `Allow` without consulting the dictionary
- [ ] `InMemoryDecisionLog` is append-only (interface design enforces — no `Update` or `Delete` methods)
- [ ] `DecisionLogEntry` carries `TenantId` as a non-nullable first-class field; every entry the log records has it populated (real tenant ULID or `TenantId.Internal`)
- [ ] `InMemoryFollowupScheduler` registered as `IHostedService` and runs in-process
- [ ] Scheduler captures `TenantId` at scheduling time and supplies it when re-invoking the orchestrator
- [ ] README and `CHANGELOG.md 0.3.0` entry explicitly call out "restarts lose pending follow-ups" — Phase 2 behavior

### Notify integration
- [ ] Runtime `.csproj` references `HoneyDrunk.Notify.Abstractions` (pin verified against current published version)
- [ ] Runtime `.csproj` does NOT reference `HoneyDrunk.Notify` (runtime), nor any `HoneyDrunk.Notify.Providers.*` package, nor any `HoneyDrunk.Notify.Queue.*` package
- [ ] Canary test `Communications_References_Only_NotifyAbstractions_NotRuntime` passes
- [ ] Orchestrator's call to `INotificationSender.SendAsync(...)` matches the current Notify.Abstractions contract shape

### DI extension
- [ ] `AddCommunications` registers `ICommunicationOrchestrator`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`, `IDecisionLog`, follow-up scheduler `IHostedService`
- [ ] In-memory store registrations honor `TryAdd*` semantics (consumer-provided implementations take precedence) — verified by integration test
- [ ] `CommunicationsStartupHook` validates `INotificationSender` is registered and fails fast if not
- [ ] `CommunicationsHealthContributor` reports Healthy when scheduler is running, Degraded when scheduler has fallen behind by more than 2× the configured interval

### Tests
- [ ] `HoneyDrunk.Communications.Tests` project created with the listed test cases (including ALL listed tenancy-specific tests — they are required, not optional)
- [ ] `CrossTenantIsolation_SameRecipient_DifferentTenants_HaveIndependentPreferenceState` test present and passing
- [ ] `CrossTenantIsolation_SameRecipient_DifferentTenants_HaveIndependentCadenceState` test present and passing
- [ ] `Orchestrator_WhenTenantIdIsInternal_SkipsPreferenceAndCadenceChecks_StillCallsNotify_StillLogsDecision` test present and passing
- [ ] `InMemoryPreferenceStore_WhenTenantIdIsInternal_ReturnsDefaultOptedIn_WithoutTouchingDictionary` test present and passing
- [ ] `InMemoryCadencePolicy_WhenTenantIdIsInternal_ReturnsAllow_WithoutTouchingDictionary` test present and passing
- [ ] `DecisionLogEntry_TenantIdField_IsAlwaysPopulated` assertion present in every test that produces a decision log entry
- [ ] All unit tests pass on tier-1 gate
- [ ] `HoneyDrunk.Communications.Canary` project created with the listed boundary tests (invariant 14)
- [ ] Canary tests `IGridContext_TenantId_IsTypedTenantId_NotString` and `TenantId_Internal_SentinelExists_AndIsConsistent` present and passing — these pin ADR-0026 D1 / D2 contracts from Communications' side
- [ ] All canary tests pass

### Publish workflow
- [ ] `.github/workflows/release-runtime.yml` present, tag-triggered on `runtime-v*`
- [ ] Workflow does NOT push tags (agents never push tags per invariant 27)
- [ ] (Verification of first publish run can be deferred to a manual post-merge tag push, like the Abstractions workflow in packet 04)

### Versioning
- [ ] `HoneyDrunk.Communications.Abstractions.csproj` bumped 0.2.0 → 0.3.0 (alignment bump only — no API changes)
- [ ] `HoneyDrunk.Communications.csproj` bumped 0.2.0 → 0.3.0
- [ ] Repo-level `CHANGELOG.md` has new `0.3.0` entry covering the welcome flow
- [ ] Per-package runtime `CHANGELOG.md` has `0.3.0` entry with "restarts lose pending follow-ups" caveat
- [ ] Per-package Abstractions `CHANGELOG.md` has `0.3.0` entry that reads `### Changed - Version bump for solution alignment (no API surface changes; Phase 2 implementations live in HoneyDrunk.Communications runtime).` (per invariant 27 — alignment-bump entries are permitted only when explicitly stating no API changes)
- [ ] Per-package runtime `README.md` has a "Welcome Flow Quickstart" section
- [ ] Per-package Abstractions `README.md` unchanged (no API changes)

### General
- [ ] PR traverses tier-1 gate
- [ ] PR body links back to this packet (invariant 32)
- [ ] No ADR IDs in `README.md` narrative body (per user preference)
- [ ] Naming rule applied throughout: interfaces keep `I`, records and concrete classes drop `I`

## Human Prerequisites

- [ ] Notify must have published `HoneyDrunk.Notify.Abstractions` to a NuGet feed reachable by Communications' CI. Notify's grid-health entry shows version `0.1.0` and signal `Live` — confirm the package is on the feed Communications will resolve from. If Notify's Abstractions has not been published (Notify is "live-undeployed" per `catalogs/contracts.json` — runtime not yet on Container Apps but contracts package may still be on NuGet), verify this before starting and stop if the package is unavailable.
- [ ] After PR merges, push the `runtime-v0.3.0` tag manually to trigger the first runtime publish (agents never push tags per invariant 27). Push `abstractions-v0.3.0` tag too — both projects move together per invariant 27, so both get published at the new version.

## Dependencies

- `04-communications-phase1-contracts.md` — five contracts and Kernel integration must be in place before the welcome flow can implement against them

## Downstream Unblocks

- Phase 3 (separate initiative `adr-0013-communications-phase3`, not yet scoped) — persistent stores via Data, Container Apps deployment, Pulse telemetry. The in-memory implementations shipped here are the reference model for the persistent-store implementations Phase 3 will produce.

## Referenced ADR Decisions

**ADR-0013 (Communications Orchestration Layer — HoneyDrunk.Communications):**
- **§Phase Plan / Phase 2:** "Implement welcome email flow: UserSignedUp → welcome email → 2-day follow-up if not activated. In-memory preference store and cadence policy for initial development. Integration with Notify's `INotificationSender`." Exactly the scope of this packet.
- **§Interaction Example:** The eight-step welcome flow described in the ADR is the canonical happy-path acceptance scenario. The unit and Canary tests in this packet exercise each step (now extended to nine steps with the explicit Internal short-circuit branch per ADR-0026).
- **§Communications owns / does NOT own:** Decision audit log is owned by Communications. Template rendering, provider adapters, retries are owned by Notify and stay there. Orchestrator calls `INotificationSender` and lets Notify do everything below the `INotificationSender` contract surface.
- **§Boundary rule:** "If the concern is delivery mechanics, it belongs in Notify. If the concern is message logic or workflow, it belongs in Communications." The Canary test enforces this at the assembly-reference level.

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **§D1:** `TenantId.Internal` static sentinel and `IsInternal` predicate exist on `HoneyDrunk.Kernel.Abstractions.Identity.TenantId`. Phase 2's orchestrator and in-memory stores consume both.
- **§D2:** `IGridContext.TenantId` is non-nullable `TenantId` — orchestrator reads it directly without null-handling.
- **§D3:** Tenancy flows via `IGridContext`, not AsyncLocal. The orchestrator and follow-up scheduler honor this — the scheduler captures `TenantId` at scheduling time and synthesizes the context at firing time, never via AsyncLocal.
- **§D4 / D6 short-circuit pattern:** The Internal short-circuit Communications applies to `IPreferenceStore.GetAsync`, `ICadencePolicy.CheckAsync`, and the orchestrator's evaluation path mirrors the pattern ADR-0026 D4 / D6 require of `ITenantRateLimitPolicy` and `IBillingEventEmitter`. Communications does NOT consume `ITenantRateLimitPolicy` or `IBillingEventEmitter` — those are Notify's intake-gateway concerns per ADR-0026 D7.
- **§D7 boundary invariant:** Tenant resolution and enforcement live in gateway-layer middleware, never in core dispatch. Communications operates **above** Notify; the `CommunicationOrchestrator.SendAsync` evaluation is Communications' analog of "intake" (it is where the decision to admit a message into the dispatch path is made). It is the appropriate location for tenant-aware preference + cadence enforcement. The orchestrator does NOT enforce rate-limits or emit billing events — those are Notify's intake concerns and remain in Notify.
- **§Cross-cutting requirement:** `DecisionLogEntry.TenantId` is first-class from day one to avoid the "add a column later" migration on a nascent table.

## Referenced Invariants

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. Communications (runtime) consumes `HoneyDrunk.Notify.Abstractions` only. The Canary test `Communications_References_Only_NotifyAbstractions_NotRuntime` enforces this at build time.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Per-package CHANGELOG.md updated only for packages with actual changes — but Phase 2's Abstractions package gets a CHANGELOG entry that explicitly states "Version bump for solution alignment (no API surface changes)" because invariant 27 requires both projects to bump together and consumers need to know why the Abstractions version moved.

> **Invariant 13:** All public APIs have XML documentation. Every new public type added in this packet (intents, helper records if any) gets full XML docs.

> **Invariant 14:** Canary tests validate cross-Node boundaries. Each Node that depends on another has a `.Canary` project verifying integration assumptions. `HoneyDrunk.Communications.Canary` is created in this packet to verify the Notify boundary.

> **Invariant 15:** Tests never depend on external services. Use InMemory providers for isolation. The unit tests use stub `INotificationSender` (Moq/NSubstitute); the in-memory stores are themselves test-friendly.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only. Both new test projects live in `tests/`.

> **Invariant 26:** Issue packets for .NET code work must include an explicit NuGet Dependencies section. The Notify.Abstractions and Hosting.Abstractions additions are listed above.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. Both projects bump 0.2.0 → 0.3.0 here. Repo-level CHANGELOG.md gets the new version entry. Per-package changelogs are updated only for packages with actual changes — Abstractions gets an alignment-bump entry that explicitly says "no API surface changes" because consumers need to know why the version moved.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Constraints

- **In-memory only.** No Data Node references, no SQL Server, no SQLite, no persistent storage. Phase 3 brings persistence. README + CHANGELOG must call out "restarts lose pending follow-ups" so consumers do not assume Phase 2 is production-durable.
- **Notify.Abstractions only.** Adding any other Notify package (runtime, providers, queues) breaks invariant 2 and the Canary test. The review agent will catch this; the Canary test catches it at build time.
- **No Pulse package reference.** Telemetry flows via Kernel's `ITelemetryActivityFactory` (already pulled in by Phase 1 Kernel integration). Direct Pulse package references are Phase 3 — and even then only if Pulse exposes a contracts package; currently telemetry flows via OpenTelemetry collectors that Pulse aggregates downstream.
- **Tenancy from `IGridContext` only.** Orchestrator and scheduler read `TenantId` from `IGridContext.TenantId` (typed, non-nullable per ADR-0026 D2). No string-shaped tenancy on any public or internal API surface introduced in this packet. No AsyncLocal (ADR-0026 D3). The follow-up scheduler captures `TenantId` at scheduling time and supplies it when the follow-up fires — never via AsyncLocal, never via a static accessor.
- **All in-memory stores keyed by `(TenantId, ...)`.** `InMemoryPreferenceStore`, `InMemoryCadencePolicy`, `DecisionLogEntry` all carry `TenantId` as part of their state key / first-class field. The "add tenancy later" anti-pattern is forbidden — even though Phase 2 has no production caller and a retrofit would technically work, the cost of designing it in now is one tuple element vs. an entire migration when Phase 3 lifts persistence.
- **Internal short-circuit is required, not optional.** `IPreferenceStore.GetAsync`, `ICadencePolicy.CheckAsync`, and the orchestrator's evaluation path all short-circuit on `tenantId.IsInternal` per the contract Phase 1 documented and ADR-0026 D4 / D6 require. Tests covering each short-circuit branch are required, not optional.
- **Decision log records every decision, including Internal.** The Internal short-circuit skips preference + cadence; it does NOT skip the decision log entry. The audit trail must be complete — every send-or-suppress decision the orchestrator makes is logged with the tenant axis populated (real ULID or `TenantId.Internal`).
- **`IDecisionLog` stays internal.** Do not lift it to `HoneyDrunk.Communications.Abstractions` in this packet. The audit-log surface needs more design before public commitment. Phase 3 may promote it. (If lifted, `DecisionLogEntry.TenantId` will already be in the right shape — that is the design intent of including it now.)
- **Cadence rules are minimal.** Phase 2 implements only the welcome-email and welcome-followup cadence rules, both scoped per `(tenantId, recipient)`. Other intent kinds default to Allow. Resist adding speculative cadence rules — they have no caller yet and would be dead code.
- **Schedule interval defaults documented.** `CommunicationsOptions.FollowupSchedulerInterval` defaults to 30 seconds in dev, 5 minutes in prod (or whatever the env-aware default ends up being — document the actual value chosen). The "+2 days for welcome follow-up" is a separate constant in `CommunicationsOptions.WelcomeFollowupDelay` defaulting to `TimeSpan.FromDays(2)`. Both override-able via `Action<CommunicationsOptions>`.
- **Naming rule discipline (Grid-wide).** New interfaces (`IDecisionLog`) keep `I`. New records (`WelcomeEmailIntent`, `WelcomeFollowupIntent`, `DecisionLogEntry`) drop `I`. New classes (`CommunicationOrchestrator`, `DefaultRecipientResolver`, `InMemoryPreferenceStore`, `InMemoryCadencePolicy`, `InMemoryDecisionLog`, `InMemoryFollowupScheduler`, `CommunicationsStartupHook`, `CommunicationsHealthContributor`) drop `I`. `TenantId` (consumed from Kernel.Abstractions) is a record struct that drops `I`.
- **Verify Notify pin at execution time.** The Notify version on NuGet may have moved between this packet's authoring (2026-05-02) and execution. Check `catalogs/grid-health.json` `honeydrunk-notify.version` for the current pin — and check the public NuGet feed to confirm `HoneyDrunk.Notify.Abstractions` at that version exists.
- **Verify `INotificationSender` shape at execution time.** The contract may have evolved between Notify 0.1.0 and execution time. The orchestrator's call site must match the current shape — read `HoneyDrunk.Notify.Abstractions` source or the NuGet package metadata before authoring `CommunicationOrchestrator.SendAsync`.
- **Verify Kernel pin includes ADR-0026 D2 promotion at execution time.** `IGridContext.TenantId` must be non-nullable `TenantId`. If the available Kernel pin still exposes `string?`, this packet is blocked on ADR-0026's Kernel half — surface the gap and stop. The Phase 1 packet (04) is the gating consumer; if it landed against an older Kernel pin that did not yet have the promotion, Phase 2 must wait until both are aligned.
- **No ADR IDs in narrative body of `README.md` files** (per user preference). ADR IDs allowed in `CHANGELOG.md` entries (metadata) and in XML docs that cross-reference the cross-cutting tenancy contract — those are load-bearing for downstream implementers.

## Labels
`feature`, `tier-2`, `ops`, `workflow`, `adr-0013`, `adr-0026`, `wave-4`

## Agent Handoff

**Objective:** Ship the first end-to-end communication flow — welcome email + 2-day follow-up — using Phase 1's tenant-aware contracts, in-memory store implementations keyed by `(TenantId, ...)`, and `INotificationSender` (from Notify) for delivery delegation. Implement the Internal short-circuit branch in the orchestrator and stores. Add a cross-tenant isolation test, an Internal short-circuit test, and Canary tests pinning the ADR-0026 D1 / D2 contracts. Add a runtime publish workflow and bump both projects to `0.3.0`.

**Target:** HoneyDrunk.Communications, branch from `main`

**Context:**
- Goal: Prove the Communications ↔ Notify boundary works end-to-end with a real flow, and prove the tenant-aware design is correct (cross-tenant isolation + Internal short-circuit) from day one
- Feature: ADR-0013 Phase 2 — welcome email flow with in-memory stores, ADR-0026 conformance applied to all stores and the orchestrator
- ADRs: ADR-0013 (primary), ADR-0026 (cross-cutting tenancy applied to in-memory stores, decision log entry, orchestrator behavior, and tests)

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `04-communications-phase1-contracts.md` merged (tenant-aware contracts and Kernel wiring exist)
- ADR-0026 Kernel half shipped with Communications using a Kernel pin that includes the D2 promotion of `IGridContext.TenantId`. If the Kernel pin available at execution time still exposes `string?`, packet is blocked.

**Constraints:**

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. Communications consumes `HoneyDrunk.Notify.Abstractions` only.

> **Invariant 12:** Semantic versioning with CHANGELOG and README.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 14:** Canary tests validate cross-Node boundaries. The new `.Canary` project is required.

> **Invariant 15:** Tests never depend on external services. Use stub `INotificationSender` and the in-memory stores.

> **Invariant 16:** No test code in runtime packages. Tests live in `tests/`.

> **Invariant 26:** NuGet Dependencies section required; Notify.Abstractions + Hosting.Abstractions additions documented above.

> **Invariant 27:** All projects in a solution share one version and move together. Both bump 0.2.0 → 0.3.0. Abstractions gets an alignment-bump CHANGELOG entry that says "no API surface changes."

> **Invariant 31:** Every PR traverses the tier-1 gate.

> **Invariant 32:** PR body links back to this packet.

- In-memory only — no persistent storage; restarts lose pending follow-ups (call this out in README + CHANGELOG)
- `Notify.Abstractions` only — never runtime, never providers, never queues
- `IDecisionLog` stays internal in this packet; `DecisionLogEntry.TenantId` is first-class from day one
- All in-memory stores keyed by `(TenantId, ...)`; cross-tenant isolation verified by required tests
- Cadence rules: welcome-email + welcome-followup once per `(tenant, recipient)` lifetime; other intent kinds default to Allow
- `tenantId.IsInternal` short-circuit required on `IPreferenceStore`, `ICadencePolicy`, and the orchestrator's evaluation path; tests covering each branch are required
- Tenancy from `IGridContext.TenantId` only (typed, non-nullable per ADR-0026 D2); no string parameters, no AsyncLocal
- Follow-up scheduler captures `TenantId` at scheduling time and synthesizes the context at firing time
- Pin Notify.Abstractions to current published version; verify `INotificationSender` shape before authoring the call site
- Verify Kernel pin includes ADR-0026 D2 promotion; if not, packet is blocked
- Records/classes drop `I` prefix; interfaces keep it; `TenantId` (record struct) drops `I`
- No ADR IDs in README narrative body (CHANGELOG entries and XML docs cross-referencing tenancy contracts are exempt)

**Key Files:**

Runtime additions:
- `src/HoneyDrunk.Communications/Internal/CommunicationOrchestrator.cs` (new)
- `src/HoneyDrunk.Communications/Internal/InMemoryPreferenceStore.cs` (new)
- `src/HoneyDrunk.Communications/Internal/InMemoryCadencePolicy.cs` (new)
- `src/HoneyDrunk.Communications/Internal/InMemoryDecisionLog.cs` (new)
- `src/HoneyDrunk.Communications/Internal/IDecisionLog.cs` (new — internal)
- `src/HoneyDrunk.Communications/Internal/DecisionLogEntry.cs` (new — record)
- `src/HoneyDrunk.Communications/Internal/InMemoryFollowupScheduler.cs` (new — IHostedService)
- `src/HoneyDrunk.Communications/Internal/DefaultRecipientResolver.cs` (new)
- `src/HoneyDrunk.Communications/Internal/CommunicationsStartupHook.cs` (replace Phase 1 stub)
- `src/HoneyDrunk.Communications/Internal/CommunicationsHealthContributor.cs` (replace Phase 1 stub)
- `src/HoneyDrunk.Communications/Intents/WelcomeEmailIntent.cs` (new — record)
- `src/HoneyDrunk.Communications/Intents/WelcomeFollowupIntent.cs` (new — record)
- `src/HoneyDrunk.Communications/CommunicationsOptions.cs` (extend)
- `src/HoneyDrunk.Communications/CommunicationsServiceCollectionExtensions.cs` (extend AddCommunications)
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj` (version bump + Notify.Abstractions + Hosting.Abstractions)
- `src/HoneyDrunk.Communications/README.md` (Welcome Flow Quickstart section)
- `src/HoneyDrunk.Communications/CHANGELOG.md` (append 0.3.0 with restart-loses-followups caveat)

Abstractions:
- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj` (version bump only)
- `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md` (append 0.3.0 alignment-bump entry)

Tests:
- `tests/HoneyDrunk.Communications.Tests/HoneyDrunk.Communications.Tests.csproj` (new)
- `tests/HoneyDrunk.Communications.Tests/CommunicationOrchestratorTests.cs` (new — includes Internal short-circuit tests and `Orchestrator_ReadsTenantIdFromGridContext_NeverFromString`)
- `tests/HoneyDrunk.Communications.Tests/InMemoryPreferenceStoreTests.cs` (new — includes Internal short-circuit test)
- `tests/HoneyDrunk.Communications.Tests/InMemoryCadencePolicyTests.cs` (new — includes Internal short-circuit test)
- `tests/HoneyDrunk.Communications.Tests/CrossTenantIsolationTests.cs` (new — REQUIRED — `CrossTenantIsolation_SameRecipient_DifferentTenants_HaveIndependentPreferenceState` + `..._HaveIndependentCadenceState`)
- `tests/HoneyDrunk.Communications.Tests/WelcomeFollowupSchedulerTests.cs` (new — includes `..._UnderCapturedTenancy` test)
- `tests/HoneyDrunk.Communications.Canary/HoneyDrunk.Communications.Canary.csproj` (new)
- `tests/HoneyDrunk.Communications.Canary/NotifyBoundaryTests.cs` (new)
- `tests/HoneyDrunk.Communications.Canary/StartupValidationTests.cs` (new)
- `tests/HoneyDrunk.Communications.Canary/TenancyContractTests.cs` (new — `IGridContext_TenantId_IsTypedTenantId_NotString` + `TenantId_Internal_SentinelExists_AndIsConsistent`)

Repo-level:
- `HoneyDrunk.Communications.slnx` (add the two test projects)
- `CHANGELOG.md` (append 0.3.0)
- `.github/workflows/release-runtime.yml` (new)

**Contracts:**
- `WelcomeEmailIntent` — concrete `IMessageIntent` for the welcome path
- `WelcomeFollowupIntent` — concrete `IMessageIntent` for the 2-day follow-up
- `IDecisionLog` (internal) — append-only audit log surface; may be lifted to Abstractions in Phase 3
- `DecisionLogEntry` (record) — single audit log entry shape
