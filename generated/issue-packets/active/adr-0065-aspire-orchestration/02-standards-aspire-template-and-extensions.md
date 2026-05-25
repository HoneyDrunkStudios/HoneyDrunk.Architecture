---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "ops", "adr-0065", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0065"]
wave: 2
initiative: adr-0065-aspire-orchestration
node: honeydrunk-standards
---

# Author the AppHost project template and Grid Aspire extension methods in HoneyDrunk.Standards

## Summary
Ship the ADR-0065 D6 Standards alignment: an AppHost project template (`HoneyDrunk.Standards.Templates/AspireAppHost`) producing a `{Node}.AppHost` scaffold with the analyzer/EditorConfig wiring and default OTLP/dashboard setup, the `HoneyDrunkAspireExtensions.AddGridTelemetry` extension implementing the D4 dual-emit pattern, and the default emulator/dev-resource wiring extensions (`AddGridCosmosEmulator`, `AddGridAzurite`, `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev`). This is the first packet on the `HoneyDrunk.Standards` solution in this initiative and the version-bumping packet — it ships new public surface (additive minor bump per ADR-0035).

## Context
ADR-0065 D6 commits a small set of Aspire-related shared assets in `HoneyDrunk.Standards`. The reasoning: new Nodes adopting Aspire pull the template + extensions and get a working baseline; existing Nodes pull the extensions piecemeal as they migrate (D7). The Standards extension methods absorb Aspire-version-evolution churn so per-Node AppHosts stay stable.

`HoneyDrunk.Standards` is a live Node with the package family rooted in `HoneyDrunk.Standards` and `HoneyDrunk.Standards.Analyzers` (alongside test/consumer projects). It ships the Grid's analyzer/EditorConfig conventions every Node references via `PrivateAssets: all` (invariant 26). The Aspire template + extensions are net-new public surface.

ADR-0065 D6 names the exact extension methods:
- `HoneyDrunkAspireExtensions.AddGridTelemetry(IResourceBuilder<T>)` — applies the D4 dual-emit pattern. Default: ship OTLP to Aspire's dashboard only. When the AppHost composes `AddPulseCollector()`, also fan out to a local Pulse.Collector instance.
- `AddGridCosmosEmulator` — Cosmos Emulator container resource with Grid naming + configuration conventions.
- `AddGridAzurite` — Azurite blob/queue/table emulator container resource.
- `AddGridServiceBusDev` — connection-string resource pointing at the dev `sb-hd-dev` namespace; resolves connection string from `dotnet user-secrets`; creates the per-session subscription on AppHost launch (per D9).
- `AddGridKeyVaultDev` — connection-string resource for the dev Key Vault; resolves via Azure CLI / Visual Studio sign-in (no emulator).
- `AddGridAppConfigDev` — connection-string resource for dev App Configuration; same dev-session-auth shape as Key Vault.

ADR-0065 commits these extensions as **public surface subject to SemVer per ADR-0035**. This packet ships them with full XML documentation (invariant 13) and the Grid's analyzer baseline (invariant 26).

> **Aspire-version pinning.** ADR-0065 Follow-up Work: "Confirm Aspire's current version (at acceptance time) and pin the Standards templates to it. Aspire breaking changes are absorbed by Standards updates per the per-Node migration ergonomics." The executor confirms Aspire's current GA version at execution time (the ADR was authored 2026-05-23 — confirm the latest stable Aspire SDK as of the merge date) and pins the template + extension projects' `PackageReference`s to that version. Future Aspire bumps land as Standards-version updates, propagating to per-Node AppHosts on the next consumer-side bump.

This packet creates new `.NET` projects (the template project, and one or more extension projects) — they need `CHANGELOG.md` and `README.md` from the first commit (invariant 12).

## Scope
- New project `HoneyDrunk.Standards.Templates.AspireAppHost` (or a sub-project of an existing templates project — match the repo's existing templates structure if one exists) — a `dotnet new` template producing a `{Node}.AppHost` scaffold with:
  - The `Microsoft.NET.Sdk` `OutputType=Exe` shape Aspire AppHosts use.
  - `PackageReference` to `Aspire.AppHost.Sdk` and the relevant Aspire SDK at the pinned version.
  - `PackageReference` to `HoneyDrunk.Standards` (`PrivateAssets: all`) for the analyzer baseline (invariant 26).
  - A starter `Program.cs` that wires `IDistributedApplicationBuilder`, calls `AddGridTelemetry`, and includes commented examples of `AddGridCosmosEmulator`/`AddGridAzurite`/`AddGridServiceBusDev`/`AddGridKeyVaultDev`/`AddGridAppConfigDev`.
  - A `.template.config/template.json` describing the template parameters (Node name, namespace, parent solution path).
- New project `HoneyDrunk.Standards.Aspire` (the home of the public extension methods — name to match the repo's existing package-naming pattern; confirm against `HoneyDrunk.Standards`/`HoneyDrunk.Standards.Analyzers` and pick the parallel form):
  - `HoneyDrunkAspireExtensions` static class with `AddGridTelemetry` and the dual-emit logic.
  - `AddGridCosmosEmulator`, `AddGridAzurite` — container resource extensions.
  - `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev` — connection-string resource extensions with dev-session auth + (for Service Bus) per-session subscription creation on AppHost launch.
- Test coverage in `HoneyDrunk.Standards.Tests` (or a new sibling test project — match the repo's existing test-project shape) — unit tests for the extension methods using Aspire's testing primitives where available; no live Azure dependency.
- `CHANGELOG.md` + `README.md` for each new project; per-package CHANGELOG entries for the packages with real changes; repo-level `CHANGELOG.md` new version entry.

## Proposed Implementation

1. **Confirm Aspire version pin.** At execution time, identify the current stable Aspire SDK version on NuGet. Pin all new `Aspire.*` `PackageReference`s in this packet to that version.

   > **CPM state on the Standards solution.** Verified at packet-authoring time (2026-05-24): the `HoneyDrunk.Standards` solution does **not** use Central Package Management today — there is no `Directory.Packages.props` and no `Directory.Build.props` at the repo or solution root. Existing projects pin `PackageReference` `Version` attributes directly in each `.csproj` (with shared values driven by private `_StyleCopPackageVersion`/`_NetAnalyzersVersion` MSBuild properties inside `HoneyDrunk.Standards.csproj` itself, not via CPM). **This packet matches the existing convention: pin Aspire versions inline in each new `.csproj` rather than introducing CPM.** Introducing CPM is a separate scope item (a Standards-solution-wide refactor) and belongs in its own ADR/initiative — not bundled into the Aspire feature packet.

2. **`HoneyDrunk.Standards.Aspire`** — new project carrying the extension methods:
   - `static class HoneyDrunkAspireExtensions` (note: not `I`-prefixed; it's a static helper class — the records-drop-I/interfaces-keep-it naming rule does not apply to static classes).
   - `IResourceBuilder<TResource> AddGridTelemetry<TResource>(this IResourceBuilder<TResource> builder)` — wires OTLP environment variables (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_SERVICE_NAME`) on the resource. The default endpoint is Aspire's dashboard's own OTLP receiver (Aspire wires this automatically when the dashboard is enabled). The dual-emit fan-out (D4) is activated by a separate composition method on the AppHost builder, e.g. `IDistributedApplicationBuilder AddPulseCollector(this IDistributedApplicationBuilder builder, bool opt = false)` that, when `opt: true`, adds Pulse.Collector as a project resource and overrides the OTLP endpoint on every other project resource to fan out to both Aspire and Pulse. The opt-in mechanism is the AppHost-level composition method; the per-resource `AddGridTelemetry` ships the OTLP wiring that follows whatever endpoint the host has set.
   - `IResourceBuilder<CosmosResource> AddGridCosmosEmulator(this IDistributedApplicationBuilder builder, string name)` — composes Aspire's `AddAzureCosmosDB` (or `AddCosmos` per the current Aspire API) in emulator mode, applies the Grid's `hd`-prefixed naming convention, and sets the Cosmos Emulator's Linux-container mode (per D9: "the AppHost uses the Linux-container mode for cross-platform consistency").
   - `IResourceBuilder<AzureStorageResource> AddGridAzurite(this IDistributedApplicationBuilder builder, string name)` — composes Aspire's Azurite resource with Grid naming.
   - `IResourceBuilder<IResourceWithConnectionString> AddGridServiceBusDev(this IDistributedApplicationBuilder builder, string name)` — connection-string resource resolving from the `ConnectionStrings:ServiceBus` key (read from `dotnet user-secrets`; ASP.NET configuration convention, matching the seeding command in the packet 03 walkthrough). On AppHost launch, creates a per-session ASB subscription named by user/machine/process so concurrent dev sessions do not interfere (D9). **On AppHost shutdown, the same composition deletes the per-session subscription** so concurrent dev sessions are not stranded with orphaned subscriptions on the dev namespace. The lifecycle (create on launch, delete on shutdown) is wired by registering an Aspire lifecycle hook (`IDistributedApplicationLifecycleHook` — `BeforeStartAsync` creates, `AfterApplicationStoppedAsync` deletes) inside the extension; document the lifecycle in the extension's XML doc. Best-effort deletion: if the delete fails (network blip, namespace gone), log and continue — orphaned subscriptions on dev are tolerable but should be the exception. A manual cleanup step is documented in packet 03 as the recovery path.
   - `IResourceBuilder<IResourceWithConnectionString> AddGridKeyVaultDev(this IDistributedApplicationBuilder builder, string name)` — connection-string resource pointing at the dev Key Vault URI; auth via Azure CLI / Visual Studio sign-in (no emulator — Key Vault is not emulated; D3).
   - `IResourceBuilder<IResourceWithConnectionString> AddGridAppConfigDev(this IDistributedApplicationBuilder builder, string name)` — same shape as `AddGridKeyVaultDev` for dev App Configuration.
   - Full XML documentation on every public member (invariant 13).
3. **`HoneyDrunk.Standards.Templates.AspireAppHost`** — new template:
   - A `dotnet new` template (package or repo-local). The template scaffold targets a `{Node}.AppHost` project layout that compiles standalone with `dotnet run --project {Node}.AppHost`.
   - The template's starter `Program.cs` references `HoneyDrunk.Standards.Aspire`'s extensions and includes commented examples of each `AddGrid*` call.
   - `.template.config/template.json` declares parameters: `NodeName`, `RootNamespace`, optional `SolutionPath`.
4. **Test coverage** — unit tests in `HoneyDrunk.Standards.Tests` (or a new sibling test project) for the extension methods. Use Aspire's `Aspire.Hosting.Testing` primitives in a *non-launching syntax-check* mode (the same mode ADR-0065 names for Workshop CI in its Operational Consequences) so tests do not require Docker Desktop or a live Azure subscription. No external dependencies (invariant 15).
5. **Versioning + CHANGELOGs + READMEs.**
   - This is the first packet on the `HoneyDrunk.Standards` solution in this initiative — per invariant 27 it bumps every non-test `.csproj` to the same new minor version in one commit (additive new public surface — minor bump per ADR-0035).
   - Repo-level `CHANGELOG.md` new version entry.
   - Per-package CHANGELOG entries for the packages with real changes: `HoneyDrunk.Standards.Aspire` and `HoneyDrunk.Standards.Templates.AspireAppHost` (both new — they need `CHANGELOG.md` and `README.md` from the first commit per invariant 12). `HoneyDrunk.Standards` and `HoneyDrunk.Standards.Analyzers` get no per-package CHANGELOG entry in this packet (alignment bump only, no functional change) — invariants 12/27.
   - Each new project's `README.md` documents its public API surface.

## Affected Files
- `HoneyDrunk.Standards/HoneyDrunk.Standards.Aspire/` (new project)
- `HoneyDrunk.Standards/HoneyDrunk.Standards.Templates.AspireAppHost/` (new template project)
- `HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/` (new tests for the Aspire extensions, or a sibling test project — match the repo's convention)
- Every non-test `.csproj` in the solution — version bump (invariant 27).
- Repo-level `CHANGELOG.md`; new per-package `CHANGELOG.md` / `README.md` for the new packages.

The Standards solution does not use CPM today (verified at packet-authoring time — no `Directory.Packages.props`); Aspire versions are pinned inline in the new `.csproj` files.

## NuGet Dependencies

`HoneyDrunk.Standards.Aspire` — new `PackageReference` set:
- `Aspire.Hosting` (or the current top-level Aspire hosting metapackage at the confirmed pinned version) — the Aspire AppHost programming model.
- `Aspire.Hosting.Azure.CosmosDB`, `Aspire.Hosting.Azure.Storage` (Azurite), `Aspire.Hosting.Azure.ServiceBus`, `Aspire.Hosting.Azure.KeyVault`, `Aspire.Hosting.Azure.AppConfiguration` — match the current Aspire integrations package names (confirm at execution time; Aspire's package naming has churn — the right names are whichever shipping Aspire integrations are current as of the pinned version).
- `Microsoft.Extensions.Configuration.UserSecrets` — for `AddGridServiceBusDev`'s `dotnet user-secrets` resolution.
- `HoneyDrunk.Standards` — `PrivateAssets: all` (invariant 26: analyzers + EditorConfig).

`HoneyDrunk.Standards.Templates.AspireAppHost` — the template scaffold's `*.csproj`:
- `Aspire.AppHost.Sdk` — the AppHost SDK target.
- `Aspire.Hosting` (pinned version, matching above).
- `HoneyDrunk.Standards` (`PrivateAssets: all`) and `HoneyDrunk.Standards.Aspire` (the template references the extension methods so a freshly-templated AppHost compiles).

Test project — match the Standards test stack already in place (xUnit + the assertion library the existing tests use). Add only what is missing:
- `Aspire.Hosting.Testing` — for non-launching syntax-check validation (D10's "future testing follow-up" cites `Aspire.Hosting.Testing`; ADR-0065 D6 wants the extensions test-covered; using `Aspire.Hosting.Testing` in non-launching mode is appropriate and CI-safe).
- `HoneyDrunk.Standards` (`PrivateAssets: all`).
- Project reference to `HoneyDrunk.Standards.Aspire`.

Add only `PackageReference` entries not already present — confirm against existing `.csproj` files first. Pin `Version=` inline on each `PackageReference` (the Standards solution does not use Central Package Management; introducing CPM is out of scope for this packet).

## Boundary Check
- [x] `HoneyDrunk.Standards` is the correct repo per ADR-0065 D6 ("HoneyDrunk.Standards gains a small set of Aspire-related shared assets").
- [x] Net-new public surface; additive minor bump per ADR-0035. No removal or rename of existing exports.
- [x] No runtime dependency on any `HoneyDrunk.*` Node beyond `HoneyDrunk.Standards` itself — the extensions live in Standards, sit beneath every Node, and are consumed by per-Node AppHosts at compose time.
- [x] No production-deployment surface touched (D5: Aspire is local-dev only; the production authoring stays in `HoneyDrunk.Standards`' shared workflows + curated Bicep — those are not edited here).

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards.Aspire` exposes `HoneyDrunkAspireExtensions` with `AddGridTelemetry`, `AddGridCosmosEmulator`, `AddGridAzurite`, `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev`
- [ ] `AddGridServiceBusDev` resolves the connection string from the `ConnectionStrings:ServiceBus` user-secrets key, creates a per-session subscription on AppHost launch, **and deletes that subscription on AppHost shutdown** via an `IDistributedApplicationLifecycleHook` (best-effort delete; log on failure)
- [ ] `AddGridCosmosEmulator` runs the Cosmos Emulator in Linux-container mode (per D9)
- [ ] All public types/methods have XML documentation (invariant 13)
- [ ] `HoneyDrunk.Standards.Templates.AspireAppHost` is a working `dotnet new` template producing a compileable `{Node}.AppHost` scaffold; the starter `Program.cs` calls `AddGridTelemetry` and includes commented examples of every `AddGrid*` resource extension
- [ ] The template's project file references the pinned Aspire SDK version and references `HoneyDrunk.Standards` (`PrivateAssets: all`) and `HoneyDrunk.Standards.Aspire`
- [ ] Aspire SDK packages are pinned to a single confirmed version across every new `.csproj` (pinned inline, matching the Standards solution's existing no-CPM convention)
- [ ] Tests for the extension methods run in non-launching mode and do not require Docker Desktop, a live Azure subscription, or any external service (invariant 15)
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry
- [ ] `HoneyDrunk.Standards.Aspire/CHANGELOG.md` + `README.md` exist (new package, created in this packet)
- [ ] `HoneyDrunk.Standards.Templates.AspireAppHost/CHANGELOG.md` + `README.md` exist (new package, created in this packet)
- [ ] `HoneyDrunk.Standards/CHANGELOG.md` and `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` get NO per-package entry (alignment bump only — invariants 12/27)
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Tag/release `HoneyDrunk.Standards` after this packet merges.** This packet's new packages (`HoneyDrunk.Standards.Aspire`, `HoneyDrunk.Standards.Templates.AspireAppHost`) reach the NuGet feed only when a human pushes the git release tag — agents never tag or publish. Wave 4 (packets 04 Notify, 05 Pulse) compiles against the new packages and cannot proceed until they are published.
- [ ] **The dev Service Bus namespace (`sb-hd-dev`) does not need to exist for this packet to merge** — `AddGridServiceBusDev` resolves a connection string at AppHost-launch time, not at build time. The namespace must exist before any per-Node AppHost using `AddGridServiceBusDev` is run (Notify's AppHost in packet 04). Packet 03 provisions the namespace.

## Referenced ADR Decisions
**ADR-0065 D4 — Pulse integration: dual-emit, opt-in.** Default ships OTLP to Aspire's dashboard only; opt-in `AddPulseCollector` adds Pulse.Collector as a project resource and fans out OTLP to both Aspire and Pulse.

**ADR-0065 D6 — Standards alignment.** Standards gains the AppHost project template + the named extension methods. Versioned per ADR-0035.

**ADR-0065 D7 — Migration is opportunistic.** New Nodes pull the template; existing Nodes pull extensions piecemeal as they migrate.

**ADR-0065 D9 — Real dev Service Bus, dotnet user-secrets, per-session subscriptions.** `AddGridServiceBusDev` resolves the connection string from `dotnet user-secrets`; the per-session subscription is created on AppHost launch.

**ADR-0065 D10 — Aspire is not in CI.** Tests in this packet run in non-launching mode (e.g. `Aspire.Hosting.Testing`'s syntax-check shape) so CI is fast and deterministic and does not require Docker Desktop or a live Azure subscription.

**ADR-0065 Operational Consequences — Aspire version evolution.** Standards absorbs Aspire churn; per-Node AppHosts stay stable. A breaking Aspire release is a coordinated Standards update.

**ADR-0035 — Abstractions versioning and deprecation policy.** New public surface in Standards = additive minor bump; the Aspire extensions are subject to the same SemVer rules as every other Standards export.

## Constraints
- **Invariant 13 — public APIs carry XML documentation.** Every extension method and template-exposed type.
- **Invariant 26 — analyzer baseline.** New projects reference `HoneyDrunk.Standards` with `PrivateAssets: all` (the package itself is *Standards* — the convention is the same: every new Standards-solution project carries the analyzer baseline).
- **Invariant 27 — solution-wide version alignment.** This is the first packet on the solution this initiative; it bumps every non-test `.csproj` to the same new minor version in one commit. Partial bumps are forbidden.
- **Invariant 12 — CHANGELOG/README discipline.** New packages need `CHANGELOG.md` + `README.md` from the first commit. Existing packages with no functional change get NO per-package CHANGELOG entry.
- **Invariant 15 — tests don't depend on external services.** The Aspire extension tests run in non-launching mode; no Docker Desktop, no Azure, no Cosmos Emulator container at test time.
- **D5 — never the production path.** Nothing in this packet wires `azd` deployment, `AzurePublisher`, or `Aspire.Hosting.Azure.Provisioning` for production-deployment authoring. The template's `Program.cs` is local-dev shape only.
- **Aspire SDK version pinning.** Pin Aspire packages to a single confirmed version across every new `.csproj`. The Standards solution does not use CPM today (no `Directory.Packages.props`); pin inline. Introducing CPM is a separate refactor.
- **No `I`-prefix on the static class.** `HoneyDrunkAspireExtensions` is a static class — the records-drop-I/interfaces-keep-it rule does not apply (it applies to records vs interfaces, not classes).

## Labels
`feature`, `tier-2`, `ops`, `adr-0065`, `wave-2`

## Agent Handoff

**Objective:** Ship the AppHost template + Grid Aspire extension methods in `HoneyDrunk.Standards` so per-Node AppHosts have a working baseline.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Ship the shared assets every per-Node AppHost in this initiative consumes.
- Feature: ADR-0065 Multi-Service Local Dev Orchestration rollout, Wave 2 (Standards foundation).
- ADRs: ADR-0065 D4/D6/D7/D9/D10 (primary), ADR-0035 (additive minor-bump policy), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0065 Accepted and its two invariants live before the Standards extensions are built against them.

**Constraints:**
- Pin Aspire SDK to a confirmed version inline across every new `.csproj` (the Standards solution does not use CPM; do not introduce CPM in this packet).
- Tests run in non-launching mode — no Docker Desktop, no live Azure (invariant 15, D10).
- Bump every non-test `.csproj` to the same new minor version in one commit (invariant 27). This is the bumping packet for `HoneyDrunk.Standards` in this initiative.
- Aspire local-dev only — no production-deployment surface (D5).
- After merge, a human must tag/release `HoneyDrunk.Standards` so the new packages reach the NuGet feed before Wave 4 starts.

**Key Files:**
- `HoneyDrunk.Standards.Aspire/` (new project)
- `HoneyDrunk.Standards.Templates.AspireAppHost/` (new template project)
- Tests for the Aspire extensions
- Every non-test `.csproj` for the version bump; repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` / `README.md` for the new packages

**Contracts:**
- `HoneyDrunkAspireExtensions.AddGridTelemetry` (new static method) — OTLP wiring on a resource builder.
- `AddGridCosmosEmulator`, `AddGridAzurite` (new) — container resource extensions.
- `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev` (new) — connection-string resource extensions, dev-session-auth shape, with per-session subscription on launch for Service Bus.
- (Composition method) `AddPulseCollector(bool opt = false)` on `IDistributedApplicationBuilder` — the AppHost-level opt-in switch for the D4 dual-emit fan-out.
