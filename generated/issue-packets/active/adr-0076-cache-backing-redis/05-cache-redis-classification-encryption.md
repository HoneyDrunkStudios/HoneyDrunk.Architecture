---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Cache
labels: ["feature", "tier-2", "cache", "redis", "security", "adr-0076", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0076", "ADR-0049", "ADR-0058"]
accepts: ADR-0076
wave: 3
initiative: adr-0076-cache-backing-redis
node: honeydrunk-cache
---

# Feature: Add classification-aware encrypted-value wrapper for Restricted-tier values in `HoneyDrunk.Cache.Redis`

## Summary
Add the application-layer-encryption surface required by ADR-0076 D6 for Restricted-tier values cached in Standard-tier Azure Cache for Redis (Premium tier — which supports encryption at rest — is NOT adopted per ADR-0076 D2 alternatives; Standard tier supports encryption in transit only). Introduce an opt-in `IEncryptedCacheStore<T>` surface (or equivalent — name to be confirmed at edit time per repo convention) that consumers explicitly use when caching values marked Restricted-tier per ADR-0049. Values written through this surface are AES-GCM-encrypted with a Vault-resolved key before being stored in Redis and decrypted on read. The standard `RedisCacheStore<T>` from packet 03 continues to serve Internal-tier and Tenant-tier values unchanged — consumers explicitly opt into encryption when their classification mandates it.

**Appends to in-progress `[0.1.0]` from packet 03 — no new version bump per invariant 27.**

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Cache`

## Motivation

ADR-0076 D6's classification carve-out is explicit:

> **No PII / Restricted-tier values in cache without classification-aware handling.** Per ADR-0058 D6 (classification inheritance) and ADR-0049, any cached value carrying Restricted-tier material requires the per-Node encryption-at-rest discipline. Azure Cache for Redis Standard tier supports encryption in transit by default; **encryption at rest is Premium-only at the time of this ADR**. **Restricted-tier values are not stored in Standard-tier Azure Cache for Redis without per-value encryption at the application layer.** Premium-tier instances are considered when a workload requires Restricted-tier caching at scale.

ADR-0076 D2 commits to Standard tier as the prod baseline, not Premium. ADR-0049 defines Restricted as a classification tier carrying the strongest handling requirements. The combination means: if any consumer wants to cache a Restricted-tier value, they need application-layer encryption — the Standard-tier Redis instance can't provide at-rest encryption itself.

Today, no consumer caches Restricted-tier values (Notify Cloud's planned uses are API-key validation results and tenant-tier descriptors, neither of which is Restricted per ADR-0049's tier definitions; Communications's preference cache is Internal-tier). But the discipline must exist before the first consumer with a Restricted-tier cache use lands — otherwise the temptation is to bypass classification awareness, ship the value through `RedisCacheStore<T>`, and absorb the silent compliance break.

This packet ships the encryption surface so Restricted-tier consumers have an in-package, opt-in path. The standard `RedisCacheStore<T>` is untouched for Internal/Tenant-tier consumers; they pay nothing for the encryption surface they don't use.

## Scope

- `src/HoneyDrunk.Cache.Redis/` updates:
  - `EncryptedRedisCacheStore<T>` — new sibling of `RedisCacheStore<T>` that wraps values in AES-GCM encryption before write and decrypts on read. Implements `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions`; consumers compose this implementation instead of (NOT in addition to) the standard `RedisCacheStore<T>` for their Restricted-tier cache use.
  - `EncryptedRedisCacheOptions` (record, no `I` prefix) — extends `RedisCacheOptions` with `EncryptionKeySecretName` (Vault secret name holding the 256-bit AES key material; the host's `ISecretStore` resolves it at composition time).
  - `AddHoneyDrunkCacheRedisEncrypted<T>` — `IServiceCollection` extension method for DI registration of the encrypted variant. Accepts an `Action<EncryptedRedisCacheOptions>` and an encryption-key factory parameter `Func<IServiceProvider, byte[]>` (same seam pattern as packet 03's connection-string factory — host resolves from Vault).
  - Encryption format: AES-GCM with 96-bit nonce + 128-bit auth tag, generating a fresh nonce per write (CSPRNG-sourced). Ciphertext format: `[nonce (12 bytes)][ciphertext][auth_tag (16 bytes)]`. On decrypt, parse the format, verify the auth tag, return the plaintext. Standard AEAD pattern; no bespoke cryptography.
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/` — new test cases:
  - Round-trip: `SetAsync` then `GetAsync` returns the original value (decryption succeeds with same key).
  - Different nonce per write: setting the same key twice produces different ciphertexts (verify via Redis fake's stored value differing across calls).
  - Tamper detection: corrupting the stored ciphertext (modifying any byte) causes `GetAsync` to throw (auth-tag verification fails).
  - Wrong key: constructing two `EncryptedRedisCacheStore<T>` with different keys; one's `SetAsync` value cannot be `GetAsync`-read by the other (auth-tag verification fails).
  - Tag-based invalidation: `RemoveByTagAsync` works the same as in `RedisCacheStore<T>` — tags are not encrypted (they're routing metadata, not value content), so the tag-to-key index continues to work.
  - Telemetry: encrypted operations emit the same counters/histograms as `RedisCacheStore<T>` (hit/miss/error, command duration); a separate counter or label distinguishes encrypted-vs-plain operations.
- Documentation:
  - `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` and repo-level `CHANGELOG.md` — append to in-progress `[0.1.0]`.
  - `src/HoneyDrunk.Cache.Redis/README.md` — new "When to use the encrypted variant" section. Plain-English explanation: "If the value being cached carries Restricted-tier material per your Node's data classification, compose `AddHoneyDrunkCacheRedisEncrypted<T>` instead of `AddHoneyDrunkCacheRedis<T>`. Otherwise the standard backing is correct." Does NOT cite ADR numbers in narrative (per memory `feedback_no_adr_in_docs`); cross-link to the data-classification reference doc in the "Cross references" footer if one exists.

## Proposed Implementation

### `EncryptedRedisCacheOptions` record

```csharp
namespace HoneyDrunk.Cache.Redis;

/// <summary>
/// Configuration for the encrypted Redis-backed ICacheStore&lt;T&gt; implementation.
/// Extends RedisCacheOptions with an encryption-key secret reference.
/// </summary>
public sealed record EncryptedRedisCacheOptions
{
    /// <summary>Connection string secret name (same seam as RedisCacheOptions).</summary>
    public string ConnectionStringSecretName { get; init; } = "redis-connection-string";

    /// <summary>Key prefix (same as RedisCacheOptions).</summary>
    public string KeyPrefix { get; init; } = string.Empty;

    /// <summary>Command timeout (same as RedisCacheOptions).</summary>
    public TimeSpan CommandTimeout { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>JsonSerializerOptions (same as RedisCacheOptions; runs BEFORE encryption).</summary>
    public JsonSerializerOptions? SerializerOptions { get; init; }

    /// <summary>
    /// Vault secret name holding the 256-bit AES encryption key. Default "redis-encryption-key".
    /// The composing host resolves this via ISecretStore and supplies the key bytes through
    /// the encryption-key factory on AddHoneyDrunkCacheRedisEncrypted&lt;T&gt;.
    /// </summary>
    public string EncryptionKeySecretName { get; init; } = "redis-encryption-key";
}
```

### `EncryptedRedisCacheStore<T>` implementation

Wraps `RedisCacheStore<T>`'s storage pattern with AES-GCM encryption. The class composes `IConnectionMultiplexer` directly (does NOT call the unencrypted `RedisCacheStore<T>` underneath — it's a sibling implementation, not a decorator, because the serialization-then-encryption order matters and a decorator pattern would double-serialize).

```csharp
namespace HoneyDrunk.Cache.Redis;

/// <summary>
/// Encrypted Redis-backed ICacheStore&lt;T&gt; implementation. Values are serialized through
/// System.Text.Json, then AES-GCM-encrypted with a Vault-resolved key, then stored in Redis.
/// Tags are NOT encrypted (they are routing metadata, not value content).
/// Use this variant when the cached value carries Restricted-tier material per data classification.
/// </summary>
public sealed class EncryptedRedisCacheStore<T> : ICacheStore<T>
{
    private readonly IConnectionMultiplexer _multiplexer;
    private readonly EncryptedRedisCacheOptions _options;
    private readonly JsonSerializerOptions _serializerOptions;
    private readonly byte[] _key;   // 256-bit AES key, resolved at construction time via factory
    private readonly ILogger<EncryptedRedisCacheStore<T>> _logger;

    public EncryptedRedisCacheStore(
        IConnectionMultiplexer multiplexer,
        IOptions<EncryptedRedisCacheOptions> options,
        byte[] encryptionKey,
        ILogger<EncryptedRedisCacheStore<T>> logger)
    {
        _multiplexer = multiplexer ?? throw new ArgumentNullException(nameof(multiplexer));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _key = encryptionKey ?? throw new ArgumentNullException(nameof(encryptionKey));
        if (_key.Length != 32)
        {
            throw new ArgumentException("Encryption key must be 256 bits (32 bytes).", nameof(encryptionKey));
        }
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
        var ciphertext = await db.StringGetAsync(NamespaceKey(key)).ConfigureAwait(false);
        if (ciphertext.IsNullOrEmpty) return default;

        var plaintext = Decrypt(ciphertext!);
        return JsonSerializer.Deserialize<T>(plaintext, _serializerOptions);
    }

    public async ValueTask SetAsync(
        string key,
        T value,
        TimeSpan? ttl = null,
        IReadOnlyCollection<string>? tags = null,
        CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        var plaintext = JsonSerializer.SerializeToUtf8Bytes(value, _serializerOptions);
        var ciphertext = Encrypt(plaintext);

        var db = _multiplexer.GetDatabase();
        var namespacedKey = NamespaceKey(key);
        await db.StringSetAsync(namespacedKey, ciphertext, ttl).ConfigureAwait(false);

        if (tags is { Count: > 0 })
        {
            // Tags are routing metadata; NOT encrypted — same tag-to-key index pattern as RedisCacheStore<T>.
            var tagOps = new List<Task>(tags.Count + 1);
            foreach (var tag in tags)
            {
                tagOps.Add(db.SetAddAsync(NamespaceTagKey(tag), namespacedKey.ToString()));
            }
            tagOps.Add(db.SetAddAsync(NamespaceKeyTagsKey(namespacedKey), tags.Select(t => (RedisValue)t).ToArray()));
            await Task.WhenAll(tagOps).ConfigureAwait(false);
        }
    }

    public ValueTask RemoveAsync(string key, CancellationToken ct = default)
    {
        // Identical to RedisCacheStore<T> — no encryption work needed for invalidation.
        // (Implementation body the same as packet 03's RedisCacheStore<T>.RemoveAsync.)
    }

    public ValueTask RemoveByTagAsync(string tag, CancellationToken ct = default)
    {
        // Identical to RedisCacheStore<T> — tags are not encrypted.
        // (Implementation body the same as packet 03's RedisCacheStore<T>.RemoveByTagAsync.)
    }

    private byte[] Encrypt(byte[] plaintext)
    {
        Span<byte> nonce = stackalloc byte[12];
        RandomNumberGenerator.Fill(nonce);

        var ciphertext = new byte[plaintext.Length];
        Span<byte> tag = stackalloc byte[16];

        using var aes = new AesGcm(_key, tagSizeInBytes: 16);
        aes.Encrypt(nonce, plaintext, ciphertext, tag);

        // Format: [nonce (12)][ciphertext][tag (16)]
        var output = new byte[12 + ciphertext.Length + 16];
        nonce.CopyTo(output.AsSpan(0, 12));
        ciphertext.AsSpan().CopyTo(output.AsSpan(12, ciphertext.Length));
        tag.CopyTo(output.AsSpan(12 + ciphertext.Length, 16));
        return output;
    }

    private byte[] Decrypt(ReadOnlySpan<byte> ciphertextBlob)
    {
        if (ciphertextBlob.Length < 12 + 16)
        {
            throw new CryptographicException("Encrypted cache value is malformed (too short).");
        }

        var nonce = ciphertextBlob[..12];
        var tag = ciphertextBlob[^16..];
        var ciphertext = ciphertextBlob[12..^16];

        var plaintext = new byte[ciphertext.Length];
        using var aes = new AesGcm(_key, tagSizeInBytes: 16);
        aes.Decrypt(nonce, ciphertext, tag, plaintext);   // throws CryptographicException on auth-tag mismatch
        return plaintext;
    }

    // NamespaceKey / NamespaceTagKey / NamespaceKeyTagsKey helpers — same as RedisCacheStore<T>.
}
```

(Note: `AesGcm` is the .NET BCL type in `System.Security.Cryptography`. Available on .NET 6+. Verified available on .NET 10.0 — the repo's target framework.)

### DI registration

```csharp
public static IServiceCollection AddHoneyDrunkCacheRedisEncrypted<T>(
    this IServiceCollection services,
    Action<EncryptedRedisCacheOptions>? configureOptions = null,
    Func<IServiceProvider, string>? connectionStringFactory = null,
    Func<IServiceProvider, byte[]>? encryptionKeyFactory = null)
{
    if (services is null) throw new ArgumentNullException(nameof(services));

    if (configureOptions is not null)
    {
        services.Configure(configureOptions);
    }

    if (connectionStringFactory is not null)
    {
        services.TryAddSingleton<IConnectionMultiplexer>(sp =>
            ConnectionMultiplexer.Connect(connectionStringFactory(sp)));
    }

    if (encryptionKeyFactory is null)
    {
        throw new InvalidOperationException(
            "AddHoneyDrunkCacheRedisEncrypted<T> requires an encryptionKeyFactory. " +
            "Resolve the key from ISecretStore (Vault) at composition time.");
    }

    services.TryAddSingleton<ICacheStore<T>>(sp =>
        new EncryptedRedisCacheStore<T>(
            sp.GetRequiredService<IConnectionMultiplexer>(),
            sp.GetRequiredService<IOptions<EncryptedRedisCacheOptions>>(),
            encryptionKeyFactory(sp),
            sp.GetRequiredService<ILogger<EncryptedRedisCacheStore<T>>>()));

    services.AddSingleton<IStartupHook, RedisCacheStartupHook>();
    services.TryAddSingleton<RedisCacheTelemetry>();
    services.AddSingleton<IHealthContributor, RedisHealthContributor>();

    return services;
}
```

The encryption-key factory parameter is **required** (no default); composing Restricted-tier handling without an explicit key resolution is a misuse. The error message points the host at `ISecretStore` for the resolution path.

### Unit tests

Add to `tests/HoneyDrunk.Cache.Redis.Tests.Unit/EncryptedRedisCacheStoreTests.cs` (new file):

- **RoundTrip:** Set value through encrypted store; get value through encrypted store with same key → original value returned.
- **DifferentNonceEachWrite:** Set same key twice with same value; verify the stored ciphertext bytes differ between the two writes (different nonce → different ciphertext).
- **TamperDetection:** Set value; modify any byte of the stored ciphertext in the Redis fake; `GetAsync` throws `CryptographicException` (auth-tag mismatch).
- **WrongKey:** Two encrypted stores with different keys; one's `SetAsync` value cannot be read by the other (auth-tag mismatch on decrypt → `CryptographicException`).
- **InvalidKeySize:** Constructing `EncryptedRedisCacheStore<T>` with a 16-byte or 24-byte key throws `ArgumentException` (256-bit key only).
- **TagsNotEncrypted:** Verify tags passed to `SetAsync` are stored in the tag index as plaintext (verify by `SetMembersAsync` on the tag key returning the original tag values, not ciphertext).
- **TagInvalidation:** `RemoveByTagAsync` invalidates encrypted values just like the plain backing.
- **MissingKeyFactory:** Calling `AddHoneyDrunkCacheRedisEncrypted<T>` without an `encryptionKeyFactory` throws `InvalidOperationException` with the helpful error message.
- **No high-cardinality on metrics:** Verify metric tags on encrypted operations follow the same discipline as packet 04's tests — no key, no tenant id on metrics; trace attributes only.

### Documentation updates

- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` and repo-level `CHANGELOG.md` — append to `[0.1.0]` describing the encrypted-value wrapper.
- `src/HoneyDrunk.Cache.Redis/README.md` — new "When to use the encrypted variant" section. Plain-English: "Use `AddHoneyDrunkCacheRedisEncrypted<T>` instead of `AddHoneyDrunkCacheRedis<T>` when the value's data classification requires at-rest encryption. The encryption is AES-GCM with a 256-bit key resolved from your Node's Vault; the standard variant skips the encryption step and is correct for Internal-tier and Tenant-tier values."

## Affected Files

- `src/HoneyDrunk.Cache.Redis/EncryptedRedisCacheStore.cs` (new)
- `src/HoneyDrunk.Cache.Redis/EncryptedRedisCacheOptions.cs` (new)
- `src/HoneyDrunk.Cache.Redis/ServiceCollectionExtensions.cs` — add `AddHoneyDrunkCacheRedisEncrypted<T>` extension method.
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/EncryptedRedisCacheStoreTests.cs` (new)
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` — append to in-progress `[0.1.0]`.
- `CHANGELOG.md` (repo root) — append to in-progress `[0.1.0]`.
- `src/HoneyDrunk.Cache.Redis/README.md` — new "When to use the encrypted variant" section.

## NuGet Dependencies

No new packages. `AesGcm` is in `System.Security.Cryptography` (BCL — available on .NET 6+, .NET 10.0 target framework includes it). `RandomNumberGenerator` is also in the BCL.

## Boundary Check

- [x] All changes inside `HoneyDrunk.Cache.Redis`. No edits to Kernel, no edits to Pulse, no edits to Vault.
- [x] **Encryption key resolution is host-time** via the `encryptionKeyFactory` parameter. The package does not take a Vault dependency; the host wires `ISecretStore` resolution.
- [x] **Encryption is opt-in.** Consumers using Internal-tier or Tenant-tier values continue using `RedisCacheStore<T>` from packet 03 unchanged — they pay nothing for the encryption surface.
- [x] **Standard AEAD cryptography (AES-GCM).** No bespoke cipher constructions. Nonce sourced from `RandomNumberGenerator` (CSPRNG). Auth tag verified on every read. Tamper detection is intrinsic to AES-GCM.
- [x] **Tags are not encrypted.** Tags are routing metadata, not value content. Tag-to-key index continues to work for invalidation.
- [x] No new version bump — appends to in-progress `[0.1.0]` from packet 03 (invariant 27).
- [x] No `Thread.Sleep` in tests (invariant 51).
- [x] No secret values anywhere — encryption key is byte[] resolved at composition; never logged, never traced, never appears in telemetry or error reports (invariant 8).
- [x] No reliance on Azure Cache for Redis Premium-tier features (per ADR-0076 D2 alternatives — Premium NOT adopted; this packet's encryption surface is exactly the reason Premium is not needed for Restricted-tier handling).

## Acceptance Criteria

- [ ] `EncryptedRedisCacheStore<T>` implements `ICacheStore<T>` with AES-GCM encryption on `SetAsync` and decryption on `GetAsync`
- [ ] Ciphertext format is `[nonce (12 bytes)][ciphertext][auth_tag (16 bytes)]`
- [ ] Nonce is fresh per write (CSPRNG-sourced via `RandomNumberGenerator.Fill`)
- [ ] Encryption key must be 256 bits (32 bytes); constructor throws `ArgumentException` on other key sizes
- [ ] Tamper detection: corrupting the stored ciphertext causes `GetAsync` to throw `CryptographicException`
- [ ] Wrong-key detection: decrypting with a different key throws `CryptographicException`
- [ ] `EncryptedRedisCacheOptions` record exists with `ConnectionStringSecretName`, `KeyPrefix`, `CommandTimeout`, `SerializerOptions`, `EncryptionKeySecretName` properties
- [ ] `AddHoneyDrunkCacheRedisEncrypted<T>` extension exists; **requires** an `encryptionKeyFactory` parameter (throws `InvalidOperationException` with helpful message if omitted)
- [ ] **Tags are stored as plaintext** in the tag-to-key index (NOT encrypted) — verified by unit test inspecting the Redis fake's tag-set contents
- [ ] `RemoveByTagAsync` invalidates encrypted values correctly (tag invalidation works regardless of value encryption)
- [ ] Unit tests pass: round-trip, different-nonce-per-write, tamper-detection, wrong-key, invalid-key-size, tags-not-encrypted, tag-invalidation, missing-key-factory, no-high-cardinality-on-metrics
- [ ] **Standard `RedisCacheStore<T>` is unchanged** by this packet — Internal-tier and Tenant-tier consumers continue using the unencrypted backing unchanged
- [ ] **`Directory.Build.props` version remains `0.1.0`** — NO version bump in this packet (invariant 27 — appends to existing in-progress version)
- [ ] `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` and repo-level `CHANGELOG.md` `[0.1.0]` entries appended (not new version section)
- [ ] `src/HoneyDrunk.Cache.Redis/README.md` "When to use the encrypted variant" section added — without citing "ADR-0076" / "ADR-0049" by number in narrative
- [ ] No new NuGet packages — `AesGcm` and `RandomNumberGenerator` are BCL types
- [ ] `pr-core.yml` and `api-compatibility.yml` both pass — the public surface gained `EncryptedRedisCacheStore<T>` and `EncryptedRedisCacheOptions`; the version is still `0.1.0` because they ship within the in-progress version
- [ ] All public APIs have XML documentation (invariant 13)
- [ ] No `Thread.Sleep` in test code (invariant 51)
- [ ] No secret values anywhere (invariant 8) — the encryption key never enters logs, traces, telemetry, or error-reporter context

## Human Prerequisites

- [ ] Packet 03 of this initiative merged — `HoneyDrunk.Cache.Redis` package exists. (Packet 04 — telemetry/health/error-reporter — does NOT need to be merged first; packet 05 can land in parallel with packet 04 against the same `0.1.0` version, both appending to the same CHANGELOG section. The agent merging second should expect to rebase on the first.)
- [ ] **No consumer is using `EncryptedRedisCacheStore<T>` yet.** This packet ships the surface; the first Restricted-tier cache use lands in a future feature packet against the consuming Node, at which time the operator generates a 256-bit encryption key, seeds it into the consumer Node's Vault, and wires the `encryptionKeyFactory` parameter to resolve from `ISecretStore`.
- [ ] **No Azure portal action required for this packet.** The encryption key is generated and seeded at the first Restricted-tier consumer composition packet, not now. No `redis-encryption-key` secret exists in any Vault at this packet's merge time.
- [ ] After this packet's PR merges and the post-merge tag-push for `v0.1.0` ships `HoneyDrunk.Cache.Redis` to NuGet, the package's public surface includes both the standard (`RedisCacheStore<T>`) and encrypted (`EncryptedRedisCacheStore<T>`) variants. Consumers choose at composition time.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. — `HoneyDrunk.Cache.Redis` is runtime; no Abstractions-on-runtime dependency added.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. — The encryption key (`byte[]`) is held in the `EncryptedRedisCacheStore<T>` instance; never logged, never traced, never written to telemetry attributes or error-reporter context. Key bytes are not serialized or formatted into any string.

> **Invariant 9:** Vault is the only source of secrets. — The `encryptionKeyFactory` parameter is the seam through which the host wires `ISecretStore` resolution. The package never resolves a secret; it accepts a factory.

> **Invariant 13:** All public APIs have XML documentation. — Every new public type and method carries XML doc.

> **Invariant 17:** Library-only Nodes have no Vault. — Cache has no Vault. The encryption key lives in the **consumer Node's** Vault when the first Restricted-tier consumer composes.

> **Invariant 21:** Applications must never pin to a specific secret version. — The `encryptionKeyFactory` resolves the latest version via `ISecretStore` (host responsibility). The package does not pin.

> **Invariant 27:** All projects in a solution share one version and move together. First packet bumps; subsequent packets append. — Second/third packet on the `HoneyDrunk.Cache` solution in this initiative (packet 04 may merge first or second; packet 05 may merge first or second; both append to `[0.1.0]` from packet 03). No version bump.

> **Invariant 51:** Test code contains no `Thread.Sleep`. — Tests use the InMemory fake and synchronous-completion patterns.

## Referenced ADR Decisions

**ADR-0076 D6 — Classification carve-out:** Restricted-tier values are not stored in Standard-tier Azure Cache for Redis without per-value encryption at the application layer. This packet ships exactly that surface — `EncryptedRedisCacheStore<T>` for Restricted-tier consumers; `RedisCacheStore<T>` from packet 03 remains for Internal-tier and Tenant-tier consumers.

**ADR-0076 D2 alternatives — Premium tier NOT adopted:** Premium tier (which supports at-rest encryption natively) is not adopted on cost grounds. The application-layer encryption in this packet is the reason Premium is not needed for Restricted-tier handling at MVP scale; this packet preserves the Standard-tier cost posture while supporting the classification discipline.

**ADR-0049 — Data classification, PII handling, and retention schedule:** Defines the tier system (Public, Internal, Tenant, Restricted) and the handling requirements per tier. Restricted-tier values carry the strongest handling — encryption at rest is one of the disciplines. This packet's encrypted variant satisfies that for cache use.

**ADR-0058 D6 — Classification inheritance:** A cached value inherits its source's classification. If the source value is Restricted-tier, the cached representation is Restricted-tier too. Per this rule, consumers caching Restricted-tier values must compose `AddHoneyDrunkCacheRedisEncrypted<T>` — using `AddHoneyDrunkCacheRedis<T>` for a Restricted-tier value would be a classification-discipline violation.

## Constraints

- **Invariant 1, 8, 9, 13, 17, 21, 27, 51:** As inlined in Referenced Invariants.
- **AES-GCM with 256-bit key, 96-bit nonce, 128-bit auth tag.** Standard AEAD parameters. No bespoke cipher constructions.
- **Fresh nonce per write** via `RandomNumberGenerator.Fill` (CSPRNG).
- **Encryption key never enters logs, traces, telemetry, or error-reporter context.** Per invariant 8.
- **Tags are NOT encrypted.** They are routing metadata; the tag-to-key index continues to function as in `RedisCacheStore<T>`.
- **`encryptionKeyFactory` is required.** No default; composing Restricted-tier handling without explicit key resolution is a misuse and throws.
- **No version bump.** Appends to in-progress `[0.1.0]`. Packet 04 and packet 05 both append; whichever lands second rebases on the first.
- **No `## Unreleased` block in CHANGELOG.** Entries land under `[0.1.0]`.
- **README does NOT cite ADR numbers in narrative.** Per memory `feedback_no_adr_in_docs`.
- **No Azure portal work in this packet.** Encryption key generation and Vault seeding happen at the first Restricted-tier consumer composition packet.

## Dependencies

- `packet:03` — the bare `HoneyDrunk.Cache.Redis` package must exist before the encrypted sibling can be added. (Packet 04 — telemetry/health/error-reporter — is NOT a dependency; packets 04 and 05 are siblings against the in-progress `[0.1.0]`.)

## Labels

`feature`, `tier-2`, `cache`, `redis`, `security`, `adr-0076`, `wave-3`

## Agent Handoff

**Objective:** Ship the classification-aware application-layer-encryption surface per ADR-0076 D6. Add `EncryptedRedisCacheStore<T>`, `EncryptedRedisCacheOptions`, `AddHoneyDrunkCacheRedisEncrypted<T>`. AES-GCM with a 256-bit key resolved through a required factory parameter. Tags remain plaintext. Standard `RedisCacheStore<T>` is unchanged. Appends to in-progress `[0.1.0]`.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Cache`, branch from `main`.

**Context:**
- Goal: Give Restricted-tier consumers an in-package opt-in encryption path so the Grid does not need to adopt Premium-tier Azure Cache for Redis (which has at-rest encryption native) for the classification discipline. The application-layer surface is the reason Premium is not needed at MVP scale.
- Feature: ADR-0076 acceptance initiative, Wave 3, Packet 05.
- ADRs: ADR-0076 D6 (the classification carve-out being implemented), ADR-0076 D2 alternatives (Premium NOT adopted — encryption is application-layer), ADR-0049 (data classification tier definitions), ADR-0058 D6 (classification inheritance — cached values inherit their source's tier).

**Acceptance Criteria:** As listed above.

**Dependencies:** `packet:03` only. (Packets 04 and 05 are sibling packets against the same in-progress `[0.1.0]` version; whichever merges second rebases.)

**Constraints:**

- **Invariant 1, 8, 9, 13, 17, 21, 27, 51:** As inlined in Referenced Invariants.
- **AES-GCM with 256-bit key, 96-bit nonce, 128-bit auth tag.** Standard AEAD. No bespoke cipher constructions.
- **Fresh nonce per write.** CSPRNG via `RandomNumberGenerator.Fill`.
- **Encryption key never in logs/traces/telemetry/error-reporter context.** Invariant 8 enforcement.
- **Tags NOT encrypted.** Routing metadata, plaintext.
- **`encryptionKeyFactory` is required.** No default; misuse throws.
- **No version bump.** Appends to `[0.1.0]`.
- **Standard `RedisCacheStore<T>` unchanged.** This packet adds a sibling implementation, does not modify the existing one.
- **No Azure portal work.** Key generation + Vault seeding happen at the first Restricted-tier consumer composition.
- **README does NOT cite ADR numbers in narrative.** Per memory `feedback_no_adr_in_docs`.
- **No `## Unreleased` block in CHANGELOG.**

**Key Files:**
- `src/HoneyDrunk.Cache.Redis/EncryptedRedisCacheStore.cs` (new)
- `src/HoneyDrunk.Cache.Redis/EncryptedRedisCacheOptions.cs` (new — sealed record, no `I` prefix)
- `src/HoneyDrunk.Cache.Redis/ServiceCollectionExtensions.cs` — add `AddHoneyDrunkCacheRedisEncrypted<T>` extension
- `tests/HoneyDrunk.Cache.Redis.Tests.Unit/EncryptedRedisCacheStoreTests.cs` (new)
- `src/HoneyDrunk.Cache.Redis/CHANGELOG.md` + repo-level `CHANGELOG.md` — append to `[0.1.0]`
- `src/HoneyDrunk.Cache.Redis/README.md` — new "When to use the encrypted variant" section

**Contracts:**

Implements existing `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions`. Introduces two new public types in `HoneyDrunk.Cache.Redis`:

- `EncryptedRedisCacheStore<T>` (sealed class, implements `ICacheStore<T>`)
- `EncryptedRedisCacheOptions` (sealed record — record naming drops the `I` prefix)
- New static method `AddHoneyDrunkCacheRedisEncrypted<T>` on the existing `ServiceCollectionExtensions` class

These are picked up by the `api-compatibility.yml` canary on the next CI run; the version remains `0.1.0` because they ship within the in-progress version per invariant 27.
