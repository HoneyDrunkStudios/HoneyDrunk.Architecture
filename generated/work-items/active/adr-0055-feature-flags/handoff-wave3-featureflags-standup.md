# Handoff — Wave 3: HoneyDrunk.FeatureFlags Node Standup

**Initiative:** `adr-0055-feature-flags`
**Wave transition:** Wave 2 (Kernel contract) → Wave 3 (FeatureFlags Node standup)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Waves 1–2 landed

- **Packet 00** — ADR-0055 flipped to **Accepted**. Two new invariants added to `constitution/invariants.md` under a new `## Feature Flag Invariants` section (the executor picked the next two free numbers at edit time — verified max at scoping was 53; confirm in the file at execution time):
  1. **Feature flags are evaluated through `IFeatureGate`, never via direct SDK calls to `Microsoft.FeatureManagement` or the App Configuration client.** Preserves backend reversibility (D15) + audit hookup + PII scrubbing on log emission.
  2. **Feature-flag names follow `{category}.{node}.{feature}` and are registered in the consuming Node's `featureflags.json` before first use.** CI gate per D6; regex `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$`.
- **Packet 01** — `IFeatureGate`, `ITargetingContext`, `InMemoryFeatureGate` registered under `honeydrunk-kernel` in `catalogs/contracts.json` and `catalogs/relationships.json`. New Node entry `honeydrunk-featureflags` added to `catalogs/nodes.json` and `catalogs/grid-health.json` (Seed, v0.0.0). Notify and Operator `consumes_detail` enriched with the new Kernel contracts.
- **Packet 02** — `schemas/featureflags-v1.json` ships the JSON Schema document for per-Node `featureflags.json` registries; `docs/feature-flags-registry-format.md` is the human-readable guide. The schema is pinned to `https://schemas.honeydrunkstudios.com/featureflags-v1.json` (or the in-repo fallback path if Studios isn't yet serving it — recorded in packet 02).
- **Packet 03** — App Configuration provisioning walkthrough extended with the "Feature-Flag Surface (ADR-0055)" section; D9 label conventions (`dev`/`staging`/`prod`/`ci`) documented and seeded in the dev App Configuration resource.
- **Packet 04** — `HoneyDrunk.Kernel.Abstractions` ships `IFeatureGate`, `ITargetingContext`, `TargetingContext` record; `HoneyDrunk.Kernel.Abstractions.Testing` ships `InMemoryFeatureGate`. The `HoneyDrunk.Kernel` solution bumped to its new minor (confirm the version at execution time — the bump may be `0.8.0` or `0.9.0` depending on whether ADR-0042's `0.8.0` shipped first).

ADR-0055's decisions are now live rules. The contract surface in Kernel.Abstractions is the foundation packets 05–08 build on.

## What Wave 3 must deliver (packet 05)

Stand up `HoneyDrunk.FeatureFlags` end-to-end from an empty GitHub repo. The Node is **Core sector**, ships **one runtime package** (`HoneyDrunk.FeatureFlags`) — no `Abstractions` split at v1 because the abstraction (`IFeatureGate`) lives in `HoneyDrunk.Kernel.Abstractions` per D4. The release baseline is **v0.1.0** (matches the HoneyDrunk.Audit standup precedent).

The package contains:
- **`AzureAppConfigurationFeatureGate`** — implements `IFeatureGate` over `Microsoft.FeatureManagement.IFeatureManagerSnapshot`, with the `ITargetingContextAccessor` resolving `ITargetingContext` from the ambient `HoneyDrunk.Kernel` `RequestContext` per ADR-0026.
- **`TenantTargetingFilter`** — `[FilterAlias("TenantTargeting")]` custom `IFeatureFilter`; matches `RequestContext.TenantId` / `Tier` against the flag's `tenants` / `tiers` configuration, falls back to `default_rollout_percentage`. JSON shape per ADR-0055 D3 example.
- **`AddFeatureFlags(IServiceCollection, IConfiguration)`** — the single public DI entry point.
- Tests + canary (`HoneyDrunk.FeatureFlags.Tests.Unit`, `HoneyDrunk.FeatureFlags.Tests.Canaries`) verifying the `IFeatureGate` contract shape against `HoneyDrunk.Kernel.Abstractions` per invariant 14.
- CI workflows wired per ADR-0012 (pr-core, release, nightly-security, nightly-deps); `.honeydrunk-review.yaml` enabled per ADR-0044.
- Repo-level + per-package CHANGELOG and README (invariant 12).

## Why one package and not an Abstractions split

ADR-0055 D4 names a single concrete package `HoneyDrunk.FeatureFlags`. The Grid's normal Abstractions/runtime split is unnecessary here because the abstraction (`IFeatureGate`) already lives in `HoneyDrunk.Kernel.Abstractions`. No second contract surface ships from this Node at v1 — `TenantTargetingFilter` is internal/registered-via-DI, not a public consumer surface.

When D15 escalation fires (e.g., LaunchDarkly becomes the backing), the split happens then: `HoneyDrunk.FeatureFlags.Abstractions` extracts host-options; `HoneyDrunk.FeatureFlags.AzureAppConfiguration` and `HoneyDrunk.FeatureFlags.LaunchDarkly` are sibling backings. v1 does not speculatively split.

## Why no `.Testing` package from this Node

`InMemoryFeatureGate` is the test fixture, and it lives in `HoneyDrunk.Kernel.Abstractions.Testing` (packet 04) — every flag-consuming Node uses that. There is no concrete need at v1 for a fixture that exercises the App-Configuration-backed runtime in process; if a real consumer needs one later, it's a small follow-up.

## Interface signatures for Wave 4

`AddFeatureFlags` — the host composition entry point packets 07 and 08 consume:

```csharp
public static IServiceCollection AddFeatureFlags(
    this IServiceCollection services,
    IConfiguration config);
```

Consumers compose:

```csharp
builder.Configuration.AddAzureAppConfiguration(opt =>
{
    opt.Connect(new Uri(builder.Configuration["AppConfig:Endpoint"]!),
               new ManagedIdentityCredential())
       .Select(KeyFilter.Any, label: env)
       .UseFeatureFlags(ff => ff.Label = env)
       .ConfigureRefresh(r => r.Register("FeatureManagement:Sentinel", refreshAll: true)
                               .SetCacheExpiration(TimeSpan.FromSeconds(30)));
});
builder.Services.AddFeatureFlags(builder.Configuration);
```

The composition wires `IFeatureManagement`, the App Configuration push-refresh, the `TenantTargetingFilter`, and the `IFeatureGate` (scoped) registration in one call.

## Frozen / do-not-touch

- **`HoneyDrunk.Kernel.Abstractions` is at packet 04's published minor.** Do not modify it from this packet. New contracts in Kernel.Abstractions are out of scope.
- **`Microsoft.FeatureManagement` types must not leak into the consumer's compile surface.** Per the first new ADR-0055 invariant ("evaluated through `IFeatureGate`, never via direct SDK calls"), consumers depend on `IFeatureGate`; the `IFeatureManager`, `IFeatureManagerSnapshot`, `IFeatureFilter` types stay inside this package. The public surface of `HoneyDrunk.FeatureFlags` is `AddFeatureFlags` (and the implementation classes if they need to be public for DI registration); the consumer's compile-time view is `IFeatureGate` only.
- **No HoneyDrunk runtime dependency beyond `HoneyDrunk.Kernel.Abstractions`.** No Pulse, no Audit, no Vault, no Transport. App Configuration is Managed-Identity-accessed per ADR-0005; no `ISecretStore` consumed here. Pulse logging composition happens at the host, not in this package.

## Invariants binding Wave 3

- **Invariant 1** — `HoneyDrunk.Kernel.Abstractions` stays zero-HoneyDrunk-dependency; the FeatureFlags Node references it normally but does NOT push types back up into Kernel.
- **Invariant 4** — DAG; this Node depends on `HoneyDrunk.Kernel.Abstractions` only among HoneyDrunk packages.
- **Invariant 11** — One repo per Node. `HoneyDrunk.FeatureFlags` is its own repo.
- **Invariant 12** — CHANGELOG + README on every package from the first commit.
- **Invariant 13** — XML documentation on every public API; document the "only sanctioned evaluation surface" on `IFeatureGate`-consuming types.
- **Invariant 14** — Contract-shape canary against `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 15** — Unit tests use no external services; use faked `IFeatureManager`.
- **Invariant 16** — No test code in runtime packages.
- **Invariant 26** — `HoneyDrunk.Standards` `PrivateAssets: all` on every project.
- **Invariant 27** — v0.1.0 baseline; one version across the solution.
- **Invariant 31 / 52** — `pr-core.yml` tier-1 gate + cloud-wired review.
- **Invariant 51** — No `Thread.Sleep` in test code.

## Acceptance gate for the wave

Packet 05's PR passes the `pr-core.yml` tier-1 gate; the `HoneyDrunk.FeatureFlags` solution builds; unit tests + canary pass; `HoneyDrunk.FeatureFlags` is at v0.1.0 with the contract shipped. Wave 4 (packet 06 in `HoneyDrunk.Actions` for the CI workflow + analyzer, packet 07 in `HoneyDrunk.Notify` for the pilot) can then start in parallel — though packet 07 specifically waits on both 05 and 06.

**Human package release at the Wave 3→4 boundary — agents never tag (invariant 27).** Packets 07 and 08 build against `HoneyDrunk.FeatureFlags` v0.1.0 from the NuGet feed; that artifact reaches the feed only after a human pushes the `v0.1.0` git tag in the new `HoneyDrunk.FeatureFlags` repo. After packet 05 merges, a human creates the GitHub release. Wave 4 cannot build against unpublished packages.

**Human repo-creation prerequisite for Wave 3 itself.** Packet 05 targets `HoneyDrunkStudios/HoneyDrunk.FeatureFlags` — the empty GitHub repo must exist on GitHub before the filing pipeline can file packet 05's issue. Create the repo (public per the "repos public by default" convention, standard `main`, no template, no auto-init) before pushing this folder to `main`.
