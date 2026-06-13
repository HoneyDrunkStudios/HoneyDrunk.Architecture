# Handoff — Wave 3: Kernel Runtime

**Initiative:** `adr-0066-health-endpoints`
**Wave transition:** Wave 2 (contract foundation) → Wave 3 (Kernel runtime + docs)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 + Wave 2 landed

- **Packet 00** — ADR-0066 flipped to **Accepted**. The ADR-0066 row inserted into `adrs/README.md`. Three new invariants added to `constitution/invariants.md` under a new `## Health Endpoint Invariants` section, numbered **54, 55, 56**:
  1. **54** — Every HTTP-fronted deployable Node exposes `/health/live`, `/health/ready`, and `/health` via Kernel's `MapHoneyDrunkHealthEndpoints` (or the Functions-host equivalent), aggregating `IHealthContributor` instances per the readiness-policy model.
  2. **55** — `/health/live` and `/health/ready` are anonymous; `/health` is auth-required.
  3. **56** — `IHealthContributor` `output` strings must not carry secrets, connection strings, tenant identifiers, or provider opaque IDs (per ADR-0049 data-classification taxonomy). Complements (does not restate) invariant 8.
- **Packet 01** — the health-endpoint contract surface (`ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`, `MapHoneyDrunkHealthEndpoints`, `HealthFunctionExtensions`) registered in `catalogs/contracts.json` and `catalogs/relationships.json` under `honeydrunk-kernel`. `catalogs/nodes.json` was NOT modified (it has no `exposes` field). `repos/HoneyDrunk.Kernel/integration-points.md` gained a "Health endpoints (ADR-0066)" subsection; `repos/HoneyDrunk.Notify/integration-points.md` gained a "Health contributor reconciliation (ADR-0066)" subsection.
- **Packet 02** — `HoneyDrunk.Kernel.Abstractions` now exposes the ADR-0066 contracts:
  - `ReadinessPolicy` enum — `Required` (default; zero-value), `OptionalReported`, `NotReadinessRelevant`.
  - `HealthCheckResponse` record — IETF `application/health+json` body root (`Status`, `Version?`, `ReleaseId?`, `Checks` dictionary).
  - `HealthCheckEntry` record — per-contributor entry (`Status`, `Time`, optional `Output`).
  - The contributor-registration helper shape (extension method or registration record) for declaring a contributor's `ReadinessPolicy` at composition.
  - The `HoneyDrunk.Kernel` solution is at `0.8.0` (or the same `0.8.0` line shared with ADR-0042 if both initiatives are concurrent).

ADR-0066's decisions are now live rules. Packets 03 and 04 implement the runtime endpoints + docs that consume the catalog-registered contracts.

## What Wave 3 must deliver

### Packet 03 — Kernel runtime endpoints

Build the runtime half of ADR-0066 in **`HoneyDrunk.Kernel`**:

- **`HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints`** — static class with `MapHoneyDrunkHealthEndpoints(this IEndpointRouteBuilder endpoints)` that maps:
  - `/health/live` — anonymous, returns `200` (empty body) when alive, `503` only when the lifecycle stage is `Stopping`/`Stopped`. **Does NOT consult contributors** (ADR-0066 D7 — protects against feedback-loop restarts).
  - `/health/ready` — anonymous, returns `200`/`503` (empty body) based on the readiness aggregate (`ReadinessPolicy.Required` contributors only).
  - `/health` — auth-required (via `RequireAuthorization()` or equivalent), returns the IETF `application/health+json` body.
- **`HoneyDrunk.Kernel.Hosting.AspNetCore.HealthFunctionExtensions`** — static class exposing `ExecuteHealthLiveAsync`, `ExecuteHealthReadyAsync`, `ExecuteHealthAggregateAsync` for the Functions-host case. Consumers compose these inside their own `[Function]` `[HttpTrigger]`-bound functions. **Pinned: ships in the new optional `HoneyDrunk.Kernel.Hosting.Functions` package** (not in `HoneyDrunk.Kernel`) to keep `Microsoft.Azure.Functions.Worker.*` out of pure-ASP.NET-Core consumers. The new package joins the solution at `0.8.0` with its own `CHANGELOG.md` + `README.md` from the first commit (invariants 12, 27).
- **Aggregator** with worst-status-wins + critical-degraded escalation (`Degraded` + `IsCritical == true` → `Unhealthy` per D4) + throwing-contributor handling (treated as `Unhealthy`, exception message as `output`, aggregation continues — does not short-circuit) + per-contributor timeout (1-second default, configurable per registration). Invokes contributors in `Priority` order. Exposes both a full aggregate (for `/health`) and a readiness aggregate (for `/health/ready`, filtered to `ReadinessPolicy.Required`).
- **IETF response writer** — serializes the aggregator's output to `application/health+json` per ADR-0066 D2 sample. Status mapping: `Healthy`→`"pass"`, `Degraded`→`"warn"`, `Unhealthy`→`"fail"` (D3). Content-Type `application/health+json`.
- **Pulse telemetry contribution per D10:**
  - Counter `honeydrunk.health.probes` with `(node, endpoint, status_code, outcome)` dimensions.
  - Histogram `honeydrunk.health.contributor.duration` with `(node, contributor)` dimensions.
  - Structured log: Warning on failed probe; Error on failed critical contributor; Error on first-time-after-success `503`.
  - Emitted via `ITelemetryActivityFactory`. **NOT** audit events (D10).

### Packet 04 — Kernel docs amendment

Amend `HoneyDrunk.Kernel/docs/Health.md` with new sections covering the ADR-0066 endpoint contract, `ReadinessPolicy` model, aggregation rules, Container Apps probe defaults (D5), Pulse telemetry (D10), the PII rule (D8), and migration notes for the Pulse/Notify amendments in packets 05/06/07. Keep the existing `IHealthCheck`/`HealthStatus`/`CompositeHealthCheck` narrative (the internal-primitive story stays accurate). Explicitly note that `IHealthCheck` is NOT consulted by the endpoint — only `IHealthContributor` participates.

This is the **second packet on the `HoneyDrunk.Kernel` solution in this initiative** (after packet 02). Per invariant 27, packet 02 already bumped the solution to `0.8.0`; packet 03 does NOT bump again — it appends to the in-progress `[0.8.0]` repo-level `CHANGELOG.md` entry and adds a per-package `HoneyDrunk.Kernel/CHANGELOG.md` entry. Packet 04 (docs) also does NOT bump — it appends a docs note to the in-progress `[0.8.0]` repo-level CHANGELOG.

## Interface signatures for downstream packets

The shape packets 05/06 will compose against:

```csharp
// ASP.NET Core host:
public static IEndpointRouteBuilder MapHoneyDrunkHealthEndpoints(this IEndpointRouteBuilder endpoints);

// Functions host:
public static class HealthFunctionExtensions
{
    public static Task<HttpResponseData> ExecuteHealthLiveAsync(HttpRequestData req, /* DI args */);
    public static Task<HttpResponseData> ExecuteHealthReadyAsync(HttpRequestData req, /* DI args */);
    public static Task<HttpResponseData> ExecuteHealthAggregateAsync(HttpRequestData req, /* DI args */);
}

// Contributor registration with ReadinessPolicy (shape per packet 02):
services.AddHealthContributor<MyContributor>(ReadinessPolicy.Required); // or similar
```

`IHealthContributor` (already in `Kernel.Abstractions.Lifecycle`):
```csharp
public interface IHealthContributor
{
    string Name { get; }
    int Priority { get; }
    bool IsCritical { get; }
    Task<(HealthStatus status, string? message)> CheckHealthAsync(CancellationToken cancellationToken = default);
}
```

`ReadinessPolicy` (from packet 02):
```csharp
public enum ReadinessPolicy
{
    Required = 0,         // gates /health/ready (default)
    OptionalReported,     // in /health body only
    NotReadinessRelevant  // only in /health, not in readiness aggregation
}
```

## Frozen / do-not-touch

- **`IHealthContributor` and `IReadinessContributor` (in `Kernel.Abstractions.Lifecycle`).** These existed before ADR-0066 and remain unchanged. The endpoint aggregator consumes `IHealthContributor`. `IReadinessContributor` is a parallel surface that exists today; ADR-0066 does NOT remove it but the endpoint code only reads `IHealthContributor`. If `IReadinessContributor` becomes redundant after ADR-0066's `ReadinessPolicy` model lands, that is a follow-up concern — not packet 03's.
- **`IHealthCheck` and `HealthStatus` (in `Kernel.Abstractions.Health`).** The simpler internal-component primitive stays as-is per ADR-0066 D4. The endpoint aggregator does NOT consult `IHealthCheck`.
- **`CompositeHealthCheck` (in `Kernel/Health/`).** The simple internal aggregator for `IHealthCheck` stays as-is. The endpoint uses its own aggregator that consumes `IHealthContributor` only.
- **`NodeLifecycleHealthContributor` (in `Kernel/Diagnostics/`).** The existing lifecycle contributor stays as-is. Its `IsCritical == true` means a `Degraded` from it escalates the aggregate to `Unhealthy` per D4 — confirm this works in unit tests.

## Invariants binding Wave 3

- **Invariant 1** — `HoneyDrunk.Kernel.Abstractions` has zero runtime dependencies on other HoneyDrunk packages. Packet 03 lives in the runtime package; it can take ASP.NET Core dependencies.
- **Invariant 2** — runtime packages depend on Abstractions; `HoneyDrunk.Kernel` depends on `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 4** — DAG; Kernel is at the root. No `PackageReference` to other HoneyDrunk runtime packages.
- **Invariant 13** — all public APIs have XML documentation.
- **Invariant 27** — one version across the solution. Packet 02 set `0.8.0`; packet 03 does NOT bump again — it appends to the `[0.8.0]` CHANGELOG.
- **Invariant 51** — no `Thread.Sleep` in tests. Timeout / duration tests drive an injected `TimeProvider` / cancellation tokens.
- **Invariant `{N2}`** — `/health` is auth-required. The endpoint mapping wires `RequireAuthorization()` (or equivalent); host configures the scheme.
- **Invariant `{N3}`** — contributor `output` strings carry no secrets / connection strings / tenant identifiers / provider opaque IDs. The aggregator and response writer do NOT auto-redact; the contributor is responsible at the report site. XML-doc this on `HealthCheckEntry.Output` (already done in packet 02).
- **ADR-0066 D7** — `/health/live` does NOT consult contributors. It returns based on lifecycle stage only.
- **ADR-0066 D10** — probe outcomes are NOT audit events. Pulse telemetry only.
- **ADR-0066 Operational Consequences** — the per-contributor timeout default is 1 second; configurable per registration.

## Cross-Initiative Coordination — ADR-0042

If ADR-0042 packet 02 has already merged when this packet starts, the `HoneyDrunk.Kernel` solution is already at `0.8.0`. Packet 03 (this packet) and packet 04 (docs) of ADR-0066 both append to the in-progress `[0.8.0]` CHANGELOG without re-bumping.

If ADR-0042 has not yet merged, the operator decides the sequencing — coordinate so the two initiatives share the `0.8.0` line cleanly.

## Acceptance gate for the wave

Packets 03 and 04's PRs pass the `pr-core.yml` tier-1 gate and the Kernel contract-shape canary. `HoneyDrunk.Kernel` exposes `MapHoneyDrunkHealthEndpoints` and `HealthFunctionExtensions` (and the docs accurately describe them). The aggregator works correctly under unit tests (worst-status-wins, criticality escalation, throwing-contributor, timeout, readiness-policy filtering). `/health/live` does not consult contributors. `/health` requires auth.

**Human package release at the Wave 3→4 boundary — agents never tag.** Packets 05 and 06 (Wave 4) build against `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` and `HoneyDrunk.Kernel.Hosting.Functions` `0.8.0` (new package, pinned in packet 03). Those artifacts reach the package feed only after a human pushes a git release tag on `HoneyDrunk.Kernel`. After packets 02, 03, and 04 have all merged (and after the ADR-0042 packet 02 if it shares the `0.8.0` line), a human tags/releases `HoneyDrunk.Kernel` `0.8.0` AND `HoneyDrunk.Kernel.Hosting.Functions` `0.8.0` so Wave 4 can compile.
