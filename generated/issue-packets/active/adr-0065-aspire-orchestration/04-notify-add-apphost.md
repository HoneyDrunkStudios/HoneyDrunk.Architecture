---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0065", "wave-4"]
dependencies: ["packet:02", "packet:03"]
adrs: ["ADR-0065"]
wave: 4
initiative: adr-0065-aspire-orchestration
node: honeydrunk-notify
---

# Add HoneyDrunk.Notify.AppHost — Notify is the first migrant to Aspire

## Summary
Add a `HoneyDrunk.Notify.AppHost` project to the `HoneyDrunk.Notify` solution: model Notify's Functions process, Notify's Worker process, the Cosmos Emulator, Azurite (for Notify's Storage Queue intake), the dev Service Bus connection (via `AddGridServiceBusDev`), the dev Key Vault connection, the dev App Configuration connection, and Pulse.Collector (opt-in dual-emit per D4). This is Notify's local-dev inner loop and the first per-Node Aspire migration in the Grid per ADR-0065 D7.

## Context
ADR-0065 D7 names Notify as the first migrant: Notify's Functions + Worker is the first multi-process composition; Notify's AppHost lands as part of the imminent Notify dev-deploy work. ADR-0065 also commits "Aspire ships first-party support for Azure Functions project resources; Notify's Functions process composes via `AddAzureFunctionsProject<T>` — recorded so the Notify migration packet uses the supported pattern from day one." (Alternatives Considered — "Adopt Aspire's Azure Functions project resource for Notify's Functions process" — Accepted.)

`HoneyDrunk.Notify` is a live Node currently at v0.2.0 with the package family `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Notify`, `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.HostBootstrap`, `HoneyDrunk.Notify.Hosting.AspNetCore`, `HoneyDrunk.Notify.ProviderSupport`, `HoneyDrunk.Notify.Providers.Email.Resend`, `HoneyDrunk.Notify.Providers.Email.Smtp`, `HoneyDrunk.Notify.Providers.Sms.Twilio`, `HoneyDrunk.Notify.Queue.Abstractions`, `HoneyDrunk.Notify.Queue.AzureStorage`, `HoneyDrunk.Notify.Queue.InMemory`, `HoneyDrunk.Notify.Tools`, `HoneyDrunk.Notify.Worker` (per the existing solution layout). Notify's two runtime entry points are **Functions** (`HoneyDrunk.Notify.Functions`) and **Worker** (`HoneyDrunk.Notify.Worker`). The AppHost composes both.

Per ADR-0065 D3, Notify's AppHost models:
- **Project resources** — `HoneyDrunk.Notify.Functions` (via `AddAzureFunctionsProject<T>` per the Accepted alternative), `HoneyDrunk.Notify.Worker` (via `AddProject<T>`), and (D4 opt-in) `HoneyDrunk.Pulse.Collector` if Pulse-iteration mode is enabled.
- **Container resources** — Cosmos Emulator (`AddGridCosmosEmulator` from packet 02), Azurite (`AddGridAzurite` for the Storage Queue intake per ADR-0028 D2/D3 Notify-internal queue).
- **Connection-string resources** — Service Bus (`AddGridServiceBusDev`), Key Vault (`AddGridKeyVaultDev`), App Configuration (`AddGridAppConfigDev`).
- **OTLP** — every project resource calls `AddGridTelemetry` so OTLP ships to Aspire's dashboard by default, with optional fan-out to Pulse.Collector.

This packet **adds the AppHost; it does not migrate Notify's existing `launchSettings.json` away**. Per ADR-0065 D7, the AppHost is the canonical inner loop going forward, but the existing `launchSettings.json` can remain in place during the transition (the developer chooses which to run). A future cleanup packet may remove the `launchSettings.json`-based composition; this packet does not.

Per invariant 27, this packet is the first packet on the `HoneyDrunk.Notify` solution in this initiative — it bumps the whole solution to a new minor version (new project added to the solution; functional change). Confirm Notify's current version at execution time and bump to the next minor.

`HoneyDrunk.Notify.AppHost` is a new project — it needs `CHANGELOG.md` and `README.md` from the first commit (invariant 12).

> **Notify's intake → worker hop is in-Node.** ADR-0028 D2/D3 (Notify intake → worker via `HoneyDrunk.Notify.Queue.*`, an Azure Storage Queue) is an in-Node queue, not a Service Bus hop. Notify's AppHost models that Azure Storage Queue via Azurite (`AddGridAzurite`), not Service Bus. The `AddGridServiceBusDev` connection in the AppHost is for any **cross-Node** Service Bus hops Notify produces or consumes (today: none for the in-Node queue, but the connection is wired so that future cross-Node hops have it in place). If Notify has zero current Service Bus hops, document that in the AppHost's `Program.cs` as a future-readiness composition and call out the Storage Queue as the live one.

## Scope
- New project `HoneyDrunk.Notify.AppHost` in the `HoneyDrunk.Notify.slnx` solution:
  - SDK: `Microsoft.NET.Sdk`, `OutputType=Exe`.
  - `PackageReference` to Aspire AppHost SDK, `HoneyDrunk.Standards` (`PrivateAssets: all`), `HoneyDrunk.Standards.Aspire` (the Grid extensions from packet 02).
  - `ProjectReference` to `HoneyDrunk.Notify.Functions` and `HoneyDrunk.Notify.Worker` (so the AppHost can compose them as project resources).
  - `Program.cs` composing the resources per the Proposed Implementation below.
- `HoneyDrunk.Notify.AppHost/CHANGELOG.md` + `README.md` (new project — invariant 12).
- Solution `.slnx` updated to include the new project.
- Version bump across the `HoneyDrunk.Notify` solution (invariant 27); repo-level `CHANGELOG.md` new version entry.

NOT in scope:
- Removing Notify's existing `launchSettings.json` composition — keep it; AppHost is the new canonical inner loop but the old composition can coexist during the transition.
- Production Bicep changes — D5: Aspire is local-dev only; production deployment authoring stays in `HoneyDrunk.Standards` shared workflows + curated Bicep per ADR-0015.
- Wiring `AddPulseCollector(...)` for Pulse dual-emit. The default OTLP shape (Aspire dashboard only — D4 default) is already in effect without any call; calling the opt-in switch with `opt: false` would be dead code. The future flip lands when a Pulse.Collector container image or NuGet host package becomes available (the composition path is documented in packet 05's `HoneyDrunk.Pulse.AppHost/README.md`). This packet documents the procedure in `HoneyDrunk.Notify.AppHost/README.md` but does not pre-wire it.

## Proposed Implementation

1. **Scaffold from the Standards template.** Use the `HoneyDrunk.Standards.Templates.AspireAppHost` template from packet 02 to generate the AppHost project (or scaffold by hand if the template path is not yet wired into `dotnet new`). The template produces the project file, `.template.config`-free starter `Program.cs`, and the standard `HoneyDrunk.Standards` analyzer baseline.

2. **`Program.cs`** — compose the Notify inner loop:
   ```csharp
   var builder = DistributedApplication.CreateBuilder(args);

   // Backing infrastructure
   var cosmos = builder.AddGridCosmosEmulator("notify-cosmos");
   var azurite = builder.AddGridAzurite("notify-azurite");
   var serviceBus = builder.AddGridServiceBusDev("grid-asb-dev");
   var keyVault = builder.AddGridKeyVaultDev("notify-kv");
   var appConfig = builder.AddGridAppConfigDev("notify-appconfig");

   // Notify's two runtime entry points
   var functions = builder
       .AddAzureFunctionsProject<Projects.HoneyDrunk_Notify_Functions>("notify-functions")
       .WithReference(azurite)
       .WithReference(cosmos)
       .WithReference(serviceBus)
       .WithReference(keyVault)
       .WithReference(appConfig)
       .AddGridTelemetry();

   var worker = builder
       .AddProject<Projects.HoneyDrunk_Notify_Worker>("notify-worker")
       .WithReference(azurite)
       .WithReference(cosmos)
       .WithReference(serviceBus)
       .WithReference(keyVault)
       .WithReference(appConfig)
       .AddGridTelemetry();

   // Pulse dual-emit (D4) — NOT wired in this packet. Default behavior ships OTLP to the
   // Aspire dashboard only. When a Pulse.Collector container image (or NuGet host package)
   // becomes available, a future packet adds the AddPulseCollector(...) composition here.
   // See HoneyDrunk.Notify.AppHost/README.md for the flip procedure.

   await builder.Build().RunAsync();
   ```
   The exact Aspire API surface depends on the pinned version from packet 02; match those exact extension method shapes. Use `WithReference` (or its current Aspire equivalent) to inject the connection-string environment variables Notify's Functions/Worker need (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, the Storage Queue connection, the Service Bus connection, the Cosmos connection) — match the env var names Notify already consumes in its `IConfiguration`/`ISecretStore` paths so no Notify runtime code change is needed.

   > **Service Bus connection-string env var name.** `AddGridServiceBusDev` reads the connection string from the `ConnectionStrings:ServiceBus` configuration key (sourced from `dotnet user-secrets`). Per Aspire's connection-string resource convention, `WithReference(serviceBus)` projects the value into the consuming process as the environment variable `ConnectionStrings__ServiceBus` (the standard ASP.NET configuration name-to-env-var mapping — double-underscore separator). Notify's existing `IConfiguration` already binds `ConnectionStrings:ServiceBus`, so no Notify runtime code change is needed. **Pin this exact key in both the user-secrets seeding step (packet 03 walkthrough) and the Notify configuration binding** so the walkthrough, the extension, and the consumer all agree on one name.

   > **Why no `AddPulseCollector(opt: false)` line.** Calling the opt-in switch with `opt: false` is dead code — the default `Program.cs` already ships OTLP to the Aspire dashboard only (D4 default behavior). The future flip is documented in `HoneyDrunk.Notify.AppHost/README.md` under "Enabling Pulse dual-emit"; the actual `AddPulseCollector(...)` invocation lands as part of the packet that introduces a Pulse.Collector container image or NuGet host package (the container-resource composition path documented in packet 05's README).

3. **Service Bus connection — future-readiness.** Audit Notify's actual ASB use today. If Notify has zero current ASB producers/consumers (the intake → worker hop is Storage Queue per ADR-0028 D2/D3), document in `Program.cs` and `README.md` that the ASB connection is wired in advance for future cross-Node hops; the live broker for v1 is Azurite. If Notify already has ASB hops (e.g. for a future BillingEvent emit), keep the ASB reference live.

4. **`HoneyDrunk.Notify.AppHost.csproj`**:
   - SDK: `Microsoft.NET.Sdk` with `OutputType=Exe` and the Aspire AppHost target the template establishes.
   - `IsAspireHost=true`.
   - `PackageReference` to Aspire AppHost SDK + Aspire integrations (Cosmos, Storage, Service Bus, Key Vault, App Configuration, Azure Functions) at the version Standards pinned in packet 02.
   - `PackageReference` to `HoneyDrunk.Standards` (`PrivateAssets: all`) and `HoneyDrunk.Standards.Aspire` (the version released after packet 02 merges).
   - `ProjectReference` to `HoneyDrunk.Notify.Functions` and `HoneyDrunk.Notify.Worker`.

5. **Solution + version bump.**
   - Add `HoneyDrunk.Notify.AppHost` to `HoneyDrunk.Notify.slnx`.
   - Bump every non-test `.csproj` in the solution to the same new minor version in one commit (invariant 27). New project added to the solution counts as functional change — minor bump.
   - Repo-level `CHANGELOG.md` new version entry describing the AppHost addition.
   - Per-package `CHANGELOG.md`: only `HoneyDrunk.Notify.AppHost` gets a new-package entry (the package itself is new). Other Notify packages get alignment-bump only — no per-package CHANGELOG noise (invariants 12/27).
   - `HoneyDrunk.Notify.AppHost/README.md` documents how to run the AppHost (`dotnet run --project HoneyDrunk.Notify.AppHost`), what it composes, the `dotnet user-secrets` seeding required for `AddGridServiceBusDev` (using the exact key `ConnectionStrings:ServiceBus` — same key the packet 03 walkthrough documents), and **how to enable Pulse dual-emit in the future**: when a Pulse.Collector container image (or NuGet host package) becomes available, add the `AddPulseCollector(...)` call to `Program.cs` per the container-resource composition path documented in `HoneyDrunk.Pulse.AppHost/README.md` from packet 05. Until then the AppHost ships OTLP to the Aspire dashboard only.

6. **Verify the AppHost compiles and launches.** Run `dotnet build` and (locally) `dotnet run --project HoneyDrunk.Notify.AppHost` to confirm the AppHost stands up: the Aspire dashboard URL opens, the Functions + Worker projects start, the Cosmos Emulator and Azurite containers start under Docker Desktop, the Service Bus dev connection resolves from user-secrets, and OTLP traces appear in the dashboard. (This is a developer-side verification — the CI gate is `dotnet build`; full launch is not part of CI per D10.)

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/HoneyDrunk.Notify.AppHost.csproj` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/Program.cs` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/CHANGELOG.md` (new, invariant 12)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/README.md` (new, invariant 12)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.slnx` — new project entry
- Every non-test `.csproj` in the solution — version bump (invariant 27)
- Repo-level `CHANGELOG.md` — new minor version entry

## NuGet Dependencies

`HoneyDrunk.Notify.AppHost` — new `PackageReference` set:
- The Aspire AppHost SDK + Aspire integrations packages (Cosmos, Storage, Service Bus, Key Vault, App Configuration, Azure Functions) at the version Standards pinned in packet 02.
- `HoneyDrunk.Standards` (`PrivateAssets: all`) at the new published version from packet 02.
- `HoneyDrunk.Standards.Aspire` at the new published version from packet 02.
- `ProjectReference` to `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.Worker`.

No other Notify project gains a new `PackageReference` in this packet — the AppHost composes existing projects; the existing projects' DI/config does not need to change.

Confirm the exact `HoneyDrunk.Standards` / `HoneyDrunk.Standards.Aspire` versions at execution time — they are set by packet 02's bump.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Notify` — the new AppHost composes Notify's existing Functions + Worker projects. Routing rule "notification, email, SMS, ... notify, channel → HoneyDrunk.Notify" maps here.
- [x] No contract change in Notify's existing packages; the AppHost is additive.
- [x] No reference from Notify to `HoneyDrunk.Pulse` runtime code — the Pulse.Collector composition uses Aspire's container or external-project resource mechanism, never a Pulse project reference (which would invert the dependency direction and pull Pulse into Notify's build).
- [x] Notify decision logic stays in Communications (invariant 41) — the AppHost touches no domain logic, only orchestration metadata.

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify.AppHost` project exists, is `OutputType=Exe`, and is included in `HoneyDrunk.Notify.slnx`
- [ ] `Program.cs` composes Cosmos Emulator, Azurite, dev Service Bus connection, dev Key Vault connection, dev App Configuration connection, the `HoneyDrunk.Notify.Functions` project via `AddAzureFunctionsProject<T>`, and the `HoneyDrunk.Notify.Worker` project via `AddProject<T>` — all using the Grid extensions from `HoneyDrunk.Standards.Aspire`
- [ ] Both project resources call `AddGridTelemetry` for OTLP wiring (Aspire-dashboard default, per D4)
- [ ] No `AddPulseCollector(...)` call appears in `Program.cs`; the default-off behavior is the Aspire-dashboard-only OTLP shape, and the README documents the future flip
- [ ] The user-secrets key for ASB is exactly `ConnectionStrings:ServiceBus` (projected by Aspire's `WithReference(serviceBus)` to the `ConnectionStrings__ServiceBus` env var) — consistent with the packet 03 walkthrough's seeding command and Notify's existing `IConfiguration` binding
- [ ] `dotnet build HoneyDrunk.Notify.slnx` succeeds
- [ ] `dotnet run --project HoneyDrunk.Notify.AppHost` launches the Aspire dashboard, starts Functions + Worker, and starts the Cosmos Emulator + Azurite containers under Docker Desktop (developer verification — captured in the PR description, not in CI)
- [ ] `HoneyDrunk.Notify.AppHost/README.md` documents the run command, the composed resources, the `dotnet user-secrets` seeding for ASB with the exact `ConnectionStrings:ServiceBus` key, and the future Pulse dual-emit flip procedure
- [ ] `HoneyDrunk.Notify.AppHost/CHANGELOG.md` exists with the initial entry
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new minor version entry describing the AppHost addition
- [ ] Per-package CHANGELOGs of unchanged Notify projects get NO entry (alignment bump only, invariants 12/27)
- [ ] No production deployment surface modified (D5 — Aspire is local-dev only)
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Publish `HoneyDrunk.Standards` (with `HoneyDrunk.Standards.Aspire` and `HoneyDrunk.Standards.Templates.AspireAppHost`) before this packet builds.** Packet 02 ships those packages; a human pushes the git release tag on `HoneyDrunk.Standards` after packet 02 merges. Agents never tag or publish. Wave 4 cannot build against unpublished Standards packages.
- [ ] **The `sb-hd-dev` Service Bus namespace must exist.** Packet 03 provisions it (Actor=Human). The AppHost's `AddGridServiceBusDev` resolves a connection string at launch — without the namespace, launch fails (build still succeeds; runtime launch fails).
- [ ] **Notify's dev Key Vault (`kv-hd-notify-dev`) must exist** with the Service Bus connection string and any other Notify secrets seeded. If the vault does not yet exist, create it per `infrastructure/walkthroughs/key-vault-creation.md`.
- [ ] **The dev App Configuration resource must exist** for `AddGridAppConfigDev` to resolve. Packet 03 provisions it in the same human session as the ASB namespace (executing the existing `infrastructure/walkthroughs/app-configuration-provisioning.md` for `env=dev`). Build succeeds without it; runtime launch fails.
- [ ] **Developer-side `dotnet user-secrets` seeding** — the developer runs `dotnet user-secrets set "ConnectionStrings:ServiceBus" "<connection-string>" --project HoneyDrunk.Notify.AppHost` once per fresh box, with the connection string read from `kv-hd-notify-dev`. The key name `ConnectionStrings:ServiceBus` is load-bearing — it is the exact key `AddGridServiceBusDev` resolves in packet 02, the key documented in the packet 03 walkthrough, and the key Notify's existing `IConfiguration` binds. (The walkthrough in packet 03 documents this; not a packet-merge prerequisite, only a launch prerequisite.)
- [ ] **Docker Desktop running on the developer's box** for the Cosmos Emulator + Azurite containers. Not a build-time prerequisite; launch-time only.

## Referenced ADR Decisions
**ADR-0065 D2 — Per-Node AppHost.** Each containerized Node's repo includes a `{Node}.AppHost` project alongside its main solution; the default `dotnet run --project {Node}.AppHost` launches the Node's local inner loop.

**ADR-0065 D3 — Resource modeling.** Project resources for `.NET` processes, container resources for emulators (Cosmos, Azurite), connection-string resources for non-emulated dev services (Service Bus, Key Vault, App Configuration).

**ADR-0065 D4 — Pulse integration, opt-in dual-emit.** Default ships OTLP to Aspire's dashboard only; opt-in `AddPulseCollector` adds Pulse.Collector and fans out OTLP.

**ADR-0065 D7 — Notify is the first migrant.** Notify's AppHost lands as part of the Notify-dev-deploy work.

**ADR-0065 Alternatives Considered (Accepted) — Aspire's Azure Functions project resource.** Notify's Functions process composes via `AddAzureFunctionsProject<T>` (first-party Aspire support).

**ADR-0065 D5 — Production deployment is separate.** Nothing in this packet wires `azd` or generates production Bicep. The AppHost is local-dev only.

**ADR-0028 D2/D3 — Notify's intake → worker queue is in-Node Storage Queue.** Notify's AppHost models that Azure Storage Queue via Azurite, not Service Bus. The Service Bus connection is wired for future cross-Node hops; the live broker for v1 is Azurite.

## Constraints
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` together. This is the bumping packet for `HoneyDrunk.Notify` in this initiative; the bump is minor (new project added — functional change).
- **Invariant 12 — CHANGELOG/README discipline.** New `HoneyDrunk.Notify.AppHost` package gets `CHANGELOG.md` + `README.md` from this commit. Unchanged packages get NO per-package CHANGELOG entry.
- **Invariant 26 — analyzer baseline.** The new AppHost project references `HoneyDrunk.Standards` with `PrivateAssets: all`.
- **Invariant 41 — preference/cadence/suppression logic lives in Communications, not Notify.** The AppHost composes Notify's existing entry points; no domain logic moves.
- **D5 — Aspire is local-dev only.** No `azd` wiring, no generated production Bicep, no production-deployment files. The Notify production deployment continues to be the existing `HoneyDrunk.Standards` shared workflow + curated Bicep per ADR-0015.
- **No Pulse runtime dependency.** Pulse.Collector composes via Aspire container/external-project resource, never via Notify referencing the Pulse runtime project (which would invert the build dependency).
- **No `AddPulseCollector(opt: false)` placeholder call.** The opt-in switch with `opt: false` is dead code — the Aspire-dashboard-only default already provides that behavior. The future flip is README-documented; the actual call lands when a Pulse.Collector container image or NuGet host package exists.
- **Pin `ConnectionStrings:ServiceBus` as the canonical key.** The packet 03 walkthrough's user-secrets seeding command, packet 02's `AddGridServiceBusDev` resolution, and Notify's existing `IConfiguration` binding all use this exact key. Aspire's `WithReference(serviceBus)` projects it to the env var `ConnectionStrings__ServiceBus`.

## Labels
`feature`, `tier-2`, `ops`, `adr-0065`, `wave-4`

## Agent Handoff

**Objective:** Add `HoneyDrunk.Notify.AppHost` as Notify's local-dev inner loop — the first per-Node Aspire migration in the Grid.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Replace the imminent ad-hoc Notify multi-process inner loop with a structured Aspire-modeled composition.
- Feature: ADR-0065 Multi-Service Local Dev Orchestration rollout, Wave 4 (first migrants — parallel with packet 05 Pulse).
- ADRs: ADR-0065 D2/D3/D4/D5/D7 (primary), ADR-0028 D2/D3 (Notify queue is in-Node), ADR-0015 (production deployment authority — unchanged).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `HoneyDrunk.Standards.Aspire` and the AppHost template ship; the AppHost references them.
- `packet:03` — the `sb-hd-dev` namespace exists so `AddGridServiceBusDev` resolves a real broker at launch.

**Constraints:**
- The AppHost is local-dev only — no production deployment surface (D5).
- Bump the whole solution one minor version (invariant 27).
- Notify decision logic stays in Communications (invariant 41) — touch no domain logic.
- Pulse dual-emit defaults to off via the Aspire-dashboard-only OTLP shape; no `AddPulseCollector(...)` call is added in this packet. The future flip is README-documented and lands when a Pulse.Collector container image or NuGet host package is available (packet 05 documents the composition path).

**Key Files:**
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/Program.cs` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/HoneyDrunk.Notify.AppHost.csproj` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.AppHost/CHANGELOG.md` + `README.md` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.slnx` (new project entry)
- Every non-test `.csproj` for the version bump; repo-level `CHANGELOG.md`

**Contracts:** None changed — the AppHost composes Notify's existing entry points without modifying their public surface.
