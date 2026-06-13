---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0065", "wave-4"]
dependencies: ["work-item:02"]
adrs: ["ADR-0065"]
wave: 4
initiative: adr-0065-aspire-orchestration
node: honeydrunk-pulse
---

# Add HoneyDrunk.Pulse.AppHost — Pulse is the second migrant to Aspire

## Summary
Add a `HoneyDrunk.Pulse.AppHost` project to the `HoneyDrunk.Pulse` solution: model Pulse.Collector as a project resource exposing its OTLP receiver, the backing infrastructure Pulse needs locally (Cosmos Emulator for telemetry stores or Pulse's durable state, dev Key Vault / App Configuration), the Aspire dashboard, and a canonical entry point for the dual-emit pattern from D4 — so that any Node's AppHost composing `AddPulseCollector(opt: true)` has a working Pulse.Collector to fan OTLP out to. Per ADR-0065 D7, Pulse is the second migrant because Notify's AppHost composes Pulse.Collector and Pulse should carry the canonical Pulse.Collector composition.

## Context
ADR-0065 D7 names Pulse as the second migrant: "Pulse migrates next, because Notify's AppHost composes Pulse.Collector and the Pulse repo benefits from carrying the canonical Pulse.Collector AppHost." ADR-0065 D4 names Pulse.Collector as the opt-in dual-emit destination: when an AppHost calls `AddPulseCollector(opt: true)`, Pulse.Collector composes as a project resource alongside the consuming Node's projects and OTLP is fanned out to both Aspire's dashboard and Pulse.Collector.

`HoneyDrunk.Pulse` is a live Node at version 0.3.0. Its packages include `HoneyDrunk.Telemetry.Abstractions`, `HoneyDrunk.Telemetry.OpenTelemetry`, `HoneyDrunk.Telemetry.Sink.AzureMonitor`, `HoneyDrunk.Telemetry.Sink.Loki`, `HoneyDrunk.Telemetry.Sink.Mimir`, `HoneyDrunk.Telemetry.Sink.PostHog`, `HoneyDrunk.Telemetry.Sink.Sentry`, `HoneyDrunk.Telemetry.Sink.Tempo`, `HoneyDrunk.Telemetry.Sink.Shared` (per the existing solution layout per the ADR-0040 packet 03 context note). The Pulse Node's runtime entry point is the **Pulse Collector** — the host that exposes the OTLP receiver and routes signals to its sinks. The Pulse.AppHost composes that Collector and the backing dependencies it needs locally.

> **Pulse.Collector is an existing project.** Verified at packet-authoring time: `HoneyDrunk.Pulse.Collector` ships today as a `Microsoft.NET.Sdk.Web` project at `HoneyDrunk.Pulse/Pulse.Collector/HoneyDrunk.Pulse.Collector.csproj` — a Grpc.AspNetCore-hosted OTLP receiver wired to the existing `HoneyDrunk.Telemetry.*` sinks. **This packet composes the existing Collector via `AddProject<Projects.HoneyDrunk_Pulse_Collector>("pulse-collector")`; it does not introduce a new Collector executable host.** No new project, no new public surface in Pulse — only the AppHost is net-new.

Per ADR-0065 D3, Pulse's AppHost models:
- **Project resources** — Pulse.Collector (the OTLP receiver host).
- **Container resources** — backing infrastructure Pulse needs locally for iteration (depends on what Pulse's storage/state model is locally — Cosmos Emulator, Azurite, or none if Pulse's local state is in-memory).
- **Connection-string resources** — dev Key Vault (for Pulse's sink credentials — App Insights, Sentry DSN, Loki/Mimir/Tempo endpoints; all stored in `kv-hd-pulse-dev` per ADR-0040 packet 02's provisioning), dev App Configuration.
- **OTLP** — Pulse.Collector calls `AddGridTelemetry` for its own self-observability; the dashboard surfaces Pulse's own traces alongside any other project resources it composes.

Per invariant 27, this packet is the first packet on the `HoneyDrunk.Pulse` solution in this initiative — it bumps the whole solution to a new minor version. Confirm Pulse's current version at execution time and bump to the next minor.

`HoneyDrunk.Pulse.AppHost` is a new project — it needs `CHANGELOG.md` and `README.md` from the first commit (invariant 12). The existing `HoneyDrunk.Pulse.Collector` project is unchanged by this packet (the AppHost composes it via project reference, no source edits to the Collector).

> **Sequencing note.** ADR-0040's Pulse work (packets 03/04/05/07 in the `adr-0040-telemetry-backend` initiative) extends `HoneyDrunk.Telemetry.Sink.AzureMonitor`. If ADR-0040 Pulse packets are mid-flight at execution time, the Pulse-solution version-bump rule (invariant 27) applies: only the first un-released packet bumps; the rest append to the same in-progress version's CHANGELOG. The executor checks the in-progress Pulse version state at edit time and either (a) is the bumping packet if no ADR-0040 Pulse packet has bumped yet, or (b) appends to the in-progress version if ADR-0040 already bumped. Record which case applies in the PR description.

## Scope
- New project `HoneyDrunk.Pulse.AppHost` in the `HoneyDrunk.Pulse.slnx` solution:
  - SDK: `Microsoft.NET.Sdk`, `OutputType=Exe`.
  - `PackageReference` to Aspire AppHost SDK, `HoneyDrunk.Standards` (`PrivateAssets: all`), `HoneyDrunk.Standards.Aspire`.
  - `ProjectReference` to the existing `HoneyDrunk.Pulse.Collector` project.
  - `Program.cs` composing the resources per the Proposed Implementation below.
- `HoneyDrunk.Pulse.AppHost/CHANGELOG.md` + `README.md` (new project — invariant 12).
- Solution `.slnx` updated to include the new AppHost project.
- Version bump across the `HoneyDrunk.Pulse` solution per invariant 27 (or CHANGELOG-append-only if ADR-0040 already bumped the in-progress version).

NOT in scope:
- Migrating Notify's AppHost (packet 04) to live-compose Pulse.Collector via project reference. Notify cannot project-reference Pulse without inverting the dependency direction. Notify composes Pulse.Collector via **container resource against a published Pulse.Collector image**, **external `AddProject<T>` against a Pulse.Collector NuGet/path resource**, or **leaves the dual-emit defaulted off** and the developer runs Pulse's AppHost separately for Pulse-iteration scenarios. This packet documents the recommended path in `HoneyDrunk.Pulse.AppHost/README.md`.
- Production Bicep changes (D5 — Aspire is local-dev only).
- Replacing the existing Pulse `launchSettings.json` composition — coexist during transition.

## Proposed Implementation

1. **Confirm the Pulse.Collector project path.** The existing `HoneyDrunk.Pulse.Collector` project lives at `HoneyDrunk.Pulse/Pulse.Collector/HoneyDrunk.Pulse.Collector.csproj` (`Microsoft.NET.Sdk.Web`, gRPC + OTLP receiver, already wired to the `HoneyDrunk.Telemetry.*` sinks). The AppHost composes it via `AddProject<Projects.HoneyDrunk_Pulse_Collector>("pulse-collector")` — no changes to the Collector itself.

2. **Scaffold the AppHost from the Standards template.** Use `HoneyDrunk.Standards.Templates.AspireAppHost` (packet 02) to generate the project skeleton.

3. **`Program.cs`** — compose the Pulse inner loop:
   ```csharp
   var builder = DistributedApplication.CreateBuilder(args);

   // Backing infrastructure (only what Pulse genuinely needs locally;
   // omit any resource Pulse's local-dev mode does not use)
   var keyVault = builder.AddGridKeyVaultDev("pulse-kv");
   var appConfig = builder.AddGridAppConfigDev("pulse-appconfig");
   // If Pulse's local state uses Cosmos / Azurite, add them here.

   // Pulse.Collector — the OTLP receiver
   var collector = builder
       .AddProject<Projects.HoneyDrunk_Pulse_Collector>("pulse-collector")
       .WithReference(keyVault)
       .WithReference(appConfig)
       .AddGridTelemetry();

   await builder.Build().RunAsync();
   ```
   The Pulse.Collector project name is fixed (`HoneyDrunk.Pulse.Collector`); the Aspire-generated `Projects.HoneyDrunk_Pulse_Collector` strong reference comes from the `ProjectReference` in the AppHost csproj.

4. **Document the cross-Node Pulse.Collector composition path in `README.md`.** The AppHost's README explains, for downstream Node AppHosts (Notify, Communications, etc.) that want the D4 dual-emit:
   - **Recommended (when Pulse.Collector publishes a container image):** the downstream AppHost composes Pulse.Collector via `AddContainer` against the published image — no project reference, no inverted dependency.
   - **Interim (until a Pulse.Collector image is published):** the developer runs Pulse's AppHost separately for Pulse-iteration scenarios; the downstream Node's AppHost simply omits the `AddPulseCollector(...)` call (the D4 default OTLP-to-Aspire-dashboard-only shape is already in effect), and the developer points the downstream Node's OTLP endpoint at Pulse.Collector's port manually if both AppHosts are running.
   - **Future:** when Pulse.Collector ships as a NuGet-distributed host package, the downstream AppHost can `AddProject<T>` against the package path. Track this as a follow-up; do not block on it.

5. **`HoneyDrunk.Pulse.AppHost.csproj`**:
   - SDK: `Microsoft.NET.Sdk` with `OutputType=Exe` and the Aspire AppHost target.
   - `IsAspireHost=true`.
   - `PackageReference` to the Aspire AppHost SDK + integrations at the version Standards pinned in packet 02.
   - `PackageReference` to `HoneyDrunk.Standards` (`PrivateAssets: all`) and `HoneyDrunk.Standards.Aspire`.
   - `ProjectReference` to the existing `HoneyDrunk.Pulse.Collector` project at `..\Pulse.Collector\HoneyDrunk.Pulse.Collector.csproj`.

6. **Solution + version bump.**
   - Add `HoneyDrunk.Pulse.AppHost` to `HoneyDrunk.Pulse.slnx`.
   - Per invariant 27: bump every non-test `.csproj` in the solution to the same new minor version **if** this is the first packet to land on the solution in the current Pulse version cycle. **If ADR-0040 Pulse packets have already bumped the in-progress version**, append to that version's CHANGELOG only — do not double-bump. The PR description records which case applies.
   - Repo-level `CHANGELOG.md` entry describing the AppHost addition (and Collector executable if introduced).
   - Per-package `CHANGELOG.md`: only the new package(s) get an entry. Other Pulse packages get alignment-bump only — no per-package CHANGELOG noise (invariants 12/27).
   - `HoneyDrunk.Pulse.AppHost/README.md` documents the run command, the composed resources, the OTLP port the Collector exposes, and the cross-Node dual-emit composition guidance from step 4.

7. **Verify the AppHost compiles and launches.** Run `dotnet build` and (locally) `dotnet run --project HoneyDrunk.Pulse.AppHost` to confirm the AppHost stands up: the Aspire dashboard URL opens, the Pulse.Collector starts and exposes its OTLP port, and OTLP traces appear in the dashboard. Developer verification, captured in the PR description.

## Affected Files
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/HoneyDrunk.Pulse.AppHost.csproj` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/Program.cs` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/CHANGELOG.md` (new, invariant 12)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/README.md` (new, invariant 12)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.slnx` — new AppHost project entry
- Every non-test `.csproj` in the solution — version bump (if first packet on the in-progress version)
- Repo-level `CHANGELOG.md`

The existing `HoneyDrunk.Pulse.Collector` project is **not modified** by this packet.

## NuGet Dependencies

`HoneyDrunk.Pulse.AppHost`:
- Aspire AppHost SDK + integrations at the version pinned in packet 02.
- `HoneyDrunk.Standards` (`PrivateAssets: all`) at the new published version from packet 02.
- `HoneyDrunk.Standards.Aspire` at the new published version from packet 02.
- `ProjectReference` to the existing `HoneyDrunk.Pulse.Collector` project.

The existing `HoneyDrunk.Pulse.Collector` gains no new `PackageReference` in this packet — its dependencies are already in place.

Confirm exact `HoneyDrunk.Standards` / `HoneyDrunk.Standards.Aspire` versions at execution time.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Pulse` — the new AppHost composes Pulse's Collector. Routing rule "observability, telemetry, traces, logs, metrics ... → HoneyDrunk.Pulse" maps here.
- [x] No contract change in Pulse's existing packages; the AppHost (and any new Collector host) is additive.
- [x] Pulse depends on Kernel; no reference to any other Node's runtime. Container-resource composition of Pulse from Notify's AppHost (packet 04) does not invert the dependency.
- [x] No production deployment surface modified (D5 — Aspire is local-dev only).

## Acceptance Criteria
- [ ] `HoneyDrunk.Pulse.AppHost` project exists, is `OutputType=Exe`, and is included in `HoneyDrunk.Pulse.slnx`
- [ ] `Program.cs` composes the existing `HoneyDrunk.Pulse.Collector` as a project resource via `AddProject<Projects.HoneyDrunk_Pulse_Collector>` and calls `AddGridTelemetry` for self-observability
- [ ] The existing `HoneyDrunk.Pulse.Collector` source is unchanged by this packet (composition only — no Collector edits)
- [ ] `dotnet build HoneyDrunk.Pulse.slnx` succeeds
- [ ] `dotnet run --project HoneyDrunk.Pulse.AppHost` launches the Aspire dashboard and the Collector (developer verification — captured in the PR description, not in CI)
- [ ] `HoneyDrunk.Pulse.AppHost/README.md` documents: the run command, the OTLP port the Collector exposes, the cross-Node dual-emit composition guidance (container-resource recommended, interim manual path, future NuGet-host follow-up)
- [ ] `HoneyDrunk.Pulse.AppHost/CHANGELOG.md` exists with the initial entry
- [ ] The PR description records whether this packet is the first one on the current Pulse version cycle (bumps) or appends to an ADR-0040-bumped in-progress version
- [ ] If bumping: every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries the AppHost-addition entry (new version section if bumping; appended to the in-progress section if not)
- [ ] No production deployment surface modified (D5 — Aspire is local-dev only)
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Publish `HoneyDrunk.Standards` (with `HoneyDrunk.Standards.Aspire` and `HoneyDrunk.Standards.Templates.AspireAppHost`) before this packet builds.** Packet 02 ships those packages; a human pushes the git release tag on `HoneyDrunk.Standards` after packet 02 merges. Wave 4 cannot build against unpublished Standards packages.
- [ ] **Pulse's dev Key Vault and dev App Configuration must exist** with the relevant sink credentials seeded (App Insights connection string per ADR-0040 packet 02 — already provisioned if that initiative landed; Sentry DSN if applicable; Loki/Mimir/Tempo endpoints if those sinks are composed locally). Build succeeds without them; runtime launch fails if any required secret is missing.
- [ ] **Docker Desktop running on the developer's box** for any container resource the AppHost composes (Cosmos Emulator if Pulse's local state uses it; not needed if the Collector is pure-memory in dev). Not a build-time prerequisite; launch-time only if container resources are composed.
- [ ] **Tag/release `HoneyDrunk.Pulse` after this packet merges** if downstream consumers (e.g. Notify's `AddPulseCollector` container-resource path, when adopted) need the new Collector image/package on a feed. This is downstream-driven; not a strict prerequisite for the AppHost itself.

## Referenced ADR Decisions
**ADR-0065 D2 — Per-Node AppHost.** Each containerized Node's repo includes a `{Node}.AppHost` project.

**ADR-0065 D3 — Resource modeling.** Pulse models its Collector as a project resource, with connection-string resources for non-emulated dev services.

**ADR-0065 D4 — Pulse integration, opt-in dual-emit.** Pulse.Collector is the destination for the dual-emit fan-out. The Pulse repo carries the canonical Pulse.Collector composition so downstream AppHosts (Notify, Communications, future) can compose Pulse.Collector as a container resource against the Pulse-published image.

**ADR-0065 D7 — Pulse is the second migrant.** Notify's AppHost composes Pulse.Collector and the Pulse repo benefits from carrying the canonical Pulse.Collector AppHost.

**ADR-0065 D5 — Production deployment is separate.** Nothing in this packet wires `azd` or generates production Bicep.

**ADR-0040 (sibling initiative) — Pulse Telemetry Sink work.** ADR-0040's Pulse packets extend `HoneyDrunk.Telemetry.Sink.AzureMonitor`. This packet does not modify that work; if ADR-0040 Pulse packets are mid-flight, the version-bump-vs-append decision applies per the Pulse note above.

## Constraints
- **Invariant 27 — one version across the solution.** This packet is the first one on the Pulse solution this initiative; bump if no ADR-0040 Pulse packet has bumped the in-progress version, otherwise append. Confirm at edit time and record in the PR description.
- **Invariant 12 — CHANGELOG/README discipline.** New `HoneyDrunk.Pulse.AppHost` (and Collector executable if introduced) get `CHANGELOG.md` + `README.md` from this commit. Unchanged packages get NO per-package CHANGELOG entry.
- **Invariant 26 — analyzer baseline.** New projects reference `HoneyDrunk.Standards` with `PrivateAssets: all`.
- **D5 — Aspire is local-dev only.** No `azd` wiring, no generated production Bicep. The Pulse production deployment continues to be the existing `HoneyDrunk.Standards` shared workflow + curated Bicep per ADR-0015.
- **No Notify dependency.** Pulse does not depend on Notify or any consumer Node. The cross-Node composition (Notify's AppHost referencing Pulse.Collector) happens at the consumer's AppHost level — never by Pulse pulling consumers in.
- **Container-resource recommended for cross-Node composition.** Document the path in `README.md`; do not project-reference Pulse from Notify or any other Node's AppHost.
- **Do not modify the Pulse.Collector project.** The existing Collector at `HoneyDrunk.Pulse/Pulse.Collector/` is composed by reference only. Any Collector source changes belong to a separate Pulse feature initiative.

## Labels
`feature`, `tier-2`, `ops`, `adr-0065`, `wave-4`

## Agent Handoff

**Objective:** Add `HoneyDrunk.Pulse.AppHost` so Pulse owns its canonical Collector composition, and any downstream AppHost can compose Pulse.Collector via the documented container-resource path.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Give Pulse a working AppHost and a canonical Collector entry point that downstream Node AppHosts can compose for the D4 dual-emit.
- Feature: ADR-0065 Multi-Service Local Dev Orchestration rollout, Wave 4 (first migrants — parallel with packet 04 Notify).
- ADRs: ADR-0065 D2/D3/D4/D5/D7 (primary), ADR-0040 (sibling Pulse telemetry work — version-bump coordination), ADR-0015 (production deployment authority — unchanged).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `HoneyDrunk.Standards.Aspire` and the AppHost template ship; the AppHost references them.
- (Soft) ADR-0040 Pulse packets — coordinate the in-progress Pulse version with whichever ADR-0040 Pulse packets are mid-flight per invariant 27.

**Constraints:**
- The AppHost is local-dev only — no production deployment surface (D5).
- Bump-vs-append per invariant 27: check the Pulse in-progress version state at edit time.
- Cross-Node Pulse.Collector composition uses container-resource path, not project reference (no inverted dependency).
- The existing `HoneyDrunk.Pulse.Collector` is composed by project reference only — no Collector source edits in this packet.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/Program.cs` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/HoneyDrunk.Pulse.AppHost.csproj` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.AppHost/CHANGELOG.md` + `README.md` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse.slnx` (new AppHost project entry)
- Every non-test `.csproj` for the version bump if applicable; repo-level `CHANGELOG.md`

**Contracts:** None changed — the AppHost composes the existing Pulse.Collector without modifying its public surface.
