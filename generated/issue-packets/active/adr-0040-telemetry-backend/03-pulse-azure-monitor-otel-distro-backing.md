---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0040", "wave-2"]
dependencies: ["packet:00", "packet:02"]
adrs: ["ADR-0040", "ADR-0028", "ADR-0005"]
accepts: ["ADR-0040"]
wave: 2
initiative: adr-0040-telemetry-backend
node: honeydrunk-pulse
---

# Extend HoneyDrunk.Telemetry.Sink.AzureMonitor — the OTLP-to-App-Insights telemetry backing

## Summary
Extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider in the `HoneyDrunk.Pulse` solution: wire the Azure Monitor OpenTelemetry Distro behind the Pulse sink contracts so Nodes emit OTLP and the provider ships traces, metrics, and logs to the App Insights resource per ADR-0040 D1/D2. This is the core implementation packet of the initiative and the first packet on the `HoneyDrunk.Pulse` solution in this initiative.

## Context
ADR-0040 D2 makes `HoneyDrunk.Pulse` the OTLP-only telemetry boundary and the **Azure Monitor OpenTelemetry Distro** (the Microsoft-maintained Azure Monitor Exporter for OpenTelemetry) the connector behind it. The exporter sits inside the Pulse Node's runtime, never in a consuming Node. This is the load-bearing reversibility property: switching backends (to Grafana Cloud + Sentry per D11, or any future option) is a configuration change at the Pulse Node only.

> **ADR-0040 amendment 2026-05-22:** the original draft assigned this work to `HoneyDrunk.Observe` and named a new `HoneyDrunk.Observe.AzureMonitor` package. That was corrected — Observe is the *inbound* observation layer for external systems; **Pulse owns outbound telemetry routing to sinks**. The `HoneyDrunk.Observe`/`HoneyDrunk.Pulse` boundary docs already say so. ADR-0040's Follow-up Work now reads: "Extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider in the Pulse solution with the Azure Monitor OpenTelemetry Distro wired through the Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`)."

**Repo-state note — read before starting.** `HoneyDrunk.Pulse` is a **live** Node at version 0.3.0. The Pulse solution already ships a `HoneyDrunk.Telemetry.Sink.AzureMonitor` project alongside `HoneyDrunk.Telemetry.Sink.Loki`, `Sink.Mimir`, `Sink.Tempo`, `Sink.Sentry`, `Sink.PostHog`, and `Sink.Shared`, plus `HoneyDrunk.Telemetry.Abstractions` and `HoneyDrunk.Telemetry.OpenTelemetry`. **This packet does not create a new package — it extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` project.** The Pulse boundaries doc names `ITraceSink`/`ILogSink`/`IMetricsSink`/`IAnalyticsSink`/`IErrorSink` as Pulse-owned, the OTel preconfigured pipelines, and multi-backend fan-out with per-sink failure isolation — the AzureMonitor sink slots into that established model.

**No new abstraction.** The Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink` in `HoneyDrunk.Telemetry.Abstractions`) already exist and are the reversibility seam — every `HoneyDrunk.Telemetry.Sink.*` provider satisfies them. The AzureMonitor sink implements those existing contracts; no `IObservabilityBackend` or other new abstraction is introduced. If the existing `Sink.AzureMonitor` is a stub, this packet fills it in against the existing contracts; if it already has structure, this packet completes the OTel Distro wiring.

## Scope
- `HoneyDrunk.Telemetry.Sink.AzureMonitor` (existing project in the `HoneyDrunk.Pulse` solution) — extend with the Azure Monitor OTel Distro composition: the `TracerProvider`, `MeterProvider`, and `LoggerProvider` builders configured with the Azure Monitor exporter, the connection string resolved from Vault.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit` (the existing test project for the sink, or a new one matching the Pulse test-project convention) — unit tests for the composition and configuration binding.

## Proposed Implementation
1. **Extend `HoneyDrunk.Telemetry.Sink.AzureMonitor`** — the existing provider project:
   - Reference the **`Azure.Monitor.OpenTelemetry.AspNetCore`** distro package (the Azure Monitor OpenTelemetry Distro) — or `Azure.Monitor.OpenTelemetry.Exporter` if a non-ASP.NET-Core host composition is needed; pick per the Pulse runtime's host model and document the choice.
   - Implement the Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`): a registration extension (e.g. `AddAzureMonitorSink`) that configures the OTel `TracerProvider` / `MeterProvider` / `LoggerProvider` with the Azure Monitor exporter, consistent with how the other `HoneyDrunk.Telemetry.Sink.*` providers register.
   - **Connection string from Vault.** The App Insights connection string (seeded by packet 02 into the Pulse Node's Key Vault) is resolved via `ISecretStore` — invariant 9, Vault is the only source of secrets; ADR-0040 D1 puts the connection string in Vault. The Pulse boundaries doc already states "Sink credentials come from Vault." Never read the connection string from an environment variable holding the raw value or from an Azure SDK default credential path.
   - The exporter must respect the OTel SDK's configured sampler — D4's sampler (packet 04) is composed into the `TracerProvider`; this packet leaves a clean seam for packet 04 to plug the sampler in (a `Sampler` parameter or builder hook), and uses the OTel default sampler until packet 04 lands.
   - Metrics and logs are **not sampled** (D4) — wire the `MeterProvider` and `LoggerProvider` straight through.
   - Preserve Pulse's per-sink failure isolation — the AzureMonitor sink failing must not take down the other sinks (an established Pulse boundary property).
2. **Sampler / processor seams.** This packet wires the exporter and the provider builders. The adaptive sampler + rules (D4) and the PII processors (D9) are packets 04 and 05 — leave explicit composition seams (builder hooks / DI extension points) for them so they plug in without restructuring this package.
3. **XML documentation** on every public member (invariant 13 — enforced by `HoneyDrunk.Standards`).
4. **Version bump.** Per invariant 27, this is the first packet to land on the `HoneyDrunk.Pulse` solution in this initiative — it bumps the version. Extending a provider with a real backend is a **minor** bump. Bump every non-test `.csproj` in the solution to the same new minor version in this commit.
5. **CHANGELOG / README.** Add a repo-level `CHANGELOG.md` entry for the new version. Add a per-package `CHANGELOG.md` entry for `HoneyDrunk.Telemetry.Sink.AzureMonitor` (the package with the actual change). Update `HoneyDrunk.Telemetry.Sink.AzureMonitor/README.md` if the public registration surface changes. If `Sink.AzureMonitor` lacks a `CHANGELOG.md`/`README.md`, create them (invariant 12).

## Affected Files
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` (existing project — extended; `CHANGELOG.md`/`README.md` created if absent)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit/` (existing or new test project — match the Pulse convention)
- Every non-test `.csproj` in the `HoneyDrunk.Pulse` solution — version bump (invariant 27).
- Repo-level `CHANGELOG.md`; `HoneyDrunk.Telemetry.Sink.AzureMonitor` per-package `CHANGELOG.md`/`README.md`.

## NuGet Dependencies
`HoneyDrunk.Telemetry.Sink.AzureMonitor` (existing project) — `PackageReference` additions:
- `Azure.Monitor.OpenTelemetry.AspNetCore` — the Azure Monitor OpenTelemetry Distro (or `Azure.Monitor.OpenTelemetry.Exporter` for a non-ASP.NET-Core host; pick per the Pulse host model and document).
- `OpenTelemetry` and `OpenTelemetry.Extensions.Hosting` — confirm these are already referenced (the Pulse solution has OTel integration via `HoneyDrunk.Telemetry.OpenTelemetry`); reference explicitly on this project if not, since packet 04's sampler composes against them.
- `Microsoft.Extensions.DependencyInjection.Abstractions`, `Microsoft.Extensions.Options`, `Microsoft.Extensions.Logging.Abstractions` — for the registration extension and options binding (likely already present via the sink-project baseline).
- `HoneyDrunk.Kernel.Abstractions` — Grid context (`IGridContext`, `TenantId`) for context enrichment on telemetry (Pulse already consumes Kernel).
- The `ISecretStore` contract for resolving the App Insights connection string — match how the other `HoneyDrunk.Telemetry.Sink.*` providers obtain Vault-sourced credentials (the Pulse boundaries doc states "Sink credentials come from Vault"); use the same Vault dependency the existing sinks use, do not introduce a different one.
- `HoneyDrunk.Telemetry.Abstractions` — the project reference to the Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`) it implements (likely already referenced).
- `HoneyDrunk.Standards` — StyleCop + EditorConfig analyzers, `PrivateAssets: all` (invariant 26 — confirm present; it is on the existing Pulse projects).

`HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit` `PackageReference` set:
- The Grid's standard test stack — match the test framework / assertion / mocking packages the other `HoneyDrunk.Pulse` test projects use (do not introduce a different stack).
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all`.
- Project reference to `HoneyDrunk.Telemetry.Sink.AzureMonitor`.

Add only `PackageReference` entries not already on the project — confirm against the existing `Sink.AzureMonitor.csproj` first.

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — ADR-0040 D2 (as amended 2026-05-22) names Pulse as the OTLP telemetry boundary; the `HoneyDrunk.Observe`/`HoneyDrunk.Pulse` boundary docs already place outbound telemetry routing in Pulse.
- [x] The Azure Monitor exporter lives inside the Pulse runtime, never in a consuming Node — D2's reversibility property.
- [x] `HoneyDrunk.Telemetry.Sink.AzureMonitor` is an existing *provider* package in the Pulse `HoneyDrunk.Telemetry.Sink.*` family — invariant 3, it consumes the Pulse Node's exported sink contracts, not internals.
- [x] No consuming Node changes — Nodes emit OTLP through the standard Pulse sink surface; the backend is composed at the Pulse host.

## Acceptance Criteria
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor` is extended (not newly created) with the Azure Monitor OpenTelemetry Distro, implementing the existing Pulse sink contracts
- [ ] A registration extension configures the OTel `TracerProvider`, `MeterProvider`, and `LoggerProvider` with the Azure Monitor exporter, consistent with the other `HoneyDrunk.Telemetry.Sink.*` providers
- [ ] The App Insights connection string is resolved via `ISecretStore` (Vault) — never from an env var holding the raw value, never hardcoded (invariants 8, 9)
- [ ] Per-sink failure isolation is preserved — the AzureMonitor sink failing does not take down the other Pulse sinks
- [ ] Traces leave a clean composition seam for the packet-04 sampler; metrics and logs are wired straight through, not sampled (D4)
- [ ] A clean composition seam exists for the packet-05 PII processors
- [ ] No new abstraction is introduced — the sink implements the existing `ITraceSink`/`ILogSink`/`IMetricsSink` contracts
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit` covers the composition and configuration binding; tests use no external services (invariant 15) and no `Thread.Sleep` (invariant 51)
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] Every non-test `.csproj` in the solution is bumped to the same new minor version (invariant 27)
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor` has `CHANGELOG.md` and `README.md` (created if absent — invariant 12); repo-level `CHANGELOG.md` has an entry for the new version
- [ ] The solution builds; existing unit and canary tests pass

## Human Prerequisites
- [ ] The `dev` App Insights resource and its Vault-stored connection string must exist (packet 02). The unit tests for this packet must not require a live resource (invariant 15 — use the in-memory secret store and exporter doubles); but an end-to-end smoke check against the `dev` resource is the realistic verification. If packet 02 has not run, the code lands but the live smoke check is deferred.

## Referenced ADR Decisions
**ADR-0040 D1 — Backend: Azure Monitor + Application Insights.** Per-environment App Insights resources; connection strings in Vault per ADR-0005.

**ADR-0040 D2 — Pulse is the OTLP-only telemetry boundary; the Azure Monitor OpenTelemetry Distro is the connector.** Nodes emit OTLP; the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider translates to App Insights' wire protocol and ships to the Azure Monitor backend. The exporter sits inside the Pulse Node's runtime, never in the consuming Node. Switching backends is a configuration change at the Pulse Node only — zero Node-level changes elsewhere.

**ADR-0040 D4 — Sampling.** Sampling is configured via OpenTelemetry primitives — a custom `Sampler` composed into the `TracerProvider`. The Azure Monitor exporter respects whatever sampler the OTel SDK is configured with. Metrics and logs are not sampled at ingestion.

**ADR-0040 Follow-up Work (as amended 2026-05-22).** "Extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider in the Pulse solution with the Azure Monitor OpenTelemetry Distro wired through the Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`)."

**ADR-0028 — Pulse owns the telemetry sink surface.** OTLP is the telemetry shape; the Pulse `HoneyDrunk.Telemetry.Sink.*` family is the provider layer behind it. Sink credentials come from Vault.

## Constraints
> **Invariant 3 — Provider packages depend on their parent Node's contracts, not internal implementation details.** `HoneyDrunk.Telemetry.Sink.AzureMonitor` consumes the Pulse Node's exported sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`), never its internal types.

> **Invariant 9 — Vault is the only source of secrets.** The App Insights connection string is resolved via `ISecretStore`. No Node reads secrets from environment variables, config files, or provider SDKs.

> **Invariant 15 — Unit tests never depend on external services.** The `Sink.AzureMonitor.Tests.Unit` project uses in-memory doubles for the secret store and the exporter — no live App Insights resource in unit tests.

> **Invariant 26 — Issue packets for .NET code work must include a `## NuGet Dependencies` section, and `HoneyDrunk.Standards` is on every .NET project** (analyzers, `PrivateAssets: all`).

> **Invariant 27 — All projects in a solution share one version and move together.** This is the first packet on the `HoneyDrunk.Pulse` solution in this initiative; it bumps the version (minor), and every non-test `.csproj` moves to the same new version in one commit. Packets 04 and 05 append to the CHANGELOG only.

- **Extend, do not create.** `HoneyDrunk.Telemetry.Sink.AzureMonitor` already exists in the Pulse solution. This packet completes/extends it — it does not scaffold a new package and must not create a `HoneyDrunk.Observe.AzureMonitor`.
- **No new abstraction.** The Pulse sink contracts already provide the reversibility seam; the sink implements them. Do not add `IObservabilityBackend`.
- **Match the existing sink family.** Register and structure the AzureMonitor sink the way `Sink.Loki`/`Sink.Mimir`/`Sink.Tempo` are — same conventions, same Vault-credential pattern, same per-sink failure isolation.
- **Leave seams for packets 04 and 05.** The sampler and the PII processors plug into the provider builders this packet wires — design the composition so they slot in without restructuring.

## Labels
`feature`, `tier-2`, `ops`, `adr-0040`, `wave-2`

## Agent Handoff

**Objective:** Extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider in the Pulse solution — the Azure Monitor OpenTelemetry Distro wired behind the Pulse sink contracts, shipping traces/metrics/logs to App Insights.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Give the Grid's OTLP telemetry a real sink — the load-bearing forcing function of ADR-0040 (a Pulse sink layer with no concrete backend fails the AI-sector standup canary).
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 2.
- ADRs: ADR-0040 D1/D2/D4 (primary; D2 amended 2026-05-22 — Pulse, not Observe, owns this), ADR-0028 (Pulse telemetry sink surface), ADR-0005 (Vault for the connection string).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0040 should be Accepted before its core implementation lands.
- `packet:02` — hard for the live smoke check (the `dev` App Insights resource + Vault connection string). The code can be authored and unit-tested without it; the end-to-end verification needs it.

**Constraints:**
- The Azure Monitor exporter lives in the Pulse runtime, never in a consuming Node — D2 reversibility.
- Extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` — do not create a new package, do not create `HoneyDrunk.Observe.AzureMonitor`.
- No new abstraction — the sink implements the existing `ITraceSink`/`ILogSink`/`IMetricsSink` contracts.
- Connection string from Vault via `ISecretStore`, same pattern as the other sinks (invariants 8, 9).
- First packet on the Pulse solution this initiative — bump the version (minor); every non-test `.csproj` moves together (invariant 27).
- Leave clean composition seams for the packet-04 sampler and the packet-05 PII processors.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` (existing project — extended)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit/`
- Repo-level `CHANGELOG.md`; the `.slnx`

**Contracts:** None new — the sink implements the existing Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`).
