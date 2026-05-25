---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Cache
labels: ["feature", "tier-2", "cache", "redis", "telemetry", "adr-0076", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0076", "ADR-0040", "ADR-0045"]
accepts: ADR-0076
wave: 3
initiative: adr-0076-cache-backing-redis
node: honeydrunk-cache
---

# Feature: Wire `HoneyDrunk.Cache.Redis` telemetry, health contributor, and `IErrorReporter` failure path

## Summary
Add operational hooks to the Redis backing landed by packet 03. Wire telemetry (hit count, miss count, eviction count if observable, command latency p50/p95/p99, connection-pool depth) through Kernel's `ITelemetryActivityFactory` per ADR-0040 D6 — telemetry flows one-way to Pulse, no runtime dependency on Pulse. Add an `IHealthContributor` reporting Redis connection state and recent hit/miss ratio for the Kernel-level `/health` and `/ready` endpoints. Wire `IErrorReporter` from `HoneyDrunk.Pulse.Abstractions` per ADR-0045 D3 for connection failures, command timeouts, and deserialization errors — also one-way. **Appends to in-progress `[0.1.0]` from packet 03 — no new version bump.**

This packet hardens the Redis backing's operational shape so the first consumer composition (Notify Cloud multi-replica or Communications shared cache) lands against a production-ready backing with cache-hit-ratio visibility, fail-fast health reporting, and structured error capture in App Insights.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Cache`

## Motivation

ADR-0076 D6 commits operational discipline: telemetry via the Pulse pipeline (hit rate, miss rate, evictions, latency p50/p95/p99, connection-pool depth) per ADR-0040, error tracking via Azure App Insights per ADR-0045 (connection failures, command timeouts, deserialization errors), cost monitoring per ADR-0052, DR tier 2 per ADR-0036. Packet 03 shipped the bare `RedisCacheStore<T>` and `RedisCacheStartupHook` — neither emits telemetry or reports health. This packet fills the operational gap.

The discipline applies the established Grid pattern: telemetry is one-way from emitting Nodes to Pulse via Kernel's activity factory; error reporting is one-way through `IErrorReporter` (a thin facade over the existing `IErrorSink` Pulse surface per ADR-0045 D3); the Cache package takes no runtime dependency on Pulse. Health reporting plugs into Kernel's `IHealthContributor` contract, which Kernel-hosted endpoints aggregate at `/health` and `/ready`.

## Scope

- `src/HoneyDrunk.Cache.Redis/` updates:
  - Telemetry instrumentation on every `RedisCacheStore<T>` operation. `Activity` spans for `cache.get`, `cache.set`, `cache.remove`, `cache.remove-by-tag` with attributes for outcome (`hit` / `miss` / `success` / `failure`), key (trace attribute only, NOT a metric dimension per ADR-0040 D6 — invariant 70 equivalent), and latency (recorded as a metric instrument).
  - Counter metrics: `cache.hits`, `cache.misses`, `cache.errors`. Histogram metrics: `cache.command.duration_ms` (per-operation latency). Tags: `cache.backing=redis`, `cache.value_type=<T>`, `cache.outcome=hit|miss|success|failure`. **No high-cardinality tags** (no key, no tenant id on metrics — those go on traces per ADR-0040 D6).
  - `RedisHealthContributor` implementing `IHealthContributor` from `HoneyDrunk.Kernel.Abstractions.Health` (verify exact namespace at edit time per repo convention — see existing Vault / Auth health contributors). Reports: connection state (`Healthy` if `IConnectionMultiplexer.IsConnected`; `Unhealthy` otherwise), most recent `PING` latency in ms, recent hit ratio over the last sampling window.
  - `IErrorReporter`-backed error reporting on connection failures, command timeouts, and deserialization exceptions. The reporter is injected (`IErrorReporter?` — nullable, so the package functions without Pulse composed if a future consumer chooses to skip error reporting). When non-null, every exception path in `RedisCacheStore<T>` calls `_errorReporter.Report(exception, context)` before propagating.
  - DI registration extension updated: `AddHoneyDrunkCacheRedis<T>` now wires the `IHealthContributor` (singleton) and, if an `IErrorReporter` is already registered in the container, picks it up via constructor injection on `RedisCacheStore<T>`.
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` and repo-level `CHANGELOG.md` — append to in-progress `[0.1.0]` (no new version bump per invariant 27).
- `src/HoneyDrunk.Cache.Redis/README.md` — update operational-shape section to document the telemetry, health, and error-reporting surfaces.
- Unit tests:
  - Telemetry: verify `Activity` is started on each operation; verify counters increment for hits/misses; verify outcome tag is set correctly.
  - Health: verify Healthy when multiplexer reports connected; Unhealthy when disconnected; recent hit ratio computed correctly.
  - Error reporting: verify `IErrorReporter.Report` is called on injected exception types (connection failure, timeout, deserialization error); verify the exception still propagates after the report.

## Proposed Implementation

### Telemetry instrumentation

Wrap every `RedisCacheStore<T>` method body in an `Activity` (started via `ITelemetryActivityFactory` from `HoneyDrunk.Kernel.Abstractions.Telemetry` — confirm exact API at edit time per the existing Vault / Auth telemetry patterns).

```csharp
public async ValueTask<T?> GetAsync(string key, CancellationToken ct = default)
{
    ct.ThrowIfCancellationRequested();
    using var activity = _activityFactory.StartActivity("cache.get", ActivityKind.Client);
    activity?.SetTag("cache.backing", "redis");
    activity?.SetTag("cache.value_type", typeof(T).Name);
    activity?.SetTag("cache.key", key);     // trace attribute, not a metric dimension

    var sw = Stopwatch.StartNew();
    try
    {
        var db = _multiplexer.GetDatabase();
        var value = await db.StringGetAsync(NamespaceKey(key)).ConfigureAwait(false);
        var elapsed = sw.Elapsed.TotalMilliseconds;
        _commandDuration.Record(elapsed, KeyValuePair.Create<string, object?>("cache.operation", "get"));

        if (value.IsNullOrEmpty)
        {
            activity?.SetTag("cache.outcome", "miss");
            _missCounter.Add(1, KeyValuePair.Create<string, object?>("cache.value_type", typeof(T).Name));
            return default;
        }

        activity?.SetTag("cache.outcome", "hit");
        _hitCounter.Add(1, KeyValuePair.Create<string, object?>("cache.value_type", typeof(T).Name));
        return JsonSerializer.Deserialize<T>(value!, _serializerOptions);
    }
    catch (Exception ex)
    {
        activity?.SetTag("cache.outcome", "failure");
        activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
        _errorCounter.Add(1, KeyValuePair.Create<string, object?>("cache.operation", "get"));
        _errorReporter?.Report(ex, new ErrorReportContext { Operation = "cache.get", Key = key });
        throw;
    }
}
```

Same pattern for `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`. Counters and histograms are static `Meter` instruments owned by `RedisCacheStore<T>` (or by a sibling `Telemetry.cs` static class — agent's call per repo convention).

### `RedisHealthContributor`

```csharp
namespace HoneyDrunk.Cache.Redis;

/// <summary>
/// Health contributor reporting Redis connection state and recent cache hit ratio.
/// Aggregated by Kernel into the /health and /ready endpoints.
/// </summary>
public sealed class RedisHealthContributor : IHealthContributor
{
    private readonly IConnectionMultiplexer _multiplexer;
    private readonly RedisCacheTelemetry _telemetry;

    public RedisHealthContributor(IConnectionMultiplexer multiplexer, RedisCacheTelemetry telemetry)
    {
        _multiplexer = multiplexer ?? throw new ArgumentNullException(nameof(multiplexer));
        _telemetry = telemetry ?? throw new ArgumentNullException(nameof(telemetry));
    }

    public string Name => "cache.redis";

    public async Task<HealthCheckResult> CheckAsync(CancellationToken cancellationToken)
    {
        if (!_multiplexer.IsConnected)
        {
            return HealthCheckResult.Unhealthy("Redis multiplexer reports disconnected.");
        }

        try
        {
            var db = _multiplexer.GetDatabase();
            var pong = await db.PingAsync().ConfigureAwait(false);
            var hitRatio = _telemetry.RecentHitRatio();
            var data = new Dictionary<string, object?>
            {
                ["ping_ms"] = pong.TotalMilliseconds,
                ["hit_ratio"] = hitRatio,
            };
            return HealthCheckResult.Healthy("Redis reachable.", data);
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Redis ping failed.", ex);
        }
    }
}
```

(The exact `IHealthContributor` shape and `HealthCheckResult` type come from `HoneyDrunk.Kernel.Abstractions`. Verify at edit time; the above is the intent. The `RecentHitRatio` helper computes hits / (hits + misses) over a small in-memory rolling window — see existing patterns in Vault's `VaultCacheHealthContributor` if it exists, otherwise a simple `(hits / (hits + misses))` computed against the telemetry counters.)

### `IErrorReporter` wiring

`IErrorReporter` is the thin facade over Pulse's `IErrorSink` per ADR-0045 D3. The interface lives in `HoneyDrunk.Pulse.Abstractions` (verify at edit time — if the interface has not yet shipped in Pulse, the package may take a temporary local interface and bridge to it later; document the decision in the PR body and add a follow-up note to swap to the real interface once Pulse ships it). For the canonical path, `RedisCacheStore<T>` takes `IErrorReporter?` (nullable) in its constructor; the DI registration leaves the binding to whoever composes the host (Notify Cloud, Communications, etc. — each composes Pulse and so the reporter is available).

```csharp
public RedisCacheStore(
    IConnectionMultiplexer multiplexer,
    IOptions<RedisCacheOptions> options,
    ILogger<RedisCacheStore<T>> logger,
    ITelemetryActivityFactory activityFactory,
    RedisCacheTelemetry telemetry,
    IErrorReporter? errorReporter = null)   // optional — package functions without Pulse composed
{
    // ... assignments ...
    _errorReporter = errorReporter;
}
```

Connection failures, command timeouts (`RedisTimeoutException`), and deserialization exceptions (`JsonException`) all route through `_errorReporter?.Report(ex, ...)` in the catch blocks before propagating. The reporter is fire-and-forget from the cache's perspective; Pulse's `IErrorReporter` implementation handles its own delivery semantics.

### DI registration updates

```csharp
public static IServiceCollection AddHoneyDrunkCacheRedis<T>(
    this IServiceCollection services,
    Action<RedisCacheOptions>? configureOptions = null,
    Func<IServiceProvider, string>? connectionStringFactory = null)
{
    // ... existing options + multiplexer + ICacheStore<T> registration ...

    services.TryAddSingleton<RedisCacheTelemetry>();   // counters / histograms / hit-ratio tracker
    services.AddSingleton<IHealthContributor, RedisHealthContributor>();
    services.AddSingleton<IStartupHook, RedisCacheStartupHook>();

    // IErrorReporter is NOT registered here — the composing host's Pulse composition handles it.
    // The constructor parameter is nullable so the package functions without it.

    return services;
}
```

### Unit tests

Extend `RedisCacheStoreTests.cs` (or split into a new test file per repo convention) covering:

- **Telemetry-Hit:** `SetAsync` then `GetAsync` records a `cache.hits` counter increment and a `cache.get` activity with `cache.outcome=hit`.
- **Telemetry-Miss:** `GetAsync` on missing key records `cache.misses` and `cache.outcome=miss`.
- **Telemetry-CommandDuration:** Each operation records a histogram observation.
- **Telemetry-Failure:** Injected `RedisException` in the multiplexer fake produces `cache.errors` increment, `cache.outcome=failure`, and `cache.set_status=Error`.
- **Health-Healthy:** Multiplexer reports `IsConnected=true`, `PingAsync` returns a small TimeSpan → `HealthCheckResult.Healthy` with `ping_ms` and `hit_ratio` in `data`.
- **Health-Unhealthy-Disconnected:** Multiplexer `IsConnected=false` → `HealthCheckResult.Unhealthy("Redis multiplexer reports disconnected.")`.
- **Health-Unhealthy-PingFailed:** Multiplexer reports connected but `PingAsync` throws → `HealthCheckResult.Unhealthy("Redis ping failed.", ex)`.
- **ErrorReporter-Called-OnFailure:** Inject a fake `IErrorReporter`; trigger a connection failure; verify `Report` was called with the expected exception type and context; verify the exception still propagates from `RedisCacheStore<T>`.
- **ErrorReporter-Optional:** Construct `RedisCacheStore<T>` with `IErrorReporter=null`; trigger a failure; verify no `NullReferenceException`; verify the exception propagates normally.
- **No high-cardinality on metrics:** Verify the counter / histogram `KeyValuePair` arguments do NOT include the cache key as a tag (only `cache.value_type`, `cache.operation`, `cache.outcome`). Trace attributes DO include the key — separate assertion.

### Documentation updates

- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` — append to the in-progress `## [0.1.0] - YYYY-MM-DD` section: telemetry instrumentation, health contributor, optional error-reporter wiring.
- Repo-level `CHANGELOG.md` — append to the in-progress `## [0.1.0]` section the same shape.
- `src/HoneyDrunk.Cache.Redis/README.md` — update the operational-shape section to document the telemetry counters/histograms/activity spans, the health contributor, and the optional error-reporter wiring. Cite operational concerns in plain English (e.g., "hit ratio and command latency are emitted as counters and histograms; consumer hosts aggregate these via their Pulse composition") without citing ADR numbers (per memory `feedback_no_adr_in_docs`).

## Affected Files

- `src/HoneyDrunk.Cache.Redis/RedisCacheStore.cs` — telemetry instrumentation + `IErrorReporter?` constructor parameter + catch-block reporter calls.
- `src/HoneyDrunk.Cache.Redis/RedisCacheTelemetry.cs` (new) — Meter/Counter/Histogram instruments + hit-ratio rolling-window helper.
- `src/HoneyDrunk.Cache.Redis/RedisHealthContributor.cs` (new) — `IHealthContributor` implementation.
- `src/HoneyDrunk.Cache.Redis/ServiceCollectionExtensions.cs` — register `RedisCacheTelemetry` and `RedisHealthContributor`.
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` — new test cases per the list above.
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` — append to in-progress `[0.1.0]`.
- `CHANGELOG.md` (repo root) — append to in-progress `[0.1.0]`.
- `src/HoneyDrunk.Cache.Redis/README.md` — operational-shape section update.

## NuGet Dependencies

### `HoneyDrunk.Cache.Redis.csproj` — additions

| Package | Notes |
|---|---|
| `System.Diagnostics.DiagnosticSource` | For `Meter`, `Counter<T>`, `Histogram<T>` types if not already pulled transitively |
| `HoneyDrunk.Pulse.Abstractions` | For `IErrorReporter` (per ADR-0045 D3). Verify the package exists and the interface ships in it at edit time; if not, document the deferral in the PR body and use a temporary local interface. |

The `ITelemetryActivityFactory` / `IHealthContributor` / `HealthCheckResult` types come from `HoneyDrunk.Kernel.Abstractions` (already referenced by packet 03). No additional Kernel package reference.

### `HoneyDrunk.Cache.Redis.Tests.Unit.csproj` — no new packages

The existing test stack (NSubstitute + AwesomeAssertions + xunit + coverlet) covers the new test cases.

## Boundary Check

- [x] All changes inside `HoneyDrunk.Cache.Redis`. No edits to Kernel, no edits to Pulse.
- [x] **One-way telemetry to Pulse via Kernel's `ITelemetryActivityFactory`.** No runtime dependency on `HoneyDrunk.Pulse` (the runtime package) — only on `HoneyDrunk.Pulse.Abstractions` (for `IErrorReporter`).
- [x] **`IErrorReporter` parameter is optional** — package functions without it. Consumer hosts that don't compose Pulse (rare; most do) get a working cache without error reporting.
- [x] **No high-cardinality identifiers on metrics.** Cache keys and tenant IDs are trace attributes only (per ADR-0040 D6).
- [x] No new version bump — appends to in-progress `[0.1.0]` from packet 03 (invariant 27).
- [x] No `Thread.Sleep` in tests (invariant 51).
- [x] No secrets in code or tests (invariant 8).

## Acceptance Criteria

- [ ] `RedisCacheStore<T>` wraps every operation in an `Activity` via `ITelemetryActivityFactory`; activity names are `cache.get`, `cache.set`, `cache.remove`, `cache.remove-by-tag`
- [ ] `Activity` attributes include `cache.backing=redis`, `cache.value_type=<T>`, `cache.key=<key>` (key is trace-only, not on metrics), `cache.outcome` (hit/miss/success/failure)
- [ ] Counter metrics emit: `cache.hits`, `cache.misses`, `cache.errors`. Histogram: `cache.command.duration_ms`. Tags on metrics include `cache.value_type`, `cache.operation`, `cache.outcome` — **NEVER** `cache.key` or `tenant.id` (per ADR-0040 D6 high-cardinality discipline)
- [ ] `RedisHealthContributor` exists, implements `IHealthContributor`, reports Healthy when multiplexer connected + PING succeeds, Unhealthy when disconnected or PING fails
- [ ] Health response `data` includes `ping_ms` (most recent PING latency) and `hit_ratio` (recent rolling hit ratio)
- [ ] `RedisCacheStore<T>` constructor accepts `IErrorReporter?` (nullable); when non-null, every catch block calls `_errorReporter.Report(...)` before propagating
- [ ] `IErrorReporter` injection is from `HoneyDrunk.Pulse.Abstractions` (or a documented temporary local interface if Pulse has not yet shipped it; PR body explains the decision)
- [ ] `AddHoneyDrunkCacheRedis<T>` extension registers `RedisCacheTelemetry`, `RedisHealthContributor`, and the existing `RedisCacheStartupHook`; does NOT register `IErrorReporter` (host's responsibility)
- [ ] Unit tests pass: hit-counter, miss-counter, command-duration histogram, activity-outcome tag, health-healthy, health-unhealthy-disconnected, health-unhealthy-ping-failed, error-reporter-called-on-failure, error-reporter-optional-null, no-key-on-metrics
- [ ] **`Directory.Build.props` version remains `0.1.0`** — NO version bump in this packet (invariant 27 — appends to the existing in-progress version)
- [ ] `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` and repo-level `CHANGELOG.md` `[0.1.0]` entries are appended (not replaced; not new version section)
- [ ] `src/HoneyDrunk.Cache.Redis/README.md` operational-shape section documents telemetry, health, and optional error-reporting surfaces — without citing "ADR-0076" / "ADR-0040" / "ADR-0045" by number in narrative
- [ ] `pr-core.yml` and `api-compatibility.yml` both pass — the public surface gained `RedisHealthContributor` and `RedisCacheTelemetry` types; the API-compatibility canary reflects an intentional minor-shape addition (the version is still `0.1.0` because this packet appends within the in-progress version per invariant 27)
- [ ] All public APIs have XML documentation (invariant 13)
- [ ] No `Thread.Sleep` in test code (invariant 51)
- [ ] No secret values anywhere (invariant 8)

## Human Prerequisites

- [ ] Packet 03 of this initiative merged — `HoneyDrunk.Cache.Redis` package exists with the bare `RedisCacheStore<T>`, `RedisCacheOptions`, `RedisCacheStartupHook`, and `AddHoneyDrunkCacheRedis<T>` extension.
- [ ] **Verify `IErrorReporter` interface exists in `HoneyDrunk.Pulse.Abstractions` at edit time.** Per ADR-0045 D3, it is a thin facade over the existing `IErrorSink`. If Pulse has not yet shipped the interface in `Pulse.Abstractions`, document the deferral in the PR body, use a temporary local interface in `HoneyDrunk.Cache.Redis`, and add a follow-up note to swap to the real `IErrorReporter` once Pulse ships it.
- [ ] **Verify `IHealthContributor` and `HealthCheckResult` namespaces** in `HoneyDrunk.Kernel.Abstractions` at edit time — exact namespace (`Health` vs `Lifecycle.Health` vs other) per repo convention. Match the existing Vault / Auth health-contributor patterns.
- [ ] **Verify `ITelemetryActivityFactory` is the canonical activity-factory contract** in `HoneyDrunk.Kernel.Abstractions.Telemetry` (or wherever Kernel ships it). Match the existing Vault / Auth telemetry-instrumentation patterns.
- [ ] After this packet's PR merges, the post-merge tag-push for `v0.1.0` is human-pushed per invariant 27. The tag triggers the release pipeline; `HoneyDrunk.Cache.Redis 0.1.0` (with telemetry + health + error reporting) publishes to NuGet. Confirm `NUGET_API_KEY` is bound to the repo before pushing the tag.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. — `HoneyDrunk.Cache.Redis` is runtime, depends on `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Pulse.Abstractions` — both Abstractions packages. Correct.

> **Invariant 4:** No circular dependencies. — Cache → Kernel.Abstractions and Cache → Pulse.Abstractions are one-way; neither Kernel nor Pulse references Cache.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. — Telemetry attributes carry the cache key (not value) and operation outcome; no secret enters traces or metrics. The error-reporter context carries exception details but never the connection-string secret.

> **Invariant 13:** All public APIs have XML documentation. — Every new public type and method carries XML doc.

> **Invariant 27:** All projects in a solution share one version and move together. The first packet to land on a solution in an initiative bumps the version; subsequent packets append to the CHANGELOG only. — This packet is the second packet on the `HoneyDrunk.Cache` solution in this initiative (packet 03 was first); it appends to the in-progress `[0.1.0]` CHANGELOG section without bumping.

> **Invariant 50:** Every Node has a `*.Tests.Unit` project. — Existing `HoneyDrunk.Cache.Redis.Tests.Unit` covers the new test cases.

> **Invariant 51:** Test code contains no `Thread.Sleep`. — No `Thread.Sleep` in new tests.

## Referenced ADR Decisions

**ADR-0076 D6 — Operational discipline:**
> The Redis instances run under standard Grid operational discipline:
> - **Telemetry** via the Pulse pipeline per [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) — hit rate, miss rate, evictions, latency p50/p95/p99, connection pool depth.
> - **Error tracking** via Azure App Insights per [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) — connection failures, command timeouts, deserialization errors.
> - **Cost monitoring** per ADR-0052 — per-environment Redis spend on the cost-governance dashboard.
> - **DR posture** per ADR-0036 — cache instances are Tier 2 (operational; loss is non-catastrophic; recovery is automatic on next-cache-warmup). No backup-and-restore discipline needed.

This packet implements the telemetry + error-tracking lines. Cost monitoring is operator-managed via the Azure cost-governance dashboard (separate scoping work, not in this initiative). DR posture requires no code work for Tier 2.

**ADR-0040 D6 — Volume discipline / no high-cardinality on metrics:**
> `user.id`, `message.id`, `request.id` belong on **traces** (where cardinality drives no extra cost in App Insights, since they're per-event), not duplicated into every log line as redundant context.

Applied here: cache keys and tenant IDs are trace attributes only. Metrics carry only low-cardinality tags (value-type-name, operation, outcome).

**ADR-0045 D3 — Errors flow through Pulse; `IErrorReporter` is a thin facade over the existing `IErrorSink`:**
> Errors flow through Pulse's existing sink surface via the `IErrorReporter` facade. The facade keeps consumer Nodes from taking a runtime dependency on Pulse's internals; the implementation routes to the App-Insights-backed `IErrorSink` provider.

The Redis backing's catch blocks call `IErrorReporter.Report(...)` (when registered); the package depends only on `HoneyDrunk.Pulse.Abstractions`, never on the Pulse runtime.

## Constraints

- **Invariant 8, 13, 27, 50, 51:** As inlined in Referenced Invariants.
- **ADR-0040 D6 high-cardinality discipline:** No `cache.key` or `tenant.id` on metric tags. Trace attributes only.
- **One-way to Pulse.** No runtime dependency on `HoneyDrunk.Pulse`. `IErrorReporter` from `HoneyDrunk.Pulse.Abstractions`; `ITelemetryActivityFactory` from `HoneyDrunk.Kernel.Abstractions`.
- **`IErrorReporter` parameter is optional.** Package functions without it.
- **No version bump.** Appends to in-progress `[0.1.0]`.
- **No `## Unreleased` block in CHANGELOG.** Entries land under `[0.1.0]`.
- **README does NOT cite ADR numbers in narrative.** Per memory `feedback_no_adr_in_docs`.

## Dependencies

- `packet:03` — the bare `HoneyDrunk.Cache.Redis` package must exist before telemetry/health/error-reporting can be wired into it.

## Labels

`feature`, `tier-2`, `cache`, `redis`, `telemetry`, `adr-0076`, `wave-3`

## Agent Handoff

**Objective:** Harden the Redis backing's operational shape per ADR-0076 D6. Wire telemetry (via Kernel's activity factory), a health contributor, and an optional `IErrorReporter` (from `HoneyDrunk.Pulse.Abstractions`). One-way to Pulse — no runtime dependency on the Pulse runtime package. Appends to in-progress `[0.1.0]` from packet 03.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Cache`, branch from `main`.

**Context:**
- Goal: Make the Redis backing production-ready for the first consumer composition (Notify Cloud multi-replica or Communications shared cache). Hit-ratio visibility, fail-fast health reporting, structured error capture in App Insights.
- Feature: ADR-0076 acceptance initiative, Wave 3, Packet 04.
- ADRs: ADR-0076 D6 (operational discipline), ADR-0040 D6 (no high-cardinality on metrics — keys go on traces), ADR-0045 D3 (`IErrorReporter` thin facade over `IErrorSink`).

**Acceptance Criteria:** As listed above.

**Dependencies:** `packet:03`.

**Constraints:**

- **One-way to Pulse.** `HoneyDrunk.Pulse.Abstractions` for `IErrorReporter` only; no runtime Pulse dependency.
- **`IErrorReporter` parameter is optional** — nullable in the `RedisCacheStore<T>` constructor. Package functions without it.
- **No high-cardinality on metrics.** Cache key + tenant ID are trace attributes only. Metric tags are `cache.value_type`, `cache.operation`, `cache.outcome`.
- **No version bump.** This is the second packet on the `HoneyDrunk.Cache` solution in this initiative; appends to `[0.1.0]` per invariant 27.
- **No `Thread.Sleep` in tests.** Per invariant 51.
- **No secret values in telemetry, traces, or error-reporter context.** Per invariant 8.
- **`IErrorReporter` interface verification.** If `HoneyDrunk.Pulse.Abstractions` does not yet ship the interface, document the deferral and use a temporary local interface — add a follow-up note to swap when Pulse ships the canonical interface.
- **`IHealthContributor` namespace verification.** Match the existing Vault / Auth health-contributor patterns.

**Key Files:**
- `src/HoneyDrunk.Cache.Redis/RedisCacheStore.cs` — instrumentation + reporter wiring.
- `src/HoneyDrunk.Cache.Redis/RedisCacheTelemetry.cs` (new) — meter/counter/histogram + hit-ratio.
- `src/HoneyDrunk.Cache.Redis/RedisHealthContributor.cs` (new) — health contributor.
- `src/HoneyDrunk.Cache.Redis/ServiceCollectionExtensions.cs` — DI updates.
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` — new test cases.
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` + repo-level `CHANGELOG.md` — append to `[0.1.0]`.
- `src/HoneyDrunk.Cache.Redis/README.md` — operational-shape update.

**Contracts:**

No new contracts authored. Implements existing contracts (`IHealthContributor`, `IStartupHook`, optionally consumes `IErrorReporter` and `ITelemetryActivityFactory`). The public surface of `HoneyDrunk.Cache.Redis` gains `RedisCacheTelemetry` (new public type) and `RedisHealthContributor` (new public type); these are picked up by the `api-compatibility.yml` canary on the next CI run, and the version is still `0.1.0` because they ship within the in-progress version.
