# Handoff — Wave 1 → Wave 2: the Pulse telemetry backing

**Read once at the Wave 1 → Wave 2 transition. Immutable (invariant 24).**

> **Note:** the filename retains `observe` for manifest stability; the work is in `HoneyDrunk.Pulse` (ADR-0040 amendment 2026-05-22 — Pulse owns outbound telemetry export, not Observe).

## What Wave 1 produced

- **ADR-0040 is Accepted** (packet 00). Status flipped; `adrs/README.md` updated. Three new telemetry invariants — **69, 70, 71** (the pre-reserved block; current highest in `constitution/invariants.md` is 51) — are added:
  1. *(69) No Node references Application Insights or any telemetry backend directly.* All telemetry routes through the `HoneyDrunk.Pulse` sink surface; backend changes are a single Pulse configuration change.
  2. *(70) High-cardinality identifiers belong on traces and logs, never duplicated as custom dimensions on metrics.* `user.id`, `message.id`, `request.id` are trace/log dimensions only.
  3. *(71) Prompt and completion text appears in telemetry only behind the `evals.sensitive=true` custom dimension and the dedicated Log Analytics table.* Default-deny for user content and model output; `HoneyDrunk.Evals` is the only carve-out.
- **The Grid catalogs record the backend** (packet 01). `catalogs/grid-health.json` has the new telemetry readout with the three per-environment App Insights resources; `catalogs/relationships.json` lists `HoneyDrunk.Telemetry.Sampling` (and `HoneyDrunk.Telemetry.Sink.AzureMonitor`) under the `honeydrunk-pulse` entry's `exposes.packages`. Note: package registration is a `relationships.json` concern — `nodes.json` has no package field.
- **The `dev` App Insights resource exists** (packet 02). `infrastructure/walkthroughs/application-insights-provisioning.md` was authored and executed for `dev`: a workspace-based App Insights resource, its backing Log Analytics workspace, a daily ingestion cap, and the connection string stored as a secret in the **Pulse** Node's `kv-hd-{service}-dev` Key Vault. `grid-health.json` shows the `dev` resource `provisioned`. **Read the walkthrough for the concrete Azure resource names and the backing-workspace decision.**

## Wave 2 packet

One packet:

- **Packet 03 (`Actor=Agent`)** — extend `HoneyDrunk.Telemetry.Sink.AzureMonitor` in the `HoneyDrunk.Pulse` solution: the Azure Monitor OpenTelemetry Distro wired behind the existing Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`), shipping traces/metrics/logs to the `dev` App Insights resource.

## Critical context for Wave 2 execution

- **Extend, do not create.** `HoneyDrunk.Pulse` is a **live** Node at v0.3.0. The Pulse solution already ships a `HoneyDrunk.Telemetry.Sink.AzureMonitor` project (alongside `Sink.Loki`, `Sink.Mimir`, `Sink.Tempo`, `Sink.Sentry`, `Sink.PostHog`, `Sink.Shared`). Packet 03 *extends* that existing provider — it does not scaffold a new package, and must not create `HoneyDrunk.Observe.AzureMonitor`.
- **No new abstraction.** The Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink` in `HoneyDrunk.Telemetry.Abstractions`) already are the reversibility seam — every `HoneyDrunk.Telemetry.Sink.*` provider satisfies them. The AzureMonitor sink implements those existing contracts. Do not add `IObservabilityBackend` or any other new abstraction.
- **Connection string from Vault.** The App Insights connection string (seeded by packet 02 into the Pulse Node's `kv-hd-{service}-dev` vault) is resolved via `ISecretStore` — invariant 9, Vault is the only source of secrets; the Pulse boundaries doc states "Sink credentials come from Vault." Match how the other `HoneyDrunk.Telemetry.Sink.*` providers obtain Vault-sourced credentials. Never read it from an environment variable holding the raw value or from an Azure SDK default. Unit tests use an in-memory secret store (invariant 15 — no live resource in unit tests).
- **Match the existing sink family.** Register and structure the AzureMonitor sink the way `Sink.Loki`/`Sink.Mimir`/`Sink.Tempo` are — same conventions, same Vault-credential pattern. Preserve Pulse's per-sink failure isolation — the AzureMonitor sink failing must not take down the other sinks.
- **Leave seams for Wave 3.** Packet 04 (sampling) plugs a `Sampler` into the `TracerProvider`; packet 05 (PII processors) plugs `SpanProcessor`/`LogRecordProcessor` into the `TracerProvider`/`LoggerProvider`. Design packet 03's composition so these slot in via builder hooks / DI extension points — without restructuring the package.
- **First packet on the `HoneyDrunk.Pulse` solution this initiative — it bumps the version** (minor, for the sink gaining a real backend). Every non-test `.csproj` moves to the same new version (invariant 27). Wave-3 packets 04, 05, and 07 append to the CHANGELOG only.
- **Metrics and logs are not sampled** (D4) — wire the `MeterProvider` and `LoggerProvider` straight through. Only the trace path gets a sampler (Wave 3).

## Wave 2 exit criteria

- `HoneyDrunk.Telemetry.Sink.AzureMonitor` is extended (not newly created) with the Azure Monitor OpenTelemetry Distro, implementing the existing Pulse sink contracts; traces/metrics/logs flow to the `dev` App Insights resource via the Vault-resolved connection string.
- No new abstraction is introduced — the sink implements the existing `ITraceSink`/`ILogSink`/`IMetricsSink`.
- Clean composition seams exist for the Wave-3 sampler and PII processors.
- The `HoneyDrunk.Pulse` solution version is bumped (minor); `HoneyDrunk.Telemetry.Sink.AzureMonitor` has `CHANGELOG.md` + `README.md`; the repo-level `CHANGELOG.md` has the new-version entry.
- The solution builds; unit tests (in-memory doubles, no live resource) pass.
