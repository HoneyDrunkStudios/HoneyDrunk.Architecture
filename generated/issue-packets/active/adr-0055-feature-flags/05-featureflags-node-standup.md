---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.FeatureFlags
labels: ["feature", "tier-2", "core", "scaffold", "adr-0055", "wave-3"]
dependencies: ["packet:01", "packet:02", "packet:03", "packet:04"]
adrs: ["ADR-0055"]
wave: 3
initiative: adr-0055-feature-flags
node: honeydrunk-featureflags
---

# Stand up the HoneyDrunk.FeatureFlags Node — App-Configuration-backed IFeatureGate + TenantTargetingFilter

## Summary
Bring the empty `HoneyDrunk.FeatureFlags` repo from zero to first-shippable state per ADR-0055 D4 and Phase 1. Land the solution layout, the package families (`HoneyDrunk.FeatureFlags` runtime; an `Abstractions` package iff additional Node-owned contracts beyond `IFeatureGate` ship — see Proposed Implementation), the `Microsoft.FeatureManagement.AzureAppConfiguration`-backed `IFeatureGate` implementation, the custom `TenantTargetingFilter` per D3, the App Configuration label-aware refresh per D9, the DI registration surface (`AddFeatureFlags(...)`), the standard CI pipeline, and a `HoneyDrunk.FeatureFlags.Tests.Canaries` project verifying integration assumptions against `HoneyDrunk.Kernel.Abstractions`.

This Node ships as **v0.1.0** — the standup baseline (matches the HoneyDrunk.Audit precedent).

## Context
ADR-0055 D4 says: "Concrete implementation lives in a new Node `HoneyDrunk.FeatureFlags`, with the published package `HoneyDrunk.FeatureFlags` providing the `Microsoft.FeatureManagement`-backed implementation and the `TenantTargetingFilter` from D3."

Per the user's "new-Node standup gets its own ADR" rule, ADR-0055 *is* that ADR (it explicitly stands up the Node). This packet executes the standup. The boundary on what to scaffold is established by the ADR + the established Grid scaffolding pattern (see `HoneyDrunk.Audit` `0.1.0` for the closest precedent — a small Core-sector Node with a clean Abstractions/runtime/Testing split).

**Abstractions split — decide at edit time.** ADR-0055 D4 names a single concrete package `HoneyDrunk.FeatureFlags` containing the App-Configuration-backed `IFeatureGate` implementation and the `TenantTargetingFilter`. The Grid pattern would normally split into `HoneyDrunk.FeatureFlags.Abstractions` + `HoneyDrunk.FeatureFlags` runtime — but here the **`IFeatureGate` abstraction lives in `HoneyDrunk.Kernel.Abstractions`** (D4), not in this Node's own Abstractions package. The question is whether this Node ships *additional* contracts beyond `IFeatureGate` that warrant an Abstractions split:
- The **`TenantTargetingFilter`** is an `IFeatureFilter` from `Microsoft.FeatureManagement`. Consumers don't reach for it directly — DI registration (the `AddFeatureFlags(...)` extension) wires it. **Not a public abstraction.**
- A potential **`IFeatureFilter` registration extension API** or **a host-options type** might want to live in an Abstractions package so the runtime can be swapped (D15 escalation). At v1, there is no concrete consumer that needs this.

**Decision rule:** ship a single `HoneyDrunk.FeatureFlags` package for now. If a second backing (D15 escalation: `HoneyDrunk.FeatureFlags.LaunchDarkly`) is added later, refactor at that time — extract the runtime-host options into a `HoneyDrunk.FeatureFlags.Abstractions` and migrate the App-Configuration-backed runtime to `HoneyDrunk.FeatureFlags.AzureAppConfiguration`. The v1 simplification is consistent with how `HoneyDrunk.Audit` shipped (one runtime + one Abstractions) and how `HoneyDrunk.Notify` started.

**Single runtime package, plus a Testing fixture if useful.** The `InMemoryFeatureGate` test fixture lives in `HoneyDrunk.Kernel.Abstractions.Testing` per packet 04 — every flag-consuming Node uses that. This Node ships an additional `HoneyDrunk.FeatureFlags.Testing` package **only if** there's a concrete need for a fixture that exercises the App-Configuration-backed runtime in process (e.g., a test that boots the real backing against an in-memory `IConfiguration`). The ADR does not require this. **Decision:** skip the `.Testing` package at v1; revisit if a real consumer needs it.

So the v0.1.0 shape is **one runtime package** (`HoneyDrunk.FeatureFlags`) plus tests/canaries projects.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.FeatureFlags`

## Scope
Stand up the repo end-to-end:

- `HoneyDrunk.FeatureFlags.slnx` — solution file.
- `HoneyDrunk.FeatureFlags/HoneyDrunk.FeatureFlags.csproj` — runtime package targeting .NET 10.0; references `HoneyDrunk.Kernel.Abstractions` (the new minor — confirm version at edit time; expected `0.8.0` or `0.9.0` per packet 04), `Microsoft.FeatureManagement.AzureAppConfiguration`, `Microsoft.Extensions.Configuration.AzureAppConfiguration`, and `HoneyDrunk.Standards` (`PrivateAssets: all`).
- `src/HoneyDrunk.FeatureFlags/AzureAppConfigurationFeatureGate.cs` — concrete `IFeatureGate` over `IFeatureManager`.
- `src/HoneyDrunk.FeatureFlags/TenantTargetingFilter.cs` — custom `IFeatureFilter` per ADR-0055 D3.
- `src/HoneyDrunk.FeatureFlags/Hosting/FeatureFlagsServiceCollectionExtensions.cs` — `AddFeatureFlags(this IServiceCollection, IConfiguration)` DI extension; wires `Microsoft.FeatureManagement`, the App Configuration push-refresh per D2, the `TenantTargetingFilter`, and the `IFeatureGate` registration.
- `HoneyDrunk.FeatureFlags.Tests.Unit/` — xUnit project (per ADR-0047), unit tests for `AzureAppConfigurationFeatureGate` (using a faked `IFeatureManager`) and `TenantTargetingFilter` (using `TargetingContext` fixtures).
- `HoneyDrunk.FeatureFlags.Tests.Canaries/` — canary project per invariant 14, verifying the contract-shape `IFeatureGate` integration against `HoneyDrunk.Kernel.Abstractions`.
- `.github/workflows/pr-core.yml` (or the reusable workflow callsite per ADR-0012) — wires `HoneyDrunk.Actions/pr-core.yml`.
- `.github/workflows/release.yml` — release flow (consult ADR-0033 / existing Node patterns).
- `.github/workflows/nightly-security.yml`, `.github/workflows/nightly-deps.yml` — wire the existing Actions reusable workflows.
- `.github/dependabot.yml` — per ADR-0009 (alerts on, grouped nightly-deps off — match the existing Node pattern).
- `.honeydrunk-review.yaml` — per ADR-0044 (review enabled).
- `.editorconfig` — per `HoneyDrunk.Standards`.
- `CHANGELOG.md` (repo-level), `README.md`, `LICENSE`, `.gitignore`, `.gitattributes` — match the established Node-repo bootstrap.
- `HoneyDrunk.FeatureFlags/CHANGELOG.md`, `HoneyDrunk.FeatureFlags/README.md` — per-package files (invariant 12).
- `Directory.Build.props`, `Directory.Packages.props` if the Grid convention uses centralized package management — match the established pattern at edit time.

The Node's first published version is **v0.1.0** (matches `HoneyDrunk.Audit` precedent).

## Proposed Implementation

1. **Solution + project bootstrap.**
   - Create `HoneyDrunk.FeatureFlags.slnx` at the repo root.
   - Create `HoneyDrunk.FeatureFlags/HoneyDrunk.FeatureFlags.csproj` targeting `net10.0`, with `HoneyDrunk.Standards` (`PrivateAssets: all`), `HoneyDrunk.Kernel.Abstractions` (latest published — confirm at edit time, expected `0.8.0` or `0.9.0` per packet 04's bump), and the Microsoft packages: `Microsoft.FeatureManagement.AzureAppConfiguration`, `Microsoft.Extensions.Configuration.AzureAppConfiguration`, `Microsoft.Extensions.DependencyInjection.Abstractions`, `Microsoft.Extensions.Hosting.Abstractions` (host extension). Reference `HoneyDrunk.Vault.Abstractions` only if the runtime needs `ISecretStore` (it does not — App Configuration is Managed-Identity-accessed per ADR-0005; no SDK-level secret is consumed here). **Do not** reference `HoneyDrunk.Pulse` or any observability package — logging goes through `Microsoft.Extensions.Logging.Abstractions` and Pulse's sink composition happens at the host, not in this package.
   - Create test projects per ADR-0047 — at minimum `HoneyDrunk.FeatureFlags.Tests.Unit` (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet); also `HoneyDrunk.FeatureFlags.Tests.Canaries` for the contract-shape canary required by invariant 14 (cross-Node-boundary verification — this Node implements `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions`).

2. **`AzureAppConfigurationFeatureGate`** — concrete `IFeatureGate` over `Microsoft.FeatureManagement.IFeatureManagerSnapshot` (or `IFeatureManager`; the snapshot variant is preferred for request-scoped consistency — confirm with the current `Microsoft.FeatureManagement` API at edit time):
   ```csharp
   public sealed class AzureAppConfigurationFeatureGate : IFeatureGate
   {
       private readonly IFeatureManagerSnapshot _featureManager;
       private readonly ITargetingContextAccessor _contextAccessor; // produces ITargetingContext from RequestContext

       public AzureAppConfigurationFeatureGate(IFeatureManagerSnapshot fm, ITargetingContextAccessor ca)
       {
           _featureManager = fm;
           _contextAccessor = ca;
       }

       public ValueTask<bool> IsEnabledAsync(string flagName)
       {
           var ctx = _contextAccessor.Current;
           return ctx is null
               ? new ValueTask<bool>(_featureManager.IsEnabledAsync(flagName))
               : new ValueTask<bool>(_featureManager.IsEnabledAsync(flagName, ctx));
       }

       public ValueTask<bool> IsEnabledAsync(string flagName, ITargetingContext context)
           => new ValueTask<bool>(_featureManager.IsEnabledAsync(flagName, context));

       public async ValueTask<T> GetVariantAsync<T>(string flagName, T defaultValue)
       {
           var variant = await _featureManager.GetVariantAsync(flagName);
           return variant is null ? defaultValue : variant.Configuration.Get<T>() ?? defaultValue;
       }
   }
   ```
   The `ITargetingContextAccessor` is a small abstraction this package introduces (internal or public — internal is fine; consumers don't construct it) that resolves an `ITargetingContext` from `HoneyDrunk.Kernel`'s `RequestContext` per ADR-0026. Default implementation reads the ambient `RequestContext` via `IRequestContextAccessor` (or whatever the existing surface is named at edit time — confirm against `HoneyDrunk.Kernel`).

3. **`TenantTargetingFilter`** — custom `IFeatureFilter` per ADR-0055 D3:
   ```csharp
   [FilterAlias("TenantTargeting")]
   public sealed class TenantTargetingFilter : IFeatureFilter
   {
       private readonly ITargetingContextAccessor _contextAccessor;
       public ValueTask<bool> EvaluateAsync(FeatureFilterEvaluationContext context)
       {
           var params = context.Parameters.Get<TenantTargetingParameters>();
           var ctx = _contextAccessor.Current;
           if (ctx?.TenantId is { } tid && params.Tenants?.Contains(tid) == true) return new(true);
           if (ctx?.Tier is { } tier && params.Tiers?.Contains(tier) == true) return new(true);
           // Fallback to default_rollout_percentage — use the inbound context's principal/tenant
           // identifier hashed to a stable 0..99 bucket (matches Microsoft.FeatureManagement's
           // TargetingFilter percentage semantics).
           return new(_FallbackPercentageHit(ctx, params.DefaultRolloutPercentage));
       }
   }

   public sealed class TenantTargetingParameters
   {
       public IReadOnlyList<string>? Tenants { get; init; }
       public IReadOnlyList<string>? Tiers { get; init; }
       public int DefaultRolloutPercentage { get; init; }
   }
   ```
   - The `FilterAlias("TenantTargeting")` matches the JSON shape ADR-0055 D3 cites (the `client_filters[].name` value).
   - The percentage fallback uses the same hashing-to-100-buckets approach `Microsoft.FeatureManagement.TargetingFilter` uses — the implementation can lean on a shared helper or replicate the simple deterministic-hash scheme; confirm the current API at edit time.
   - The filter is registered via DI in the `AddFeatureFlags` extension (step 4).

4. **`AddFeatureFlags` DI extension** — `Hosting/FeatureFlagsServiceCollectionExtensions.cs`:
   ```csharp
   public static IServiceCollection AddFeatureFlags(this IServiceCollection services, IConfiguration config)
   {
       services
           .AddAzureAppConfiguration() // refresh hook
           .AddFeatureManagement(config)
           .AddFeatureFilter<TenantTargetingFilter>();
       services.AddSingleton<ITargetingContextAccessor, DefaultTargetingContextAccessor>();
       services.AddScoped<IFeatureGate, AzureAppConfigurationFeatureGate>();
       return services;
   }
   ```
   - The extension is the single entry point for hosts to compose the flag system.
   - Document in the README that hosts must also wire App Configuration's connection per ADR-0005's pattern (Managed Identity-based; no DSN, no key).
   - Document the D9 label-aware refresh: hosts pass the `IConfiguration` already configured with `.AddAzureAppConfiguration(opt => opt.UseFeatureFlags(...).Select(KeyFilter.Any, label: env).Watch(...))` so the active env's label-scoped flags load.

5. **`DefaultTargetingContextAccessor`** — internal class that reads the ambient `RequestContext` per ADR-0026 and returns an `ITargetingContext`. If no `RequestContext` is ambient (background worker, scheduled job not using the explicit-context overload), `Current` returns `null` and the binary `IsEnabledAsync(string)` path uses the no-context evaluation — this is the safe-default behaviour for off-request paths that aren't supplying explicit targeting context.

6. **CI wiring per ADR-0012.**
   - `.github/workflows/pr-core.yml` calls the reusable `HoneyDrunk.Actions/.github/workflows/pr-core.yml` workflow (the Grid-standard tier-1 gate per invariant 31).
   - `.github/workflows/release.yml` per the existing Node-release pattern.
   - `.github/workflows/nightly-security.yml`, `.github/workflows/nightly-deps.yml` — per ADR-0009 + the existing pattern.
   - `.github/workflows/featureflags-validate.yml` — this Node's own `featureflags.json` is registered if the Node ships any internal flags (it likely does not — the Node is the flag *system*, not a flag consumer). Skip the workflow callsite at standup; add it later if/when the Node consumes its own flags.
   - `.github/dependabot.yml` — alerts on, auto-PRs off; group nightly-deps per ADR-0009.

7. **Contract-shape canary per invariant 14.** `HoneyDrunk.FeatureFlags.Tests.Canaries` includes:
   - `IFeatureGate` shape canary — asserts `IFeatureGate` in the consumed `HoneyDrunk.Kernel.Abstractions` package has the three methods with the expected signatures. If the upstream contract drifts without a coordinated bump, this canary fails. Implementation can reuse `HoneyDrunk.Actions`'s `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Kernel.Abstractions` if that workflow exists at edit time (per invariant 46 / 49 / 43 — same pattern as `IAuditLog` / `ICommunicationOrchestrator` / `IChatClient`).
   - A second canary verifies `AzureAppConfigurationFeatureGate` composes against a fake `IFeatureManagerSnapshot` and a fake `ITargetingContextAccessor` and returns the expected results for set up flags (effectively an end-to-end smoke test against the runtime). Use `Microsoft.FeatureManagement`'s `InMemoryFeatureManager` or similar test surface if available — confirm at edit time.

8. **`.honeydrunk-review.yaml`** — `enabled: true` per ADR-0044, so review agents run on the Node's PRs.

9. **Repo bootstrap files.**
   - `CHANGELOG.md` (repo-level): `[0.1.0] - YYYY-MM-DD - Initial Node standup per ADR-0055.`
   - `README.md` (repo-level): Node overview, package descriptions, the public API (`AddFeatureFlags`, `IFeatureGate` from Kernel), composition example, App Configuration prerequisite, ADR-0055 cross-reference, license footer.
   - `HoneyDrunk.FeatureFlags/CHANGELOG.md`: `[0.1.0]` per-package entry.
   - `HoneyDrunk.FeatureFlags/README.md`: package-scope README with installation, public surface, usage example.
   - `LICENSE` per ADR-0039 (whichever license the Grid uses for Core-sector public packages).
   - `.gitignore`, `.gitattributes` matching the Grid Node pattern.

10. **First release tag — human action.** Agents never tag (invariant 27). Once this packet's PR merges, a human pushes the `v0.1.0` tag, triggering the release workflow to publish `HoneyDrunk.FeatureFlags` to NuGet. Downstream packets (06 unit-tests against `HoneyDrunk.Kernel.Abstractions`; 07 Notify pilot; 08 Operator CLI) consume the published package.

## Affected Files
The entire repo content — this is a from-zero standup. Every file listed in the Scope section.

## NuGet Dependencies
- **`HoneyDrunk.FeatureFlags`** (runtime):
  - `HoneyDrunk.Standards` (`PrivateAssets: all`)
  - `HoneyDrunk.Kernel.Abstractions` (latest published; confirm version at edit time after packet 04 ships)
  - `Microsoft.FeatureManagement.AzureAppConfiguration` (latest stable at edit time)
  - `Microsoft.Extensions.Configuration.AzureAppConfiguration` (latest stable at edit time)
  - `Microsoft.Extensions.DependencyInjection.Abstractions` (latest stable matching .NET 10)
  - `Microsoft.Extensions.Hosting.Abstractions` (latest stable matching .NET 10)
  - `Microsoft.Extensions.Logging.Abstractions` (latest stable matching .NET 10) — for ILogger logging only
- **`HoneyDrunk.FeatureFlags.Tests.Unit`**:
  - `HoneyDrunk.Standards` (`PrivateAssets: all`)
  - `HoneyDrunk.Kernel.Abstractions.Testing` (for `InMemoryFeatureGate` — though the unit tests here exercise the *runtime*, not the Kernel fixture; reference if useful)
  - The ADR-0047 test stack: xUnit v2, NSubstitute, AwesomeAssertions, coverlet.collector — confirm versions against `HoneyDrunk.Standards`'s shared `Directory.Build.props` if it ships one.
  - `Microsoft.NET.Test.Sdk`
  - `Microsoft.FeatureManagement` test helpers if available
- **`HoneyDrunk.FeatureFlags.Tests.Canaries`**:
  - Same test stack as Unit tests.
  - `HoneyDrunk.Kernel.Abstractions` (the contract under canary).

## Boundary Check
- [x] All code in `HoneyDrunk.FeatureFlags`. The repo is created via this packet's Human Prerequisite step; the issue is filed against the new repo.
- [x] Implements `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions` — the abstraction/implementation split per ADR-0055 D4.
- [x] No upward dependency — does not reference any non-Kernel-Abstractions HoneyDrunk package (no Pulse, no Audit, no Vault — App Configuration auth is via Managed Identity per ADR-0005).
- [x] Single-package v1 (no `Abstractions` split) — matches the ADR's "the published package `HoneyDrunk.FeatureFlags`" wording and the Audit standup precedent.

## Acceptance Criteria
- [ ] The `HoneyDrunk.FeatureFlags` repo exists on GitHub (human prerequisite) and this packet's branch lands a complete solution scaffold
- [ ] The solution builds with `dotnet build` at .NET 10.0
- [ ] `HoneyDrunk.FeatureFlags` package exposes `AddFeatureFlags(IServiceCollection, IConfiguration)` as the single DI entry point
- [ ] `AzureAppConfigurationFeatureGate` implements `IFeatureGate` from `HoneyDrunk.Kernel.Abstractions` and delegates to `Microsoft.FeatureManagement.IFeatureManagerSnapshot` (or `IFeatureManager` if the snapshot variant is unsuitable)
- [ ] `TenantTargetingFilter` is registered with `[FilterAlias("TenantTargeting")]`, accepts the `TenantTargetingParameters` shape ADR-0055 D3 defines (`tenants`, `tiers`, `default_rollout_percentage`), and evaluates against the ambient `ITargetingContext`
- [ ] The `TenantTargetingFilter` percentage fallback is deterministic — same input always produces the same bucket
- [ ] `DefaultTargetingContextAccessor` populates `ITargetingContext` from the ambient `HoneyDrunk.Kernel` `RequestContext` per ADR-0026; returns `null` when no RequestContext is ambient (and the no-context evaluation path runs)
- [ ] Unit tests cover: `AzureAppConfigurationFeatureGate` delegation to `IFeatureManager`, the `GetVariantAsync<T>` default-fallback path, `TenantTargetingFilter` matching on `tenants`, on `tiers`, on the default-rollout percentage, and the no-context fallback to the binary `IsEnabledAsync(string)` path
- [ ] Canary tests verify `IFeatureGate` contract shape against the consumed `HoneyDrunk.Kernel.Abstractions` package — drift fails the build
- [ ] CI is wired per ADR-0012: `pr-core.yml`, `release.yml`, `nightly-security.yml`, `nightly-deps.yml` callsites exist
- [ ] `.honeydrunk-review.yaml` is `enabled: true` (ADR-0044 / invariant 52)
- [ ] `HoneyDrunk.Standards` is referenced (`PrivateAssets: all`) on every project (invariant 26)
- [ ] Repo-level `CHANGELOG.md` carries a `[0.1.0]` initial entry; `HoneyDrunk.FeatureFlags/CHANGELOG.md` carries the per-package `[0.1.0]` entry (invariant 12)
- [ ] Repo-level `README.md` and `HoneyDrunk.FeatureFlags/README.md` exist and document the API/installation/composition (invariant 12)
- [ ] Public APIs carry XML documentation (invariant 13)
- [ ] No `Thread.Sleep` in test code (invariant 51); no external dependencies in tests (invariant 15); test projects do not bleed into runtime packages (invariant 16)
- [ ] The `pr-core.yml` tier-1 gate passes on the standup PR

## Human Prerequisites
- [ ] **Create the empty `HoneyDrunk.FeatureFlags` GitHub repo** under `HoneyDrunkStudios` before pushing this folder to `main`. Per the standing convention "repos public by default" the repo is public. The standard `main` branch, no template, no auto-init (the standup PR adds README/LICENSE/etc.). The repo must exist on GitHub or the filing pipeline cannot file this packet's issue.
- [ ] After this packet's PR merges, a human pushes the `v0.1.0` git tag to trigger the release workflow and publish the `HoneyDrunk.FeatureFlags` package to NuGet (agents never tag — invariant 27). The downstream packets (06 references it via NuGet; 07 Notify pilot composes it; 08 Operator CLI composes it) cannot build until v0.1.0 is on the package feed.
- [ ] Managed Identity Reader role assignment on the dev App Configuration resource for the consuming Node's Managed Identity (Notify per packet 07; Operator per packet 08). This is a portal step done as part of packet 03's walkthrough application; if not yet done at packet 05's execution time, record as a downstream prerequisite for packets 07 and 08.

## Referenced ADR Decisions
**ADR-0055 D2 — Backend: Azure App Configuration's feature-flags surface.** The package `Microsoft.FeatureManagement.AzureAppConfiguration` provides the native feature-flag model, label-based environment scoping, built-in targeting filters, and Event-Grid push refresh. No new vendor; existing App Configuration relationship (ADR-0005).

**ADR-0055 D3 — `TenantTargetingFilter`.** The only custom `IFeatureFilter` the Grid commits to at v1. Resolves the active `TenantId` from `RequestContext` per ADR-0026, matches against the flag's `tenants:` or `tiers:` configuration, falls back to `default_rollout_percentage`. JSON shape: `{ "name": "TenantTargeting", "parameters": { "tenants": [...], "tiers": [...], "default_rollout_percentage": int } }`.

**ADR-0055 D4 — `IFeatureGate` interface in Kernel.Abstractions; concrete here.** This Node implements `IFeatureGate` (defined in `HoneyDrunk.Kernel.Abstractions` per packet 04) using `Microsoft.FeatureManagement` internally. Consumers see only `IFeatureGate`; the SDK is hidden.

**ADR-0055 D9 — Local-dev affordances.** Label-aware refresh: hosts wire App Configuration with `.UseFeatureFlags(...).Select(label: env)` so the dev/staging/prod/ci label scope determines the active flag values. Document this in the README and in `AddFeatureFlags`'s XML-doc.

**ADR-0055 D14 Phase 1 — Standup.** "Stand up the `HoneyDrunk.FeatureFlags` Node with the `Microsoft.FeatureManagement.AzureAppConfiguration`-backed implementation, the `TenantTargetingFilter`, and the App Configuration label conventions per D9." This packet executes Phase 1.

## Constraints
- **Invariant 1 — Abstractions zero-dependency.** This Node's runtime references `Microsoft.FeatureManagement.AzureAppConfiguration` — fine for a runtime package. But `HoneyDrunk.Kernel.Abstractions` (the contract source) stays zero-HoneyDrunk-dependency; do NOT push any internal type back up into `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 4 — DAG; Kernel is at the root.** This Node depends on `HoneyDrunk.Kernel.Abstractions` only. No other HoneyDrunk runtime package.
- **First new ADR-0055 invariant — `IFeatureGate` is the only sanctioned evaluation surface.** Consumers of this Node compose `AddFeatureFlags` and depend on `IFeatureGate`; they do not (and must not) reach for `IFeatureManager` directly. Document this on `AddFeatureFlags`'s XML-doc.
- **Invariant 11 — One repo per Node.** This Node is its own repo per ADR-0055 D4.
- **Invariant 12 — CHANGELOG + README on every package from the first commit.** Both files ship.
- **Invariant 13 — XML documentation on every public API.**
- **Invariant 14 — Contract-shape canary.** The Node's CI includes a canary against `HoneyDrunk.Kernel.Abstractions` (the source of `IFeatureGate`).
- **Invariant 15 — Unit tests no external services.** Unit tests use a faked `IFeatureManager` and a faked `ITargetingContextAccessor`. The canary may use `InMemoryFeatureManager` or similar if `Microsoft.FeatureManagement` ships such a fixture.
- **Invariant 16 — No test code in runtime packages.**
- **Invariant 26 — `HoneyDrunk.Standards` `PrivateAssets: all` on every new .NET project.**
- **Invariant 27 — One version across the solution.** v0.1.0 standup baseline.
- **Invariant 31 / 52 — pr-core tier-1 gate + cloud-wired review.** CI wires both.
- **Invariant 51 — No `Thread.Sleep` in test code.**

## Labels
`feature`, `tier-2`, `core`, `scaffold`, `adr-0055`, `wave-3`

## Agent Handoff

**Objective:** Stand up the `HoneyDrunk.FeatureFlags` Node — solution, the App-Configuration-backed `IFeatureGate` implementation, the `TenantTargetingFilter`, the `AddFeatureFlags` DI extension, CI, tests, canary — and ship v0.1.0.

**Target:** `HoneyDrunk.FeatureFlags`, branch from `main`.

**Context:**
- Goal: Provide the concrete flag-system implementation that every consuming Node composes; preserve backend reversibility (D15) by depending on `IFeatureGate` from Kernel.Abstractions only, hiding `Microsoft.FeatureManagement` inside this Node.
- Feature: ADR-0055 Feature Flag rollout, Wave 3 (the substrate).
- ADRs: ADR-0055 D2/D3/D4/D9/D14 (primary), ADR-0005 (App Configuration backing — Managed Identity), ADR-0026 (RequestContext source for `ITargetingContext`), ADR-0047 (test stack), ADR-0012 (CI workflows), ADR-0044 (review agent enablement), ADR-0039 (license), ADR-0033 (release tagging is a human step).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — catalog entry for `honeydrunk-featureflags` lands before the standup so the Node is discoverable.
- `packet:02` — `featureflags-v1.json` schema exists so consumers (and this Node's documentation) can reference it.
- `packet:03` — App Configuration walkthrough extension applied so the runtime backing has a live App Configuration resource and seeded labels to wire against.
- `packet:04` — `HoneyDrunk.Kernel.Abstractions` ships `IFeatureGate` and the new minor is published; this Node compiles against the new minor.

**Constraints:**
- Single-package v1 (no `Abstractions` split — matches Audit precedent and the ADR's wording).
- No reference to non-Kernel-Abstractions HoneyDrunk packages.
- `IFeatureGate` is the only sanctioned consumer surface; document this on `AddFeatureFlags`.
- `HoneyDrunk.Standards` `PrivateAssets: all` on every project.
- v0.1.0 release baseline (per the Audit standup precedent).

**Key Files:**
- `HoneyDrunk.FeatureFlags.slnx`
- `src/HoneyDrunk.FeatureFlags/AzureAppConfigurationFeatureGate.cs`
- `src/HoneyDrunk.FeatureFlags/TenantTargetingFilter.cs`
- `src/HoneyDrunk.FeatureFlags/Hosting/FeatureFlagsServiceCollectionExtensions.cs`
- `HoneyDrunk.FeatureFlags.Tests.Unit/`, `HoneyDrunk.FeatureFlags.Tests.Canaries/`
- `.github/workflows/pr-core.yml`, `release.yml`, `nightly-*.yml`
- `.honeydrunk-review.yaml`
- Repo-level + per-package `CHANGELOG.md`, `README.md`

**Contracts:**
- Implements `IFeatureGate` (from `HoneyDrunk.Kernel.Abstractions`) via `AzureAppConfigurationFeatureGate`.
- Exposes `AddFeatureFlags(IServiceCollection, IConfiguration)` as the public DI surface.
- `TenantTargetingFilter` is registered internally; not part of the public consumer surface.
