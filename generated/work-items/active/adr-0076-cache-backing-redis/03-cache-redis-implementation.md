---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Cache
labels: ["feature", "tier-2", "cache", "redis", "adr-0076", "wave-2"]
dependencies: ["work-item:01", "work-item:02"]
adrs: ["ADR-0076", "ADR-0058", "ADR-0059", "ADR-0005"]
accepts: ADR-0076
wave: 2
initiative: adr-0076-cache-backing-redis
node: honeydrunk-cache
---

# Feature: Implement `HoneyDrunk.Cache.Redis` — `RedisCacheStore<T>` on StackExchange.Redis + DI registration + tests

## Summary
First real package in the `HoneyDrunk.Cache` solution. Add `src/HoneyDrunk.Cache.Redis/` project. Implement `RedisCacheStore<T>` against `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions` (declared by ADR-0058 D2, in place on `main` via PR #301), backed by `StackExchange.Redis`. Provide `AddHoneyDrunkCacheRedis<T>` extension method on `IServiceCollection` for DI registration with `RedisCacheOptions` configuration. Use System.Text.Json for value serialization. Use standard Redis protocol commands only — no `RediSearch`, `RedisJSON`, `RedisTimeSeries`, `RedisGraph`, or `RedisBloom` module commands per ADR-0076 D3. Implement tag-to-key index using standard Redis sets for `RemoveByTagAsync`. Wire startup-warmup connection probe via `IStartupHook` from `HoneyDrunk.Kernel.Abstractions.Lifecycle` so host startup fails fast on unreachable Redis. Comprehensive unit tests against an InMemory `IConnectionMultiplexer` fake covering Get/Set/Remove/RemoveByTag/TTL/tag-invalidation/serialization-roundtrip/connection-failure semantics. **First/version-bumping packet on the `HoneyDrunk.Cache` solution** (`0.0.1` → `0.1.0`, first feature beyond the empty placeholder).

This is the package that fills ADR-0058 D8's deferred "first distributed backing" decision and gives the Cache Node (stood up empty per ADR-0059) its first real implementation. The placeholder `HoneyDrunk.Cache.Adapters` project from the standup stays as a sibling and receives the alignment-bump version per invariant 27.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Cache`

## Motivation

The empty scaffold landed by ADR-0059's standup is the room with the lighting on; this packet is the first piece of furniture. ADR-0076 D1 commits the literal package name `HoneyDrunk.Cache.Redis` (matching the ADR text exactly; NOT `HoneyDrunk.Cache.Adapters.Redis` or any other naming variant). The package implements the `ICacheStore<T>` contract that ADR-0058 D2 placed in `HoneyDrunk.Kernel.Abstractions` and that PR #301 has merged onto `main`.

The implementation surface is small by design — four method implementations on `ICacheStore<T>` plus a DI registration extension plus a startup hook plus a configuration record. Per ADR-0058 D2 the contract is deliberately minimal at v1 (no `GetOrSetAsync` sugar — consumers compose it themselves). This packet honors that minimalism; it does NOT add convenience helpers, "load if missing" patterns, or refresh-ahead behavior.

`StackExchange.Redis` is the .NET-ecosystem standard Redis client per ADR-0076 D1 ("`StackExchange.Redis` (the .NET-ecosystem standard Redis client)"). The package is widely deployed, AI-assistance-gradient deep, well-documented. No exotic client choice; the boring choice is the right one.

Redis-protocol-only discipline (ADR-0076 D3) means the implementation uses commands every Redis-protocol-compatible server speaks (open Redis, Valkey, KeyDB, Dragonfly, every cloud-managed Redis). The vendor-exit hedge is preserved by code; future migration to a different backing is a managed-service swap, not a code rewrite.

## Scope

- New `src/HoneyDrunk.Cache.Redis/` project with the following surface:
  - `RedisCacheStore<T>` — implements `ICacheStore<T>` against `IConnectionMultiplexer` from `StackExchange.Redis`.
  - `RedisCacheOptions` record — configuration (connection string secret name, key prefix, serializer options, command timeout).
  - `AddHoneyDrunkCacheRedis<T>` — `IServiceCollection` extension for DI registration.
  - `RedisCacheStartupHook` — implements `IStartupHook` from `HoneyDrunk.Kernel.Abstractions.Lifecycle` for connection-warmup at host startup.
  - Internal helpers — value serialization via System.Text.Json, key namespacing, tag-to-key index management using standard Redis sets.
- New `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` project with unit tests against an InMemory `IConnectionMultiplexer` fake.
- `HoneyDrunk.Cache.slnx` updated to reference the new project(s).
- Repo-level `Directory.Build.props` version bump `0.0.1` → `0.1.0` (first real feature; alignment-bumps the placeholder Adapters project per invariant 27).
- Repo-level `CHANGELOG.md` — new `[0.1.0]` dated entry.
- `src/HoneyDrunk.Cache.Redis/README.md` + `CHANGELOG.md` — new per-package docs.
- `src/HoneyDrunk.Cache.Adapters/CHANGELOG.md` — receives a one-line alignment-bump entry per invariants 12/27 ("Version bumped to 0.1.0 alongside `HoneyDrunk.Cache.Redis` first release; no functional change to this package.") — explicit no-noise wording per invariant 27 ("Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries"). On re-reading invariant 27: the alignment-bump-noise prohibition means **do NOT add a CHANGELOG entry to a package that has no real change**. The placeholder Adapters project has no real change — it gets the version bump (silent, per invariant 27's "all projects share one version") but **no CHANGELOG entry**. Acceptance criteria reflect this.
- `.github/workflows/api-compatibility.yml` — first contract-shape canary for `HoneyDrunk.Cache.Redis` (since the package now ships a public surface — `AddHoneyDrunkCacheRedis<T>`, `RedisCacheOptions`). The ADR-0059 scaffold packet explicitly omitted `api-compatibility.yml` because Cache owned no contracts at stand-up; this packet adds the canary scoped to `HoneyDrunk.Cache.Redis` because there is now a public surface to freeze.

## Proposed Implementation

### `src/HoneyDrunk.Cache.Redis/HoneyDrunk.Cache.Redis.csproj`

Minimal `.csproj`. Per invariant 26, `HoneyDrunk.Standards` is referenced with `PrivateAssets="all"`. The runtime dependencies are `StackExchange.Redis`, `HoneyDrunk.Kernel.Abstractions` (for the contract), and `Microsoft.Extensions.DependencyInjection.Abstractions` (for the `IServiceCollection` extension method).

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Description>Azure Cache for Redis backing implementation of ICacheStore&lt;T&gt; for the HoneyDrunk Grid. Standard Redis protocol commands only; no Azure-Redis modules. System.Text.Json for value serialization. Tag-to-key index for RemoveByTagAsync support.</Description>
    <PackageTags>cache;redis;distributed-cache;stackexchange-redis;azure-cache-for-redis;honeydrunk</PackageTags>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
    <PackageReference Include="HoneyDrunk.Kernel.Abstractions" Version="0.8.0" />
    <PackageReference Include="StackExchange.Redis" />
    <PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" />
    <PackageReference Include="Microsoft.Extensions.Options" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" />
  </ItemGroup>
</Project>
```

(The exact version pins on `StackExchange.Redis`, `Microsoft.Extensions.*` go to the `Directory.Packages.props` central-version-management file if the repo uses CPM — verify at edit time and use the repo's pattern. Otherwise, pin to the latest stable in the `.csproj` directly. The `HoneyDrunk.Kernel.Abstractions` version is `0.8.0` — the version landed by ADR-0058's packet 04 introducing the contract.)

### `RedisCacheOptions` record

Plain configuration record bound from `IOptions<RedisCacheOptions>`. The connection string is a Vault-resolved secret (NOT a configuration value baked into appsettings); the option carries the *secret name*, not the secret value. The composing host resolves the secret via `ISecretStore` and configures the `IConnectionMultiplexer` accordingly — this packet does NOT take a runtime dependency on `HoneyDrunk.Vault` because Vault composition is host-time. Per the records-naming rule (memory `project_naming_rule_records`): record types drop the `I`, interfaces keep it. `RedisCacheOptions` is a record, no `I` prefix.

```csharp
namespace HoneyDrunk.Cache.Redis;

/// <summary>
/// Configuration for the Redis-backed ICacheStore&lt;T&gt; implementation.
/// </summary>
public sealed record RedisCacheOptions
{
    /// <summary>
    /// Vault secret name holding the Redis connection string. Default "redis-connection-string".
    /// The composing host resolves this via ISecretStore and constructs the IConnectionMultiplexer.
    /// </summary>
    public string ConnectionStringSecretName { get; init; } = "redis-connection-string";

    /// <summary>
    /// Optional key prefix applied to every cache operation. Use for per-Node namespacing.
    /// Example: "notify-cloud:apikeys" so Notify Cloud's keys do not collide with Communications's.
    /// Per ADR-0058 D5, tenant-keying is the call-site's responsibility — this prefix is Node-level.
    /// </summary>
    public string KeyPrefix { get; init; } = string.Empty;

    /// <summary>
    /// Default command timeout for Redis operations. Default 5 seconds.
    /// </summary>
    public TimeSpan CommandTimeout { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>
    /// JsonSerializerOptions used to serialize/deserialize values.
    /// Default: SystemTextJson defaults with PropertyNamingPolicy = CamelCase.
    /// </summary>
    public JsonSerializerOptions? SerializerOptions { get; init; }
}
```

### `RedisCacheStore<T>` implementation

Implements every method on `ICacheStore<T>` using standard Redis protocol commands.

```csharp
namespace HoneyDrunk.Cache.Redis;

/// <summary>
/// Redis-backed ICacheStore&lt;T&gt; implementation. Uses standard Redis protocol commands only —
/// no RediSearch, RedisJSON, RedisTimeSeries, RedisGraph, or RedisBloom module commands.
/// Values serialize through System.Text.Json. Tag-to-key index uses Redis sets for RemoveByTagAsync.
/// </summary>
public sealed class RedisCacheStore<T> : ICacheStore<T>
{
    private readonly IConnectionMultiplexer _multiplexer;
    private readonly RedisCacheOptions _options;
    private readonly JsonSerializerOptions _serializerOptions;
    private readonly ILogger<RedisCacheStore<T>> _logger;

    public RedisCacheStore(
        IConnectionMultiplexer multiplexer,
        IOptions<RedisCacheOptions> options,
        ILogger<RedisCacheStore<T>> logger)
    {
        _multiplexer = multiplexer ?? throw new ArgumentNullException(nameof(multiplexer));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _serializerOptions = _options.SerializerOptions ?? new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async ValueTask<T?> GetAsync(string key, CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        var db = _multiplexer.GetDatabase();
        var value = await db.StringGetAsync(NamespaceKey(key)).ConfigureAwait(false);
        if (value.IsNullOrEmpty) return default;
        return JsonSerializer.Deserialize<T>(value!, _serializerOptions);
    }

    public async ValueTask SetAsync(
        string key,
        T value,
        TimeSpan? ttl = null,
        IReadOnlyCollection<string>? tags = null,
        CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        var serialized = JsonSerializer.Serialize(value, _serializerOptions);
        var db = _multiplexer.GetDatabase();
        var namespacedKey = NamespaceKey(key);

        // Standard Redis protocol: SETEX (or SET with EX/PX) for TTL, SET for no-TTL.
        await db.StringSetAsync(namespacedKey, serialized, ttl).ConfigureAwait(false);

        // Tag-to-key index using Redis sets — standard SADD per tag, plus a reverse-index
        // SADD per key listing its tags so RemoveAsync can prune the tag entries cleanly.
        if (tags is { Count: > 0 })
        {
            var tagOps = new List<Task>(tags.Count + 1);
            foreach (var tag in tags)
            {
                tagOps.Add(db.SetAddAsync(NamespaceTagKey(tag), namespacedKey.ToString()));
            }
            tagOps.Add(db.SetAddAsync(NamespaceKeyTagsKey(namespacedKey), tags.Select(t => (RedisValue)t).ToArray()));
            await Task.WhenAll(tagOps).ConfigureAwait(false);
        }
    }

    public async ValueTask RemoveAsync(string key, CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        var db = _multiplexer.GetDatabase();
        var namespacedKey = NamespaceKey(key);

        // Look up the key's tag set; remove the key from each tag's set; delete the key's tag set;
        // delete the key. Standard Redis: SMEMBERS, SREM, DEL.
        var keyTagsKey = NamespaceKeyTagsKey(namespacedKey);
        var tags = await db.SetMembersAsync(keyTagsKey).ConfigureAwait(false);
        if (tags.Length > 0)
        {
            var pruneOps = new List<Task>(tags.Length + 1);
            foreach (var tag in tags)
            {
                pruneOps.Add(db.SetRemoveAsync(NamespaceTagKey(tag.ToString()), namespacedKey.ToString()));
            }
            pruneOps.Add(db.KeyDeleteAsync(keyTagsKey));
            await Task.WhenAll(pruneOps).ConfigureAwait(false);
        }

        await db.KeyDeleteAsync(namespacedKey).ConfigureAwait(false);
    }

    public async ValueTask RemoveByTagAsync(string tag, CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        var db = _multiplexer.GetDatabase();
        var tagKey = NamespaceTagKey(tag);

        // Look up every key in the tag's set; delete each; clean up the per-key tag-index entries; delete the tag set.
        var keys = await db.SetMembersAsync(tagKey).ConfigureAwait(false);
        if (keys.Length == 0)
        {
            await db.KeyDeleteAsync(tagKey).ConfigureAwait(false);
            return;
        }

        var deleteOps = new List<Task>(keys.Length * 2 + 1);
        foreach (var redisKey in keys)
        {
            deleteOps.Add(db.KeyDeleteAsync((RedisKey)redisKey.ToString()));
            deleteOps.Add(db.KeyDeleteAsync(NamespaceKeyTagsKey((RedisKey)redisKey.ToString())));
        }
        deleteOps.Add(db.KeyDeleteAsync(tagKey));
        await Task.WhenAll(deleteOps).ConfigureAwait(false);
    }

    private RedisKey NamespaceKey(string key) =>
        string.IsNullOrEmpty(_options.KeyPrefix)
            ? key
            : $"{_options.KeyPrefix}:{key}";

    private RedisKey NamespaceTagKey(string tag) =>
        string.IsNullOrEmpty(_options.KeyPrefix)
            ? $"__tag:{tag}"
            : $"{_options.KeyPrefix}:__tag:{tag}";

    private RedisKey NamespaceKeyTagsKey(RedisKey namespacedKey) =>
        $"{namespacedKey}:__tags";
}
```

(The exact code shape — using statements, nullability annotations, sealed/non-sealed decisions, etc. — is the agent's call within the repo's conventions. The above is the intent and the algorithm; conformity to the repo's analyzer set, file-per-type discipline, and StyleCop rules is the agent's responsibility.)

### `RedisCacheStartupHook` — IStartupHook for connection warmup

Implements `IStartupHook` from `HoneyDrunk.Kernel.Abstractions.Lifecycle` (verified at `HoneyDrunk.Kernel.Abstractions/Lifecycle/IStartupHook.cs`). Executes a `PING` against the configured Redis instance during host startup — fails fast if Redis is unreachable, matching the established pattern from Vault's startup-warmup discipline.

```csharp
namespace HoneyDrunk.Cache.Redis;

/// <summary>
/// IStartupHook that warms the Redis connection at host startup. Fails fast if Redis is unreachable
/// so the host does not start up in a degraded state.
/// </summary>
public sealed class RedisCacheStartupHook : IStartupHook
{
    private readonly IConnectionMultiplexer _multiplexer;
    private readonly ILogger<RedisCacheStartupHook> _logger;

    public RedisCacheStartupHook(
        IConnectionMultiplexer multiplexer,
        ILogger<RedisCacheStartupHook> logger)
    {
        _multiplexer = multiplexer ?? throw new ArgumentNullException(nameof(multiplexer));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    // Run after most early hooks but before any business-logic startup that needs cache to be available.
    public int Priority => 100;

    public async Task ExecuteAsync(CancellationToken cancellationToken)
    {
        var db = _multiplexer.GetDatabase();
        var pong = await db.PingAsync().ConfigureAwait(false);
        _logger.LogInformation("Redis cache backing reachable; PING latency {LatencyMs}ms", pong.TotalMilliseconds);
    }
}
```

### `AddHoneyDrunkCacheRedis<T>` extension

`IServiceCollection` extension for DI registration. Registers `ICacheStore<T>` → `RedisCacheStore<T>`, the `RedisCacheOptions` binding, the startup hook, and (if not already registered) the `IConnectionMultiplexer` singleton. The `IConnectionMultiplexer` factory takes the Vault-resolved connection string — the registration accepts a `Func<IServiceProvider, string>` for the connection-string factory so the host wires Vault resolution at composition time without forcing this package to take a Vault dependency.

```csharp
namespace HoneyDrunk.Cache.Redis;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers a Redis-backed ICacheStore&lt;T&gt; with the given options and a connection-string
    /// factory. The factory typically resolves the connection string from ISecretStore (Vault)
    /// at composition time.
    /// </summary>
    public static IServiceCollection AddHoneyDrunkCacheRedis<T>(
        this IServiceCollection services,
        Action<RedisCacheOptions>? configureOptions = null,
        Func<IServiceProvider, string>? connectionStringFactory = null)
    {
        if (services is null) throw new ArgumentNullException(nameof(services));

        if (configureOptions is not null)
        {
            services.Configure(configureOptions);
        }

        if (connectionStringFactory is not null)
        {
            services.TryAddSingleton<IConnectionMultiplexer>(sp =>
            {
                var connectionString = connectionStringFactory(sp);
                return ConnectionMultiplexer.Connect(connectionString);
            });
        }

        services.TryAddSingleton<ICacheStore<T>, RedisCacheStore<T>>();
        services.AddSingleton<IStartupHook, RedisCacheStartupHook>();

        return services;
    }
}
```

(`TryAddSingleton` for `IConnectionMultiplexer` and `ICacheStore<T>` so multiple calls to `AddHoneyDrunkCacheRedis<T>` for different `T` share one multiplexer and don't double-register the same generic closure.)

### Unit tests — `tests/HoneyDrunk.Cache.Redis.Tests.Unit/`

Test against an InMemory `IConnectionMultiplexer` fake (NSubstitute per the repo's test stack, or a hand-rolled in-process fake — the agent picks per existing convention). Coverage:

- `GetAsync` on a missing key returns `default(T?)`.
- `SetAsync` then `GetAsync` returns the set value, round-tripped through serialization.
- `SetAsync` with a `ttl` is reflected in the `StringSetAsync` call's expiry parameter.
- `SetAsync` with `tags` calls `SetAddAsync` for each tag and for the per-key reverse index.
- `SetAsync` with an empty `tags` collection behaves the same as `null` (no `SetAddAsync` invocations).
- `RemoveAsync` calls `KeyDeleteAsync` and prunes the tag indexes the key appeared in.
- `RemoveByTagAsync` deletes every key in the tag set and the tag set itself; also prunes the per-key tag-index entries.
- `RemoveByTagAsync` on a non-existent tag is a no-op (no exception).
- Connection failure during a Get/Set surfaces as the appropriate exception type — no swallowing.
- Serialization round-trip for a non-trivial type (e.g., a record with nested properties).
- `KeyPrefix` is applied correctly when non-empty (verify `StringSetAsync` was called with the prefixed key).
- No `Thread.Sleep` anywhere (invariant 51); TTL tests use the test-fake's clock or skip time-advance verification (TTL is delegated to Redis, not asserted by the test — the test verifies the parameter was passed correctly).

### Solution-level changes

- `HoneyDrunk.Cache.slnx` references the new `src/HoneyDrunk.Cache.Redis/` project and the new `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` project.
- `Directory.Build.props` `<Version>` bumped `0.0.1` → `0.1.0` (first feature beyond empty placeholder; minor bump for additive feature).
- `src/HoneyDrunk.Cache.Adapters/HoneyDrunk.Cache.Adapters.csproj` carries the alignment bump silently per invariant 27 — **no per-package CHANGELOG entry** because there is no functional change (invariant 27's no-alignment-noise rule).

### Repo-level + per-package documentation

- Repo-level `CHANGELOG.md` — new `## [0.1.0] - YYYY-MM-DD` entry covering the Redis backing.
- `src/HoneyDrunk.Cache.Redis/README.md` — per-package README. Includes purpose, installation (`dotnet add package HoneyDrunk.Cache.Redis`), DI registration example, configuration (`RedisCacheOptions`), and the operational shape (Redis-protocol-only, `allkeys-lru` is set on the Azure resource not in the client, tag-to-key index uses Redis sets, value serialization is System.Text.Json). Does NOT cite ADR numbers in narrative paragraphs (per memory `feedback_no_adr_in_docs`).
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` — new per-package CHANGELOG with `## [0.1.0] - YYYY-MM-DD` entry.
- Repo root `README.md` — update the "For downstream consumers" section to remove the v0.0.1 "no backings shipped" placeholder text and show the Redis backing as the first real available backing. Update the "Phase-1 honest limitation" section to reflect that the first backing has shipped.

### `.github/workflows/api-compatibility.yml` — contract-shape canary scoped to `HoneyDrunk.Cache.Redis`

The ADR-0059 scaffold packet explicitly omitted `api-compatibility.yml` because Cache owned no public surface. This packet adds the canary because `HoneyDrunk.Cache.Redis` now ships a public surface (`AddHoneyDrunkCacheRedis<T>`, `RedisCacheOptions`, `RedisCacheStore<T>`, `RedisCacheStartupHook`). The workflow file is a thin caller of `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main` scoped to `project-path: src/HoneyDrunk.Cache.Redis`. The exact file shape mirrors the same workflow in `HoneyDrunk.Audit`, `HoneyDrunk.AI`, `HoneyDrunk.Capabilities`, and `HoneyDrunk.Communications`.

Branch protection on `main` should be updated to require `api-compatibility` as well as `pr-core / core` — this is a small repo-settings change tracked in the Human Prerequisites section.

## Affected Files

- `src/HoneyDrunk.Cache.Redis/HoneyDrunk.Cache.Redis.csproj` (new)
- `src/HoneyDrunk.Cache.Redis/RedisCacheStore.cs` (new)
- `src/HoneyDrunk.Cache.Redis/RedisCacheOptions.cs` (new)
- `src/HoneyDrunk.Cache.Redis/RedisCacheStartupHook.cs` (new)
- `src/HoneyDrunk.Cache.Redis/ServiceCollectionExtensions.cs` (new)
- `src/HoneyDrunk.Cache.Redis/README.md` (new)
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` (new)
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/HoneyDrunk.Cache.Redis.Tests.Unit.csproj` (new)
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/RedisCacheStoreTests.cs` (new — main test file; agent may decompose further per repo convention)
- `HoneyDrunk.Cache.slnx` — reference the new projects.
- `Directory.Build.props` — version bump `0.0.1` → `0.1.0`.
- `CHANGELOG.md` (repo root) — new `[0.1.0]` entry.
- `README.md` (repo root) — update "For downstream consumers" and "Phase-1 honest limitation" sections.
- `src/HoneyDrunk.Cache.Adapters/HoneyDrunk.Cache.Adapters.csproj` — implicit alignment bump via `Directory.Build.props` (no edit needed if the .csproj inherits version).
- `src/HoneyDrunk.Cache.Adapters/CHANGELOG.md` — **no new entry** (invariant 27 no-alignment-noise rule; the package has no functional change).
- `.github/workflows/api-compatibility.yml` (new) — contract-shape canary scoped to `HoneyDrunk.Cache.Redis`.

## NuGet Dependencies

### `HoneyDrunk.Cache.Redis.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` — analyzers + EditorConfig (invariant 26) |
| `HoneyDrunk.Kernel.Abstractions` | Version `0.8.0` (the version landed by ADR-0058's contract packet; pin to that version or to a wildcard that resolves to `0.8.*` per the repo's central-version-management convention) |
| `StackExchange.Redis` | Latest stable. The .NET-ecosystem standard Redis client per ADR-0076 D1. |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | For the `IServiceCollection` extension method. |
| `Microsoft.Extensions.Options` | For `IOptions<RedisCacheOptions>` binding. |
| `Microsoft.Extensions.Logging.Abstractions` | For `ILogger<T>` injection. |

### `HoneyDrunk.Cache.Redis.Tests.Unit.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk` | Test runner SDK |
| `xunit` | xUnit framework per ADR-0047 D2 (the shared test stack) |
| `xunit.runner.visualstudio` | xUnit VS adapter |
| `NSubstitute` | Mocking per ADR-0047 D2 |
| `AwesomeAssertions` | Assertion library per ADR-0047 D2 |
| `coverlet.collector` | Coverage collector per ADR-0047 D3 |

Project reference: `src/HoneyDrunk.Cache.Redis/HoneyDrunk.Cache.Redis.csproj`.

## Boundary Check

- [x] `HoneyDrunk.Cache.Redis` implements `ICacheStore<T>` declared in `HoneyDrunk.Kernel.Abstractions` per ADR-0058 D2 and ADR-0076 D1. Routing rule "context, GridContext, ... → Kernel; cache backings → Cache".
- [x] **Package name is `HoneyDrunk.Cache.Redis`** (literal text from ADR-0076 D1) — NOT `HoneyDrunk.Cache.Adapters.Redis` or any other naming variant.
- [x] One-way dependency: Cache → Kernel.Abstractions. No reverse edge.
- [x] No `HoneyDrunk.Pulse` reference (telemetry is one-way via Kernel's `ITelemetryActivityFactory` — packet 04 wires it). No runtime dependency on Pulse per the Cache → Pulse boundary.
- [x] No `HoneyDrunk.Vault` reference. Connection-string resolution is host-time composition — the package accepts a `Func<IServiceProvider, string>` factory so the host wires Vault without coupling this package to Vault.
- [x] **Standard Redis protocol commands only.** Implementation uses `StringSetAsync`, `StringGetAsync`, `KeyDeleteAsync`, `SetAddAsync`, `SetMembersAsync`, `SetRemoveAsync`, `PingAsync` — all Redis-core commands. Verify with grep: no usage of `Module*`, no `FT.*` (RediSearch), no `JSON.*` (RedisJSON), no `TS.*` (RedisTimeSeries), no `GRAPH.*` (RedisGraph), no `BF.*` / `CF.*` / `TDIGEST.*` (RedisBloom) — zero matches expected.
- [x] System.Text.Json for value serialization. Newtonsoft.Json NOT referenced.
- [x] Tag-to-key index uses standard Redis sets (`SADD` / `SMEMBERS` / `SREM`). No bespoke pub-sub-on-Redis pattern (ADR-0058 D7's cache-invalidation Lane 2 is Service Bus, not Redis pub/sub).
- [x] No Azure-Redis-Modules dependency anywhere.
- [x] No `MultiplexerPool` or other StackExchange.Redis-internal types exposed across the public API.
- [x] **First/version-bumping packet on the `HoneyDrunk.Cache` solution** per invariant 27. `Directory.Build.props` version bump `0.0.1` → `0.1.0` in this commit.
- [x] **No `HoneyDrunk.Cache.Adapters/CHANGELOG.md` entry** for the alignment bump (invariant 27 no-alignment-noise rule).
- [x] No tests run against a live Redis instance — unit tests use an InMemory `IConnectionMultiplexer` fake (invariant 15).
- [x] No `Thread.Sleep` in test code (invariant 51).
- [x] No secrets in code, tests, or fixtures (invariant 8).

## Acceptance Criteria

- [ ] `src/HoneyDrunk.Cache.Redis/` exists as a project in the solution; `HoneyDrunk.Cache.slnx` references it
- [ ] `RedisCacheStore<T>` implements `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions` with all four methods (`GetAsync`, `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`)
- [ ] **No `GetOrSetAsync` helper added** (per ADR-0058 D8 / Alternatives — convenience sugar is deferred until usage justifies it)
- [ ] `RedisCacheOptions` record exists with `ConnectionStringSecretName`, `KeyPrefix`, `CommandTimeout`, `SerializerOptions` properties
- [ ] `AddHoneyDrunkCacheRedis<T>` extension exists on `IServiceCollection`; accepts an optional `Action<RedisCacheOptions>` and an optional connection-string factory
- [ ] `RedisCacheStartupHook` implements `IStartupHook` from `HoneyDrunk.Kernel.Abstractions.Lifecycle`; pings Redis at startup; fails fast if Redis is unreachable
- [ ] **Implementation uses only standard Redis protocol commands.** Verify with grep across `src/HoneyDrunk.Cache.Redis/`: zero matches for `FT.`, `JSON.`, `TS.`, `GRAPH.`, `BF.`, `CF.`, `TDIGEST.`, `Module` (per ADR-0076 D3)
- [ ] **Value serialization uses System.Text.Json.** Verify: zero references to `Newtonsoft.Json` in `.csproj` or `.cs` files; the serializer call sites use `JsonSerializer.Serialize` / `JsonSerializer.Deserialize`
- [ ] Tag-to-key index uses Redis sets (`SetAddAsync`, `SetMembersAsync`, `SetRemoveAsync`); no pub/sub pattern
- [ ] Unit tests pass: GetAsync-missing, SetAsync→GetAsync round-trip, SetAsync TTL parameter propagation, SetAsync tags → SetAddAsync invocations, SetAsync empty-tags → no SADD, RemoveAsync prunes tag index, RemoveByTagAsync deletes all keys + the tag set, RemoveByTagAsync on missing tag is no-op, connection-failure surfaces exception, KeyPrefix applied correctly, non-trivial-type serialization round-trip
- [ ] **No live Redis required for unit tests** — tests run against an InMemory `IConnectionMultiplexer` fake (invariant 15)
- [ ] **No `Thread.Sleep` in any test file** (invariant 51) — verify with grep across `tests/`
- [ ] `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` project exists; coverlet coverage configured per ADR-0047 D3
- [ ] `HoneyDrunk.Cache.Redis.csproj` carries the package references listed in the NuGet Dependencies section above; `HoneyDrunk.Kernel.Abstractions` pinned to `0.8.0` (or schema-equivalent per CPM)
- [ ] **`Directory.Build.props` version is `0.1.0`** (bumped from `0.0.1`); invariant 27 — all non-test `.csproj` files inherit the same version in a single commit
- [ ] **`src/HoneyDrunk.Cache.Adapters/CHANGELOG.md` has NO new entry** — invariant 27 no-alignment-noise rule (placeholder has no functional change)
- [ ] Repo-level `CHANGELOG.md` has a new `## [0.1.0] - YYYY-MM-DD` entry covering the Redis backing
- [ ] `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` (new) has a `## [0.1.0] - YYYY-MM-DD` entry per invariant 12
- [ ] `src/HoneyDrunk.Cache.Redis/README.md` (new) documents purpose, installation, DI registration example, configuration, operational shape — **without citing "ADR-0076" or "ADR-0058" by number in narrative** (per memory `feedback_no_adr_in_docs`)
- [ ] Repo-root `README.md` updated to remove the "no backings shipped at v0.0.1" placeholder; reflects that the Redis backing is the first available backing
- [ ] `.github/workflows/api-compatibility.yml` (new) calls `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main` scoped to `project-path: src/HoneyDrunk.Cache.Redis`
- [ ] `pr-core.yml` and `api-compatibility.yml` both pass on the PR
- [ ] All public APIs have XML documentation (invariant 13)
- [ ] No secret values anywhere in code, tests, or fixtures (invariant 8)
- [ ] No PII or restricted-tier value handling in this package beyond the standard Redis storage — restricted-tier application-layer encryption is packet 05's territory and is not implemented here

## Human Prerequisites

- [ ] Packet 01 of this initiative merged — the `azure-cache-for-redis-provisioning.md` walkthrough exists so the package README can cross-reference it; the catalog rows exist so the module identity is established.
- [ ] Packet 02 of this initiative complete — the dev Redis instance (`redis-hd-dev`) exists in the Azure subscription. Unit tests do not strictly require this (they use the InMemory fake), but a live instance is required for any post-merge operator smoke verification.
- [ ] **Upstream ADR-0058 packet 04 merged** — the `ICacheStore<T>` contract exists in `HoneyDrunk.Kernel.Abstractions` at version `0.8.0`. PR #301 confirmed merged at scoping time; the package reference resolves correctly.
- [ ] **Upstream ADR-0059 packet 03 merged** — the `HoneyDrunk.Cache` repo exists with the placeholder `HoneyDrunk.Cache.Adapters` project, the solution file, and the CI workflows. PR #323 confirmed merged at scoping time.
- [ ] Branch protection on `main` updated to require `api-compatibility` check after this PR merges (so future PRs don't bypass the canary). The ADR-0059 standup packet noted this would happen "when a future backing introduces its own public surface" — that future is now. The branch-protection update is a small org-admin action; the PR's body should call it out as a post-merge step.
- [ ] **No `NUGET_API_KEY` activity in this packet.** The version bump to `0.1.0` does NOT trigger a tag push. The first tag push (`v0.1.0`) is human-pushed per invariant 27 after this PR merges and the operator has verified the package on the local feed / test composition. Filing the tag-push as a discrete follow-up note in the PR body is sufficient.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Cache.Redis` is a runtime package, not an Abstractions package. It depends on `HoneyDrunk.Kernel.Abstractions` (an Abstractions package — permitted on a runtime package per invariant 2) and on `StackExchange.Redis` (third-party). No Abstractions-on-other-HoneyDrunk-runtime dependency.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `HoneyDrunk.Cache.Redis` (runtime) depends on `HoneyDrunk.Kernel.Abstractions` (abstractions). Correct.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Cache → Kernel.Abstractions is one-way. Kernel does not reference Cache.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. — The package does not log connection strings, access keys, or any secret value. Telemetry attributes carry cache key names (not values) and operation outcomes; no secret enters the telemetry pipeline.

> **Invariant 9:** Vault is the only source of secrets. — The connection-string factory parameter on `AddHoneyDrunkCacheRedis<T>` is the seam through which the host wires `ISecretStore` resolution. The package itself never resolves a secret; it accepts a factory.

> **Invariant 11:** One repo per Node. — Cache is one repo; the Redis backing is one package within it.

> **Invariant 12:** Every shipped package has a CHANGELOG.md and README.md. New packages and new repos include their creation in acceptance criteria. — Both files are authored for `HoneyDrunk.Cache.Redis`.

> **Invariant 13:** All public APIs have XML documentation. — Every public type, method, parameter, and return value on the Redis backing surface carries XML doc.

> **Invariant 14:** Canary tests validate cross-Node boundaries. — The `api-compatibility.yml` workflow is the contract-shape canary for `HoneyDrunk.Cache.Redis`'s public surface. Future shape drift fails the build unless paired with an intentional version bump.

> **Invariant 15:** Unit tests and in-process integration tests never depend on external services. Use InMemory providers for isolation. — Unit tests use an InMemory `IConnectionMultiplexer` fake. No live Redis dependency.

> **Invariant 17:** One Key Vault per deployable Node per environment. Library-only Nodes have no vault. — `HoneyDrunk.Cache` is a library Node — no `kv-hd-cache-{env}` Vault exists. The connection-string factory parameter on `AddHoneyDrunkCacheRedis<T>` is the seam through which the host wires resolution from the **consumer Node's** Vault.

> **Invariant 21:** Applications must never pin to a specific secret version. — The connection-string factory resolves the latest version via `ISecretStore` (host responsibility). The package does not pin.

> **Invariant 26:** Every project consumes `HoneyDrunk.Standards` via `PackageReference` with `PrivateAssets="all"`. — Applied to both `HoneyDrunk.Cache.Redis.csproj` and `HoneyDrunk.Cache.Redis.Tests.Unit.csproj`.

> **Invariant 27:** All projects in a solution share one version and move together. The first packet to land on a solution in an initiative bumps the version; subsequent packets append to the CHANGELOG only. Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries. — This packet is the first packet on the `HoneyDrunk.Cache` solution in this initiative; it bumps `0.0.1` → `0.1.0`. The placeholder `HoneyDrunk.Cache.Adapters` alignment-bumps silently (no CHANGELOG noise entry).

> **Invariant 50:** Every Node has a `*.Tests.Unit` project. — `HoneyDrunk.Cache.Redis.Tests.Unit` is added.

> **Invariant 51:** Test code contains no `Thread.Sleep`. Enforced by an analyzer rule. — Tests use the InMemory fake's deterministic shape; no time-advance via `Thread.Sleep`.

## Referenced ADR Decisions

**ADR-0076 D1:** Package name `HoneyDrunk.Cache.Redis` (literal text). StackExchange.Redis client. Azure Cache for Redis as the runtime backing. Per-environment instances `redis-hd-{env}`. Managed-identity auth where supported, access-key fallback via Vault per ADR-0005. Same region as the Container Apps environment.

**ADR-0076 D3:** Redis-protocol-only; no Azure-Redis modules. The implementation uses standard Redis commands (`SET`, `GET`, `DEL`, `SADD`, `SMEMBERS`, `SREM`, `PING`); no `RediSearch`, no `RedisJSON`, no `RedisTimeSeries`, no `RedisGraph`, no `RedisBloom`. No reliance on Azure-managed Redis persistence (cache values are by-construction ephemeral). System.Text.Json for value serialization (the "standard pattern" cited by D3 — Redis stores strings; the serializer materializes typed values at the boundary).

**ADR-0076 D4:** Default eviction policy is `allkeys-lru`. The policy is set on the Azure resource at provisioning time (packet 02) — the client does not configure server-side eviction. The README documents the assumption that the configured backing has `allkeys-lru` set; consumers running against a Redis instance with a different policy may see different invalidation behavior under memory pressure.

**ADR-0076 D5:** Provider abstraction held. The package name `HoneyDrunk.Cache.Redis` reflects the backing identity (Redis), NOT exclusivity (other backings — Cosmos with TTL, Postgres with TTL, self-hosted Redis on Container Apps — are permitted per ADR-0058 D5 + ADR-0076 D5 / D7). The README's "For downstream consumers" section notes the per-Node escape valve.

**ADR-0058 D2:** `ICacheStore<T>` lives in `HoneyDrunk.Kernel.Abstractions`. This packet implements it; it does not re-declare it.

**ADR-0058 D8:** No `GetOrSetAsync` helper at v1. This packet honors the minimalism; convenience sugar waits for usage justification.

**ADR-0005:** Vault as only source of secrets. Connection-string Vault seeding is host-time work at the first consumer composition packet; this package's connection-string-factory parameter is the seam.

## Dependencies

- `work-item:01` — the catalog rows and walkthrough must exist before this packet ships (the README cross-references the walkthrough; the catalog rows establish the module identity).
- `work-item:02` — the dev Redis instance must exist (unit tests don't need it, but the post-merge smoke verification does).

## Labels

`feature`, `tier-2`, `cache`, `redis`, `adr-0076`, `wave-2`

## Agent Handoff

**Objective:** Implement `HoneyDrunk.Cache.Redis` — the first distributed-cache backing for the Cache Node. `RedisCacheStore<T>` on `StackExchange.Redis`, `RedisCacheOptions`, `AddHoneyDrunkCacheRedis<T>` DI extension, `RedisCacheStartupHook` for connection warmup, comprehensive unit tests, contract-shape canary, version bump `0.0.1` → `0.1.0`. **No live Redis dependency for unit tests; no GetOrSetAsync helper; standard Redis protocol commands only; System.Text.Json for serialization; package name exactly `HoneyDrunk.Cache.Redis` per ADR-0076 D1.**

**Target:** `HoneyDrunkStudios/HoneyDrunk.Cache`, branch from `main`.

**Context:**
- Goal: Fill ADR-0058 D8's deferred "first distributed backing" decision and give the Cache Node its first real implementation. The Redis backing is the package that Notify Cloud multi-replica and Communications shared cache will compose at their respective host-time when they pull on distributed caching.
- Feature: ADR-0076 acceptance initiative, Wave 2, Packet 03.
- ADRs: ADR-0076 (D1/D3/D4/D5 — the backing decision being implemented), ADR-0058 (D2 — the contract source; D8 — the no-GetOrSetAsync rule), ADR-0059 (the Node home for backings), ADR-0005 (consumer-Vault factory seam).

**Acceptance Criteria:** As listed above.

**Dependencies:** `work-item:01`, `work-item:02`.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. — Redis package is runtime, depends on Kernel.Abstractions. Correct.
- **Invariant 2:** Runtime depends on Abstractions, not other runtimes at the same layer. — Correct.
- **Invariant 4:** DAG, Kernel at root. — One-way Cache → Kernel.Abstractions.
- **Invariant 8:** Secret values never in logs/traces/exceptions/telemetry. — The package never logs connection strings or access keys.
- **Invariant 9:** Vault is the only source of secrets. — Connection-string factory parameter is the seam.
- **Invariant 11/12/13/14/15/17/21/26/27/50/51:** As inlined in the Referenced Invariants section above. Critical: no live Redis in unit tests (invariant 15); first packet on solution bumps version (invariant 27); no `Thread.Sleep` in tests (invariant 51); Cache has no Vault (invariant 17); placeholder Adapters CHANGELOG gets NO alignment-bump entry (invariant 27 no-alignment-noise rule).
- **Package name `HoneyDrunk.Cache.Redis`** (literal text from ADR-0076 D1) — NOT `HoneyDrunk.Cache.Adapters.Redis` or any other variant.
- **Standard Redis protocol commands only** (per ADR-0076 D3) — no `RediSearch`, `RedisJSON`, `RedisTimeSeries`, `RedisGraph`, `RedisBloom`. Verify with grep at acceptance time.
- **System.Text.Json for value serialization** (per ADR-0076 D3) — no Newtonsoft.Json reference.
- **No `GetOrSetAsync` helper** (per ADR-0058 D8 / Alternatives) — convenience sugar is deferred.
- **No `HoneyDrunk.Pulse` reference** — telemetry wires in packet 04 via Kernel's `ITelemetryActivityFactory`, one-way.
- **No `HoneyDrunk.Vault` reference** — connection-string factory parameter is the seam; the host wires Vault.
- **`IStartupHook` lives in `HoneyDrunk.Kernel.Abstractions.Lifecycle`** (verified at `Kernel.Abstractions/Lifecycle/IStartupHook.cs`).
- **First packet on the `HoneyDrunk.Cache` solution in this initiative** — version bump `0.0.1` → `0.1.0` in `Directory.Build.props`. Placeholder Adapters alignment-bumps silently.
- **No `## Unreleased` block in CHANGELOG.** Per memory `feedback_no_unreleased_commits`. Entry lands under `## [0.1.0] - YYYY-MM-DD`.
- **README does NOT cite ADR numbers in narrative.** Per memory `feedback_no_adr_in_docs`.
- **No tag push as part of this packet.** Tags are human-pushed per invariant 27; the first `v0.1.0` tag is a post-merge step the operator performs.
- **Branch protection update** to require `api-compatibility` is a small post-merge org-admin action; PR body calls it out.

**Key Files:**
- `src/HoneyDrunk.Cache.Redis/HoneyDrunk.Cache.Redis.csproj` — package references as listed
- `src/HoneyDrunk.Cache.Redis/RedisCacheStore.cs` — main implementation
- `src/HoneyDrunk.Cache.Redis/RedisCacheOptions.cs` — configuration record (no `I` prefix per records-naming rule)
- `src/HoneyDrunk.Cache.Redis/RedisCacheStartupHook.cs` — `IStartupHook` for connection warmup
- `src/HoneyDrunk.Cache.Redis/ServiceCollectionExtensions.cs` — `AddHoneyDrunkCacheRedis<T>`
- `src/HoneyDrunk.Cache.Redis/README.md` + `CHANGELOG.md` (new)
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` — full unit-test coverage
- `HoneyDrunk.Cache.slnx` — reference new projects
- `Directory.Build.props` — version `0.1.0`
- `CHANGELOG.md` (repo root) — `[0.1.0]` entry
- `README.md` (repo root) — update placeholder text
- `.github/workflows/api-compatibility.yml` (new)

**Contracts:**

This packet implements one contract: `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions` (declared by ADR-0058 D2, version `0.8.0`). It introduces public types in `HoneyDrunk.Cache.Redis`:

- `RedisCacheStore<T>` (sealed class, implements `ICacheStore<T>`)
- `RedisCacheOptions` (sealed record — record naming drops the `I` prefix)
- `RedisCacheStartupHook` (sealed class, implements `IStartupHook` from `HoneyDrunk.Kernel.Abstractions.Lifecycle`)
- `ServiceCollectionExtensions` (static class with `AddHoneyDrunkCacheRedis<T>` extension method)

These four public types are the contract surface that the `api-compatibility.yml` canary freezes. Future shape drift on any of them requires an intentional version bump.
