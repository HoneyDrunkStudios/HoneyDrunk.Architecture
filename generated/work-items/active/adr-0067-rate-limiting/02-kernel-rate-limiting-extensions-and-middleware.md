---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0067", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0067"]
wave: 2
initiative: adr-0067-rate-limiting
node: honeydrunk-kernel
---

# Ship AddGridRateLimiting and UseGridRateLimiting extension methods in HoneyDrunk.Kernel

## Summary
Ship the Grid-wide rate-limiter wiring in `HoneyDrunk.Kernel` per ADR-0067 D9: `AddGridRateLimiting()` / `UseGridRateLimiting()` extension methods on the Kernel runtime, the partitioned ASP.NET Core `RateLimiter` middleware reading `IGridContext.TenantId`, the RFC 7807 `application/problem+json` 429 envelope per D6, the IETF `RateLimit-*` success-side headers per D7, and the three default-named policies `"tier"` / `"anon"` / `"quota-billable"`. Includes anonymous-endpoint keying on `CF-Connecting-IP` (with connection-IP fallback) per D5, API-key-prefix keying for pre-auth API-key-validation endpoints per D5, and `TenantId.Internal` bypass per ADR-0026 D4. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution.

## Context
ADR-0026 D4 already placed `ITenantRateLimitPolicy` and `TenantRateLimitDecision` in `HoneyDrunk.Kernel.Abstractions`, with a `NoopTenantRateLimitPolicy` default in `HoneyDrunk.Kernel`. The contract describes a decision; this packet ships the **substrate** that turns the contract into an enforced HTTP-pipeline middleware.

ADR-0067 D1 commits ASP.NET Core's built-in `RateLimiter` middleware (`Microsoft.AspNetCore.RateLimiting`, .NET 8+) as the substrate. It is first-party, in-process, free, and supports `PartitionedRateLimiter.Create<TResource, TPartitionKey>` natively — keying on `TenantId` requires no shim. The `OnRejected` hook customizes the 429 response in a single delegate. Cloudflare's edge rate limiting (per ADR-0029) sits above the application limiter for gross-abuse absorption; the two do not overlap by design.

ADR-0067 D9 commits the wiring location: `HoneyDrunk.Kernel`. Every Node that exposes an HTTP surface composes `AddGridRateLimiting()` / `UseGridRateLimiting()` at host time. Library-only Nodes (Kernel itself, Vault, Transport) do not. Pushing the wiring into Kernel means every Node that exposes HTTP gets the same shape, and a future Gateway Node — when it lands — reuses the Kernel extension without re-litigating the response/header conventions.

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts; ships `ITenantRateLimitPolicy` and `TenantRateLimitDecision`) and `HoneyDrunk.Kernel` (runtime; ships `NoopTenantRateLimitPolicy` plus the existing `AddHoneyDrunkNode` / `UseGridContext` extensions). This packet is the **first and only packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.7.0` → `0.8.0`; new feature, additive, no break). Per ADR-0035 D1 (additive minor bump), this is a minor bump. **Coordination note:** the `adr-0042-idempotency` initiative also bumps `HoneyDrunk.Kernel` from `0.7.0` → `0.8.0`. If both initiatives are mid-flight, the *first* packet on the solution bumps and the second appends to the in-progress `[0.8.0]` CHANGELOG line (invariant 27). Check the in-progress version state at execution time and choose between bumping and appending; state the choice in the PR. If ADR-0042's packet 02 lands first, this packet appends to its in-progress `[0.8.0]` entry. If this packet lands first, ADR-0042's packet 02 appends to ours.

> **Middleware ordering — load-bearing.** `UseGridRateLimiting` must be registered **after** `UseRouting`, **after** `UseAuthentication`, and **after** `UseGridContext` (the existing extension that populates `IGridContext.TenantId`), and **before** endpoint dispatch. `IGridContext.TenantId` must be present at partition-factory time; if it is not, the limiter cannot key on it. This is invariant 5/6 ("GridContext present and populated") applied at the middleware-ordering level. Document this ordering on the `UseGridRateLimiting` XML doc-comment.

> **The runtime extension is additive — no contract change.** `ITenantRateLimitPolicy` (in `HoneyDrunk.Kernel.Abstractions`) is unchanged. The existing `NoopTenantRateLimitPolicy` default stays — Nodes that have not opted into rate limiting see no behaviour change. Only hosts that compose `AddGridRateLimiting()` and `UseGridRateLimiting()` activate the middleware.

## Scope
- **`HoneyDrunk.Kernel`** (runtime package) — new types:
  - `AddGridRateLimiting(this IServiceCollection, Action<GridRateLimitOptions>? configure = null)` — DI registration extension. Wires `Microsoft.AspNetCore.RateLimiting` services, registers the partition factory keyed on `IGridContext.TenantId`, wires the `OnRejected` delegate that emits the RFC 7807 envelope per D6 and the `Retry-After` header, and registers the three default-named policies. Returns `IServiceCollection` for chaining.
  - `UseGridRateLimiting(this IApplicationBuilder)` — middleware registration extension. Registers the ASP.NET Core rate-limiter middleware in the pipeline and also registers the small response-decorating middleware that emits the `RateLimit-*` success-side headers per D7 on every response from a rate-limited endpoint (200, 4xx, 5xx, and 429 alike).
  - `GridRateLimitOptions` — options class consumed by `AddGridRateLimiting`. Holds per-policy tunables (token-bucket capacity / replenishment rate for the anonymous policy; everything else delegates to `ITenantRateLimitPolicy`). Includes the anonymous-endpoint defaults (60 requests/minute, 10 requests/second burst per ADR-0067 D5) and a `Func<HttpContext, TenantId>`-style hook left null by default (so the partition factory falls through to `IGridContextAccessor.Current.TenantId`).
  - `GridRateLimitPolicies` (static class) — string constants for the three named policies: `Tier = "tier"`, `Anonymous = "anon"`, `QuotaBillable = "quota-billable"`. Public so consuming Nodes can reference them in `[EnableRateLimiting(GridRateLimitPolicies.Tier)]`.
  - The internal partition factory + the `OnRejected` delegate that writes the RFC 7807 body and the `Retry-After` header. The `tenant_id` field is **deliberately not** in the body. The `tier` field is **omitted** for anonymous responses.
  - The internal response-decorating middleware that reads the limiter state and writes `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers on the outgoing response. The IETF draft `RateLimit-*` form only — the legacy `X-RateLimit-*` mirrors are **not** emitted. When multiple limits apply, report the most-restrictive limit currently in effect.
- Unit tests for: tenant-keyed partition under `TenantId`; anonymous endpoint keyed on `CF-Connecting-IP` (verify the connection-IP fallback when the header is absent); API-key-prefix keying for the pre-auth endpoint shape; `TenantId.Internal` bypass; the 429 RFC 7807 body shape (correct `type` URI, `title`, `status`, `detail`, `instance`, `tier` populated for authenticated and **omitted** for anonymous, `retry_after_seconds`, `correlation_id`; `tenant_id` **absent**); the `Retry-After` header in seconds (not HTTP-date); the `RateLimit-*` success-side headers present on a 200; the limiter consults `ITenantRateLimitPolicy` and applies the returned `TenantRateLimitDecision`.
- Both `.csproj` files in the solution version-bumped to `0.8.0` (invariant 27) — see the coordination note above.
- `HoneyDrunk.Kernel/CHANGELOG.md` and `HoneyDrunk.Kernel/README.md` updated.
- Repo-level `CHANGELOG.md` gets a new `[0.8.0]` entry (or appends to the in-progress entry from ADR-0042 if it landed first).

## Proposed Implementation
1. **`AddGridRateLimiting`** — register `services.AddRateLimiter(options => ...)`. Inside the configure delegate:
   - Set `options.RejectionStatusCode = StatusCodes.Status429TooManyRequests`.
   - Set `options.OnRejected` to a delegate that:
     - Reads `IGridContext.CorrelationId`, `IGridContext.TenantId` (or `null` if anonymous), the tenant's `tier` (or `null` for anonymous), the lease metadata's retry-after (`lease.TryGetMetadata(MetadataName.RetryAfter, out TimeSpan retryAfter)`), and the request `HttpContext`.
     - Sets the `Retry-After` header in **seconds** (not HTTP-date).
     - Writes the RFC 7807 `application/problem+json` body. For authenticated rejections include `tier` and `retry_after_seconds` and `correlation_id`; for anonymous rejections omit `tier` and omit any tenant-identifying field. Never include `tenant_id`.
     - The `type` URI is the constant `https://docs.honeydrunkstudios.com/errors/rate-limited` (ADR-0067 D6); the docs site at that URI is authored as a separate follow-up — the URI here is stable regardless.
     - `title` is the fixed string `Rate limit exceeded`.
   - Register a `PartitionedRateLimiter.Create<HttpContext, string>(...)` global limiter (or per-policy partitioned limiters under `options.AddPolicy(...)`). The partition factory chooses a partition key per request:
     - If the request lands an authenticated `IGridContext.TenantId` that is not `TenantId.Internal`, partition on `TenantId.Value`. Call `ITenantRateLimitPolicy.EvaluateAsync(tenantId, operationKey, ct)` (the `operationKey` is the endpoint route name or a stable per-endpoint string; document the convention at the extension method) to obtain a `TenantRateLimitDecision`, and build a `TokenBucketRateLimiter` partition limiter from the tier configuration the policy implies. The token-bucket parameters (capacity, replenishment rate, queue length) are sourced from `ITenantRateLimitPolicy`'s decision shape — extend the decision-consumption path to read per-tier limits from the policy (the policy implementation in Notify Cloud per ADR-0067 D3 is responsible for the per-tier numbers; the Kernel substrate just consumes the decision). If `ITenantRateLimitPolicy` returns the `NoopTenantRateLimitPolicy`'s `Allow` decision, the partition limiter is effectively unbounded (`Allow` is the existing noop behaviour — preserve it).
     - If the request is `TenantId.Internal`, bypass the limiter — return `RateLimitPartition.GetNoLimiter(...)` so internal callers see no behaviour change (ADR-0026 D4: internal is always `Allow`).
     - If the request is anonymous (no authenticated `TenantId`), partition on `CF-Connecting-IP` (the Cloudflare header per ADR-0029); fall back to `HttpContext.Connection.RemoteIpAddress` when the header is absent (dev/staging paths that bypass Cloudflare). Apply a `TokenBucketRateLimiter` from `GridRateLimitOptions.AnonymousPolicy` (default 60 requests/minute, 10 requests/second burst per ADR-0067 D5).
     - If the request is an API-key-validation pre-auth call (the endpoint is opted into the API-key-prefix policy via attribute, or the policy name is `"anon"` but a configured "treat-as-api-key-prefix" predicate matches), partition on the first 8 characters of the API key — the non-secret display prefix. The endpoint that owns this hook is Notify Cloud's (or any future API-key-bearing Node's); Kernel exposes the seam.
   - Register the three default-named policies via `options.AddPolicy("tier", ...)`, `options.AddPolicy("anon", ...)`, `options.AddPolicy("quota-billable", ...)`. `"quota-billable"` is **composed** with `"tier"` — D9 states "composed with `\"tier\"` on endpoints that count toward daily/monthly quota." The Phase-1 implementation of `"quota-billable"` is that endpoints attributed with it inherit the `"tier"` partition but emit an additional billing-event hook (the *quota counter* itself lives in the policy implementation, per ADR-0067 D8; Kernel does not own the counter store). State explicitly in the XML doc-comment that the `"quota-billable"` policy in Kernel is **a marker** for endpoints that should accumulate quota — the quota *enforcement* (the calendar-anchored counter check) lives in the consuming Node's `ITenantRateLimitPolicy` implementation, which is responsible for returning a `TenantRateLimitDecision` that reflects the quota status. Kernel does not ship a quota counter.
2. **`UseGridRateLimiting`** — call `app.UseRateLimiter()` and additionally insert the small response-decorating middleware that reads the limiter state and emits the `RateLimit-*` headers. The headers are emitted on every response from a rate-limited endpoint — 200, 4xx, 5xx, and 429. When multiple limits apply (per-second burst, per-minute sustained, daily-quota), the headers report the most-restrictive limit currently in effect (the limit closest to firing). Do not emit the `X-RateLimit-*` legacy mirrors. Document the required middleware ordering on the XML doc-comment: **after** `UseRouting`, `UseAuthentication`, and `UseGridContext`; **before** endpoint dispatch.
3. **`GridRateLimitOptions`** — a small options class. Default values match ADR-0067 D5 (anonymous: 60/min, 10/sec burst). Exposes a `Func<HttpContext, string?>` hook for the API-key-prefix extraction (default null; the consuming Node provides it). Exposes a `Func<HttpContext, string>` hook for the per-endpoint `operationKey` (default: the endpoint route name).
4. **`GridRateLimitPolicies`** — `public static class` with the three `public const string` policy names. Consuming Nodes use them in `[EnableRateLimiting(GridRateLimitPolicies.Tier)]` so policy-name typos are compile-time errors.
5. **Unit tests** — under the repo's existing test stack (per ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet). Use `Microsoft.AspNetCore.TestHost` / `WebApplicationFactory<TStartup>` for the middleware integration tests; no `Thread.Sleep` (invariant 51) — drive token-bucket timing via injected `TimeProvider` or `Microsoft.AspNetCore.RateLimiting`'s test hooks. Assert:
   - Authenticated request with a `TenantId` lands in the tenant-keyed partition.
   - `TenantId.Internal` bypasses (no limiter applied; no headers — or headers reflecting effectively-unbounded; match the bypass semantics).
   - Anonymous request keys on `CF-Connecting-IP` when present.
   - Anonymous request falls back to connection IP when `CF-Connecting-IP` is absent.
   - 429 response is `application/problem+json` with the exact field set: `type`, `title` = "Rate limit exceeded", `status` = 429, `detail`, `instance`, `tier` (authenticated only — **absent for anonymous**), `retry_after_seconds`, `correlation_id`. `tenant_id` is **absent**.
   - `Retry-After` header is in seconds (not HTTP-date).
   - `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers are present on a successful 200 from a rate-limited endpoint.
   - Legacy `X-RateLimit-*` headers are **not** emitted.
   - The middleware calls `ITenantRateLimitPolicy.EvaluateAsync` (use NSubstitute to verify); the returned `TenantRateLimitDecision` shapes the partition limiter.
   - The three named policies are discoverable via `[EnableRateLimiting("tier")]` / `[EnableRateLimiting("anon")]` / `[EnableRateLimiting("quota-billable")]`.
6. **Versioning** — bump every non-test `.csproj` in the solution to `0.8.0` in one commit (invariant 27) — see the coordination note for the case where ADR-0042's packet 02 has already done the bump and this packet appends. Add a repo-level `[0.8.0]` CHANGELOG entry (or append). Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel` (the runtime package has functional changes); the `HoneyDrunk.Kernel.Abstractions` package gets no per-package CHANGELOG entry from this packet (no functional change to Abstractions; alignment bump only, no noise entry per invariant 12/27). Update `HoneyDrunk.Kernel/README.md` to document the new extension methods.

## Affected Files
- `HoneyDrunk.Kernel/` — new files: `RateLimiting/GridRateLimitOptions.cs`, `RateLimiting/GridRateLimitPolicies.cs`, `RateLimiting/GridRateLimitingExtensions.cs` (or the repo's existing convention for hosting extensions — the file `Hosting/HoneyDrunkServiceCollectionExtensions.cs` already houses the existing extensions; either co-locate or split into a dedicated `RateLimiting/` folder, per the repo's preference).
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump (or alignment bump if ADR-0042 #02 already bumped).
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — alignment bump only (no new types).
- `HoneyDrunk.Kernel/CHANGELOG.md`, `HoneyDrunk.Kernel/README.md`.
- Repo-level `CHANGELOG.md`.
- The Kernel test project — new tests under `HoneyDrunk.Kernel.Tests/RateLimiting/`.

## NuGet Dependencies
- **`HoneyDrunk.Kernel`** — new `PackageReference` to `Microsoft.AspNetCore.RateLimiting` (the .NET 8+ built-in; the package may already be transitively present via `Microsoft.AspNetCore.App` on the host. Confirm whether `HoneyDrunk.Kernel`'s `.csproj` targets `Microsoft.AspNetCore.App` shared framework or imports the assembly explicitly; in either case the namespace `Microsoft.AspNetCore.RateLimiting` becomes available on the Kernel runtime once referenced. State the choice in the PR.) Plus `Microsoft.Extensions.Options` (likely already referenced).
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions. Nothing from this packet lands in Abstractions.
- **Kernel test project** — `Microsoft.AspNetCore.Mvc.Testing` (for `WebApplicationFactory<TStartup>`) if not already referenced; otherwise the existing test stack covers it.

## Boundary Check
- [x] `AddGridRateLimiting` / `UseGridRateLimiting` live in `HoneyDrunk.Kernel` runtime per ADR-0067 D9 explicit placement.
- [x] No new abstractions in `HoneyDrunk.Kernel.Abstractions` — the primitive (`ITenantRateLimitPolicy`) is ADR-0026's; this packet is wiring only.
- [x] No dependency on `HoneyDrunk.Transport`, `HoneyDrunk.Notify`, or any other HoneyDrunk runtime package — Kernel sits at the root of the DAG (invariant 4).
- [x] No quota counter store ships here — Kernel does not own the counter (ADR-0067 D8). The `"quota-billable"` policy is a marker; quota enforcement lives in the consuming Node's `ITenantRateLimitPolicy` implementation.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel` exposes `AddGridRateLimiting(this IServiceCollection, Action<GridRateLimitOptions>?)` and `UseGridRateLimiting(this IApplicationBuilder)` extension methods
- [ ] `AddGridRateLimiting` wires ASP.NET Core `RateLimiter` services, the partition factory reading `IGridContext.TenantId` (with `TenantId.Internal` bypass), and the `OnRejected` delegate
- [ ] The three default-named policies are registered: `GridRateLimitPolicies.Tier = "tier"`, `GridRateLimitPolicies.Anonymous = "anon"`, `GridRateLimitPolicies.QuotaBillable = "quota-billable"`
- [ ] The 429 response body is `application/problem+json` with exact fields: `type` (= `https://docs.honeydrunkstudios.com/errors/rate-limited`), `title` (= `Rate limit exceeded`), `status` (= 429), `detail`, `instance`, `tier` (authenticated only — absent for anonymous), `retry_after_seconds`, `correlation_id`; `tenant_id` is absent (unit-tested)
- [ ] The `Retry-After` header is in seconds, not HTTP-date (unit-tested)
- [ ] `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers are present on every response from a rate-limited endpoint (200, 4xx, 5xx, 429); the legacy `X-RateLimit-*` mirrors are NOT emitted (unit-tested)
- [ ] When multiple limits apply, the `RateLimit-*` headers report the most-restrictive limit currently in effect
- [ ] Anonymous endpoints key on `CF-Connecting-IP` with `HttpContext.Connection.RemoteIpAddress` fallback (unit-tested both paths)
- [ ] Anonymous defaults are 60 requests/minute and 10 requests/second burst (ADR-0067 D5), tunable via `GridRateLimitOptions`
- [ ] The API-key-prefix partition seam is exposed on `GridRateLimitOptions` (a hook the consuming Node fills); default null
- [ ] The middleware calls `ITenantRateLimitPolicy.EvaluateAsync` for authenticated requests (unit-tested with NSubstitute)
- [ ] `[EnableRateLimiting("tier")]`, `[EnableRateLimiting("anon")]`, `[EnableRateLimiting("quota-billable")]` route requests to the correct partition (unit-tested)
- [ ] No new types in `HoneyDrunk.Kernel.Abstractions` (invariant 1 — Abstractions are zero-HoneyDrunk-dependency and this packet adds wiring, not contracts)
- [ ] `HoneyDrunk.Kernel` does NOT take a `PackageReference` on `HoneyDrunk.Transport` or any other HoneyDrunk runtime package (invariant 4)
- [ ] Both non-test `.csproj` files in the solution are at the same version (`0.8.0` — bumped here, or aligned with ADR-0042's prior bump if it landed first) in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a `[0.8.0]` entry (or appends to the in-progress entry); per-package `HoneyDrunk.Kernel/CHANGELOG.md` has a `[0.8.0]` entry for the rate-limiting wiring; `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` gets NO entry (no functional change)
- [ ] `HoneyDrunk.Kernel/README.md` documents the new extension methods and the required middleware ordering (after `UseRouting`, `UseAuthentication`, `UseGridContext`; before endpoint dispatch)
- [ ] Tests contain no `Thread.Sleep` (invariant 51); token-bucket timing driven via `TimeProvider` or the rate-limiting test hooks
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Coordinate the version-bump with the `adr-0042-idempotency` initiative.** Both initiatives bump `HoneyDrunk.Kernel` from `0.7.0` to `0.8.0`. If ADR-0042 packet 02 lands first, this packet appends to the in-progress `[0.8.0]` entry. If this packet lands first, ADR-0042 packet 02 appends to ours. State the chosen path in the PR.
- [ ] **The 429 `type` URI points at `https://docs.honeydrunkstudios.com/errors/rate-limited`** — that docs page does not yet exist at packet-execution time. The URI is stable (it does not change when the page is authored), so the packet ships the constant URI now. The docs page authoring is a separate, deferred follow-up (recorded in the dispatch plan's Deferred Follow-ups). A 429-responding consumer following the URI today will land on a 404 page until the docs follow-up lands — acceptable, since the URI itself is the machine-readable identifier and the field set in the body is sufficient for SDK consumers per ADR-0057 D8.
- [ ] **Publishing the upstream NuGet package** — after this packet merges, a human pushes a git release tag on `HoneyDrunk.Kernel` for `0.8.0` so consuming Nodes (Notify Cloud at standup time, Web.Rest, Communications, any future deployable) can compile against it. Agents never tag or publish.

## Referenced ADR Decisions
**ADR-0067 D1 — Primary substrate.** ASP.NET Core `RateLimiter` middleware (`Microsoft.AspNetCore.RateLimiting`), partition-keyed on `TenantId` via `PartitionedRateLimiter.Create<TResource, TPartitionKey>`. First-party, in-process, free. `OnRejected` hook customizes the 429 envelope. Cloudflare's edge rate limiting (per ADR-0029) sits above for gross-abuse absorption; the two do not overlap.

**ADR-0067 D5 — Identity resolution and limiter key.** Authenticated: `TenantId` from `IGridContext.TenantId`; `TenantId.Internal` bypasses (per ADR-0026 D4). Anonymous: `CF-Connecting-IP` with `HttpContext.Connection.RemoteIpAddress` fallback (per ADR-0029); anonymous defaults: 60/min, 10/sec burst. API-key-validation pre-auth endpoints: keyed on the first 8 characters of the API key (non-secret display prefix per the API-key-store contract Notify Cloud commits in ADR-0027).

**ADR-0067 D6 — 429 response shape (RFC 7807).** `application/problem+json` body with exact field set: `type` (= `https://docs.honeydrunkstudios.com/errors/rate-limited`), `title` (= `Rate limit exceeded`), `status` (= 429), `detail`, `instance` (request path), `tier` (lower-cased — `"free"` / `"pro"` / `"scale"`; OMITTED for anonymous), `retry_after_seconds`, `correlation_id` (= `IGridContext.CorrelationId`). `tenant_id` is **deliberately NOT in the body**. `Retry-After` header in seconds, not HTTP-date.

**ADR-0067 D7 — Success-side `RateLimit-*` headers.** `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` on every response from a rate-limited endpoint (200, 4xx, 5xx, 429). IETF draft form only (`draft-ietf-httpapi-ratelimit-headers`); legacy `X-RateLimit-*` mirrors NOT emitted. When multiple limits apply, report the most-restrictive limit currently in effect. `RateLimit-Policy` header deferred.

**ADR-0067 D8 — Rate limit vs. quota.** Rate limit (per-second, per-minute): in-process token bucket (or distributed if D5b triggers); hard 429. Quota (per-day, per-month): per-tenant counter store keyed on `(TenantId, CounterKey, Window)` with calendar-anchored reset; tier-dependent overage (Free hard 429; Pro/Scale billable via Stripe meter). Kernel does NOT ship the counter store — the consuming Node's `ITenantRateLimitPolicy` implementation owns it (ADR-0067 D8).

**ADR-0067 D9 — Kernel extension methods + named policies.** `AddGridRateLimiting(this IServiceCollection, Action<GridRateLimitOptions>?)` and `UseGridRateLimiting(this IApplicationBuilder)` in `HoneyDrunk.Kernel`. Three default-named policies: `"tier"` (per-tenant token bucket — authenticated default), `"anon"` (per-IP token bucket — unauthenticated default), `"quota-billable"` (composed with `"tier"` for endpoints that count toward daily/monthly quota — marker only at Kernel level; quota enforcement in the consuming Node's policy). Per-endpoint via `[EnableRateLimiting("policy-name")]`. Per-Node opt-in.

**ADR-0067 §Operational Consequences — In-process drift.** "Until D5b's distributed-limiter migration trigger fires, a Notify Cloud tenant whose traffic lands on different replicas can in principle observe slightly higher aggregate limits than their tier nominally allows... The drift is bounded — at 2 replicas the maximum drift is 2× — and is acceptable at the v1 paying-tenant ceiling." Kernel's wiring uses the in-process limiter; the migration to a distributed backing is a future ADR.

**ADR-0026 D4 (referenced) — `ITenantRateLimitPolicy`.** `EvaluateAsync(TenantId, string operationKey, CancellationToken) → ValueTask<TenantRateLimitDecision>`. The decision carries `Outcome` (`Allow` / `Throttle` / `Reject`), optional `RetryAfter`, and a non-PII `Reason`. `TenantId.Internal` is always `Allow` (short-circuit). Unchanged by this packet.

**Invariant 5 / 6 — GridContext present and populated.** The middleware ordering — `GridContextMiddleware` (the existing `UseGridContext`) before the rate-limiter middleware — is required for `TenantId` to be available at partition-factory time. Documented at `UseGridRateLimiting`.

**Invariant 8 — Secret values never appear in logs or traces.** The 429 body's `detail` field, the audit emit (packet 03), and the Pulse metric (packet 04) carry no secret material. API key prefixes (8-character display prefix per the API-key-store contract Notify Cloud commits in ADR-0027) are non-secret display values and may appear; the full key never does. Tests assert the API key prefix is at most 8 characters and that the full key is never logged or reflected in any header or body.

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Nothing in this packet lands in `HoneyDrunk.Kernel.Abstractions`. All wiring stays in the `HoneyDrunk.Kernel` runtime package.
- **Invariant 4 — DAG; Kernel is at the root.** Do NOT take a `PackageReference` on `HoneyDrunk.Transport` or any other HoneyDrunk runtime package. ASP.NET Core's `Microsoft.AspNetCore.RateLimiting` is a Microsoft framework package, not a HoneyDrunk dependency.
- **Invariant 5 / 6 — GridContext present and populated.** Middleware ordering: `UseGridContext` runs before `UseGridRateLimiting`. Document this on the `UseGridRateLimiting` XML doc-comment so consuming Nodes set up the pipeline correctly.
- **Invariant 8 — Secret values never appear in logs or traces.** The 429 body and the `Retry-After` header carry no secret material. The API-key-prefix partition key is the non-secret 8-character display prefix; the full key never appears in any partition key, log, header, or body. Add a test that publishes a request with a full API key and asserts the full key is not present in the partition-key trace, the 429 body, or any header.
- **Invariant 13 — all public APIs have XML documentation.** `AddGridRateLimiting`, `UseGridRateLimiting`, `GridRateLimitOptions`, `GridRateLimitPolicies`, and the public constants all carry XML doc-comments. The required-middleware-ordering note is on `UseGridRateLimiting`'s doc.
- **Invariant 27 — one version across the solution.** Both `.csproj` files go to `0.8.0` in one commit (or both stay at `0.8.0` if ADR-0042 packet 02 already did the bump and this packet appends). Partial bumps are forbidden.
- **Invariant 12 — per-package CHANGELOGs updated only for packages with functional changes.** `HoneyDrunk.Kernel/CHANGELOG.md` gets an entry (real changes); `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` gets no entry (alignment bump only).
- **Invariant 51 — no `Thread.Sleep` in test code.** Token-bucket timing driven via `TimeProvider` or the rate-limiting test hooks.
- **Records drop the `I`; interfaces keep it.** `GridRateLimitOptions` (record-style options class — name carries no `I` regardless). `GridRateLimitPolicies` (static class — no `I`). No new interfaces in this packet.
- **The 429 `type` URI is stable now; the docs page is deferred.** Ship the URI as the constant in code; do not block on the docs follow-up.
- **Kernel does NOT ship the quota counter store.** The `"quota-billable"` policy is a marker. Quota enforcement (calendar-anchored counter, billable-overage transition) lives in the consuming Node's `ITenantRateLimitPolicy` implementation per ADR-0067 D8.

## Labels
`feature`, `tier-2`, `core`, `adr-0067`, `wave-2`

## Agent Handoff

**Objective:** Ship `AddGridRateLimiting` / `UseGridRateLimiting` extension methods, the ASP.NET Core `RateLimiter` middleware wiring, the RFC 7807 429 envelope, the IETF `RateLimit-*` headers, the three default-named policies, and the partition-key resolution (tenant / anonymous-IP / API-key-prefix) in `HoneyDrunk.Kernel`. Bump the `HoneyDrunk.Kernel` solution to `0.8.0` (or align with `adr-0042-idempotency` if it bumped first).

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the substrate every Node that exposes an HTTP surface composes to enforce per-tenant rate limits with a consistent response shape.
- Feature: ADR-0067 Inbound Rate Limiting and Quota Enforcement rollout, Wave 2 (the foundation).
- ADRs: ADR-0067 D1/D5/D6/D7/D8/D9 (primary), ADR-0026 D4 (`ITenantRateLimitPolicy` already exists — consumed, not changed), ADR-0029 (Cloudflare `CF-Connecting-IP` header), ADR-0027 (Notify Cloud first consumer — currently Proposed; the production policy lands separately when ADR-0027 ships), ADR-0035 D1 (additive minor bump), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0067 should be Accepted before the substrate ships.

**Constraints:**
- No types land in `HoneyDrunk.Kernel.Abstractions` (invariant 1). All wiring stays in the Kernel runtime package.
- No `PackageReference` on `HoneyDrunk.Transport` or any other HoneyDrunk runtime package (invariant 4).
- Middleware ordering — `UseGridContext` before `UseGridRateLimiting`; documented at the extension method (invariant 5/6).
- Full API keys never appear in partition keys, logs, headers, or bodies — only the 8-character display prefix (invariant 8).
- Bump both non-test `.csproj` files to `0.8.0` in one commit (invariant 27); coordinate with `adr-0042-idempotency` initiative which also bumps Kernel to `0.8.0`.
- Kernel does NOT ship the quota counter store — that lives in the consuming Node's policy implementation (ADR-0067 D8).
- The 429 `type` URI is `https://docs.honeydrunkstudios.com/errors/rate-limited` — stable now; docs page is a deferred follow-up.

**Key Files:**
- `HoneyDrunk.Kernel/RateLimiting/` — new directory with `GridRateLimitOptions.cs`, `GridRateLimitPolicies.cs`, `GridRateLimitingExtensions.cs` (or co-located with existing `Hosting/` extensions per repo convention).
- `HoneyDrunk.Kernel/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- Both `.csproj` files for the version bump (or alignment).
- Kernel test project — new `RateLimiting/` tests.

**Contracts:**
- `AddGridRateLimiting(this IServiceCollection, Action<GridRateLimitOptions>?)` (new extension method).
- `UseGridRateLimiting(this IApplicationBuilder)` (new extension method).
- `GridRateLimitOptions` (new public options class).
- `GridRateLimitPolicies` (new public static class with three string constants).
- `ITenantRateLimitPolicy` (existing — consumed, not changed).
