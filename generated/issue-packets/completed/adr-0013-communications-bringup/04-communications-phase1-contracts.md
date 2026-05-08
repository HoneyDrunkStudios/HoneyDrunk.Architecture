---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "contracts", "adr-0013", "adr-0026", "wave-3"]
dependencies: ["03-communications-scaffold.md"]
adrs: ["ADR-0013", "ADR-0026"]
wave: 3
initiative: adr-0013-communications-bringup
node: honeydrunk-communications
---

# Feature: Phase 1 — define 5 seed contracts in Abstractions and wire Kernel integration

## Summary
Land Phase 1 of the Communications standup: define the five seed contracts (`ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`) in `HoneyDrunk.Communications.Abstractions` — **all tenant-aware from day one per ADR-0026** — wire Kernel integration in the `HoneyDrunk.Communications` runtime project (DI extension `AddCommunications(...)` that registers `IGridContext` consumers, lifecycle hooks, telemetry plumbing — but **no concrete `ICommunicationOrchestrator` implementation yet** — that ships in Phase 2), and add a tag-driven publish workflow so the Abstractions package can be released to NuGet. Both projects bump from `0.1.0` to `0.2.0`.

Tenancy primitives consumed in this packet are owned by Kernel (per ADR-0026): the `TenantId` ULID record struct in `HoneyDrunk.Kernel.Abstractions.Identity`, the `TenantId.Internal` sentinel + `IsInternal` predicate, and the non-nullable `IGridContext.TenantId` property. `IPreferenceStore` and `ICadencePolicy` signatures take `TenantId` as a first-class parameter. There is no string-based tenant identifier anywhere on the contract surface this packet ships.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications`

## Motivation
Phase 1's purpose per ADR-0013 is "Contracts and Scaffold." The scaffold (packet 03) shipped the empty solution. This packet ships the contract surface that Phase 2 (welcome flow) and any future consumer will build against.

The contracts are seed contracts — subject to refinement during Phase 2 implementation. Resist the temptation to over-design. Five interfaces with the minimum surface area needed to compose Phase 2's welcome flow is the goal. Where exact member shapes are uncertain, prefer narrow surfaces that can be widened later over wide surfaces that must be narrowed (the latter is a breaking change).

Kernel integration in this packet is **wiring only** — registering DI extension methods that will be filled in by Phase 2. The runtime project gains a `CommunicationsServiceCollectionExtensions` static class with `AddCommunications(this IServiceCollection services, Action<CommunicationsOptions>? configure = null)` that:

- Validates required Kernel services are registered (`IGridContextAccessor`, `IOperationContextAccessor`, `INodeLifecycle` if needed)
- Registers an `IStartupHook` placeholder that no-ops in Phase 1 and gets replaced in Phase 2
- Registers an `IHealthContributor` that reports `Healthy` unconditionally for now (Phase 2 will add real health logic when there's flow state to check)
- Adds telemetry enrichment via Kernel's `ITelemetryActivityFactory` so Phase 2 decision spans inherit the correct GridContext

## Scope

### `HoneyDrunk.Communications.Abstractions` — five seed contracts

All five interfaces ship in Phase 1 with full XML documentation (invariant 13). Exact member shapes are at the executor's discretion — the constraints below pin the **boundaries**, not the **signatures**. Interfaces (records keep no `I`; interfaces keep `I`):

#### `ICommunicationOrchestrator`
Top-level entry point. Given a business event, decides what messages to send, to whom, and when. Delegates delivery to Notify (in Phase 2 — this is the contract surface, not the implementation).

Suggested members (Phase 1 is contract-only; Phase 2 implements):
- `Task<MessageDecision> EvaluateAsync(IMessageIntent intent, CancellationToken ct)` — returns the orchestration decision (sent / suppressed / scheduled) without performing delivery
- `Task<MessageDecision> SendAsync(IMessageIntent intent, CancellationToken ct)` — performs the full evaluate-and-deliver path

Where `MessageDecision` is a non-`I`-prefixed record introduced in Abstractions carrying:
- `MessageDecisionOutcome` enum (Sent, SuppressedByPreference, SuppressedByCadence, Scheduled, Failed)
- `string Reason` for audit
- `DateTimeOffset? ScheduledFor` when scheduled
- `string? CorrelationKey` linking back to the originating intent

#### `IMessageIntent`
Maps a business event to a message intent — captures the **why** and **what** of a communication without prescribing delivery details.

Suggested members:
- `string IntentKind { get; }` — string identifier (e.g., `"welcome-email"`, `"subscription-expiring"`); kept stringly-typed for extensibility
- `string TriggerEventId { get; }` — opaque identifier of the originating business event for audit
- `RecipientHandle Recipient { get; }` — who the message targets (record, no `I` prefix; carries identity but not preferences — preferences resolved separately by `IPreferenceStore`)
- `IReadOnlyDictionary<string, string> Payload { get; }` — intent-specific data (e.g., user's display name for welcome email template variables)

`RecipientHandle` is a record in Abstractions: `RecipientHandle(string Identity, string PreferredChannel)` — minimum needed for the welcome flow. Phase 3 may extend with tenant/project scope.

#### `IRecipientResolver`
Resolves the target audience for a message intent. In simple cases (welcome email) the recipient is implicit in the intent and the resolver is a pass-through. In complex cases (digest emails sent to all users in a project) the resolver expands to multiple recipients.

Suggested members:
- `IAsyncEnumerable<RecipientHandle> ResolveAsync(IMessageIntent intent, CancellationToken ct)` — async enumerable supports both pass-through (yield the intent's recipient) and fan-out (yield N recipients) without forcing materialization

#### `IPreferenceStore`
User communication preferences — opt-in/out, channel preferences, quiet hours, suppression lists. **Tenant-scoped per ADR-0026** — the same human user across two tenants has two distinct preference rows. Lookups are keyed by `(TenantId, RecipientHandle)`, never by `RecipientHandle` alone.

Suggested members:
- `Task<RecipientPreferences> GetAsync(TenantId tenantId, RecipientHandle recipient, CancellationToken ct)` — returns the recipient's current preference snapshot for this tenant
- `Task SetAsync(TenantId tenantId, RecipientHandle recipient, RecipientPreferences preferences, CancellationToken ct)` — Phase 1 in-memory store implements; Phase 3 persistent store overrides

`TenantId` is `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` (the ULID-backed `readonly record struct` that already exists in Kernel.Abstractions per ADR-0026 D1). The Abstractions project must add a `using HoneyDrunk.Kernel.Abstractions.Identity;` to surface the type — this requires `HoneyDrunk.Kernel.Abstractions` as a NuGet reference on the **Communications.Abstractions** project. Per invariant 1, Abstractions packages may reference other Abstractions packages; the only forbidden direction is depending on a runtime package. `HoneyDrunk.Kernel.Abstractions` is itself an Abstractions package and is the canonical home of Grid identity primitives, so this reference is permitted and consistent with how every other Node's Abstractions package consumes Kernel identity types.

`RecipientPreferences` is a record in Abstractions: `RecipientPreferences(bool OptedOut, IReadOnlySet<string> SuppressedIntentKinds, TimeSpan? QuietHoursStart, TimeSpan? QuietHoursEnd, string? PreferredChannel)`.

XML docs on the interface must explicitly state: "When `tenantId.IsInternal` is true, implementations should return the default opted-in preference snapshot without consulting any backing store. Internal Grid traffic is not subject to per-tenant preference enforcement (mirrors ADR-0026 D4 / D6 short-circuit pattern for `ITenantRateLimitPolicy` and `IBillingEventEmitter`)."

#### `ICadencePolicy`
Enforces message frequency and spacing rules per recipient — prevents notification fatigue and respects rate limits. **Tenant-scoped per ADR-0026** — cadence state is per-`(TenantId, recipient, intent kind)`. A user being rate-limited in one tenant does not affect their cadence state in any other tenant.

Suggested members:
- `Task<CadenceVerdict> CheckAsync(TenantId tenantId, RecipientHandle recipient, IMessageIntent intent, CancellationToken ct)` — returns whether the intent passes cadence (Allow / Suppress / DeferUntil(timestamp)) for this `(tenant, recipient, intent kind)` triple

`CadenceVerdict` is a record in Abstractions: `CadenceVerdict(CadenceOutcome Outcome, DateTimeOffset? DeferUntil, string Reason)` where `CadenceOutcome` is an enum (Allow, Suppress, Defer).

XML docs on the interface must explicitly state: "When `tenantId.IsInternal` is true, implementations should return `CadenceVerdict(CadenceOutcome.Allow, DeferUntil: null, Reason: \"internal-tenant-bypass\")` without consulting any backing store. Internal Grid traffic is not subject to per-tenant cadence enforcement."

### `HoneyDrunk.Communications` — Kernel integration wiring

Add the runtime DI extension. Concrete `ICommunicationOrchestrator` implementation is **not** in this packet; that ships in Phase 2. The runtime project gains:

- `CommunicationsOptions.cs` — options POCO. Phase 1 has minimal fields (e.g., `bool EnableHealthChecks { get; set; } = true`); Phase 2 expands with welcome-flow-specific options.
- `CommunicationsServiceCollectionExtensions.cs` — `AddCommunications(this IServiceCollection, Action<CommunicationsOptions>?)` static method. Validates Kernel services present (specifically: `IGridContextAccessor` must be registered — Phase 2's orchestrator reads `gridContext.TenantId` per ADR-0026 D2 and the validation guards against composition errors); registers a no-op `IStartupHook`; registers a Healthy-by-default `IHealthContributor`; sets up telemetry enrichment hooks. Does **not** register `ICommunicationOrchestrator` yet — Phase 2 adds that registration.

The Kernel pin chosen for this packet **must include the ADR-0026 D2 type promotion** — `IGridContext.TenantId` must be the non-nullable `TenantId` type, not the legacy `string?` shape. Verify by inspecting `HoneyDrunk.Kernel.Abstractions.Context.IGridContext` source (or the published Kernel.Abstractions package's reference assembly) before pinning. If the Kernel pin available at execution time still exposes `string?`, this packet is blocked — surface the gap as a Phase 1 prerequisite issue against ADR-0026's own initiative and stop. Falling back to a string-shaped contract here would lock Communications into stringly-typed tenancy that has to be migrated later.

NuGet additions to the runtime project:
- `HoneyDrunk.Kernel.Abstractions` (latest stable — match Notify's pin if Notify already aligned to Kernel 0.4.0; check Notify's `.csproj`)
- `HoneyDrunk.Kernel` (same pin; runtime needs the lifecycle hook base classes)
- `Microsoft.Extensions.DependencyInjection.Abstractions` (already transitively present via Kernel.Abstractions; add explicit reference if the analyzer flags it)
- `Microsoft.Extensions.Options.ConfigurationExtensions` (for `CommunicationsOptions` binding)

### Publish workflow

Add `.github/workflows/release-abstractions.yml` triggered on tag push `abstractions-v*`. Mirror the publish workflow shape used by Notify (or whichever Grid repo currently has a published Abstractions package). Two jobs:

1. **build** — `dotnet pack src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj -c Release -o ./packages`
2. **publish** — `uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-publish-nuget.yml@main` (or the canonical reusable publish workflow — check Notify's release workflows for the current name) with the package artifact and the NuGet org's API key as a secret.

Publish the runtime package similarly via a separate `release-runtime.yml` triggered on `runtime-v*` — Phase 2 may need this workflow when the runtime is ready to publish. **Defer `release-runtime.yml` to Phase 2 (packet 05)** since publishing an empty Kernel-integration shell adds no consumer value. Only the Abstractions publish workflow ships in this packet.

### Version bump

Per invariant 27, both projects move together. Bump both `HoneyDrunk.Communications.Abstractions` and `HoneyDrunk.Communications` from `0.1.0` to `0.2.0`. Update:
- Repo-level `CHANGELOG.md` — new `0.2.0` entry summarizing Phase 1 (five contracts shipped, Kernel integration wired, Abstractions publish workflow added)
- Per-package `CHANGELOG.md` for Abstractions — `0.2.0` entry detailing the five interfaces
- Per-package `CHANGELOG.md` for runtime — `0.2.0` entry detailing the Kernel integration extension
- Per-package `README.md` for Abstractions — replace the "no public types yet" placeholder with the actual contract surface description and a minimal usage example
- Per-package `README.md` for runtime — replace the placeholder with the `AddCommunications(...)` registration example

## NuGet Dependencies

### `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | Already present from scaffold; no change. `PrivateAssets="all"`. |
| `HoneyDrunk.Kernel.Abstractions` | NEW. Required to reference the typed `TenantId` (`HoneyDrunk.Kernel.Abstractions.Identity.TenantId`) on `IPreferenceStore` and `ICadencePolicy` signatures. Pin to the version Notify currently uses (check `HoneyDrunk.Notify/src/HoneyDrunk.Notify/HoneyDrunk.Notify.csproj`). The pin **must include** the ADR-0026 D2 type-promoted `IGridContext.TenantId` — verify before pinning; if not, this packet is blocked on ADR-0026's Kernel half. Per invariant 1, an Abstractions package may depend on another Abstractions package (Kernel.Abstractions is itself an Abstractions package). |

### `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | Already present from scaffold; no change. |
| `<ProjectReference Include="..\HoneyDrunk.Communications.Abstractions\..." />` | Already present from scaffold; no change. |
| `HoneyDrunk.Kernel.Abstractions` | NEW. Pin to the version Notify currently uses (check `HoneyDrunk.Notify/src/HoneyDrunk.Notify/HoneyDrunk.Notify.csproj`). Required for `IGridContextAccessor`, `IOperationContextAccessor`, telemetry contracts. |
| `HoneyDrunk.Kernel` | NEW. Same pin. Required for `IStartupHook`, `IHealthContributor` base types. |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | NEW. For `CommunicationsOptions` binding from configuration. |

If the analyzer flags `Microsoft.Extensions.DependencyInjection.Abstractions` as missing, add it explicitly — usually transitively present via Kernel.Abstractions.

## Affected Files

### `HoneyDrunk.Communications.Abstractions`
- `src/HoneyDrunk.Communications.Abstractions/ICommunicationOrchestrator.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/IMessageIntent.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/IRecipientResolver.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/IPreferenceStore.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/ICadencePolicy.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/MessageDecision.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/MessageDecisionOutcome.cs` (new — enum)
- `src/HoneyDrunk.Communications.Abstractions/RecipientHandle.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/RecipientPreferences.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/CadenceVerdict.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/CadenceOutcome.cs` (new — enum)
- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj` (version bump 0.1.0 → 0.2.0; add `HoneyDrunk.Kernel.Abstractions` reference for the typed `TenantId`)
- `src/HoneyDrunk.Communications.Abstractions/README.md` (replace placeholder with real description + usage example)
- `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md` (append `0.2.0` entry)

### `HoneyDrunk.Communications` (runtime)
- `src/HoneyDrunk.Communications/CommunicationsOptions.cs` (new)
- `src/HoneyDrunk.Communications/CommunicationsServiceCollectionExtensions.cs` (new — `AddCommunications` static method)
- `src/HoneyDrunk.Communications/Internal/CommunicationsStartupHook.cs` (new — Phase 1 no-op; Phase 2 fills in)
- `src/HoneyDrunk.Communications/Internal/CommunicationsHealthContributor.cs` (new — Healthy-by-default for Phase 1)
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj` (version bump 0.1.0 → 0.2.0; add Kernel + Options refs)
- `src/HoneyDrunk.Communications/README.md` (replace placeholder with `AddCommunications` example)
- `src/HoneyDrunk.Communications/CHANGELOG.md` (append `0.2.0` entry)

### Repo-level
- `CHANGELOG.md` (append `0.2.0` entry covering both projects)
- `.github/workflows/release-abstractions.yml` (new — tag-driven publish for the Abstractions package)
- `.slnx` (no edit needed — projects already referenced)

## Boundary Check

- [x] All work in `HoneyDrunk.Communications` repo
- [x] Abstractions has zero runtime HoneyDrunk dependencies (invariant 1) — only `HoneyDrunk.Standards` analyzers and a single Abstractions-to-Abstractions reference on `HoneyDrunk.Kernel.Abstractions` (permitted; Kernel.Abstractions is the canonical home of Grid identity primitives like `TenantId`)
- [x] Runtime depends only on Abstractions + Kernel (Kernel.Abstractions for contracts including `TenantId` and `IGridContext`, Kernel for hook base classes) — no other runtime references at this layer (invariant 2). **Notify is NOT referenced in this packet** — that's Phase 2.
- [x] No concrete `ICommunicationOrchestrator` registration — Phase 2 adds that. The DI extension wires Kernel integration only.
- [x] Records carry no `I` prefix; interfaces carry `I` prefix (Grid-wide naming rule)
- [x] Tenancy primitives consumed only — Communications does NOT define a parallel `TenantId`, does NOT introduce a string-shaped tenancy parameter anywhere, does NOT use AsyncLocal for tenant propagation. All tenancy reads from `IGridContext.TenantId` per ADR-0026 D2 / D3.

## Acceptance Criteria

### Contracts (Abstractions)
- [ ] `ICommunicationOrchestrator` defined with full XML docs (invariant 13)
- [ ] `IMessageIntent` defined with full XML docs
- [ ] `IRecipientResolver` defined with full XML docs
- [ ] `IPreferenceStore` defined with full XML docs; `GetAsync` and `SetAsync` signatures take `TenantId` as the first parameter (after `this`) per ADR-0026
- [ ] `ICadencePolicy` defined with full XML docs; `CheckAsync` signature takes `TenantId` as the first parameter (after `this`) per ADR-0026
- [ ] `IPreferenceStore` and `ICadencePolicy` XML docs explicitly document the `TenantId.IsInternal` short-circuit contract (implementations return defaults without consulting backing stores when the Internal sentinel is supplied)
- [ ] `MessageDecision` record defined (no `I` prefix; record type)
- [ ] `MessageDecisionOutcome` enum defined
- [ ] `RecipientHandle` record defined (no `I` prefix)
- [ ] `RecipientPreferences` record defined (no `I` prefix)
- [ ] `CadenceVerdict` record defined (no `I` prefix)
- [ ] `CadenceOutcome` enum defined
- [ ] Abstractions project references `HoneyDrunk.Kernel.Abstractions` (for the `TenantId` type) and zero HoneyDrunk runtime packages (invariant 1 — Abstractions-to-Abstractions is permitted)
- [ ] No `string` tenant parameters anywhere on the contract surface (review agent will flag any string-shaped tenancy)
- [ ] All public types compile clean with `<Nullable>enable</Nullable>` and `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` (no `?` annotations missed; no warnings)

### Runtime (Kernel integration)
- [ ] `CommunicationsOptions` POCO defined
- [ ] `CommunicationsServiceCollectionExtensions.AddCommunications(...)` static extension method defined
- [ ] `AddCommunications` validates Kernel services are registered (e.g., throws if `IGridContextAccessor` missing — Phase 2's orchestrator depends on reading `gridContext.TenantId` per ADR-0026 D2) — fail-fast at startup
- [ ] `AddCommunications` registers a no-op `IStartupHook` placeholder
- [ ] `AddCommunications` registers a `Healthy`-returning `IHealthContributor`
- [ ] `AddCommunications` does NOT register a concrete `ICommunicationOrchestrator` (that's Phase 2)
- [ ] Runtime references `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` (matching Notify's pin); the chosen pin **must include the ADR-0026 D2 promotion** of `IGridContext.TenantId` to non-nullable `TenantId` (verify before pinning)
- [ ] Runtime does NOT reference `HoneyDrunk.Notify.Abstractions` or `HoneyDrunk.Notify` runtime (that's Phase 2)

### Versioning
- [ ] `HoneyDrunk.Communications.Abstractions.csproj` bumped 0.1.0 → 0.2.0
- [ ] `HoneyDrunk.Communications.csproj` bumped 0.1.0 → 0.2.0 (invariant 27 — both move together)
- [ ] Repo-level `CHANGELOG.md` has new `0.2.0` entry covering both projects (invariant 27)
- [ ] Per-package Abstractions `CHANGELOG.md` has `0.2.0` entry detailing the five interfaces and supporting records (invariant 12)
- [ ] Per-package runtime `CHANGELOG.md` has `0.2.0` entry detailing Kernel integration (invariant 12)
- [ ] Per-package Abstractions `README.md` updated with real contract surface description and minimal usage example (invariant 12)
- [ ] Per-package runtime `README.md` updated with `AddCommunications` registration example (invariant 12)

### Publish workflow
- [ ] `.github/workflows/release-abstractions.yml` present, tag-triggered on `abstractions-v*`, calling the canonical `HoneyDrunk.Actions` reusable publish workflow
- [ ] Workflow does NOT push tags itself (agents never push tags per invariant 27)
- [ ] Pushing an `abstractions-v0.2.0` tag manually after merge produces a successful publish to the configured NuGet feed (verified by either a successful workflow run or by an explicit "deferred to first manual tag" note in the PR body)

### General
- [ ] PR traverses tier-1 gate (build, analyzers, vuln scan, secret scan)
- [ ] PR body links back to this packet (invariant 32)
- [ ] No ADR IDs in `README.md` narrative body (per user preference)
- [ ] Naming rule applied: all five contracts keep `I` prefix; all records (`MessageDecision`, `RecipientHandle`, `RecipientPreferences`, `CadenceVerdict`) drop `I` prefix

## Human Prerequisites

- [ ] NuGet feed credentials accessible to the publish workflow. If the org-wide `NUGET_API_KEY` secret is already wired for other Grid repos (Notify, Vault, Kernel), Communications inherits that — confirm. If not, set the org secret once via the GitHub UI: Settings → Secrets and variables → Actions → New organization secret. Cross-link: `infrastructure/azure-identity-and-secrets.md` if the credential lives in Vault rather than GitHub secrets.
- [ ] After PR merges, push the `abstractions-v0.2.0` tag manually to trigger the first publish (agents never push tags per invariant 27). Verify the package appears on the NuGet feed.

## Dependencies

- `03-communications-scaffold.md` — empty solution and projects must exist before contracts and Kernel wiring land
- **ADR-0026 Kernel half** (separate initiative) — the typed `TenantId.Internal` sentinel + `IsInternal` predicate must exist on `HoneyDrunk.Kernel.Abstractions.Identity.TenantId`, AND `IGridContext.TenantId` must be promoted from `string?` to non-nullable `TenantId`, AND `GridContextMiddleware` must apply the Internal default at Grid entry. If any of these are not yet shipped at execution time, this packet is blocked — surface the gap rather than fall back to string-shaped tenancy.

## Downstream Unblocks

- `05-communications-phase2-welcome-flow.md` — Phase 2 implements the concrete `CommunicationOrchestrator` runtime, the welcome flow, and the in-memory store implementations on top of these contracts; also adds `release-runtime.yml`

## Referenced ADR Decisions

**ADR-0013 (Communications Orchestration Layer — HoneyDrunk.Communications):**
- **§Contracts table:** Five seed contracts — `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`. Subject to refinement during implementation. Member shapes proposed in this packet are starting points; adjustments during implementation are permitted as long as the boundary semantics in §Communications owns / does NOT own remain intact.
- **§Phase Plan / Phase 1:** "Define `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy` in `HoneyDrunk.Communications.Abstractions`. Wire Kernel integration (IGridContext, lifecycle hooks)." Exactly the scope of this packet, minus the welcome flow which is Phase 2.
- **§Dependency Graph:** Communications consumes Kernel directly. This packet adds the Kernel NuGet refs.

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **§D1:** `TenantId` (`HoneyDrunk.Kernel.Abstractions.Identity.TenantId`) is the canonical tenant identifier — Communications consumes this primitive directly on `IPreferenceStore` and `ICadencePolicy` signatures. Adds a `TenantId.Internal` static sentinel + `IsInternal` predicate that `IPreferenceStore` and `ICadencePolicy` XML docs reference for the short-circuit contract.
- **§D2:** `IGridContext.TenantId` is non-nullable `TenantId`. The Kernel pin chosen for this packet must include this promotion. Phase 2's orchestrator reads the typed value directly.
- **§D3:** Tenancy flows via `IGridContext`, not AsyncLocal. `IPreferenceStore` and `ICadencePolicy` make this explicit by taking `TenantId` as a parameter — the orchestrator (Phase 2) reads it from `IGridContext` and threads it down.
- **§D4 / D6 short-circuit pattern:** The `TenantId.IsInternal` short-circuit Communications applies to its preference + cadence stores mirrors the pattern ADR-0026 D4 / D6 require of `ITenantRateLimitPolicy` and `IBillingEventEmitter`. Communications does NOT consume `ITenantRateLimitPolicy` or `IBillingEventEmitter` itself (those are Notify's intake-gateway concerns per ADR-0026 D7) — Communications operates above Notify and inherits whatever rate-limit / billing posture Notify enforces.

**Memory: Grid-wide naming rule (records drop `I`, interfaces keep `I`):** All five Phase 1 contracts are interfaces and stay I-prefixed. All record types (`MessageDecision`, `RecipientHandle`, `RecipientPreferences`, `CadenceVerdict`) drop the I prefix.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. *(The five interfaces and five supporting record/enum types are pure contracts — no HoneyDrunk runtime references in Abstractions.)*

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. `HoneyDrunk.Communications` (runtime) depends on `HoneyDrunk.Communications.Abstractions`. Phase 2 will add `HoneyDrunk.Notify.Abstractions` (Notify's contracts package) — never `HoneyDrunk.Notify` runtime. *(This packet adds Kernel.Abstractions and Kernel; Kernel is special — it is the foundation, and consuming Kernel runtime is permitted by every Node per the relationships graph.)*

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level `CHANGELOG.md` mandatory; per-package `README.md` and `CHANGELOG.md` mandatory. README must describe public API surface — this packet replaces the "no public types yet" placeholders with the real contract surface description.

> **Invariant 13:** All public APIs have XML documentation. Enforced by `HoneyDrunk.Standards` analyzers. Every interface, record, and enum defined in this packet must have full `///` XML documentation.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. The Kernel additions are listed above; `HoneyDrunk.Standards` is already present from scaffold.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. Both projects bump 0.1.0 → 0.2.0 here. The repo-level `CHANGELOG.md` must always get an entry for the new version. Per-package changelogs are updated only for packages with actual changes — both packages have actual changes in this packet, so both get per-package entries (no alignment-bump noise).

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Constraints

- **No concrete `ICommunicationOrchestrator` implementation.** This is the Phase 1 packet — contracts only on the Abstractions side, Kernel wiring only on the runtime side. The orchestrator implementation lives in Phase 2 (packet 05). Stubbing it here would inflate the PR and force the Phase 2 packet to either rewrite or extend, both of which are scope creep.
- **No Notify reference yet.** Phase 2 introduces `HoneyDrunk.Notify.Abstractions` as the delivery contract. Adding it here is premature — there is no caller for `INotificationSender` in this packet.
- **No persistent stores.** `IPreferenceStore` is a contract here; the in-memory implementation lives in Phase 2. Persistent (Data-backed) stores are Phase 3.
- **Kernel pin matches Notify AND must include ADR-0026 D2 promotion.** Check `HoneyDrunk.Notify/src/HoneyDrunk.Notify/HoneyDrunk.Notify.csproj` for the current Kernel pin. Verify the pinned Kernel.Abstractions version exposes `IGridContext.TenantId` as non-nullable `TenantId` (not `string?`). If the pin is older, this packet is blocked on ADR-0026's Kernel half — surface the gap and stop. Drift between Notify and Communications on Kernel pins risks Phase 2 integration friction.
- **Tenant-aware contract surface — no string tenant parameters.** `IPreferenceStore` and `ICadencePolicy` take `TenantId` (typed) as a first-class parameter. The review agent will flag any string-shaped tenancy on the public surface. AsyncLocal-based tenancy is forbidden (ADR-0026 D3).
- **Internal short-circuit documented in XML docs.** `IPreferenceStore` and `ICadencePolicy` XML docs explicitly document the `TenantId.IsInternal` short-circuit contract — implementations are required to return defaults (opted-in / Allow) without consulting backing stores when the Internal sentinel is supplied. This is the specification Phase 2 implementations honor.
- **Naming rule discipline (Grid-wide).** The five interfaces keep their `I` prefix. The five record / enum supporting types (`MessageDecision`, `MessageDecisionOutcome`, `RecipientHandle`, `RecipientPreferences`, `CadenceVerdict`, `CadenceOutcome`) do NOT carry an `I` prefix. The review agent will flag any I-prefixed record. Note that `TenantId` itself is a record struct that drops the `I` per the same rule (it is consumed from Kernel.Abstractions, not defined here).
- **Member-shape suggestions are suggestions — except for the `TenantId` parameter.** The bullet-point member lists in this packet's "Scope" section are starting points. If the implementation discovers a cleaner shape (e.g., `EvaluateAsync` should return `IAsyncEnumerable<MessageDecision>` to support fan-out at the orchestrator level), the executor may adjust — as long as the boundary semantics from ADR-0013 and the tenancy semantics from ADR-0026 stay intact. The `TenantId` parameter on `IPreferenceStore` and `ICadencePolicy` is **not** negotiable. Document other deviations in the PR body so the Phase 2 packet can plan against the actual shape.
- **No publish-runtime workflow yet.** Only the Abstractions publish workflow ships in this packet. Publishing an empty Kernel-integration shell adds no consumer value. `release-runtime.yml` ships in Phase 2 alongside the welcome flow.
- **No ADR IDs in narrative body of `README.md` files** (per user preference). ADR IDs allowed in `CHANGELOG.md` entries (metadata) and in XML docs that reference the cross-cutting tenancy contract — those references are load-bearing for downstream implementers.

## Labels
`feature`, `tier-2`, `ops`, `contracts`, `adr-0013`, `adr-0026`, `wave-3`

## Agent Handoff

**Objective:** Define the five Phase 1 seed contracts in Abstractions (tenant-aware shapes per ADR-0026), wire Kernel integration in the runtime project (no concrete orchestrator yet), add the tag-driven Abstractions publish workflow, and bump both projects to `0.2.0`.

**Target:** HoneyDrunk.Communications, branch from `main`

**Context:**
- Goal: Ship the tenant-aware contract surface that Phase 2 (welcome flow) will implement against
- Feature: ADR-0013 Phase 1 — contracts and Kernel wiring
- ADRs: ADR-0013 (primary), ADR-0026 (cross-cutting tenancy applied to `IPreferenceStore` + `ICadencePolicy` signatures and to the runtime's `IGridContext.TenantId` consumption pattern)

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `03-communications-scaffold.md` merged (empty solution exists)
- ADR-0026 Kernel half shipped — `TenantId.Internal` sentinel + `IsInternal` predicate exist; `IGridContext.TenantId` promoted to non-nullable `TenantId`; `GridContextMiddleware` applies the Internal default at Grid entry. If absent, packet is blocked — surface the gap.

**Constraints:**

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Per-package README must describe public API surface — replace the "no public types yet" placeholders.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** NuGet Dependencies section required; new Kernel + Options refs documented above.

> **Invariant 27:** All projects in a solution share one version and move together. Both projects bump 0.1.0 → 0.2.0 in this packet. Repo-level CHANGELOG.md gets the new version entry.

> **Invariant 31:** Every PR traverses the tier-1 gate.

> **Invariant 32:** PR body links back to this packet.

- Five interfaces keep `I` prefix; six supporting types (4 records + 2 enums) drop the `I` prefix
- `IPreferenceStore` and `ICadencePolicy` take `TenantId` (typed; from `HoneyDrunk.Kernel.Abstractions.Identity`) as a first-class parameter — never a string
- XML docs on `IPreferenceStore` and `ICadencePolicy` document the `TenantId.IsInternal` short-circuit contract (defaults returned without consulting backing stores when Internal sentinel is supplied)
- Communications.Abstractions adds a NuGet reference on `HoneyDrunk.Kernel.Abstractions` (Abstractions-to-Abstractions, permitted under invariant 1)
- No concrete `ICommunicationOrchestrator` implementation
- No `HoneyDrunk.Notify.*` references yet (Phase 2)
- No persistent stores yet (Phase 3)
- Kernel pin must match Notify's current pin AND must include ADR-0026 D2 promotion (non-nullable typed `IGridContext.TenantId`); if not, packet is blocked
- Only `release-abstractions.yml` ships; `release-runtime.yml` ships in Phase 2
- No ADR IDs in README narrative body (CHANGELOG entries and XML docs that cross-reference ADR-0026 contracts are exempt)

**Key Files:**

Abstractions:
- `src/HoneyDrunk.Communications.Abstractions/ICommunicationOrchestrator.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/IMessageIntent.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/IRecipientResolver.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/IPreferenceStore.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/ICadencePolicy.cs` (new)
- `src/HoneyDrunk.Communications.Abstractions/MessageDecision.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/MessageDecisionOutcome.cs` (new — enum)
- `src/HoneyDrunk.Communications.Abstractions/RecipientHandle.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/RecipientPreferences.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/CadenceVerdict.cs` (new — record)
- `src/HoneyDrunk.Communications.Abstractions/CadenceOutcome.cs` (new — enum)
- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj` (version bump)
- `src/HoneyDrunk.Communications.Abstractions/README.md` (rewrite)
- `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md` (append 0.2.0)

Runtime:
- `src/HoneyDrunk.Communications/CommunicationsOptions.cs` (new)
- `src/HoneyDrunk.Communications/CommunicationsServiceCollectionExtensions.cs` (new)
- `src/HoneyDrunk.Communications/Internal/CommunicationsStartupHook.cs` (new — no-op)
- `src/HoneyDrunk.Communications/Internal/CommunicationsHealthContributor.cs` (new — Healthy default)
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj` (version bump + Kernel refs)
- `src/HoneyDrunk.Communications/README.md` (rewrite)
- `src/HoneyDrunk.Communications/CHANGELOG.md` (append 0.2.0)

Repo-level:
- `CHANGELOG.md` (append 0.2.0)
- `.github/workflows/release-abstractions.yml` (new — tag-driven publish)

**Contracts:**
- `ICommunicationOrchestrator` — top-level entry; evaluate / send
- `IMessageIntent` — business event → intent shape
- `IRecipientResolver` — recipient enumeration
- `IPreferenceStore` — preference get/set
- `ICadencePolicy` — cadence check (allow / suppress / defer)
