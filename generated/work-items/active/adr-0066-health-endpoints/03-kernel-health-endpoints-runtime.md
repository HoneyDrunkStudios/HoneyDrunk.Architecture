---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0066", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0066"]
wave: 3
initiative: adr-0066-health-endpoints
node: honeydrunk-kernel
---

# Add MapHoneyDrunkHealthEndpoints, IETF response writer, Functions-host helper, and contributor execution timeout

## Summary
Add the runtime half of ADR-0066 to the `HoneyDrunk.Kernel` runtime package: the `MapHoneyDrunkHealthEndpoints` ASP.NET Core extension that maps the three endpoints (`/health/live`, `/health/ready`, `/health`), the IETF `application/health+json` response writer for `/health`, the `HealthFunctionExtensions` static helper for Functions-host composition, the aggregator that drives `IHealthContributor` instances per the readiness-policy model with worst-status-wins + critical-degraded escalation (D4), and the per-contributor 1-second timeout wrapper (D-Operational-Consequences). Append to the in-progress `[0.8.0]` CHANGELOG entry packet 02 opened.

## Context
Packet 02 ships the ADR-0066 *contracts* in `HoneyDrunk.Kernel.Abstractions` (`ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`). This packet ships the *runtime endpoints + aggregator* in the `HoneyDrunk.Kernel` package: the extension method every HTTP-fronted Node calls in its host composition, and the Functions-host helper for the Notify.Functions case (D9).

ADR-0066 D9 is explicit:
- Implementation home: `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` (runtime — not Abstractions — because it composes with ASP.NET Core types).
- Substrate: `Microsoft.Extensions.Diagnostics.HealthChecks` (the existing framework health-checks middleware) where it composes. Where the substrate's default response writer diverges from the IETF shape (it does — the default is a plain status string), Kernel ships its own response writer that emits the D2 shape.
- Functions-host shape: a static helper class `HealthFunctionExtensions` exposing `ExecuteHealthLiveAsync`, `ExecuteHealthReadyAsync`, `ExecuteHealthAggregateAsync` that consumers compose into their own `HttpTrigger` function (the Functions host is per-function-binding; consumers wire the helper inside their function).

ADR-0066 D4 commits the aggregation rules:
- Contributors invoked in `Priority` order (lower first).
- Aggregate is the **worst** of all contributor statuses, with **criticality refinement**: a `Degraded` from a contributor whose `IsCritical == true` escalates to `Unhealthy` for the aggregate.
- A throwing contributor is treated as `Unhealthy`, the exception message becomes the contributor's `output` (subject to D8 PII rule), and aggregation continues — one contributor's failure does not short-circuit others.
- `IHealthCheck` (the simpler internal-component primitive) is **not** consulted by the endpoint.

ADR-0066 D7 commits the readiness-policy aggregation refinement: `/health/ready` reflects only the subset of contributors with `ReadinessPolicy.Required` (its degraded/unhealthy status fails the endpoint); `OptionalReported` contributors appear in `/health` body but do not affect `/health/ready`; `NotReadinessRelevant` contributors only appear in `/health`. The default at registration is `Required`.

ADR-0066 Operational Consequences names the per-contributor timeout: the Kernel aggregator wraps each contributor in a **1-second timeout by default**, configurable per registration. A slow contributor (Vault, etc.) past 1 second is treated as `Unhealthy` with an output like "contributor timed out after 1s" — the readiness gate fails fast rather than letting a slow contributor delay the entire probe past Container Apps' 3-second timeout (which would fail the probe and take the Node out of rotation).

ADR-0066 D6 commits the auth posture: `/health/live` and `/health/ready` are anonymous; `/health` is auth-required. The `MapHoneyDrunkHealthEndpoints` extension wires this — the probe endpoints get an `AllowAnonymous` attribute (or the equivalent endpoint-routing convention) and `/health` is left to the host's default auth policy (the host configures the auth scheme; the extension declares the endpoint as requiring auth).

ADR-0066 D10 commits the telemetry contribution: every probe invocation contributes a `honeydrunk.health.probes` counter with `(node, endpoint, status_code, outcome)` dimensions, a `honeydrunk.health.contributor.duration` histogram with `(node, contributor)` dimensions, structured logs at Warning (failed probe) / Error (failed critical contributor / first-time-after-success 503). All via Kernel's existing `ITelemetryActivityFactory` — not a separate sink (D10 prose).

This packet is the **second packet on the `HoneyDrunk.Kernel` solution in this initiative**. Per invariant 27, packet 02 already bumped the solution to `0.8.0`; this packet does NOT bump again — it appends to the in-progress `[0.8.0]` CHANGELOG entry and adds a per-package CHANGELOG entry to `HoneyDrunk.Kernel` (which now has real functional changes). Coordinate the working branch with packet 02's: land 02 first (or rebase 03 onto 02's merge) so `0.8.0` is consistent.

## Scope
- `HoneyDrunk.Kernel` (runtime package) — new types and extensions in the `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` namespace:
  - `MapHoneyDrunkHealthEndpoints(this IEndpointRouteBuilder endpoints)` — ASP.NET Core endpoint mapper.
  - The IETF response writer that serializes the aggregator's output into `application/health+json`.
  - The contributor aggregator with worst-status-wins + critical-degraded-to-unhealthy escalation + 1-second per-contributor timeout (configurable).
  - The Pulse telemetry hooks (counter + histogram + structured log) per ADR-0066 D10.
- **New separate optional package** `HoneyDrunk.Kernel.Hosting.Functions` — pinned decision (no executor choice). Ships `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthFunctionExtensions` (same namespace) exposing `ExecuteHealthLiveAsync`, `ExecuteHealthReadyAsync`, `ExecuteHealthAggregateAsync` for the Functions-host case. Splitting keeps `Microsoft.Azure.Functions.Worker` out of pure-ASP.NET-Core consumers (`HoneyDrunk.Kernel` stays ASP.NET-Core-only). The new package ships with its own `CHANGELOG.md` + `README.md` from the first commit (invariant 12) and joins the solution at the same `0.8.0` version (invariant 27). It gets registered in `catalogs/relationships.json` as a follow-up catalog update (packet 01 catalogs the helper names, not the package split).
- Unit tests for: the response shape, aggregator semantics, criticality escalation, throwing-contributor handling, timeout behaviour, readiness-policy filtering, the keyless-ASP.NET case (host that has no auth scheme wired — `/health` should require auth, the absence of an auth scheme is a host configuration error not a runtime fallback).
- `HoneyDrunk.Kernel/CHANGELOG.md` gets a `[0.8.0]` per-package entry; repo-level `CHANGELOG.md` `[0.8.0]` entry is appended to (not newly created — packet 02 created it).
- `HoneyDrunk.Kernel/README.md` updated for the new runtime API surface.
- `HoneyDrunk.Kernel/docs/Health.md` is **not** edited in this packet — packet 04 amends the docs (separately, to keep this packet code-focused).

## Proposed Implementation
1. **Aggregator.** Implement an internal `HealthAggregator` (name TBD; live next to the endpoint helper). It takes an `IEnumerable<IHealthContributor>` (resolved from DI), a per-contributor `ReadinessPolicy` lookup (registered alongside each contributor per packet 02's shape), an `ITelemetryActivityFactory`, an `INodeContext` (for the `node` telemetry dimension and the `Version` / `releaseId` fields in the IETF response), and a configurable per-contributor timeout (`TimeSpan`, default 1 second).
   - Invokes contributors in `Priority` order.
   - Each contributor's call is wrapped in `Task.WhenAny(CheckHealthAsync(...), Task.Delay(timeout))`. On timeout: treat as `Unhealthy` with `output = "contributor timed out after {timeout}"`.
   - On exception: catch, treat as `Unhealthy`, set `output = ex.Message` (subject to D8 PII rule — the *exception* is the contributor's surface here, and the contributor is responsible for not throwing PII-laden messages). Aggregation continues — do not short-circuit.
   - Returns two surfaces: (a) the **aggregate** `HealthStatus` after worst-status-wins + criticality refinement (`Degraded` + `IsCritical == true` → `Unhealthy`); (b) the **per-contributor entries** for the IETF body.
   - For readiness, the aggregator exposes a separate "readiness aggregate" that filters by `ReadinessPolicy.Required` only — `/health/ready` reads this.
2. **`MapHoneyDrunkHealthEndpoints`** — an `IEndpointRouteBuilder` extension that maps three endpoints:
   - **`/health/live`** — anonymous; returns `200 OK` with empty body unless the host process is in the `Stopping`/`Stopped` lifecycle stage (per the existing `NodeLifecycleHealthContributor`), in which case `503`. **Does not consult contributors** (ADR-0066 D7) — protects against feedback-loop restarts on dependency hiccups.
   - **`/health/ready`** — anonymous; calls the aggregator's readiness-aggregate; returns `200` (healthy or degraded) or `503` (unhealthy) with **empty body** (ADR-0066 D2 — probes don't consume bodies, empty body avoids PII leak).
   - **`/health`** — auth-required (uses the host's default auth scheme; declared via `RequireAuthorization()` or equivalent); calls the aggregator's full aggregate; returns the IETF `application/health+json` body with the per-contributor breakdown.
3. **IETF response writer.** A small writer that turns the aggregator's output into the D2-shaped JSON:
   ```json
   {
     "status": "pass" | "warn" | "fail",
     "version": "...",
     "releaseId": "...",
     "checks": {
       "<contributor-name>": [{ "status": "...", "time": "...", "output": "..." }]
     }
   }
   ```
   Status mapping: `Healthy`→`"pass"`, `Degraded`→`"warn"`, `Unhealthy`→`"fail"` (ADR-0066 D3). `version` and `releaseId` from the assembly metadata (`AssemblyInformationalVersionAttribute` is the standard source; pick the one matching what the existing Kernel surfaces use for `IGridContext`'s release identification, if any). Content-Type header `application/health+json`.
4. **`HealthFunctionExtensions`** — static helper in the new `HoneyDrunk.Kernel.Hosting.Functions` package exposing:
   ```csharp
   public static Task<HttpResponseData> ExecuteHealthLiveAsync(HttpRequestData req, ...);
   public static Task<HttpResponseData> ExecuteHealthReadyAsync(HttpRequestData req, ...);
   public static Task<HttpResponseData> ExecuteHealthAggregateAsync(HttpRequestData req, ...);
   ```
   Each takes an `HttpRequestData` (Functions host) plus whatever DI services the consumer's function resolves (the aggregator, etc.) and returns an `HttpResponseData` with the same shape as the ASP.NET Core endpoint. The Functions consumer composes them into a `[Function(...)]` `[HttpTrigger(...)]`-bound function (precedent: `HoneyDrunk.Notify.Functions.HealthFunction` will call `ExecuteHealthAggregateAsync` once packet 06 wires it). **Package split is pinned:** the type lives in `HoneyDrunk.Kernel.Hosting.Functions`, not in `HoneyDrunk.Kernel` — pure-ASP.NET-Core consumers (Pulse.Collector, future Notify.Worker for the Worker side) take a dependency only on `HoneyDrunk.Kernel`; only Functions-host consumers (Notify.Functions today) take a dependency on `HoneyDrunk.Kernel.Hosting.Functions`.
5. **Telemetry per D10.**
   - Counter `honeydrunk.health.probes` with dimensions `(node, endpoint, status_code, outcome)`. `endpoint` is `live`/`ready`/`health`; `outcome` is `healthy`/`degraded`/`unhealthy`.
   - Histogram `honeydrunk.health.contributor.duration` with `(node, contributor)`. Recorded inside the aggregator's per-contributor invocation.
   - Structured log at **Warning** on a failed probe (`503` or contributor exception). **Error** if the failing contributor is `IsCritical`. **Error** on a first-time-after-success `503` (track the per-endpoint last-status in a small in-memory cache; the first transition healthy→unhealthy logs at Error unconditionally, sustained failures aggregate into the counter).
   - All emitted via Kernel's existing `ITelemetryActivityFactory` (D10 prose: "the same surface used by every other Kernel-instrumented operation"). Probe outcomes are NOT audit events (D10 prose).
6. **Auth posture.** The probe endpoints carry `AllowAnonymous`; `/health` carries `RequireAuthorization()` (no explicit policy name — the host configures the default policy / scheme). XML-doc the `/health` mapping to state that the host is responsible for configuring an auth scheme; if no scheme is configured, the host's default `RequireAuthorization()` behaviour applies (which on most hosts returns `401` — that is the right behaviour, not a fallback to anonymous). **No Kernel-side no-throw fallback ships in this packet.** A host that calls `MapHoneyDrunkHealthEndpoints` without an auth scheme wired will surface ASP.NET Core's default startup behaviour (the host's existing auth scheme is consulted; if none, the host's default policy applies). Packets 05/06 carry a Human Prerequisite requiring the host has an auth scheme wired before adopting the helper — invariant `{N2}` is enforced at the host, not by the Kernel helper.
7. **Unit tests** — using the InMemory `IHealthContributor` test doubles from the Kernel test stack:
   - Three healthy contributors → aggregate `Healthy`, IETF body has three `pass` entries.
   - One critical contributor reporting `Degraded` → aggregate escalated to `Unhealthy` (D4).
   - One non-critical contributor reporting `Degraded` → aggregate stays `Degraded`.
   - Throwing contributor → treated as `Unhealthy`, exception message in `output`, aggregation continues.
   - Slow contributor (drive via injected `TimeProvider` / cancellation token, no `Thread.Sleep` — invariant 51) → timed-out, `Unhealthy`, `output` says "timed out".
   - `/health/ready` filters to `ReadinessPolicy.Required` only; `OptionalReported` + `NotReadinessRelevant` contributors do not affect it.
   - `/health/live` does not consult contributors at all; returns `200` regardless of contributor state; returns `503` only when the lifecycle stage is `Stopping`/`Stopped`.
   - `/health` body matches the IETF wire shape (round-trip a JSON sample from ADR-0066 D2).
   - The `/health` endpoint requires auth — a request without credentials returns `401` (with the host's default scheme).
8. **Versioning** — do NOT bump versions; packet 02 already set the solution to `0.8.0`. Append the runtime additions to the existing repo-level `[0.8.0]` CHANGELOG entry. Add a `[0.8.0]` entry to `HoneyDrunk.Kernel/CHANGELOG.md` (this package now has real changes). Update `HoneyDrunk.Kernel/README.md`.

## Affected Files
- `HoneyDrunk.Kernel/Hosting/HealthEndpoints.cs` (or `HoneyDrunk.Kernel/Hosting/AspNetCore/HealthEndpoints.cs` if a deeper namespace is preferred to match the existing `Hosting/` folder layout — the existing `Hosting/` folder is `HoneyDrunkApplicationBuilderExtensions.cs`-shaped, single-level).
- `HoneyDrunk.Kernel/Hosting/HealthFunctionExtensions.cs` (or under `Hosting/Functions/`).
- `HoneyDrunk.Kernel/Health/HealthAggregator.cs` (next to `CompositeHealthCheck.cs`).
- `HoneyDrunk.Kernel/Health/IetfHealthResponseWriter.cs` (or similar).
- `HoneyDrunk.Kernel/Diagnostics/HealthProbeTelemetry.cs` (the counter/histogram/log emit helper).
- `HoneyDrunk.Kernel/CHANGELOG.md`, `HoneyDrunk.Kernel/README.md`.
- Repo-level `CHANGELOG.md` — append to the existing `[0.8.0]` entry.
- The Kernel unit-test project — new tests.

## NuGet Dependencies
- **`HoneyDrunk.Kernel`** — gains (or already has):
  - `Microsoft.AspNetCore.Routing` (or whatever the Kernel runtime already uses for `IEndpointRouteBuilder`/endpoint mapping — check the existing `HoneyDrunk.Kernel/Hosting/HoneyDrunkApplicationBuilderExtensions.cs` for the current set; reuse).
  - `Microsoft.AspNetCore.Authorization` (for `RequireAuthorization` / `AllowAnonymous`) if not already present.
  - `Microsoft.Extensions.Diagnostics.HealthChecks` — the substrate per ADR-0066 D9 (only if the existing helper does not already pull it in).
  - `System.Text.Json` (BCL — likely already a transitive).
  - **Does NOT take** a `PackageReference` on `Microsoft.Azure.Functions.Worker.*` — the Functions-host helper is split into the new `HoneyDrunk.Kernel.Hosting.Functions` package (see below).
- **`HoneyDrunk.Kernel.Hosting.Functions`** — new optional package:
  - `Microsoft.Azure.Functions.Worker` and `Microsoft.Azure.Functions.Worker.Extensions.Http`.
  - `PackageReference` on `HoneyDrunk.Kernel` (re-uses the aggregator + IETF response writer).
  - `HoneyDrunk.Standards` (`PrivateAssets: all`) like every other published package.
  - Joins the solution at `0.8.0` (invariant 27). Ships its own `CHANGELOG.md` + `README.md` from the first commit (invariant 12).
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`.
- **Kernel unit-test project** — the repo's existing test stack (ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet); add `Microsoft.AspNetCore.Mvc.Testing` (or `WebApplicationFactory`) only if the endpoint tests need a full pipeline — otherwise unit-test the aggregator + response writer + extension methods directly. State the choice in the PR.

## Boundary Check
- [x] `MapHoneyDrunkHealthEndpoints` (in `HoneyDrunk.Kernel`) and `HealthFunctionExtensions` (in the new `HoneyDrunk.Kernel.Hosting.Functions` package) are the runtime encoding of ADR-0066 D9.
- [x] No `PackageReference` from `HoneyDrunk.Kernel` to `HoneyDrunk.Transport` or other runtime HoneyDrunk packages (invariant 4, DAG preserved). `HoneyDrunk.Kernel.Hosting.Functions` depends only on `HoneyDrunk.Kernel`.
- [x] Runtime code in the `HoneyDrunk.Kernel` runtime package and the new sibling package, not in `Abstractions` (invariant 1/2).
- [x] The Functions-host helper does not force Functions packages onto ASP.NET-Core-only consumers (pinned: `HoneyDrunk.Kernel.Hosting.Functions` is a separate optional package).

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel` exposes `MapHoneyDrunkHealthEndpoints(this IEndpointRouteBuilder endpoints)` returning the `IEndpointRouteBuilder` for chaining
- [ ] `/health/live` is mapped, anonymous, returns `200` with empty body when the process is alive, `503` only when the lifecycle stage is `Stopping`/`Stopped`; does NOT consult contributors
- [ ] `/health/ready` is mapped, anonymous, calls the readiness aggregate (`ReadinessPolicy.Required` contributors only), returns `200` or `503` with empty body
- [ ] `/health` is mapped, auth-required (via `RequireAuthorization()` or equivalent), calls the full aggregate, returns the IETF `application/health+json` body
- [ ] The aggregator runs contributors in `Priority` order, applies worst-status-wins with `Degraded` + `IsCritical == true` escalating to `Unhealthy` (D4)
- [ ] A throwing contributor is treated as `Unhealthy` with the exception message as `output`; aggregation continues without short-circuiting
- [ ] Each contributor is wrapped in a configurable per-contributor timeout (default 1 second); timed-out contributors become `Unhealthy` with an "contributor timed out after {timeout}" output
- [ ] The IETF response writer emits `application/health+json` matching ADR-0066 D2's sample (status pass/warn/fail; version; releaseId; checks dictionary keyed by contributor name with per-entry status/time/output)
- [ ] `HealthFunctionExtensions` exposes `ExecuteHealthLiveAsync`, `ExecuteHealthReadyAsync`, `ExecuteHealthAggregateAsync` with `HttpRequestData` → `HttpResponseData` shapes; **ships in the new `HoneyDrunk.Kernel.Hosting.Functions` package (pinned), not in `HoneyDrunk.Kernel`**
- [ ] Telemetry per D10: counter `honeydrunk.health.probes` with `(node, endpoint, status_code, outcome)` dimensions; histogram `honeydrunk.health.contributor.duration` with `(node, contributor)` dimensions; Warning log on failed probe, Error on failed critical contributor and on first-time-after-success `503`
- [ ] Probe outcomes are NOT emitted as audit events
- [ ] `IHealthCheck` (the simpler internal-component primitive) is NOT consulted by the endpoint or aggregator (D4)
- [ ] All new public types have XML documentation (invariant 13)
- [ ] No `PackageReference` to other HoneyDrunk runtime packages (invariant 4)
- [ ] No version bump in this packet — the solution stays at `0.8.0` from packet 02
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` has a `[0.8.0]` entry for the new runtime endpoints + aggregator + helpers
- [ ] Repo-level `CHANGELOG.md` `[0.8.0]` entry is extended (not duplicated) with the runtime additions
- [ ] `HoneyDrunk.Kernel/README.md` documents `MapHoneyDrunkHealthEndpoints` and the Functions-host helper
- [ ] The new `HoneyDrunk.Kernel.Hosting.Functions` package ships with its own `CHANGELOG.md` + `README.md` from the first commit and is at `0.8.0` (invariants 12, 27)
- [ ] Unit tests cover: worst-status-wins, critical-degraded escalation, throwing-contributor, timeout, readiness-policy filtering, `/health/live` not consulting contributors, IETF response round-trip, `/health` requires auth
- [ ] Unit tests contain no `Thread.Sleep` (invariant 51) — timing driven by injected `TimeProvider` / cancellation tokens
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0066 D1 — Three endpoints.** `/health/live` (liveness — process alive, no dep checks), `/health/ready` (readiness — required deps reachable), `/health` (full aggregate, auth-required).

**ADR-0066 D2 — Response shape.** Probes: empty body + `200`/`503`. `/health`: IETF `application/health+json` body with `status`/`version`/`releaseId`/`checks`. Status mapping `Healthy`→`pass`, `Degraded`→`warn`, `Unhealthy`→`fail` (D3).

**ADR-0066 D4 — Aggregation.** Worst-status-wins across contributors, in `Priority` order. **Criticality refinement: a `Degraded` from a contributor whose `IsCritical == true` escalates to `Unhealthy`.** A throwing contributor → `Unhealthy`, exception message as `output`, aggregation continues. `IHealthCheck` (simpler internal primitive) is NOT consulted by the endpoint — it stays the internal-component shape.

**ADR-0066 D6 — Auth posture.** `/health/live` and `/health/ready` anonymous; `/health` auth-required (host configures scheme).

**ADR-0066 D7 — Readiness-policy aggregation.** `/health/ready` aggregates only `ReadinessPolicy.Required` contributors. Default at registration is `Required`. `OptionalReported` and `NotReadinessRelevant` appear in `/health` body (D7 prose; `NotReadinessRelevant` is even more restricted — only `/health`).

**ADR-0066 D9 — Implementation home + substrate.** `HoneyDrunk.Kernel.Hosting.AspNetCore.HealthEndpoints` with `MapHoneyDrunkHealthEndpoints`. Substrate: `Microsoft.Extensions.Diagnostics.HealthChecks` plus a Kernel-shipped IETF response writer. Functions-host helper class with three static `ExecuteHealth*Async` methods. The `INotifyHealthContributor` reconciliation (the Notify-private interface bridging) is packet 06's work, not this packet's.

**ADR-0066 D10 — Telemetry.** Counter `honeydrunk.health.probes` with `(node, endpoint, status_code, outcome)`. Histogram `honeydrunk.health.contributor.duration` with `(node, contributor)`. Warning log on failed probe; Error on failed critical contributor; first-time-after-success `503` logs at Error. Emitted via `ITelemetryActivityFactory`. Probe outcomes are NOT audit events.

**ADR-0066 Operational Consequences — Contributor timeout.** "Contributors must be aggressively bounded (sub-100ms target, hard timeout enforced by the aggregator). The Kernel aggregator wraps each contributor in a 1-second timeout by default; configurable per registration."

**ADR-0066 D11 — Out of scope.** No public status page, no cross-Node aggregate dashboard, no per-tenant readiness, no tenant-visible SLA signal from this endpoint — those are future concerns that compose against the contract this packet ships.

## Constraints
- **Invariant 2 — runtime packages depend on Abstractions, never on another runtime package at the same layer.** `HoneyDrunk.Kernel` depends on `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 4 — DAG; Kernel is at the root.** `HoneyDrunk.Kernel` must NOT take a `PackageReference` on any other HoneyDrunk runtime package.
- **Invariant 13 — all public APIs have XML documentation.**
- **Invariant 27 — one version across the solution.** Packet 02 already bumped to `0.8.0`; this packet does NOT bump again — it appends to the in-progress `[0.8.0]` CHANGELOG. If a new optional Functions-host package is introduced, it lands at the same `0.8.0` version.
- **Invariant 51 — no `Thread.Sleep` in test code.** Timeout/duration tests drive an injected `TimeProvider` or cancellation token.
- **Invariant 12 — new packages ship CHANGELOG.md and README.md from the first commit.** If the optional Functions-host package is introduced, both files exist from the first commit.
- **Probe outcomes are NOT audit events.** ADR-0066 D10 explicit — probes flow telemetry only, never `IAuditLog`.
- **`IHealthCheck` is not consulted by the endpoint.** ADR-0066 D4 — the simpler primitive stays internal-component shape; only `IHealthContributor` participates in endpoint aggregation.
- **`/health/live` does not consult contributors.** ADR-0066 D7 — it returns based on lifecycle stage only, to prevent feedback-loop restarts.

## Labels
`feature`, `tier-2`, `core`, `adr-0066`, `wave-3`

## Agent Handoff

**Objective:** Add the ADR-0066 runtime endpoints, aggregator, IETF response writer, Functions-host helper, contributor timeout wrapper, and Pulse telemetry contribution to the `HoneyDrunk.Kernel` runtime package.

**Target:** `HoneyDrunk.Kernel`, branch from `main` (after packet 02 has merged — rebase if needed so `0.8.0` is consistent).

**Context:**
- Goal: Ship the endpoint surface every other Node calls in its host composition.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 3.
- ADRs: ADR-0066 D1/D2/D3/D4/D6/D7/D9/D10 (primary), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry` ship in `HoneyDrunk.Kernel.Abstractions` `0.8.0`. Land 02 first or rebase onto its merge.

**Constraints:**
- No `PackageReference` to other HoneyDrunk runtime packages (invariant 4).
- No version bump — packet 02 set `0.8.0`; append to the in-progress `[0.8.0]` CHANGELOG.
- Probe outcomes flow as telemetry, never as audit events (D10).
- `IHealthCheck` is not consulted by the endpoint; only `IHealthContributor` (D4).
- `/health/live` does not consult contributors; it returns based on lifecycle stage only (D7).
- Contributor execution wrapped in a 1-second default timeout (configurable per registration).
- Records / types drop the `I`; interfaces keep it.

**Key Files:**
- `HoneyDrunk.Kernel/Hosting/HealthEndpoints.cs` — ASP.NET Core endpoint mapper.
- `HoneyDrunk.Kernel/Health/HealthAggregator.cs`, `IetfHealthResponseWriter.cs`.
- `HoneyDrunk.Kernel/Diagnostics/HealthProbeTelemetry.cs`.
- `HoneyDrunk.Kernel.Hosting.Functions/` — new project: `HealthFunctionExtensions.cs`, `HoneyDrunk.Kernel.Hosting.Functions.csproj`, `CHANGELOG.md`, `README.md`.
- `HoneyDrunk.Kernel/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.

**Contracts:**
- `MapHoneyDrunkHealthEndpoints` (new extension in `HoneyDrunk.Kernel` runtime) — maps `/health/live`, `/health/ready`, `/health`.
- `HealthFunctionExtensions` (new static class in the new `HoneyDrunk.Kernel.Hosting.Functions` package) — Functions-host helper with three `ExecuteHealth*Async` methods.
- Consumes `ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`, `IHealthContributor` from `HoneyDrunk.Kernel.Abstractions` `0.8.0`.
