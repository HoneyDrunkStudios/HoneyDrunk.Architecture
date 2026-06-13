# Handoff — Wave 4: First Migrants (Notify + Pulse)

**Initiative:** `adr-0065-aspire-orchestration`
**Wave transition:** Wave 2 (Standards) + Wave 3 (dev ASB provisioning) → Wave 4 (first per-Node AppHosts)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Waves 2 + 3 landed

- **Packet 02 (Standards)** — `HoneyDrunk.Standards.Aspire` ships the `HoneyDrunkAspireExtensions` static class (`AddGridTelemetry`, `AddGridCosmosEmulator`, `AddGridAzurite`, `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev`) plus the AppHost-level `AddPulseCollector(opt: false)` composition method. `HoneyDrunk.Standards.Templates.AspireAppHost` ships the `dotnet new` template. Aspire SDK is pinned at the version recorded in packet 02's PR description. `HoneyDrunk.Standards` is at the new minor version; the new packages have been tagged/released by a human, so the NuGet feed carries them.
- **Packet 03 (Architecture / Human)** — `infrastructure/walkthroughs/dev-service-bus-namespace-provisioning.md` exists, parameterised for environment, and documents manual orphan-subscription cleanup; the `sb-hd-dev` Service Bus namespace exists in the Azure subscription at Basic tier in the `dev` resource group; the connection string is stored in the chosen Key Vault (per-Node `kv-hd-notify-dev` recommended, keyed `ConnectionStrings:ServiceBus`) and never in the repo (invariants 8, 9). **The dev App Configuration resource also exists**, provisioned in the same human session via the existing `infrastructure/walkthroughs/app-configuration-provisioning.md` for `env=dev`. The ~$10/month recurring cost is recorded against the studio's Azure budget per ADR-0052.

Wave 4 turns these foundations into actual per-Node AppHosts.

## What Wave 4 must deliver

Two packets in parallel, different repos:

### Packet 04 — `HoneyDrunk.Notify` (first migrant)

Add a new `HoneyDrunk.Notify.AppHost` project to the `HoneyDrunk.Notify.slnx` solution. Compose:
- **Project resources** — `HoneyDrunk.Notify.Functions` via `AddAzureFunctionsProject<T>` (per ADR-0065's Accepted alternative); `HoneyDrunk.Notify.Worker` via `AddProject<T>`. Both call `AddGridTelemetry`.
- **Container resources** — Cosmos Emulator (`AddGridCosmosEmulator`); Azurite (`AddGridAzurite`) for the Notify intake → worker Storage Queue per ADR-0028 D2/D3.
- **Connection-string resources** — dev Service Bus (`AddGridServiceBusDev` — wired in advance for future cross-Node hops; the live in-Node intake queue uses Azurite); dev Key Vault (`AddGridKeyVaultDev`); dev App Configuration (`AddGridAppConfigDev`).
- **Pulse dual-emit** — **no `AddPulseCollector(...)` call** in packet 04. The Aspire-dashboard-only default (D4) is the operative behavior; calling the opt-in switch with `opt: false` would be dead code. The live wiring follows the container-resource path documented in packet 05's `HoneyDrunk.Pulse.AppHost/README.md`, and lands in a future packet when a Pulse.Collector container image or NuGet host package exists. Do not project-reference Pulse.
- New `HoneyDrunk.Notify.AppHost/CHANGELOG.md` + `README.md` (invariant 12). README documents the run command, composed resources, the `dotnet user-secrets` seeding using the exact `ConnectionStrings:ServiceBus` key (which Aspire's `WithReference(serviceBus)` projects as the `ConnectionStrings__ServiceBus` env var), and the future Pulse dual-emit flip procedure.
- **Version-bumping packet for `HoneyDrunk.Notify`** — every non-test `.csproj` in the solution to the same new minor version in one commit (invariant 27).

### Packet 05 — `HoneyDrunk.Pulse` (second migrant)

Add a new `HoneyDrunk.Pulse.AppHost` project to the `HoneyDrunk.Pulse.slnx` solution. **`HoneyDrunk.Pulse.Collector` already exists** (`HoneyDrunk.Pulse/Pulse.Collector/HoneyDrunk.Pulse.Collector.csproj`, `Microsoft.NET.Sdk.Web`, gRPC + OTLP receiver) — compose it by project reference; do not introduce a new Collector host. Compose:
- **Project resources** — the existing `HoneyDrunk.Pulse.Collector` via `AddProject<Projects.HoneyDrunk_Pulse_Collector>`; calls `AddGridTelemetry` for self-observability.
- **Connection-string resources** — dev Key Vault (for sink credentials — App Insights connection string per ADR-0040 packet 02's provisioning if that initiative is live; Sentry DSN if applicable; etc.); dev App Configuration.
- New `HoneyDrunk.Pulse.AppHost/CHANGELOG.md` + `README.md` (invariant 12). README documents the run command, OTLP port the Collector exposes, and the **cross-Node dual-emit composition guidance** for downstream AppHosts (container-resource recommended; interim manual path; future NuGet-host follow-up).
- **Version-bump-or-append per invariant 27** — first packet on the Pulse solution this initiative; check the in-progress Pulse version state at edit time (ADR-0040's Pulse packets may be mid-flight). If no in-progress bump, this packet bumps. If ADR-0040 already bumped, this packet appends to that version's CHANGELOG. Record which case applies in the PR description.

## Aspire APIs to use

Match the API surface of the Aspire SDK version pinned by packet 02 (recorded in packet 02's PR description). The shapes referenced in the packets:

```csharp
var builder = DistributedApplication.CreateBuilder(args);
var cosmos = builder.AddGridCosmosEmulator("notify-cosmos");
var azurite = builder.AddGridAzurite("notify-azurite");
var serviceBus = builder.AddGridServiceBusDev("grid-asb-dev");
var keyVault = builder.AddGridKeyVaultDev("notify-kv");
var appConfig = builder.AddGridAppConfigDev("notify-appconfig");

var functions = builder
    .AddAzureFunctionsProject<Projects.HoneyDrunk_Notify_Functions>("notify-functions")
    .WithReference(azurite).WithReference(cosmos).WithReference(serviceBus)
    .WithReference(keyVault).WithReference(appConfig)
    .AddGridTelemetry();

var worker = builder
    .AddProject<Projects.HoneyDrunk_Notify_Worker>("notify-worker")
    .WithReference(azurite).WithReference(cosmos).WithReference(serviceBus)
    .WithReference(keyVault).WithReference(appConfig)
    .AddGridTelemetry();

// No AddPulseCollector(...) call — D4 default behavior (Aspire-dashboard-only OTLP)
// is what packet 04 ships. The flip lands when a Pulse.Collector image/host exists.

await builder.Build().RunAsync();
```

The exact method names (`AddAzureFunctionsProject<T>`, `AddProject<T>`, `WithReference`) follow the pinned Aspire version's API. If the pinned version uses different names, use those — match the shipped Aspire surface, not the example above.

## Cross-Node Pulse.Collector composition path — recorded for packet 04

Notify's AppHost (packet 04) cannot project-reference `HoneyDrunk.Pulse` — that would invert the dependency direction (Pulse depends on Kernel; Notify depends on Kernel; neither depends on the other). The recommended cross-Node Pulse.Collector composition is:

1. **Container resource against a published Pulse.Collector image** (recommended when Pulse.Collector publishes one). When Pulse.Collector publishes an image (separate follow-up — not part of this initiative), a future packet adds `AddPulseCollector(...)` to Notify's AppHost composing via `AddContainer` against that image.
2. **Interim path** — until a published image exists, packet 04 omits the `AddPulseCollector(...)` call entirely (the D4 default OTLP-to-Aspire-dashboard-only shape is already in effect) and the developer runs Pulse's AppHost separately for Pulse-iteration scenarios. The developer points Notify's OTLP endpoint at Pulse.Collector's port manually when both AppHosts are running.
3. **Future** — a NuGet-distributed Pulse.Collector host package allows downstream AppHosts to `AddProject<T>` against the package path. Track as a follow-up.

Packet 04 ships the default-off behavior (no call); packet 05's README documents the live cross-Node path the operator chooses when an image/host exists.

## Notify-side ASB audit — record in packet 04's PR

Audit Notify's actual ASB hops at packet 04 execution time. The intake → worker hop is in-Node Storage Queue per ADR-0028 D2/D3 — that uses Azurite, not Service Bus. If Notify has zero current cross-Node ASB hops, document `Program.cs` and `README.md` so the executor and future readers understand the ASB connection is wired in advance for future hops; the live broker for v1 is Azurite.

## Frozen / do-not-touch

- **Notify's existing `launchSettings.json` composition** — keep it. The AppHost is additive; the existing local-dev path may coexist during the transition. A future cleanup packet may remove `launchSettings.json`-based composition; this initiative does not.
- **Notify's domain logic** — invariant 41: preference/cadence/suppression logic lives in Communications, not Notify. The AppHost composes Notify's existing entry points without modifying any domain logic.
- **Notify's production Bicep** (and Pulse's) — D5: Aspire is local-dev only. No production deployment surface is modified.
- **`ITransportEnvelope`, ASB sink configuration, OTel exporter wiring** — Pulse's existing telemetry contracts. Packet 05 does not modify them; the existing `HoneyDrunk.Pulse.Collector` project is composed by project reference, not edited.

## Invariants binding Wave 4

- **Invariant 27** — one version across each solution. Notify (packet 04) bumps; Pulse (packet 05) bumps or appends per the in-progress version state.
- **Invariant 12** — new AppHost packages get `CHANGELOG.md` + `README.md` from the first commit. Unchanged packages (including the existing `HoneyDrunk.Pulse.Collector`) get no per-package CHANGELOG entry (alignment bump only).
- **Invariant 26** — new projects reference `HoneyDrunk.Standards` with `PrivateAssets: all`.
- **Invariant 41** — preference/cadence/suppression logic stays in Communications, not Notify. Packet 04 touches no Notify domain logic.
- **D5** — Aspire is local-dev only. No `azd` wiring, no generated production Bicep, no production-deployment files in either packet.
- **D7** — multi-process Nodes must have an AppHost; single-process Nodes may; library-only Nodes do not. Notify and Pulse are the first two multi-process Nodes to land their AppHost; both are *required* by the first new invariant.

## Acceptance gate for the wave

Both packets pass `pr-core.yml` tier-1. Both bump (or, for Pulse, bump-or-append) per invariant 27. Both AppHosts compile (`dotnet build` succeeds) and (developer-verified, captured in PR descriptions, not in CI) launch under `dotnet run --project {Node}.AppHost`. The Aspire dashboard opens; the composed project resources start; container resources start under Docker Desktop. CI does **not** launch the AppHosts (per D10 — Aspire is not in CI).

After this wave, Notify and Pulse have working local-dev inner loops aligned with the Grid's Aspire stance. The pattern is in place for Communications (when its worker arrives), the AI-sector seed Nodes (at first feature packet), Notify Cloud (at standup), Audit (at first feature packet), and any future multi-process Node.
